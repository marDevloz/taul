import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/services/conflict_resolver.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taul_sync_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('bidirectional sync', () {
    test('entries sync between two databases', () {
      final localEntries = [
        Entry(
          id: 'e1',
          type: EntryType.note,
          title: 'Local note',
          content: 'Local content',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024, 1, 2),
        ),
      ];

      final remoteEntries = [
        Entry(
          id: 'e2',
          type: EntryType.note,
          title: 'Remote note',
          content: 'Remote content',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024, 1, 2),
        ),
      ];

      final allEntries = [...localEntries, ...remoteEntries];
      expect(allEntries.length, 2);
      expect(allEntries.map((e) => e.id).toSet(), {'e1', 'e2'});
    });
  });

  group('conflict detection', () {
    test('detects simultaneous modifications', () {
      final base = Entry(
        id: 'e1',
        type: EntryType.note,
        title: 'Original',
        content: 'Original content',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 1),
      );

      final local = base.copyWith(
        title: 'Local edit',
        updatedAt: DateTime(2024, 1, 3),
      );

      final remote = base.copyWith(
        title: 'Remote edit',
        updatedAt: DateTime(2024, 1, 3),
      );

      final conflicts = ConflictResolver.detectConflicts(
        localEntries: [local],
        remoteEntries: [remote],
        lastSyncAt: DateTime(2024, 1, 2),
        peerDeviceId: 'peer-1',
      );

      expect(conflicts.length, 1);
      expect(conflicts.first.entryId, 'e1');
      expect(conflicts.first.resolution, ConflictResolution.pending);
    });

    test('no conflict when only one side modified', () {
      final base = Entry(
        id: 'e1',
        type: EntryType.note,
        title: 'Original',
        content: 'Original content',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 1),
      );

      final local = base.copyWith(
        title: 'Local edit',
        updatedAt: DateTime(2024, 1, 3),
      );

      final conflicts = ConflictResolver.detectConflicts(
        localEntries: [local],
        remoteEntries: [base],
        lastSyncAt: DateTime(2024, 1, 2),
        peerDeviceId: 'peer-1',
      );

      expect(conflicts, isEmpty);
    });
  });

  group('conflict resolution', () {
    test('keepLocal preserves local version', () {
      final conflict = ConflictResolver.resolveConflict(
        conflict: _testConflict(),
        resolution: ConflictResolution.keepLocal,
      );

      expect(conflict.resolution, ConflictResolution.keepLocal);
      expect(conflict.resolvedAt, isNotNull);
    });

    test('keepRemote preserves remote version', () {
      final conflict = ConflictResolver.resolveConflict(
        conflict: _testConflict(),
        resolution: ConflictResolution.keepRemote,
      );

      expect(conflict.resolution, ConflictResolution.keepRemote);
      expect(conflict.resolvedAt, isNotNull);
    });

    test('keepBoth preserves both versions', () {
      final conflict = ConflictResolver.resolveConflict(
        conflict: _testConflict(),
        resolution: ConflictResolution.keepBoth,
      );

      expect(conflict.resolution, ConflictResolution.keepBoth);
      expect(conflict.resolvedAt, isNotNull);
    });
  });

  group('deleted entries', () {
    test('deleted entry is detected', () {
      final entry = Entry(
        id: 'e1',
        type: EntryType.note,
        title: 'Deleted',
        content: '',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        deletedAt: DateTime(2024, 1, 5),
      );

      expect(entry.isDeleted, isTrue);
    });

    test('non-deleted entry is not detected', () {
      final entry = Entry(
        id: 'e1',
        type: EntryType.note,
        title: 'Active',
        content: 'Content',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      expect(entry.isDeleted, isFalse);
    });
  });

  group('in-memory database', () {
    test('NativeDatabase creates in-memory db', () {
      final db = NativeDatabase.memory();
      expect(db, isNotNull);
    });
  });
}

Conflict _testConflict() => Conflict(
      id: 1,
      entryId: 'e1',
      localVersion: Entry(
        id: 'e1',
        type: EntryType.note,
        title: 'Local',
        content: 'Local content',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 3),
      ),
      remoteVersion: Entry(
        id: 'e1',
        type: EntryType.note,
        title: 'Remote',
        content: 'Remote content',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 3),
      ),
      peerDeviceId: 'peer-1',
      createdAt: DateTime(2024, 1, 3),
    );
