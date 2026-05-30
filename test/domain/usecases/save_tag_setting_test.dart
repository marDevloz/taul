import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/repositories/i_tag_settings_repository.dart';
import 'package:taul/domain/usecases/save_tag_setting.dart';

class MockTagSettingsRepository extends Mock implements ITagSettingsRepository {}

void main() {
  late MockTagSettingsRepository repository;
  late SaveTagSetting useCase;

  setUp(() {
    repository = MockTagSettingsRepository();
    useCase = SaveTagSetting(repository: repository);
  });

  group('SaveTagSetting', () {
    test('should_save_tag_with_color', () async {
      when(() => repository.save('urgent', color: '#E06C75', isSecure: false))
          .thenAnswer((_) => Future.value());

      await useCase.call('urgent', color: '#E06C75');

      verify(() => repository.save('urgent', color: '#E06C75', isSecure: false))
          .called(1);
    });

    test('should_save_tag_with_is_secure', () async {
      when(() => repository.save('secret', color: any(named: 'color'), isSecure: true))
          .thenAnswer((_) => Future.value());

      await useCase.call('secret', isSecure: true);

      verify(() => repository.save('secret', color: any(named: 'color'), isSecure: true))
          .called(1);
    });

    test('should_save_tag_with_no_optional_fields', () async {
      when(() => repository.save('simple', color: any(named: 'color'), isSecure: false))
          .thenAnswer((_) => Future.value());

      await useCase.call('simple');

      verify(() => repository.save('simple', color: any(named: 'color'), isSecure: false))
          .called(1);
    });
  });
}
