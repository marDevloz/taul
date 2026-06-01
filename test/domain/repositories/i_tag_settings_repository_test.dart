import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/domain/repositories/i_tag_settings_repository.dart';

class MockTagSettingsRepository extends Mock implements ITagSettingsRepository {}

void main() {
  late MockTagSettingsRepository repository;

  setUpAll(() {
    registerFallbackValue(
      TagSetting(name: 'fallback', createdAt: DateTime.now()),
    );
  });

  setUp(() {
    repository = MockTagSettingsRepository();
  });

  group('ITagSettingsRepository', () {
    test('should_have_getSystemTags', () async {
      when(() => repository.getSystemTags()).thenAnswer((_) async => []);

      final result = await repository.getSystemTags();

      expect(result, isEmpty);
      verify(() => repository.getSystemTags()).called(1);
    });

    test('should_have_getUserTags', () async {
      when(() => repository.getUserTags()).thenAnswer((_) async => []);

      final result = await repository.getUserTags();

      expect(result, isEmpty);
      verify(() => repository.getUserTags()).called(1);
    });

    test('should_have_seedSystemTags', () async {
      when(() => repository.seedSystemTags()).thenAnswer((_) async => Future.value());

      await repository.seedSystemTags();

      verify(() => repository.seedSystemTags()).called(1);
    });
  });
}
