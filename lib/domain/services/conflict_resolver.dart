import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';

class ConflictResolver {
  static List<Conflict> detectConflicts({
    required List<Entry> localEntries,
    required List<Entry> remoteEntries,
    required DateTime? lastSyncAt,
    required String peerDeviceId,
  }) {
    if (lastSyncAt == null) return [];

    final localMap = {for (final e in localEntries) e.id: e};
    final conflicts = <Conflict>[];

    for (final remote in remoteEntries) {
      final local = localMap[remote.id];
      if (local == null) continue; // new entry from remote, no conflict

      final localModified = local.updatedAt.isAfter(lastSyncAt);
      final remoteModified = remote.updatedAt.isAfter(lastSyncAt);

      if (localModified && remoteModified) {
        conflicts.add(Conflict(
          id: 0,
          entryId: remote.id,
          localVersion: local,
          remoteVersion: remote,
          resolution: ConflictResolution.pending,
          peerDeviceId: peerDeviceId,
          createdAt: DateTime.now(),
        ));
      }
    }

    return conflicts;
  }

  static Conflict resolveConflict({
    required Conflict conflict,
    required ConflictResolution resolution,
  }) {
    return conflict.copyWith(
      resolution: resolution,
      resolvedAt: DateTime.now(),
    );
  }
}