import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/database/tag_settings_dao.dart';

void main() {
  late AppDatabase database;
  late TagSettingsDao dao;

  setUp(() {
    database = AppDatabase.forTesting();
    dao = TagSettingsDao(database);
  });

  tearDown(() {
    database.close();
  });

  group('TagSettingsDao - table exists', () {
    test('should have tag_settings table after database creation', () async {
      final tables = await database.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tag_settings'",
      ).get();

      expect(tables, hasLength(1));
      expect(tables.first.data['name'], 'tag_settings');
    });
  });

  group('TagSettingsDao - CRUD', () {
    test('should insert and retrieve a tag setting', () async {
      await dao.upsert('urgent', color: '#E06C75');

      final result = await dao.getByName('urgent');
      expect(result, isNotNull);
      expect(result!.name, 'urgent');
      expect(result.color, '#E06C75');
      expect(result.isSecure, false);
      expect(result.createdAt, isNotNull);
    });

    test('should return null for non-existent tag', () async {
      final result = await dao.getByName('nonexistent');
      expect(result, isNull);
    });

    test('should upsert overwrites existing tag', () async {
      await dao.upsert('work', color: '#61AFEF');
      await dao.upsert('work', color: '#E06C75', isSecure: true);

      final result = await dao.getByName('work');
      expect(result, isNotNull);
      expect(result!.color, '#E06C75');
      expect(result.isSecure, true);
    });

    test('should get all tags', () async {
      await dao.upsert('alpha');
      await dao.upsert('beta');
      await dao.upsert('gamma');

      final all = await dao.getAllTags();
      expect(all, hasLength(3));

      final names = all.map((t) => t.name).toSet();
      expect(names, containsAll(['alpha', 'beta', 'gamma']));
    });

    test('should delete a tag', () async {
      await dao.upsert('todelete');
      expect(await dao.getByName('todelete'), isNotNull);

      await dao.deleteByName('todelete');
      expect(await dao.getByName('todelete'), isNull);
    });

    test('should update color', () async {
      await dao.upsert('colorful', color: '#FF0000');
      await dao.updateColor('colorful', '#00FF00');

      final result = await dao.getByName('colorful');
      expect(result!.color, '#00FF00');
    });

    test('should set color to null', () async {
      await dao.upsert('nullable', color: '#FF0000');
      await dao.updateColor('nullable', null);

      final result = await dao.getByName('nullable');
      expect(result!.color, isNull);
    });

    test('should update secure flag', () async {
      await dao.upsert('securetag');
      expect((await dao.getByName('securetag'))!.isSecure, false);

      await dao.updateSecure('securetag', true);
      expect((await dao.getByName('securetag'))!.isSecure, true);

      await dao.updateSecure('securetag', false);
      expect((await dao.getByName('securetag'))!.isSecure, false);
    });

    test('should handle tag with null color', () async {
      await dao.upsert('nocolor');

      final result = await dao.getByName('nocolor');
      expect(result, isNotNull);
      expect(result!.name, 'nocolor');
      expect(result.color, isNull);
      expect(result.isSecure, false);
    });
  });
}
