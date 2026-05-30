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
      expect(all, hasLength(2));
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
}
