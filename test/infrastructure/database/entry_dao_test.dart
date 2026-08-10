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

  group('EntryDao.search with FTS5 unavailable', () {
    /// Simulates a device without FTS5 support (e.g. Android system SQLite):
    /// the guarded `_createFtsTable()` silently fails, so the entries_fts
    /// virtual table never exists and every FTS query throws
    /// "no such table: entries_fts".
    Future<void> dropFtsTable() async {
      await database.customStatement('DROP TABLE entries_fts');
    }

    Future<void> insertEntry(
      String id,
      String title,
      String content, {
      List<String> tags = const [],
    }) {
      return dao.insert(Entry(
        id: id,
        type: EntryType.note,
        title: title,
        content: content,
        tags: tags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    test('should_degrade_to_like_search_when_fts5_unavailable', () async {
      await dropFtsTable();
      await insertEntry('1', 'Flutter notes', 'Some content about Flutter');
      await insertEntry('2', 'Unrelated', 'Different content');

      final results = await dao.search('Flutter');

      expect(results.length, 1);
      expect(results.first.id, '1');
    });

    test('should_match_content_and_tags_via_like_when_fts5_unavailable',
        () async {
      await dropFtsTable();
      await insertEntry('1', 'Title', 'arquitectura limpia en Flutter');
      await insertEntry('2', 'Another', 'Nothing here', tags: ['mobile']);

      final byContent = await dao.search('arquitectura');
      expect(byContent.map((e) => e.id), ['1']);

      final byTag = await dao.search('mobile');
      expect(byTag.map((e) => e.id), ['2']);
    });

    test('should_require_all_tokens_when_fts5_unavailable', () async {
      await dropFtsTable();
      await insertEntry('1', 'Flutter notes', 'A bit about Dart');
      await insertEntry('2', 'Flutter only', 'No topics here');

      final results = await dao.search('flutter dart');

      expect(results.map((e) => e.id), ['1']);
    });

    test('should_match_like_wildcards_literally_when_fts5_unavailable',
        () async {
      await dropFtsTable();
      await insertEntry('1', '100% real', 'text');
      await insertEntry('2', '100 dolares', 'text');

      final results = await dao.search('100%');

      expect(results.map((e) => e.id), ['1']);
    });

    test('should_exclude_deleted_entries_via_like_when_fts5_unavailable',
        () async {
      await dropFtsTable();
      await insertEntry('1', 'Flutter notes', 'Some content');
      await dao.insert(Entry(
        id: '2',
        type: EntryType.note,
        title: 'Flutter deleted',
        content: 'Some content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      ));

      final results = await dao.search('Flutter');

      expect(results.map((e) => e.id), ['1']);
    });
  });

  group('EntryDao.search with FTS5 available', () {
    test('should_return_fts_results_when_table_exists', () async {
      await dao.insert(Entry(
        id: '1',
        type: EntryType.note,
        title: 'Flutter notes',
        content: 'Some content about Flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final results = await dao.search('Flutter');

      expect(results.length, 1);
      expect(results.first.id, '1');
    });
  });
}
