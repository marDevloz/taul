import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:taul/domain/usecases/toggle_entry_tag.dart';

class MockEntryRepository extends Mock implements IEntryRepository {}

void main() {
  late MockEntryRepository repository;
  late ToggleEntryTag useCase;

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
    useCase = ToggleEntryTag(repository: repository);
  });

  group('ToggleEntryTag', () {
    test('should_add_tag_when_not_present', () async {
      final entry = Entry(
        id: 'entry-1',
        type: EntryType.note,
        title: 'Note',
        content: 'Content',
        tags: ['existing'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      when(() => repository.update(any())).thenAnswer((invocation) {
        final entry = invocation.positionalArguments[0] as Entry;
        return Future.value(entry);
      });

      final result = await useCase.call(entry, 'favorito');

      expect(result.tags, contains('favorito'));
      expect(result.tags, contains('existing'));
      expect(result.version, entry.version + 1);
    });

    test('should_remove_tag_when_present', () async {
      final entry = Entry(
        id: 'entry-2',
        type: EntryType.note,
        title: 'Note',
        content: 'Content',
        tags: ['favorito', 'existing'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      when(() => repository.update(any())).thenAnswer((invocation) {
        final entry = invocation.positionalArguments[0] as Entry;
        return Future.value(entry);
      });

      final result = await useCase.call(entry, 'favorito');

      expect(result.tags, isNot(contains('favorito')));
      expect(result.tags, contains('existing'));
    });
  });
}
