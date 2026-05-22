import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/domain/usecases/get_entry.dart';

class MockEntryRepository extends Mock implements IEntryRepository {}

void main() {
  late MockEntryRepository repository;
  late GetEntry useCase;

  setUp(() {
    repository = MockEntryRepository();
    useCase = GetEntry(repository: repository);
  });

  group('GetEntry', () {
    test('should_return_entry_when_found', () async {
      final entry = Entry(
        id: 'test-id',
        type: EntryType.note,
        title: 'Test',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      when(() => repository.getById('test-id')).thenAnswer((_) => Future.value(entry));

      final result = await useCase.call('test-id');
      expect(result.id, 'test-id');
      expect(result.title, 'Test');
    });

    test('should_throw_when_not_found', () async {
      when(() => repository.getById('missing')).thenThrow(
        const EntryNotFoundFailure(),
      );

      expect(
        () => useCase.call('missing'),
        throwsA(isA<EntryNotFoundFailure>()),
      );
    });
  });
}
