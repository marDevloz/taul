import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:taul/infrastructure/sync/sync_wire_format.dart';

/// HTTPS sync client for connecting to a remote sync server.
///
/// Validates TLS fingerprint, enforces timeouts, handles chunked sends.
class SyncClient {
  static const _connectTimeout = Duration(seconds: 10);
  static const _readTimeout = Duration(seconds: 30);
  static const _chunkSize = 100;
  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 2);

  SyncClient();

  /// Sends a sync request to the remote server.
  Future<SyncResponse> sync({
    required String host,
    required int port,
    required List<int> expectedFingerprint,
    required String pairingCode,
    required SyncRequest request,
  }) async {
    final uri = Uri.parse('https://$host:$port/sync');
    final client = _createClient();

    try {
      final actualFingerprint = await _getFingerprint(host, port);
      if (!_matchFingerprint(expectedFingerprint, actualFingerprint)) {
        throw const TlsFingerprintMismatchException();
      }

      if (request.entries.length > _chunkSize) {
        return await _sendChunked(
          client: client, uri: uri, pairingCode: pairingCode, request: request,
        );
      }

      return await _sendWithRetry(
        client: client, uri: uri, pairingCode: pairingCode, request: request,
      );
    } on SocketException {
      throw const SyncInterruptedException();
    } on TimeoutException {
      throw const SyncInterruptedException();
    } finally {
      client.close();
    }
  }

  Future<SyncResponse> _sendWithRetry({
    required http.Client client,
    required Uri uri,
    required String pairingCode,
    required SyncRequest request,
  }) async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await _sendSingle(
          client: client, uri: uri, pairingCode: pairingCode, request: request,
        );
      } on RateLimitException {
        if (attempt == _maxRetries - 1) rethrow;
        await Future<void>.delayed(_retryDelay * (attempt + 1));
      }
    }
    throw const SyncInterruptedException();
  }

  http.Client _createClient() {
    return http.Client();
  }

  Future<SyncResponse> _sendSingle({
    required http.Client client,
    required Uri uri,
    required String pairingCode,
    required SyncRequest request,
  }) async {
    final response = await client
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            'x-pairing-code': pairingCode,
          },
          body: jsonEncode(request.toJson()),
        )
        .timeout(_readTimeout);

    return _handleResponse(response);
  }

  Future<SyncResponse> _sendChunked({
    required http.Client client,
    required Uri uri,
    required String pairingCode,
    required SyncRequest request,
  }) async {
    final entries = request.entries;
    SyncResponse? lastResponse;

    for (var i = 0; i < entries.length; i += _chunkSize) {
      final chunk = entries.sublist(i, (i + _chunkSize).clamp(0, entries.length));
      final chunkRequest = SyncRequest(
        deviceId: request.deviceId,
        lastSyncAt: request.lastSyncAt,
        entries: chunk,
      );

      final response = await client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'x-pairing-code': pairingCode,
            },
            body: jsonEncode(chunkRequest.toJson()),
          )
          .timeout(_readTimeout);

      lastResponse = _handleResponse(response);
    }

    return lastResponse ??
        SyncResponse(
          deviceId: request.deviceId,
          entriesReceived: 0,
          conflictsCount: 0,
        );
  }

  SyncResponse _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        return SyncResponse.fromJson(
          Map<String, dynamic>.from(
            // ignore: avoid_dynamic_calls
            (response.body as dynamic) as Map,
          ),
        );
      case 401:
        throw const PairingCodeRejectedException();
      case 409:
        throw const SyncConflictException();
      case 429:
        throw const RateLimitException();
      default:
        if (response.statusCode >= 500) {
          throw ServerErrorException(response.statusCode);
        }
        throw UnexpectedResponseException(response.statusCode);
    }
  }

  Future<List<int>> _getFingerprint(String host, int port) async {
    final socket = await SecureSocket.connect(
      host,
      port,
      timeout: _connectTimeout,
      onBadCertificate: (_) => true,
    );
    final der = socket.peerCertificate?.der;
    await socket.close();
    return der?.cast<int>() ?? [];
  }

  bool _matchFingerprint(List<int> expected, List<int> actual) {
    if (expected.length != actual.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) return false;
    }
    return true;
  }
}

// ── Exceptions ──

class TlsFingerprintMismatchException implements Exception {
  const TlsFingerprintMismatchException();
  @override
  String toString() => 'TLS fingerprint does not match expected value';
}

class PairingCodeRejectedException implements Exception {
  const PairingCodeRejectedException();
  @override
  String toString() => 'Pairing code rejected by server';
}

class SyncConflictException implements Exception {
  const SyncConflictException();
  @override
  String toString() => 'Sync conflict detected';
}

class RateLimitException implements Exception {
  const RateLimitException();
  @override
  String toString() => 'Rate limited — server busy';
}

class ServerErrorException implements Exception {
  final int statusCode;
  const ServerErrorException(this.statusCode);
  @override
  String toString() => 'Server error ($statusCode)';
}

class UnexpectedResponseException implements Exception {
  final int statusCode;
  const UnexpectedResponseException(this.statusCode);
  @override
  String toString() => 'Unexpected response ($statusCode)';
}

class SyncInterruptedException implements Exception {
  const SyncInterruptedException();
  @override
  String toString() => 'Sync interrupted — server unreachable';
}
