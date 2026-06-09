import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:taul/infrastructure/sync/certificate_manager.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';

/// HTTPS sync server using Shelf.
///
/// Listens on a random port (49152–65535), validates pairing code via
/// X-Pairing-Code header, auto-shuts down after 5 min inactivity.
class SyncServer {
  final CertificateManager _certManager;
  final String pairingCode;
  final Future<SyncResponse> Function(SyncRequest) onRequest;
  final Logger _log;

  HttpServer? _server;
  Timer? _inactivityTimer;
  int? _port;
  bool _handlingRequest = false;

  static const _minPort = 49152;
  static const _maxPort = 65535;
  static const _inactivityTimeout = Duration(minutes: 5);

  SyncServer({
    required CertificateManager certManager,
    required this.pairingCode,
    required this.onRequest,
    Logger? logger,
  })  : _certManager = certManager,
        _log = logger ?? Logger();

  int? get port => _port;
  bool get isRunning => _server != null;

  /// Starts the HTTPS server on a random available port.
  Future<int> start() async {
    final context = await _certManager.getContext();
    final handler = const Pipeline()
        .addMiddleware(_logMiddleware())
        .addHandler(_handleRequest);

    // Pick random port in ephemeral range
    _port = _randomPort();

    _server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      _port!,
      securityContext: context,
    );

    _resetInactivityTimer();
    _log.i('Sync server started on port $_port');
    return _port!;
  }

  /// Shuts down the server gracefully.
  Future<void> stop() async {
    _inactivityTimer?.cancel();
    await _server?.close(force: true);
    _server = null;
    _port = null;
    _log.i('Sync server stopped');
  }

  Future<Response> _handleRequest(Request request) async {
    _resetInactivityTimer();

    // Only accept POST /sync
    if (request.method != 'POST' || request.url.path != 'sync') {
      return Response.notFound('Not found');
    }

    // Validate pairing code
    final code = request.headers['x-pairing-code'];
    if (code != pairingCode) {
      return Response.forbidden(
        _encodeError(401, 'Invalid pairing code'),
        headers: {'content-type': 'application/json'},
      );
    }

    // Reject concurrent requests
    if (_handlingRequest) {
      return Response(
        429,
        body: _encodeError(429, 'Sync in progress'),
        headers: {'content-type': 'application/json'},
      );
    }

    _handlingRequest = true;
    try {
      final body = await request.readAsString();
      final syncRequest = SyncRequest.fromJson(
        Map<String, dynamic>.from(
          // ignore: avoid_dynamic_calls
          (body as dynamic) as Map,
        ),
      );

      final response = await onRequest(syncRequest);

      return Response.ok(
        jsonEncode(response.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, st) {
      _log.e('Sync request failed', error: e, stackTrace: st);
      return Response.internalServerError(
        body: _encodeError(500, 'Internal error'),
        headers: {'content-type': 'application/json'},
      );
    } finally {
      _handlingRequest = false;
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, () {
      _log.i('Inactivity timeout — shutting down sync server');
      stop();
    });
  }

  int _randomPort() {
    const range = _maxPort - _minPort;
    return _minPort + (DateTime.now().microsecondsSinceEpoch % range);
  }

  String _encodeError(int code, String message) {
    return jsonEncode(SyncErrorResponse(code: code, message: message).toJson());
  }

  Middleware _logMiddleware() => (handler) {
        return (request) async {
          _log.d('${request.method} ${request.url}');
          return handler(request);
        };
      };
}
