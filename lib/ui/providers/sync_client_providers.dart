import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taul/domain/entities/sync_state.dart';
import 'package:taul/infrastructure/sync/sync_client.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';
import 'package:taul/ui/providers/device_id_provider.dart';
import 'package:taul/ui/providers/sync_providers.dart';

/// Parameters for connecting to a remote sync server.
class ConnectParams {
  final String host;
  final int port;
  final List<int> fingerprint;
  final String pairingCode;

  const ConnectParams({
    required this.host,
    required this.port,
    required this.fingerprint,
    required this.pairingCode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectParams &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          fingerprint == other.fingerprint &&
          pairingCode == other.pairingCode;

  @override
  int get hashCode => Object.hash(host, port, fingerprint, pairingCode);
}

// ── TLS trust-on-first-use helpers ──

/// Hex-encode a list of bytes (fingerprint).
String fingerprintToHex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Hex-decode a string back to a list of bytes.
List<int> hexToFingerprint(String hex) {
  if (hex.isEmpty) return [];
  if (hex.length.isOdd) {
    throw ArgumentError('Hex string must have even length, got ${hex.length}');
  }
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

/// Check if a fingerprint is trusted for a given host:port.
/// Returns true if first-time (no trust stored) or if it matches.
/// Throws [TlsFingerprintMismatchException] if a different fingerprint is stored.
Future<bool> checkOrStoreTrust({
  required String host,
  required int port,
  required List<int> fingerprint,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'tls_trust_$host:$port';
  final hex = fingerprintToHex(fingerprint);

  final stored = prefs.getString(key);
  if (stored == null) {
    // First-time trust: store and proceed
    await prefs.setString(key, hex);
    return true;
  }

  if (stored == hex) {
    // Trusted: proceed
    return true;
  }

  // Mismatch: reject
  throw const TlsFingerprintMismatchException();
}

// ── Provider ──

/// Orchestrates the client-side sync flow:
/// 1. Check/establish TLS trust (trust-on-first-use)
/// 2. Fetch local entries modified since last sync
/// 3. Call SyncService.performSync()
/// 4. Process the response via SyncCoordinator.processSyncResponse()
/// 5. Store lastSyncAt for this peer
/// 6. Return ProcessSyncResult
final connectAndSyncProvider =
    FutureProvider.autoDispose.family<ProcessSyncResult, ConnectParams>((ref, params) async {
  final coordinator = ref.read(syncCoordinatorProvider);
  final service = ref.read(syncServiceProvider);
  final deviceId = await ref.read(deviceIdProvider.future);
  final syncRepo = ref.read(syncRepositoryProvider);

  if (service == null) {
    throw StateError('SyncService not available');
  }

  // 1. TLS trust-on-first-use (inside try-catch to set error state on mismatch)
  // 2. Set state to connecting
  ref.read(syncStateProvider.notifier).state = SyncState.connecting;

  try {
    await checkOrStoreTrust(
      host: params.host,
      port: params.port,
      fingerprint: params.fingerprint,
    );

    // 2. Fetch local entries modified since last sync with this peer
    // Use host:port as the peer identifier for client-side lastSyncAt tracking
    final peerKey = '${params.host}:${params.port}';
    final lastSyncAt = await syncRepo.getLastSyncAt(peerKey);
    final localEntries = await syncRepo.getModifiedEntries(lastSyncAt);

    // 3. Build and send sync request with local delta
    final request = SyncRequest(
      deviceId: deviceId,
      lastSyncAt: lastSyncAt,
      entries: localEntries,
    );

    final response = await service.performSync(
      host: params.host,
      port: params.port,
      fingerprint: params.fingerprint,
      pairingCode: params.pairingCode,
      request: request,
    );

    // 4. Process the response
    final result = await coordinator.processSyncResponse(response);

    // 5. Store server's lastSyncAt for next sync
    if (response.serverLastSyncAt != null) {
      await syncRepo.setLastSyncAt(peerKey, response.serverLastSyncAt!);
    }

    // 6. Store result and set state to complete
    ref.read(lastSyncResultProvider.notifier).state = result;
    ref.read(syncStateProvider.notifier).state = SyncState.complete;

    return result;
  } catch (e) {
    // Set state to error on any failure (including TLS trust mismatch)
    ref.read(syncStateProvider.notifier).state = SyncState.error;
    rethrow;
  }
});
