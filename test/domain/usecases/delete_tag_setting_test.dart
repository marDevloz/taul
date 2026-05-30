import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/repositories/i_tag_settings_repository.dart';
import 'package:taul/domain/usecases/delete_tag_setting.dart';

class MockTagSettingsRepository extends Mock implements ITagSettingsRepository {}

void main() {
  late MockTagSettingsRepository repository;
  late DeleteTagSetting useCase;

  setUp(() {
    repository = MockTagSettingsRepository();
    useCase = DeleteTagSetting(repository: repository);
  });

  group('DeleteTagSetting', () {
    test('should_delete_tag_by_name', () async {
      when(() => repository.delete('urgent')).thenAnswer((_) => Future.value());

      await useCase.call('urgent');

      verify(() => repository.delete('urgent')).called(1);
    });

    test('should_not_throw_when_deleting_non_existent_tag', () async {
      when(() => repository.delete('nonexistent')).thenAnswer((_) => Future.value());

      await expectLater(useCase.call('nonexistent'), completes);
    });
  });
}
