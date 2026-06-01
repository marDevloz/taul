import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';

void main() {
  late AppDatabase database;
  late EntryDao dao;

  setUp(() {
    database = AppDatabase.forTesting();
    dao = EntryDao(database);
  });

  tearDown(() {
    database.close();
  });

  group('EntryDao tagsColors round-trip', () {
    test('should round-trip tagsColors with 3 entries', () async {
      final tagsColors = <String, String>{
        'urgent': '#E06C75',
        'work': '#61AFEF',
        'personal': '#98C379',
      };

      final entry = Entry(
        id: 'test-id-1',
        type: EntryType.note,
        title: 'Test tagsColors',
        content: 'Content with colored tags',
        tags: ['urgent', 'work', 'personal'],
        tagsColors: tagsColors,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);
      final retrieved = await dao.get('test-id-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.tagsColors, tagsColors);
    });

    test('should store null in DB when tagsColors is empty', () async {
      final entry = Entry(
        id: 'test-id-2',
        type: EntryType.note,
        title: 'Empty tagsColors',
        content: 'Content without tag colors',
        tags: ['general'],
        tagsColors: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);

      // Verify via raw query that tags_color is NULL in the database
      final rows = await database.customSelect(
        'SELECT tags_color FROM entries WHERE id = ?',
        variables: [Variable.withString('test-id-2')],
      ).get();

      expect(rows, hasLength(1));
      expect(rows.first.data['tags_color'], isNull);
    });

    test('should return empty map when tags_color is NULL (legacy)', () async {
      // Insert a row with a raw INSERT that sets tags_color to NULL.
      // DateTime columns must use Unix timestamps (seconds since epoch) for
      // Drift's default type mapping.
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await database.customInsert(
        'INSERT INTO entries (id, type, title, content, metadata, tags, '
        'tags_color, secret, requires_auth, created_at, updated_at, version) '
        'VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?)',
        variables: [
          Variable.withString('legacy-id'),
          Variable.withString('note'),
          Variable.withString('Legacy Entry'),
          Variable.withString('This entry has no tags_color'),
          Variable.withString('{}'),
          Variable.withString('["old"]'),
          Variable.withInt(0),
          Variable.withInt(now),
          Variable.withInt(now),
          Variable.withInt(1),
        ],
      );

      final retrieved = await dao.get('legacy-id');

      expect(retrieved, isNotNull);
      expect(retrieved!.tagsColors, isEmpty);
    });

    test('should handle insert-update-read cycle for tagsColors', () async {
      final initialColors = <String, String>{
        'tag1': '#C678DD',
      };

      final entry = Entry(
        id: 'test-id-3',
        type: EntryType.note,
        title: 'Update tagsColors',
        content: 'Testing tagsColors update',
        tags: ['tag1'],
        tagsColors: initialColors,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);

      // Update with additional colors
      final updatedColors = <String, String>{
        'tag1': '#C678DD',
        'tag2': '#D19A66',
      };
      final updated = entry.copyWith(
        tagsColors: updatedColors,
        updatedAt: DateTime.now(),
      );

      await dao.update(updated);
      final retrieved = await dao.get('test-id-3');

      expect(retrieved, isNotNull);
      expect(retrieved!.tagsColors, updatedColors);
    });
  });

  group('EntryDao completedAt', () {
    test('should persist completedAt as null for new entry', () async {
      final entry = Entry(
        id: 'task-1',
        type: EntryType.task,
        title: 'New task',
        content: 'Task content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);
      final retrieved = await dao.get('task-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.completedAt, isNull);
    });

    test('should round-trip completedAt when set', () async {
      final completedTime = DateTime(2026, 5, 31, 12, 0, 0);
      final entry = Entry(
        id: 'task-2',
        type: EntryType.task,
        title: 'Completed task',
        content: 'Done',
        completedAt: completedTime,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);
      final retrieved = await dao.get('task-2');

      expect(retrieved, isNotNull);
      expect(retrieved!.completedAt, completedTime);
    });

    test('should persist completedAt after update', () async {
      final entry = Entry(
        id: 'task-3',
        type: EntryType.task,
        title: 'Task to complete',
        content: 'Pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);

      final completedTime = DateTime(2026, 5, 31, 14, 30, 0);
      final updated = entry.copyWith(
        completedAt: completedTime,
        updatedAt: DateTime.now(),
      );
      await dao.update(updated);

      final retrieved = await dao.get('task-3');
      expect(retrieved!.completedAt, completedTime);
    });
  });

  group('EntryDao excludeArchived', () {
    test('should include all entries when excludeArchived is false', () async {
      // Insert entries with and without archivado tag
      await dao.insert(Entry(
        id: 'entry-1',
        type: EntryType.note,
        title: 'Normal entry',
        content: 'Content',
        tags: ['work'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await dao.insert(Entry(
        id: 'entry-2',
        type: EntryType.note,
        title: 'Archived entry',
        content: 'Content',
        tags: ['archivado'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final entries = await dao.list(excludeArchived: false);
      expect(entries, hasLength(2));
    });

    test('should exclude entries with archivado tag when excludeArchived is true', () async {
      await dao.insert(Entry(
        id: 'entry-3',
        type: EntryType.note,
        title: 'Normal entry',
        content: 'Content',
        tags: ['work'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await dao.insert(Entry(
        id: 'entry-4',
        type: EntryType.note,
        title: 'Archived entry',
        content: 'Content',
        tags: ['archivado'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final entries = await dao.list(excludeArchived: true);
      expect(entries, hasLength(1));
      expect(entries.first.id, 'entry-3');
    });

    test('should exclude entries with archivado among multiple tags', () async {
      await dao.insert(Entry(
        id: 'entry-5',
        type: EntryType.note,
        title: 'Multi-tag archived',
        content: 'Content',
        tags: ['work', 'archivado', 'urgent'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await dao.insert(Entry(
        id: 'entry-6',
        type: EntryType.note,
        title: 'Not archived',
        content: 'Content',
        tags: ['work', 'urgent'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final entries = await dao.list(excludeArchived: true);
      expect(entries, hasLength(1));
      expect(entries.first.id, 'entry-6');
    });
  });

  group('Migration 7→8', () {
    test('should have completed_at column in entries table', () async {
      final columns = await database.customSelect(
        "PRAGMA table_info(entries)",
      ).get();
      final columnNames = columns.map((c) => c.data['name'] as String).toList();
      expect(columnNames, contains('completed_at'));
    });

    test('should have is_system column in tag_settings table', () async {
      final columns = await database.customSelect(
        "PRAGMA table_info(tag_settings)",
      ).get();
      final columnNames = columns.map((c) => c.data['name'] as String).toList();
      expect(columnNames, contains('is_system'));
    });

    test('should seed 4 system tags on database creation', () async {
      final tags = await database.select(database.tagSettings).get();
      final systemTags = tags.where((t) => t.isSystem).toList();
      expect(systemTags, hasLength(4));

      final names = systemTags.map((t) => t.name).toSet();
      expect(names, containsAll(['pendiente', 'completada', 'favorito', 'archivado']));
    });

    test('should set isSystem true for system tags', () async {
      final pendiente = await (database.select(database.tagSettings)
            ..where((t) => t.name.equals('pendiente')))
          .getSingleOrNull();
      expect(pendiente, isNotNull);
      expect(pendiente!.isSystem, true);
    });

    test('should set isSystem false for user-created tags', () async {
      // Insert a user tag via DAO
      await database.into(database.tagSettings).insert(
        TagSettingsCompanion.insert(
          name: 'mytag',
          color: const Value('#FF0000'),
        ),
      );

      final mytag = await (database.select(database.tagSettings)
            ..where((t) => t.name.equals('mytag')))
          .getSingleOrNull();
      expect(mytag, isNotNull);
      expect(mytag!.isSystem, false);
    });
  });
}
