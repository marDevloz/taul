import 'dart:async';

import 'package:logger/logger.dart';
import 'package:taul/domain/entities/sync_state.dart';
import 'package:taul/infrastructure/sync/sync_client.dart';
import 'package:taul/infrastructure/sync/sync_server.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';

class SyncService {
  final SyncServer _server;
  final SyncClient _client;
  final String deviceId;
  final Future<SyncResponse> Function(SyncRequest) onRequest;
  final Logger _log;

  final _stateController = StreamController<SyncState>.broadcast();
  final _recoveryTimers = <Timer>[];
  SyncState _state = SyncState.idle;

  SyncService({
    required SyncServer server,
    required SyncClient client,
    required this.deviceId,
    required this.onRequest,
    Logger? log,
  })  : _server = server,
        _client = client,
        _log = log ?? Logger();

  Stream<SyncState> get stateStream => _stateController.stream;
  SyncState get currentState => _state;

  void _transition(SyncState next) {
    _state = next;
    _stateController.add(next);
  }

  Future<void> startServer() async {
    _transition(SyncState.pairing);
    try {
      await _server.start();
    } catch (e, st) {
      _log.e('Failed to start server', error: e, stackTrace: st);
      _transition(SyncState.error);
      _scheduleRecover();
    }
  }

  Future<SyncResponse> performSync({
    required String host,
    required int port,
    required List<int> fingerprint,
    required String pairingCode,
    required SyncRequest request,
  }) async {
    _transition(SyncState.syncing);
    try {
      final response = await _client.sync(
        host: host,
        port: port,
        expectedFingerprint: fingerprint,
        pairingCode: pairingCode,
        request: request,
      );
      _transition(SyncState.complete);
      return response;
    } catch (e, st) {
      _log.e('Sync failed', error: e, stackTrace: st);
      _transition(SyncState.error);
      _scheduleRecover();
      rethrow;
    }
  }

  void _scheduleRecover() {
    _recoveryTimers.add(
      Timer(const Duration(seconds: 5), () {
        _recoveryTimers.removeWhere((t) => !t.isActive);
        if (_state == SyncState.error) _transition(SyncState.idle);
      }),
    );
  }

  Future<void> stop() async {
    await _server.stop();
    _transition(SyncState.idle);
  }

  void dispose() {
    for (final timer in _recoveryTimers) {
      timer.cancel();
    }
    _recoveryTimers.clear();
    _stateController.close();
  }
}
