import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/sync_state.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Conflict;
import 'package:taul/infrastructure/database/conflict_dao.dart';
import 'package:taul/infrastructure/sync/sync_service.dart';

final syncServiceProvider = Provider<SyncService?>((ref) => null);

final syncStateProvider = StateProvider<SyncState>((ref) => SyncState.idle);

final conflictCountProvider = StreamProvider<int>((ref) async* {
  final dao = ConflictDao(AppDatabase());
  while (true) {
    yield await dao.getPendingCount();
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

final pendingConflictsProvider = FutureProvider<List<Conflict>>((ref) async {
  final dao = ConflictDao(AppDatabase());
  return dao.getByResolution(ConflictResolution.pending);
});

final startSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final service = ref.read(syncServiceProvider);
    if (service == null) return;
    ref.read(syncStateProvider.notifier).state = SyncState.pairing;
    service.stateStream.listen((state) {
      ref.read(syncStateProvider.notifier).state = state;
    });
    await service.startServer();
  };
});

final stopSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final service = ref.read(syncServiceProvider);
    if (service == null) return;
    await service.stop();
    ref.read(syncStateProvider.notifier).state = SyncState.idle;
  };
});

final resolveConflictProvider =
    Provider<Future<void> Function(int, ConflictResolution)>((ref) {
  return (int id, ConflictResolution resolution) async {
    final dao = ConflictDao(AppDatabase());
    await dao.updateResolution(id, resolution);
    ref.invalidate(pendingConflictsProvider);
    ref.invalidate(conflictCountProvider);
  };
});
