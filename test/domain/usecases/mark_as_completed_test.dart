import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/domain/usecases/mark_as_completed.dart';

class MockEntryRepository extends Mock implements IEntryRepository {}

void main() {
  late MockEntryRepository repository;
  late MarkAsCompleted useCase;

  setUpAll(() {
    registerFallbackValue(
      Entry(
        id: 'fallback',
        type: EntryType.note,
        title: 'fallback',
        content: '',
        metadata: {},
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      ),
    );
  });

  setUp(() {
    repository = MockEntryRepository();
    useCase = MarkAsCompleted(repository: repository);
  });

  group('MarkAsCompleted', () {
    test('should_swap_pendiente_for_completada_and_set_completed_at', () async {
      final task = Entry(
        id: 'task-1',
        type: EntryType.task,
        title: 'Task',
        content: 'Do it',
        tags: ['pendiente', 'urgente'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      Entry? captured;
      when(() => repository.update(any())).thenAnswer((invocation) {
        captured = invocation.positionalArguments[0] as Entry;
        return Future.value(captured!);
      });

      final result = await useCase.call(task);

      expect(result.tags, isNot(contains('pendiente')));
      expect(result.tags, contains('completada'));
      expect(result.tags, contains('urgente'));
      expect(result.completedAt, isNotNull);
      expect(result.version, task.version + 1);
    });

    test('should_set_completedAt_even_when_no_pendiente', () async {
      final task = Entry(
        id: 'task-2',
        type: EntryType.task,
        title: 'Task',
        content: 'Do it',
        tags: ['urgente'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      when(() => repository.update(any())).thenAnswer((invocation) {
        final entry = invocation.positionalArguments[0] as Entry;
        return Future.value(entry);
      });

      final result = await useCase.call(task);

      expect(result.tags, contains('completada'));
      expect(result.tags, isNot(contains('pendiente')));
      expect(result.completedAt, isNotNull);
    });
  });
}
