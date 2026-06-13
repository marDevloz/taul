import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_sync_repository.dart';
import 'package:taul/infrastructure/database/conflict_dao.dart';
import 'package:taul/infrastructure/sync/sync_coordinator.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';

class MockSyncRepository extends Mock implements ISyncRepository {}
class MockConflictDao extends Mock implements ConflictDao {}

void main() {
  late MockSyncRepository repo;
  late MockConflictDao conflictDao;
  late SyncCoordinator coordinator;
  final now = DateTime.now();
  final localDeviceId = 'local-device';

  setUpAll(() {
    registerFallbackValue(const SyncRequest(deviceId: ''));
    registerFallbackValue(SyncResponse(deviceId: '', entriesReceived: 0, conflictsCount: 0));
    registerFallbackValue(Conflict(
      id: 0,
      entryId: '',
      localVersion: Entry(
        id: '',
        type: EntryType.note,
        title: '',
        content: '',
        createdAt: now,
        updatedAt: now,
      ),
      remoteVersion: Entry(
        id: '',
        type: EntryType.note,
        title: '',
        content: '',
        createdAt: now,
        updatedAt: now,
      ),
      peerDeviceId: '',
      createdAt: now,
    ));
  });

  setUp(() {
    repo = MockSyncRepository();
    conflictDao = MockConflictDao();
    coordinator = SyncCoordinator(
      repo: repo,
      conflictDao: conflictDao,
      localDeviceId: localDeviceId,
    );
  });

  group('handleSyncRequest', () {
    test('should_upsert_non_conflicting_entries', () async {
      final remoteEntry = Entry(
        id: 'entry-1',
        type: EntryType.note,
        title: 'Remote Entry',
        content: 'From remote',
        tags: [],
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
      );
      final request = SyncRequest(
        deviceId: 'remote-device',
        lastSyncAt: now.subtract(const Duration(hours: 2)),
        entries: [remoteEntry],
      );

      when(() => repo.getModifiedEntries(any())).thenAnswer((_) async => []);
      when(() => repo.upsertEntries(any())).thenAnswer((_) async {});
      when(() => repo.setLastSyncAt(any(), any())).thenAnswer((_) async {});

      final response = await coordinator.handleSyncRequest(request);

      expect(response.entriesReceived, 1);
      expect(response.conflictsCount, 0);
      expect(response.deviceId, localDeviceId);
      expect(response.serverLastSyncAt, isNotNull);
      verify(() => repo.upsertEntries(any())).called(1);
      verify(() => repo.setLastSyncAt('remote-device', any())).called(1);
    });

    test('should_detect_conflict_when_both_modified', () async {
      final entryId = 'entry-1';
      final localEntry = Entry(
        id: entryId,
        type: EntryType.note,
        title: 'Local Version',
        content: 'Edited locally',
        tags: [],
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 2)),
      );
      final remoteEntry = Entry(
        id: entryId,
        type: EntryType.note,
        title: 'Remote Version',
        content: 'Edited remotely',
        tags: [],
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
      );
      final request = SyncRequest(
        deviceId: 'remote-device',
        lastSyncAt: now,
        entries: [remoteEntry],
      );

      when(() => repo.getModifiedEntries(any())).thenAnswer((_) async => [localEntry]);
      when(() => conflictDao.insert(any())).thenAnswer((_) async => Conflict(
        id: 1,
        entryId: entryId,
        localVersion: localEntry,
        remoteVersion: remoteEntry,
        peerDeviceId: 'remote-device',
        createdAt: DateTime.now(),
      ));
      when(() => repo.setLastSyncAt(any(), any())).thenAnswer((_) async {});

      final response = await coordinator.handleSyncRequest(request);

      expect(response.conflictsCount, 1);
      expect(response.entriesReceived, 1);
      // Conflicting entry should NOT be upserted
      verifyNever(() => repo.upsertEntries(any()));
      verify(() => conflictDao.insert(any())).called(1);
    });

    test('should_not_detect_conflict_for_new_remote_entries', () async {
      final remoteEntry = Entry(
        id: 'new-entry',
        type: EntryType.note,
        title: 'Brand New',
        content: 'Only exists remotely',
        tags: [],
        createdAt: now,
        updatedAt: now,
      );
      final request = SyncRequest(
        deviceId: 'remote-device',
        lastSyncAt: now.subtract(const Duration(hours: 1)),
        entries: [remoteEntry],
      );

      when(() => repo.getModifiedEntries(any())).thenAnswer((_) async => []);
      when(() => repo.upsertEntries(any())).thenAnswer((_) async {});
      when(() => repo.setLastSyncAt(any(), any())).thenAnswer((_) async {});

      final response = await coordinator.handleSyncRequest(request);

      expect(response.conflictsCount, 0);
      verify(() => repo.upsertEntries(any())).called(1);
    });

    test('should_return_local_delta_in_response', () async {
      final localEntry = Entry(
        id: 'local-entry',
        type: EntryType.note,
        title: 'Local Delta',
        content: 'Modified locally since last sync',
        tags: [],
        createdAt: now,
        updatedAt: now,
      );
      final request = SyncRequest(
        deviceId: 'remote-device',
        lastSyncAt: now.subtract(const Duration(hours: 1)),
        entries: [],
      );

      when(() => repo.getModifiedEntries(any())).thenAnswer((_) async => [localEntry]);
      when(() => repo.setLastSyncAt(any(), any())).thenAnswer((_) async {});

      final response = await coordinator.handleSyncRequest(request);

      expect(response.entries, contains(localEntry));
      expect(response.entriesReceived, 0);
      expect(response.conflictsCount, 0);
    });

    test('should_handle_first_sync_with_null_lastSyncAt', () async {
      final remoteEntry = Entry(
        id: 'entry-1',
        type: EntryType.note,
        title: 'First Sync',
        content: 'First sync entry',
        tags: [],
        createdAt: now,
        updatedAt: now,
      );
      final request = SyncRequest(
        deviceId: 'remote-device',
        lastSyncAt: null,
        entries: [remoteEntry],
      );

      when(() => repo.getModifiedEntries(null))
          .thenAnswer((_) async => [remoteEntry]);
      when(() => repo.upsertEntries(any())).thenAnswer((_) async {});
      when(() => repo.setLastSyncAt(any(), any())).thenAnswer((_) async {});

      final response = await coordinator.handleSyncRequest(request);

      expect(response.conflictsCount, 0); // No conflicts on first sync
      verify(() => repo.upsertEntries(any())).called(1);
    });
  });
}
