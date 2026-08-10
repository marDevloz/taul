import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/database/tag_settings_dao.dart';

void main() {
  late AppDatabase database;
  late EntryDao dao;
  late TagSettingsDao tagSettingsDao;

  setUp(() {
    database = AppDatabase.forTesting();
    dao = EntryDao(database);
    tagSettingsDao = TagSettingsDao(database);
  });

  tearDown(() {
    database.close();
  });

  Future<void> createEntry(String id, List<String> tags) {
    return dao.insert(Entry(
      id: id,
      type: EntryType.note,
      title: 'Titulo $id',
      content: 'Contenido $id',
      tags: tags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  group('EntryDao.renameTagOnAllEntries', () {
    test(
        'should_rename_tag_on_all_entries_and_rebuild_fts_like_remove_tag_guard',
        () async {
      await createEntry('tag-1', ['Trabajo']);
      await createEntry('tag-2', ['trabajo', 'otro']);
      await createEntry('tag-3', ['otro']);

      // Before rename the old tag matches in FTS (including case variant)
      expect((await dao.search('trabajo')).length, 2);

      final affected = await dao.renameTagOnAllEntries('trabajo', 'empleo');
      expect(affected.toSet(), {'tag-1', 'tag-2'});

      // Entries now carry the new name (canonical casing); control untouched
      expect((await dao.get('tag-1'))!.tags, ['empleo']);
      expect((await dao.get('tag-2'))!.tags, ['empleo', 'otro']);
      expect((await dao.get('tag-3'))!.tags, ['otro']);

      // FTS rebuilt: old tag no longer matches, renamed tag does
      expect(await dao.search('trabajo'), isEmpty);
      expect((await dao.search('empleo')).map((e) => e.id).toSet(),
          {'tag-1', 'tag-2'});
      expect(
        (await dao.search('otro')).map((e) => e.id).toSet(),
        {'tag-2', 'tag-3'},
      );
    });

    test('should_apply_new_casing_on_case_only_rename_and_collapse_variants',
        () async {
      await createEntry('case-1', ['trabajo', 'Trabajo', 'TRABAJO']);
      await createEntry('case-2', ['trabajo', 'otro']);

      final affected = await dao.renameTagOnAllEntries('trabajo', 'Trabajo');
      expect(affected.toSet(), {'case-1', 'case-2'});

      // Variants collapse to a single canonical tag; no duplicates
      expect((await dao.get('case-1'))!.tags, ['Trabajo']);
      expect((await dao.get('case-2'))!.tags, ['Trabajo', 'otro']);

      // Search remains accurate under the canonical casing
      expect(
        (await dao.search('Trabajo')).map((e) => e.id).toSet(),
        {'case-1', 'case-2'},
      );
    });

    test('should_dedupe_when_new_name_already_exists_on_an_entry', () async {
      await createEntry('merge-1', ['trabajo', 'empleo']);

      final affected = await dao.renameTagOnAllEntries('trabajo', 'empleo');
      expect(affected.toSet(), {'merge-1'});
      expect((await dao.get('merge-1'))!.tags, ['empleo']);
    });

    test('should_not_touch_entries_without_the_tag', () async {
      await createEntry('ctrl-1', ['otro']);

      final affected = await dao.renameTagOnAllEntries('trabajo', 'empleo');
      expect(affected, isEmpty);
      expect((await dao.get('ctrl-1'))!.tags, ['otro']);
    });

    test('should_not_recreate_or_delete_tag_settings', () async {
      await tagSettingsDao.upsert('trabajo', color: '#FF0000', isSecure: true);
      await createEntry('s-1', ['trabajo']);

      await dao.renameTagOnAllEntries('trabajo', 'empleo');

      // Data layer only rewrites entries — TagSettings remain for the UI.
      final source = await tagSettingsDao.getByName('trabajo');
      expect(source, isNotNull);
      expect(source!.isSecure, isTrue);
      expect(await tagSettingsDao.getByName('empleo'), isNull);
    });

    test('should_rename_and_search_via_like_when_fts5_unavailable', () async {
      await database.customStatement('DROP TABLE entries_fts');
      await createEntry('l-1', ['Trabajo']);
      await createEntry('l-2', ['trabajo', 'otro']);

      await dao.renameTagOnAllEntries('trabajo', 'empleo');

      expect(await dao.search('trabajo'), isEmpty);
      expect((await dao.search('empleo')).map((e) => e.id).toSet(),
          {'l-1', 'l-2'});
    });
  });
}