import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/database/tag_settings_dao.dart';
import 'package:taul/infrastructure/database/tag_settings_repository_impl.dart';

void main() {
  late AppDatabase database;
  late TagSettingsDao dao;
  late TagSettingsRepositoryImpl repository;

  setUp(() {
    database = AppDatabase.forTesting();
    dao = TagSettingsDao(database);
    repository = TagSettingsRepositoryImpl(dao: dao);
  });

  tearDown(() {
    database.close();
  });

  group('TagSettingsRepositoryImpl', () {
    test('should_save_and_get_all_tags', () async {
      await repository.save('urgent', color: '#E06C75');
      await repository.save('work', color: '#61AFEF');

      final all = await repository.getAll();
      // 4 system tags seeded in onCreate + 2 user tags
      expect(all, hasLength(6));
      expect(all.map((t) => t.name), containsAll(['urgent', 'work']));
    });

    test('should_get_by_name', () async {
      await repository.save('urgent', color: '#E06C75');

      final result = await repository.getByName('urgent');
      expect(result, isNotNull);
      expect(result!.name, 'urgent');
      expect(result.color, '#E06C75');
    });

    test('should_return_null_for_missing_tag', () async {
      final result = await repository.getByName('nonexistent');
      expect(result, isNull);
    });

    test('should_delete_tag', () async {
      await repository.save('todelete');
      expect(await repository.getByName('todelete'), isNotNull);

      await repository.delete('todelete');
      expect(await repository.getByName('todelete'), isNull);
    });

    test('should_update_color', () async {
      await repository.save('colorful', color: '#FF0000');
      await repository.updateColor('colorful', '#00FF00');

      final result = await repository.getByName('colorful');
      expect(result!.color, '#00FF00');
    });

    test('should_update_secure', () async {
      await repository.save('securetag');
      await repository.updateSecure('securetag', true);

      final result = await repository.getByName('securetag');
      expect(result!.isSecure, true);
    });

    test('should_round_trip_with_is_secure', () async {
      await repository.save('secret', color: '#FF0000', isSecure: true);

      final result = await repository.getByName('secret');
      expect(result!.isSecure, true);
      expect(result.color, '#FF0000');
    });
  });

  group('TagSettingsRepositoryImpl - isSystem', () {
    test('should default isSystem to false for user tags', () async {
      await repository.save('usertag', color: '#FF0000');
      final result = await repository.getByName('usertag');
      expect(result!.isSystem, false);
    });

    test('should persist isSystem when set to true', () async {
      await repository.save('pendiente', isSystem: true);
      final result = await repository.getByName('pendiente');
      expect(result!.isSystem, true);
    });

    test('should getSystemTags return only system tags', () async {
      await repository.save('work', isSystem: false);

      final systemTags = await repository.getSystemTags();
      // 4 system tags seeded in onCreate
      expect(systemTags, hasLength(4));
      final names = systemTags.map((t) => t.name).toSet();
      expect(names, containsAll(['pendiente', 'completada', 'favorito', 'archivado']));

      for (final tag in systemTags) {
        expect(tag.isSystem, true);
      }
    });

    test('should getUserTags return only user tags', () async {
      await repository.save('work', isSystem: false);
      await repository.save('personal', isSystem: false);

      final userTags = await repository.getUserTags();
      expect(userTags, hasLength(2));
      final names = userTags.map((t) => t.name).toSet();
      expect(names, containsAll(['work', 'personal']));

      for (final tag in userTags) {
        expect(tag.isSystem, false);
      }
    });

    test('should seedSystemTags create 4 system tags', () async {
      await repository.seedSystemTags();

      final systemTags = await repository.getSystemTags();
      expect(systemTags, hasLength(4));

      final names = systemTags.map((t) => t.name).toSet();
      expect(names, containsAll(['pendiente', 'completada', 'favorito', 'archivado']));
    });

    test('should seedSystemTags be idempotent', () async {
      await repository.seedSystemTags();
      await repository.seedSystemTags();

      final systemTags = await repository.getSystemTags();
      expect(systemTags, hasLength(4));
    });
  });
}
