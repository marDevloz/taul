import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class MockEntryRepository extends Mock implements IEntryRepository {}

void main() {
  late MockEntryRepository repository;

  setUpAll(() {
    registerFallbackValue(
      Entry(
        id: 'fallback',
        type: EntryType.note,
        title: 'fallback',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  setUp(() {
    repository = MockEntryRepository();
  });

  group('IEntryRepository.list', () {
    test('should_accept_excludeArchived_parameter', () async {
      when(
        () => repository.list(excludeArchived: any(named: 'excludeArchived')),
      ).thenAnswer((_) async => []);

      final result = await repository.list(excludeArchived: true);

      expect(result, isEmpty);
      verify(() => repository.list(excludeArchived: true)).called(1);
    });

    test('should_default_excludeArchived_to_false', () async {
      when(() => repository.list()).thenAnswer((_) async => []);

      final result = await repository.list();

      expect(result, isEmpty);
      verify(() => repository.list()).called(1);
    });
  });
}
