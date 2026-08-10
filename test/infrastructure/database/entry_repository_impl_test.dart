import 'package:flutter_test/flutter_test.dart';
import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/database/entry_repository_impl.dart';

void main() {
  late AppDatabase database;
  late EntryDao dao;
  late EntryRepositoryImpl repository;

  setUp(() {
    database = AppDatabase.forTesting();
    dao = EntryDao(database);
    repository = EntryRepositoryImpl(dao: dao);
  });

  tearDown(() {
    database.close();
  });

  group('EntryRepositoryImpl', () {
    test('should_create_entry', () async {
      final entry = Entry(
        id: 'test-id',
        type: EntryType.note,
        title: 'Test Note',
        content: 'Test content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await repository.create(entry);
      expect(result.id, 'test-id');
      expect(result.title, 'Test Note');
    });

    test('should_get_entry_by_id', () async {
      final entry = Entry(
        id: 'test-id',
        type: EntryType.note,
        title: 'Test',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(entry);
      final result = await repository.getById('test-id');
      expect(result.id, 'test-id');
      expect(result.title, 'Test');
    });

    test('should_throw_when_entry_not_found', () async {
      expect(
        () => repository.getById('missing'),
        throwsA(isA<EntryNotFoundFailure>()),
      );
    });

    test('should_update_entry', () async {
      final entry = Entry(
        id: 'test-id',
        type: EntryType.note,
        title: 'Original',
        content: 'Original content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(entry);
      final updated = entry.copyWith(title: 'Updated', updatedAt: DateTime.now());
      final result = await repository.update(updated);
      expect(result.title, 'Updated');
    });

    test('should_soft_delete_entry', () async {
      final entry = Entry(
        id: 'test-id',
        type: EntryType.note,
        title: 'To Delete',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(entry);
      await repository.softDelete('test-id');

      // Should not appear in regular listing
      final entries = await repository.list();
      expect(entries.where((e) => e.id == 'test-id'), isEmpty);
    });

    test('should_list_entries', () async {
      final entry1 = Entry(
        id: '1',
        type: EntryType.note,
        title: 'First',
        content: 'Content 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final entry2 = Entry(
        id: '2',
        type: EntryType.idea,
        title: 'Second',
        content: 'Content 2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(entry1);
      await repository.create(entry2);

      final entries = await repository.list();
      expect(entries.length, 2);
    });

    test('should_filter_by_type', () async {
      final note = Entry(
        id: '1',
        type: EntryType.note,
        title: 'Note',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final idea = Entry(
        id: '2',
        type: EntryType.idea,
        title: 'Idea',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(note);
      await repository.create(idea);

      final ideas = await repository.list(type: EntryType.idea);
      expect(ideas.length, 1);
      expect(ideas.first.id, '2');
    });

    test('should_search_by_title_via_fts5', () async {
      final entry = Entry(
        id: 'search-1',
        type: EntryType.note,
        title: 'Flutter notes',
        content: 'Some content about Flutter',
        tags: ['mobile', 'dart'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(entry);
      final results = await repository.search('Flutter');
      expect(results.length, 1);
      expect(results.first.id, 'search-1');
    });

    test('should_search_by_content_via_fts5', () async {
      final entry = Entry(
        id: 'search-2',
        type: EntryType.note,
        title: 'Title',
        content: 'arquitectura limpia en Flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(entry);
      final results = await repository.search('arquitectura');
      expect(results.length, 1);
      expect(results.first.id, 'search-2');
    });

    test('should_return_empty_when_no_match', () async {
      final entry = Entry(
        id: 'search-3',
        type: EntryType.note,
        title: 'Something',
        content: 'Unrelated content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(entry);
      final results = await repository.search('zzzznotfound');
      expect(results, isEmpty);
    });

    test('should_match_prefix_partial_word', () async {
      final entry = Entry(
        id: 'search-4',
        type: EntryType.note,
        title: 'Flutter notes',
        content: 'Some content about Flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.create(entry);
      // "Flu" should match "Flutter" before user finishes typing
      final results = await repository.search('Flu');
      expect(results.length, 1);
      expect(results.first.id, 'search-4');
    });

    test('should_remove_tag_from_all_entries_and_rebuild_fts', () async {
      // Regression guard for the propagation pattern #38 (tag rename) will copy.
      await repository.create(Entry(
        id: 'tag-1',
        type: EntryType.note,
        title: 'Primera',
        content: 'Contenido uno',
        tags: ['Trabajo'], // case-insensitive variant
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repository.create(Entry(
        id: 'tag-2',
        type: EntryType.note,
        title: 'Segunda',
        content: 'Contenido dos',
        tags: ['trabajo', 'otro'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repository.create(Entry(
        id: 'tag-3',
        type: EntryType.note,
        title: 'Control',
        content: 'Contenido tres',
        tags: ['otro'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Before removal the tag matches in FTS (including case variant)
      expect((await repository.search('trabajo')).length, 2);

      final affected = await dao.removeTagFromAllEntries('trabajo');
      expect(affected.toSet(), {'tag-1', 'tag-2'});

      // Entries no longer carry the tag (case-insensitive); control untouched
      for (final id in ['tag-1', 'tag-2']) {
        final e = await repository.getById(id);
        expect(e.tags.where((t) => t.toLowerCase() == 'trabajo'), isEmpty);
      }
      expect((await repository.getById('tag-3')).tags, ['otro']);

      // FTS rebuilt: old tag no longer matches, remaining tags still do
      expect(await repository.search('trabajo'), isEmpty);
      expect((await repository.search('otro')).map((e) => e.id).toSet(),
          {'tag-2', 'tag-3'});
    });

    test('should_exclude_archived_entries_when_excludeArchived_true', () async {
      await repository.create(Entry(
        id: 'repo-1',
        type: EntryType.note,
        title: 'Normal',
        content: 'Content',
        tags: ['work'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repository.create(Entry(
        id: 'repo-2',
        type: EntryType.note,
        title: 'Archived',
        content: 'Content',
        tags: ['archivado'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final entries = await repository.list(excludeArchived: true);
      expect(entries, hasLength(1));
      expect(entries.first.id, 'repo-1');
    });

    test('should_include_all_entries_when_excludeArchived_false', () async {
      await repository.create(Entry(
        id: 'repo-3',
        type: EntryType.note,
        title: 'Normal',
        content: 'Content',
        tags: ['work'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await repository.create(Entry(
        id: 'repo-4',
        type: EntryType.note,
        title: 'Archived',
        content: 'Content',
        tags: ['archivado'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final entries = await repository.list(excludeArchived: false);
      expect(entries, hasLength(2));
    });
  });
}
