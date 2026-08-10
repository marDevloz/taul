import 'package:shared_preferences/shared_preferences.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_sync_repository.dart';
import 'package:taul/infrastructure/database/app_database.dart'
    hide Conflict, Entry;
import 'package:taul/infrastructure/database/conflict_dao.dart';
import 'package:taul/infrastructure/database/entry_dao.dart';

class SyncRepositoryImpl implements ISyncRepository {
  final AppDatabase _database;
  final EntryDao _entryDao;
  final ConflictDao _conflictDao;

  SyncRepositoryImpl({
    required AppDatabase database,
    required EntryDao entryDao,
    required ConflictDao conflictDao,
  })  : _database = database,
        _entryDao = entryDao,
        _conflictDao = conflictDao;

  @override
  Future<List<Entry>> getModifiedEntries(DateTime? lastSyncAt) async {
    final all = await _entryDao.list(includeDeleted: true);
    if (lastSyncAt == null) return all;
    return all.where((e) => e.updatedAt.isAfter(lastSyncAt)).toList();
  }

  @override
  Future<void> upsertEntries(List<Entry> entries) async {
    await _entryDao.batchUpsert(entries);
  }

  @override
  Future<List<Conflict>> getConflicts() async =>
      _conflictDao.getByResolution(ConflictResolution.pending);

  @override
  Future<void> applyConflictResolution({
    required Conflict conflict,
    required ConflictResolution resolution,
    Entry? entryToUpdate,
    Entry? entryToInsert,
  }) async {
    await _database.transaction(() async {
      if (entryToUpdate != null) {
        await _entryDao.update(entryToUpdate);
      }
      if (entryToInsert != null) {
        await _entryDao.insert(entryToInsert);
      }
      await _conflictDao.updateResolution(conflict.id, resolution);
    });
  }

  @override
  Future<DateTime?> getLastSyncAt(String peerDeviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('sync_last_$peerDeviceId');
    return lastSync != null ? DateTime.parse(lastSync) : null;
  }

  @override
  Future<void> setLastSyncAt(String peerDeviceId, DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_last_$peerDeviceId', timestamp.toIso8601String());
  }
}
