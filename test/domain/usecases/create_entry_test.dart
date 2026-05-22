import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/domain/usecases/create_entry.dart';

class MockEntryRepository extends Mock implements IEntryRepository {}

void main() {
  late MockEntryRepository repository;
  late CreateEntry useCase;

  setUp(() {
    repository = MockEntryRepository();
    useCase = CreateEntry(repository: repository);
  });

  group('CreateEntry', () {
    test('should_create_entry_with_valid_data', () async {
      when(() => repository.create(any())).thenAnswer((invocation) {
        final entry = invocation.positionalArguments[0] as Entry;
        return Future.value(entry);
      });

      final result = await useCase.call(
        title: 'Test Note',
        content: 'Test content',
      );

      expect(result.title, 'Test Note');
      expect(result.content, 'Test content');
      expect(result.type, EntryType.note);
      expect(result.id.isNotEmpty, true);
      expect(result.version, 1);
      verify(() => repository.create(any())).called(1);
    });

    test('should_throw_on_empty_title', () async {
      expect(
        () => useCase.call(title: '', content: 'content'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('should_infer_idea_type_when_content_starts_with_exclamation', () async {
      when(() => repository.create(any())).thenAnswer(
        (i) => Future.value(i.positionalArguments[0] as Entry),
      );

      final result = await useCase.call(title: 'Idea', content: '! great idea');

      expect(result.type, EntryType.idea);
    });

    test('should_infer_glossary_type_when_content_contains_at', () async {
      when(() => repository.create(any())).thenAnswer(
        (i) => Future.value(i.positionalArguments[0] as Entry),
      );

      final result = await useCase.call(title: 'Term', content: 'definition @context');

      expect(result.type, EntryType.glossary);
    });
  });
}
