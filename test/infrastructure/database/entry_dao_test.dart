import 'package:drift/drift.dart' show Variable;
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
}
