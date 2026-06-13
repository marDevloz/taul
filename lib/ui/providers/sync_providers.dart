import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/sync_state.dart';
import 'package:taul/infrastructure/database/conflict_dao.dart';
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/sync/certificate_manager.dart';
import 'package:taul/infrastructure/sync/pairing_service.dart';
import 'package:taul/infrastructure/sync/sync_client.dart';
import 'package:taul/infrastructure/sync/sync_coordinator.dart';
import 'package:taul/infrastructure/sync/sync_repository_impl.dart';
import 'package:taul/infrastructure/sync/sync_server.dart';
import 'package:taul/infrastructure/sync/sync_service.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';
import 'package:taul/ui/providers/device_id_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
export 'package:taul/ui/providers/sync_client_providers.dart'
    show connectAndSyncProvider;

/// Manages certificate lifecycle for HTTPS sync.
final certificateManagerProvider = FutureProvider<CertificateManager>((ref) {
  return CertificateManager.create();
});

/// Coordinates the sync exchange on the server side.
final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final db = ref.watch(databaseProvider);
  final entryDao = EntryDao(db);
  final conflictDao = ConflictDao(db);
  final repo = SyncRepositoryImpl(entryDao: entryDao, conflictDao: conflictDao);
  final deviceId = ref.watch(deviceIdProvider).valueOrNull ?? 'unknown';
  return SyncCoordinator(
    repo: repo,
    conflictDao: conflictDao,
    localDeviceId: deviceId,
  );
});

/// Manages pairing codes and IP detection.
final pairingServiceProvider = Provider<PairingService>((ref) {
  return PairingService();
});

/// The sync server instance. Only created when sync is started.
final syncServerProvider = FutureProvider.family<SyncServer, String>(
  (ref, pairingCode) async {
    final certManager = ref.watch(certificateManagerProvider).valueOrNull;
    if (certManager == null) throw Exception('Certificate manager not ready');
    final coordinator = ref.watch(syncCoordinatorProvider);
    return SyncServer(
      certManager: certManager,
      pairingCode: pairingCode,
      onRequest: coordinator.handleSyncRequest,
      logger: Logger(),
    );
  },
);

/// The main sync service. Returns null until startSync is called.
final syncServiceProvider = StateProvider<SyncService?>((ref) => null);

final syncStateProvider = StateProvider<SyncState>((ref) => SyncState.idle);

/// Stores the result of the last completed client sync.
final lastSyncResultProvider = StateProvider<ProcessSyncResult?>(
  (ref) => null,
);

final conflictCountProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);
  final dao = ConflictDao(db);
  while (true) {
    yield await dao.getPendingCount();
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

final pendingConflictsProvider = FutureProvider<List<Conflict>>((ref) async {
  final db = ref.watch(databaseProvider);
  final dao = ConflictDao(db);
  return dao.getByResolution(ConflictResolution.pending);
});

final startSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final existing = ref.read(syncServiceProvider);
    if (existing != null) {
      // Already running — no-op (idempotent)
      return;
    }

    _startCancelled = false;
    ref.read(syncStateProvider.notifier).state = SyncState.pairing;

    try {
      // 1. Generate pairing code
      final pairingService = ref.read(pairingServiceProvider);
      final pairingCode = pairingService.generateCode();

      // 2. Create the sync server (certificate + setup)
      final server = await ref.read(syncServerProvider(pairingCode).future);
      if (_startCancelled) {
        _resetSyncSession(ref);
        return;
      }

      // 3. Start the HTTPS server (socket bind)
      final port = await server.start();
      if (_startCancelled) {
        await server.stop();
        _resetSyncSession(ref);
        return;
      }

      // 4. Get device ID and create sync service
      final deviceId = await ref.read(deviceIdProvider.future);
      final client = SyncClient();
      final coordinator = ref.read(syncCoordinatorProvider);
      final service = SyncService(
        server: server,
        client: client,
        deviceId: deviceId,
        onRequest: coordinator.handleSyncRequest,
        log: Logger(),
      );

      // 5. Store service and listen to state changes
      ref.read(syncServiceProvider.notifier).state = service;
      service.stateStream.listen((state) {
        ref.read(syncStateProvider.notifier).state = state;
      });

      // 6. Store port + pairing code for UI consumption
      _currentPort = port;
      _currentPairingCode = pairingCode;
      _currentPairingService = pairingService;
    } catch (e, st) {
      if (_startCancelled) {
        // Stop was pressed during a failing start — just go idle
        _resetSyncSession(ref);
        return;
      }
      Logger().e('Failed to start sync', error: e, stackTrace: st);
      ref.read(syncStateProvider.notifier).state = SyncState.error;
      // Auto-recover after 5 seconds
      Future<void>.delayed(const Duration(seconds: 5), () {
        ref.read(syncStateProvider.notifier).state = SyncState.idle;
      });
    }
  };
});

// Track current sync session details for the UI.
int? _currentPort;
String? _currentPairingCode;
PairingService? _currentPairingService;
bool _startCancelled = false;

/// Current sync server port (for QR code generation).
final syncPortProvider = Provider<int?>((ref) => _currentPort);

/// Current pairing code for device pairing.
final syncPairingCodeProvider = Provider<String?>((ref) => _currentPairingCode);

/// Current pairing service (for local IP detection).
final syncPairingServiceProvider = Provider<PairingService?>(
  (ref) => _currentPairingService,
);

final stopSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // Signal any in-flight start to abort
    _startCancelled = true;

    final service = ref.read(syncServiceProvider);
    if (service != null) {
      try {
        await service.stop();
      } catch (e, st) {
        Logger().e('Error stopping sync service', error: e, stackTrace: st);
      }
    }

    _resetSyncSession(ref);
  };
});

/// Resets all sync session state back to idle.
void _resetSyncSession(Ref ref) {
  ref.read(syncServiceProvider.notifier).state = null;
  ref.read(syncStateProvider.notifier).state = SyncState.idle;
  _currentPort = null;
  _currentPairingCode = null;
  _currentPairingService = null;
}

final resolveConflictProvider =
    Provider<Future<void> Function(int, ConflictResolution)>((ref) {
  return (int id, ConflictResolution resolution) async {
    final db = ref.read(databaseProvider);
    final dao = ConflictDao(db);
    await dao.updateResolution(id, resolution);
    ref.invalidate(pendingConflictsProvider);
    ref.invalidate(conflictCountProvider);
  };
});
