import 'package:logger/logger.dart';
import 'package:taul/domain/repositories/i_sync_repository.dart';
import 'package:taul/domain/services/conflict_resolver.dart';
import 'package:taul/infrastructure/database/conflict_dao.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';

/// Orchestrates the bidirectional sync exchange on the server side.
///
/// Called by [SyncServer] when a POST /sync request arrives.
/// 1. Loads local entries modified since the remote's lastSyncAt
/// 2. Detects conflicts where both sides modified the same entry
/// 3. Stores conflicts in the DB
/// 4. Upserts non-conflicting remote entries
/// 5. Records lastSyncAt for this peer
/// 6. Returns SyncResponse with local delta + conflict count
class SyncCoordinator {
  final ISyncRepository _repo;
  final ConflictDao _conflictDao;
  final String _localDeviceId;
  final Logger _log;

  SyncCoordinator({
    required ISyncRepository repo,
    required ConflictDao conflictDao,
    required String localDeviceId,
    Logger? log,
  })  : _repo = repo,
        _conflictDao = conflictDao,
        _localDeviceId = localDeviceId,
        _log = log ?? Logger();

  /// Handles an incoming sync request from a remote device.
  Future<SyncResponse> handleSyncRequest(SyncRequest request) async {
    _log.i(
      'Sync request from ${request.deviceId}: '
      '${request.entries.length} entries, '
      'lastSyncAt: ${request.lastSyncAt}',
    );

    // 1. Load local entries modified since remote's lastSyncAt
    final localDelta = await _repo.getModifiedEntries(request.lastSyncAt);
    _log.d('Local delta: ${localDelta.length} entries');

    // 2. Detect conflicts: entries modified on BOTH sides since lastSyncAt
    final conflicts = ConflictResolver.detectConflicts(
      localEntries: localDelta,
      remoteEntries: request.entries,
      lastSyncAt: request.lastSyncAt,
      peerDeviceId: request.deviceId,
    );
    _log.d('Conflicts detected: ${conflicts.length}');

    // 3. Store conflicts in the DB
    for (final conflict in conflicts) {
      await _conflictDao.insert(conflict);
    }

    // 4. Upsert non-conflicting remote entries
    final conflictIds = conflicts.map((c) => c.entryId).toSet();
    final entriesToUpsert = request.entries
        .where((e) => !conflictIds.contains(e.id))
        .toList();

    if (entriesToUpsert.isNotEmpty) {
      _log.d('Upserting ${entriesToUpsert.length} non-conflicting entries');
      await _repo.upsertEntries(entriesToUpsert);
    }

    // 5. Record sync timestamp for this peer
    final now = DateTime.now();
    await _repo.setLastSyncAt(request.deviceId, now);

    // 6. Return response with local delta + conflict count
    _log.i(
      'Sync complete: received ${request.entries.length}, '
      'conflicts: ${conflicts.length}, '
      'returning ${localDelta.length} entries',
    );

    return SyncResponse(
      deviceId: _localDeviceId,
      entriesReceived: request.entries.length,
      conflictsCount: conflicts.length,
      serverLastSyncAt: now,
      entries: localDelta,
    );
  }
}
