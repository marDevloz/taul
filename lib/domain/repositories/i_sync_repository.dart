import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';

abstract class ISyncRepository {
  Future<List<Entry>> getModifiedEntries(DateTime? lastSyncAt);
  Future<void> upsertEntries(List<Entry> entries);
  Future<List<Conflict>> getConflicts();
  Future<void> applyConflictResolution({
    required Conflict conflict,
    required ConflictResolution resolution,
    Entry? entryToUpdate,
    Entry? entryToInsert,
  });
  Future<DateTime?> getLastSyncAt(String peerDeviceId);
  Future<void> setLastSyncAt(String peerDeviceId, DateTime timestamp);
}