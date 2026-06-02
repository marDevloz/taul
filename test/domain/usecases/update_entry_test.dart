import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/domain/usecases/update_entry.dart';

class MockEntryRepository extends Mock implements IEntryRepository {}

void main() {
  late MockEntryRepository repository;
  late UpdateEntry useCase;

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
    useCase = UpdateEntry(repository: repository);
  });

  group('UpdateEntry', () {
    test('should_reattach_pendiente_when_task_missing_pendiente_and_no_completada',
        () async {
      final existing = Entry(
        id: 'task-1',
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

      final result = await useCase.call(existing);

      expect(result.tags, contains('pendiente'));
      expect(result.tags, contains('urgente'));
    });

    test('should_not_add_pendiente_when_task_already_has_it', () async {
      final existing = Entry(
        id: 'task-2',
        type: EntryType.task,
        title: 'Task',
        content: 'Do it',
        tags: ['pendiente', 'urgente'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      when(() => repository.update(any())).thenAnswer((invocation) {
        final entry = invocation.positionalArguments[0] as Entry;
        return Future.value(entry);
      });

      final result = await useCase.call(existing);

      expect(result.tags.where((t) => t == 'pendiente').length, 1);
    });

    test('should_not_add_pendiente_when_task_has_completada', () async {
      final existing = Entry(
        id: 'task-3',
        type: EntryType.task,
        title: 'Task',
        content: 'Done',
        tags: ['completada', 'urgente'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      when(() => repository.update(any())).thenAnswer((invocation) {
        final entry = invocation.positionalArguments[0] as Entry;
        return Future.value(entry);
      });

      final result = await useCase.call(existing);

      expect(result.tags, isNot(contains('pendiente')));
      expect(result.tags, contains('completada'));
    });

    test('should_not_affect_tags_for_non_task_entries', () async {
      final existing = Entry(
        id: 'note-1',
        type: EntryType.note,
        title: 'Note',
        content: 'Just a note',
        tags: ['personal'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      when(() => repository.update(any())).thenAnswer((invocation) {
        final entry = invocation.positionalArguments[0] as Entry;
        return Future.value(entry);
      });

      final result = await useCase.call(existing);

      expect(result.tags, ['personal']);
    });
  });
}
