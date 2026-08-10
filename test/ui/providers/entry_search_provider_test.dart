import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/ui/providers/entry_providers.dart';

void main() {
  late AppDatabase database;
  late EntryDao dao;

  setUp(() {
    database = AppDatabase.forTesting();
    dao = EntryDao(database);
  });

  tearDown(() {
    database.close();
  });

  Future<void> insertEntry(
    String id,
    String title, {
    EntryType type = EntryType.note,
    String content = 'Contenido de ejemplo',
    List<String> tags = const [],
  }) {
    return dao.insert(Entry(
      id: id,
      type: type,
      title: title,
      content: content,
      tags: tags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('searchResultsProvider with active filters', () {
    test('should_search_within_active_tag_filter', () async {
      await insertEntry('1', 'Plan Flutter', tags: ['work']);
      await insertEntry('2', 'Plan Flutter', tags: ['personal']);

      final container = makeContainer();
      container.read(selectedTagFilterProvider.notifier).state = 'work';
      container.read(entrySearchProvider.notifier).state = 'Plan';

      final results = await container.read(searchResultsProvider.future);

      expect(results.map((e) => e.id), ['1']);
    });

    test('should_search_within_active_type_filter', () async {
      await insertEntry('1', 'Plan Flutter', type: EntryType.note);
      await insertEntry('2', 'Plan Flutter', type: EntryType.idea);

      final container = makeContainer();
      container.read(selectedTypeFilterProvider.notifier).state =
          EntryType.idea;
      container.read(entrySearchProvider.notifier).state = 'Plan';

      final results = await container.read(searchResultsProvider.future);

      expect(results.map((e) => e.id), ['2']);
    });

    test('should_combine_tag_filter_with_search_query', () async {
      await insertEntry('1', 'Flutter notes', tags: ['work']);
      await insertEntry('2', 'Flutter notes', tags: ['personal']);
      await insertEntry('3', 'Sin buscar', tags: ['work']);

      final container = makeContainer();
      container.read(selectedTagFilterProvider.notifier).state = 'work';
      container.read(entrySearchProvider.notifier).state = 'flutter';

      final results = await container.read(searchResultsProvider.future);

      expect(results.map((e) => e.id), ['1']);
    });
  });
}