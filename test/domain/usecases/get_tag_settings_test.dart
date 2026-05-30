import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/domain/repositories/i_tag_settings_repository.dart';
import 'package:taul/domain/usecases/get_tag_settings.dart';

class MockTagSettingsRepository extends Mock implements ITagSettingsRepository {}

void main() {
  late MockTagSettingsRepository repository;
  late GetTagSettings useCase;

  setUp(() {
    repository = MockTagSettingsRepository();
    useCase = GetTagSettings(repository: repository);
  });

  group('GetTagSettings', () {
    test('should_return_all_tags', () async {
      final tags = [
        TagSetting(name: 'urgent', color: '#E06C75', createdAt: DateTime.now()),
        TagSetting(name: 'work', color: '#61AFEF', createdAt: DateTime.now()),
      ];

      when(() => repository.getAll()).thenAnswer((_) => Future.value(tags));

      final result = await useCase.call();
      expect(result, hasLength(2));
      expect(result.first.name, 'urgent');
      verify(() => repository.getAll()).called(1);
    });

    test('should_return_empty_list_when_no_tags', () async {
      when(() => repository.getAll()).thenAnswer((_) => Future.value([]));

      final result = await useCase.call();
      expect(result, isEmpty);
      verify(() => repository.getAll()).called(1);
    });
  });
}
