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

  Future<void> insertEntry(
    String id,
    String title, {
    EntryType type = EntryType.note,
    String content = 'Busca este contenido',
    List<String> tags = const [],
    DateTime? completedAt,
  }) {
    return dao.insert(Entry(
      id: id,
      type: type,
      title: title,
      content: content,
      tags: tags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      completedAt: completedAt,
    ));
  }

  group('EntryDao.search applies active filters (FTS path)', () {
    test('should_filter_results_by_type_when_type_provided', () async {
      await insertEntry('1', 'Flutter notes');
      await insertEntry('2', 'Flutter ideas', type: EntryType.idea);

      final results = await dao.search('Flutter', type: EntryType.note.label);

      expect(results.map((e) => e.id), ['1']);
    });

    test('should_filter_results_by_tag_when_tag_provided', () async {
      await insertEntry('1', 'Flutter notes', tags: ['work']);
      await insertEntry('2', 'Flutter notes', tags: ['personal']);

      final results = await dao.search('Flutter', tag: 'work');

      expect(results.map((e) => e.id), ['1']);
    });

    test('should_match_tag_filter_case_insensitively', () async {
      await insertEntry('1', 'Flutter notes', tags: ['Work']);

      final results = await dao.search('Flutter', tag: 'work');

      expect(results.map((e) => e.id), ['1']);
    });

    test('should_filter_to_completed_tasks_when_completedOnly_true', () async {
      await insertEntry(
        '1',
        'Comprar harina',
        type: EntryType.task,
        completedAt: DateTime.now(),
      );
      await insertEntry('2', 'Comprar harina', type: EntryType.task);
      await insertEntry('3', 'Comprar harina', type: EntryType.note);

      final results = await dao.search('harina', completedOnly: true);

      expect(results.map((e) => e.id), ['1']);
    });

    test('should_filter_to_pending_tasks_when_completedOnly_false', () async {
      await insertEntry(
        '1',
        'Comprar harina',
        type: EntryType.task,
        completedAt: DateTime.now(),
      );
      await insertEntry('2', 'Comprar harina', type: EntryType.task);
      await insertEntry('3', 'Comprar harina', type: EntryType.note);

      final results = await dao.search('harina', completedOnly: false);

      expect(results.map((e) => e.id), ['2']);
    });

    test('should_exclude_archived_when_excludeArchived_true', () async {
      await insertEntry('1', 'Flutter notes', tags: ['work']);
      await insertEntry('2', 'Flutter notes', tags: ['archivado']);

      final results = await dao.search('Flutter', excludeArchived: true);

      expect(results.map((e) => e.id), ['1']);
    });

    test('should_include_archived_when_excludeArchived_false', () async {
      await insertEntry('1', 'Flutter notes', tags: ['work']);
      await insertEntry('2', 'Flutter notes', tags: ['archivado']);

      final results = await dao.search('Flutter', excludeArchived: false);

      expect(results.map((e) => e.id).toSet(), {'1', '2'});
    });
  });

  group(
    'EntryDao.search applies active filters when FTS5 unavailable (LIKE path)',
    () {
      setUp(() async {
        await database.customStatement('DROP TABLE entries_fts');
      });

      test('should_filter_results_by_type_via_like_when_fts5_unavailable',
          () async {
        await insertEntry('1', 'Flutter notes');
        await insertEntry('2', 'Flutter ideas', type: EntryType.idea);

        final results = await dao.search('Flutter', type: EntryType.note.label);

        expect(results.map((e) => e.id), ['1']);
      });

      test('should_filter_results_by_tag_via_like_when_fts5_unavailable',
          () async {
        await insertEntry('1', 'Flutter notes', tags: ['work']);
        await insertEntry('2', 'Flutter notes', tags: ['personal']);

        final results = await dao.search('Flutter', tag: 'work');

        expect(results.map((e) => e.id), ['1']);
      });

      test('should_filter_to_pending_tasks_via_like_when_fts5_unavailable',
          () async {
        await insertEntry(
          '1',
          'Comprar harina',
          type: EntryType.task,
          completedAt: DateTime.now(),
        );
        await insertEntry('2', 'Comprar harina', type: EntryType.task);

        final results = await dao.search('harina', completedOnly: false);

        expect(results.map((e) => e.id), ['2']);
      });

      test('should_exclude_archived_via_like_when_fts5_unavailable', () async {
        await insertEntry('1', 'Flutter notes', tags: ['work']);
        await insertEntry('2', 'Flutter notes', tags: ['archivado']);

        final results = await dao.search('Flutter', excludeArchived: true);

        expect(results.map((e) => e.id), ['1']);
      });
    },
  );
}