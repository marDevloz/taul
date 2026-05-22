import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/domain/usecases/search_entries.dart';

class MockEntryRepository extends Mock implements IEntryRepository {}

void main() {
  late MockEntryRepository repository;
  late SearchEntries useCase;

  setUp(() {
    repository = MockEntryRepository();
    useCase = SearchEntries(repository: repository);
  });

  group('SearchEntries', () {
    test('should_return_empty_for_empty_query', () async {
      final result = await useCase.call('');
      expect(result, isEmpty);
    });

    test('should_call_repository_with_sanitized_query', () async {
      when(() => repository.search('flutter', limit: 100))
          .thenAnswer((_) => Future.value([]));

      await useCase.call('flutter');
      verify(() => repository.search('flutter', limit: 100)).called(1);
    });

    test('should_return_matching_entries', () async {
      final entries = [
        Entry(
          id: '1',
          type: EntryType.note,
          title: 'Flutter notes',
          content: 'Learning Flutter',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(() => repository.search('flutter', limit: 100))
          .thenAnswer((_) => Future.value(entries));

      final result = await useCase.call('flutter');
      expect(result.length, 1);
      expect(result.first.title, contains('Flutter'));
    });
  });
}
