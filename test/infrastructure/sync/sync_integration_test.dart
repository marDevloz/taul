import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_sync_repository.dart';
import 'package:taul/infrastructure/database/conflict_dao.dart';
import 'package:taul/infrastructure/sync/sync_coordinator.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';

class MockRepo extends Mock implements ISyncRepository {}
class MockConflictDao2 extends Mock implements ConflictDao {}

void main() {
  late MockRepo deviceARepo;
  late MockConflictDao2 deviceAConflictDao;
  late MockRepo deviceBRepo;
  late MockConflictDao2 deviceBConflictDao;
  late SyncCoordinator deviceACoordinator;
  late SyncCoordinator deviceBCoordinator;

  final now = DateTime.now();

  setUpAll(() {
    registerFallbackValue(const SyncRequest(deviceId: ''));
    registerFallbackValue(SyncResponse(deviceId: '', entriesReceived: 0, conflictsCount: 0));
    registerFallbackValue(Conflict(
      id: 1,
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
    deviceARepo = MockRepo();
    deviceAConflictDao = MockConflictDao2();
    deviceBRepo = MockRepo();
    deviceBConflictDao = MockConflictDao2();

    deviceACoordinator = SyncCoordinator(
      repo: deviceARepo,
      conflictDao: deviceAConflictDao,
      localDeviceId: 'device-a',
    );
    deviceBCoordinator = SyncCoordinator(
      repo: deviceBRepo,
      conflictDao: deviceBConflictDao,
      localDeviceId: 'device-b',
    );
  });

  group('bidirectional sync', () {
    test('should_sync_entries_bidirectionally_without_conflicts', () async {
      // Device A has one modified entry
      final entryA = Entry(
        id: 'entry-a',
        type: EntryType.note,
        title: 'From A',
        content: 'Created on A',
        tags: ['tag1'],
        createdAt: now,
        updatedAt: now,
      );

      // Device B has one modified entry
      final entryB = Entry(
        id: 'entry-b',
        type: EntryType.note,
        title: 'From B',
        content: 'Created on B',
        tags: ['tag2'],
        createdAt: now,
        updatedAt: now,
      );

      // --- Sync A → B ---
      // A sends its delta to B
      when(() => deviceBRepo.getModifiedEntries(any()))
          .thenAnswer((_) async => [entryB]);
      when(() => deviceBRepo.upsertEntries(any()))
          .thenAnswer((_) async {});
      when(() => deviceBRepo.setLastSyncAt(any(), any()))
          .thenAnswer((_) async {});

      final requestAtoB = SyncRequest(
        deviceId: 'device-a',
        lastSyncAt: now.subtract(const Duration(hours: 1)),
        entries: [entryA],
      );
      final responseOnB = await deviceBCoordinator.handleSyncRequest(requestAtoB);
      // B received entryA, returns its delta (entryB) with 0 conflicts
      expect(responseOnB.conflictsCount, 0);
      expect(responseOnB.entriesReceived, 1);
      expect(responseOnB.entries, contains(entryB));
      verify(() => deviceBRepo.upsertEntries(any())).called(1);

      // --- Sync B → A ---
      // B sends its delta to A
      when(() => deviceARepo.getModifiedEntries(any()))
          .thenAnswer((_) async => [entryA]);
      when(() => deviceARepo.upsertEntries(any()))
          .thenAnswer((_) async {});
      when(() => deviceARepo.setLastSyncAt(any(), any()))
          .thenAnswer((_) async {});

      final requestBtoA = SyncRequest(
        deviceId: 'device-b',
        lastSyncAt: now.subtract(const Duration(hours: 1)),
        entries: [entryB],
      );
      final responseOnA = await deviceACoordinator.handleSyncRequest(requestBtoA);
      // A received entryB, returns its delta (entryA) with 0 conflicts
      expect(responseOnA.conflictsCount, 0);
      expect(responseOnA.entriesReceived, 1);
      expect(responseOnA.entries, contains(entryA));
      verify(() => deviceARepo.upsertEntries(any())).called(1);
    });

    test('should_detect_conflicts_when_same_entry_modified_on_both', () async {
      final entryId = 'shared-entry';
      final localVersion = Entry(
        id: entryId,
        type: EntryType.note,
        title: 'Local Edit',
        content: 'Modified on A',
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 2)),
      );
      final remoteVersion = Entry(
        id: entryId,
        type: EntryType.note,
        title: 'Remote Edit',
        content: 'Modified on B',
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
      );

      // Device A receives entry from B where both modified the same entry
      when(() => deviceARepo.getModifiedEntries(any()))
          .thenAnswer((_) async => [localVersion]);
      when(() => deviceAConflictDao.insert(any())).thenAnswer((_) async => Conflict(
        id: 1,
        entryId: entryId,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
        peerDeviceId: 'device-b',
        createdAt: DateTime.now(),
      ));
      when(() => deviceARepo.setLastSyncAt(any(), any()))
          .thenAnswer((_) async {});

      final request = SyncRequest(
        deviceId: 'device-b',
        lastSyncAt: now,
        entries: [remoteVersion],
      );
      final response = await deviceACoordinator.handleSyncRequest(request);

      expect(response.conflictsCount, 1);
      // Conflicting entry should NOT be upserted
      verifyNever(() => deviceARepo.upsertEntries(any()));
      verify(() => deviceAConflictDao.insert(any())).called(1);
    });

    test('should_handle_first_sync_with_no_prior_lastSyncAt', () async {
      final entryA = Entry(
        id: 'entry-1',
        type: EntryType.note,
        title: 'Initial Sync',
        content: 'First sync from A',
        createdAt: now,
        updatedAt: now,
      );

      // Device A sends first sync (no lastSyncAt)
      when(() => deviceBRepo.getModifiedEntries(null))
          .thenAnswer((_) async => []); // B has nothing
      when(() => deviceBRepo.upsertEntries(any()))
          .thenAnswer((_) async {});
      when(() => deviceBRepo.setLastSyncAt(any(), any()))
          .thenAnswer((_) async {});

      final request = SyncRequest(
        deviceId: 'device-a',
        lastSyncAt: null,
        entries: [entryA],
      );
      final response = await deviceBCoordinator.handleSyncRequest(request);

      expect(response.conflictsCount, 0); // First sync: no conflicts
      expect(response.entriesReceived, 1);
      verify(() => deviceBRepo.upsertEntries(any())).called(1);
    });
  });
}
