import 'package:shared_preferences/shared_preferences.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_sync_repository.dart';
import 'package:taul/infrastructure/database/conflict_dao.dart';
import 'package:taul/infrastructure/database/entry_dao.dart';

class SyncRepositoryImpl implements ISyncRepository {
  final EntryDao _entryDao;
  final ConflictDao _conflictDao;

  SyncRepositoryImpl({
    required EntryDao entryDao,
    required ConflictDao conflictDao,
  })  : _entryDao = entryDao,
        _conflictDao = conflictDao;

  @override
  Future<List<Entry>> getModifiedEntries(DateTime? lastSyncAt) async {
    final all = await _entryDao.list(includeDeleted: true);
    if (lastSyncAt == null) return all;
    return all.where((e) => e.updatedAt.isAfter(lastSyncAt)).toList();
  }

  @override
  Future<void> upsertEntries(List<Entry> entries) async {
    for (final entry in entries) {
      final existing = await _entryDao.get(entry.id);
      if (existing == null) {
        await _entryDao.insert(entry);
      } else if (entry.updatedAt.isAfter(existing.updatedAt)) {
        await _entryDao.update(entry);
      }
    }
  }

  @override
  Future<List<Conflict>> getConflicts() async =>
      _conflictDao.getByResolution(ConflictResolution.pending);

  @override
  Future<void> resolveConflict(int id, ConflictResolution resolution) =>
      _conflictDao.updateResolution(id, resolution);

  @override
  Future<DateTime?> getLastSyncAt(String peerDeviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sync_last_$peerDeviceId') != null
        ? DateTime.parse(prefs.getString('sync_last_$peerDeviceId')!)
        : null;
  }

  @override
  Future<void> setLastSyncAt(String peerDeviceId, DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_last_$peerDeviceId', timestamp.toIso8601String());
  }
}
