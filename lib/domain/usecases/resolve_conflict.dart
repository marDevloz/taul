import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/repositories/i_sync_repository.dart';
import 'package:uuid/uuid.dart';

class ResolveConflict {
  final ISyncRepository _syncRepository;
  final Uuid _uuid;

  ResolveConflict({
    required ISyncRepository syncRepository,
    Uuid? uuid,
  })  : _syncRepository = syncRepository,
        _uuid = uuid ?? const Uuid();

  Future<void> call({
    required Conflict conflict,
    required ConflictResolution resolution,
  }) async {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        await _syncRepository.applyConflictResolution(
          conflict: conflict,
          resolution: resolution,
        );
        break;
      case ConflictResolution.keepRemote:
        final winner = conflict.remoteVersion.copyWith(
          updatedAt: DateTime.now(),
          version: conflict.remoteVersion.version + 1,
        );
        await _syncRepository.applyConflictResolution(
          conflict: conflict,
          resolution: resolution,
          entryToUpdate: winner,
        );
        break;
      case ConflictResolution.keepBoth:
        final copy = conflict.remoteVersion.copyWith(
          id: _uuid.v4(),
          updatedAt: DateTime.now(),
          version: 1,
          deletedAt: null,
        );
        await _syncRepository.applyConflictResolution(
          conflict: conflict,
          resolution: resolution,
          entryToInsert: copy,
        );
        break;
      case ConflictResolution.pending:
        return;
    }
  }
}
