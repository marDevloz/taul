import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/home_view.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart'
    hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/database/tag_settings_dao.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() {
    database.close();
  });

  group('SnakeFab Task filter', () {
    testWidgets('should show Task type in type filter options', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
          ],
          child: const MaterialApp(home: HomeView()),
        ),
      );
      await tester.pumpAndSettle();

      // Find the type filter FAB (filter_list icon) and expand it
      final filterFab = find.byIcon(Icons.filter_list);
      expect(filterFab, findsOneWidget);

      await tester.tap(filterFab);
      await tester.pumpAndSettle();

      // Task option should be visible
      expect(find.text('Tarea'), findsOneWidget);
    });

    testWidgets('should show Task icon in type filter', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
          ],
          child: const MaterialApp(home: HomeView()),
        ),
      );
      await tester.pumpAndSettle();

      // Expand the type filter
      final filterFab = find.byIcon(Icons.filter_list);
      await tester.tap(filterFab);
      await tester.pumpAndSettle();

      // The checklist icon for Task should be visible
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });
  });

  group('SnakeFab system tags in filter', () {
    testWidgets('should include system tags in tag filter', (tester) async {
      // Insert a user tag so we also test that user + system show up
      final dao = TagSettingsDao(database);
      await dao.upsert('work', color: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
          ],
          child: const MaterialApp(home: HomeView()),
        ),
      );
      await tester.pumpAndSettle();

      // Find the tag filter FAB and expand it
      final tagFab = find.byIcon(Icons.sell_outlined);
      expect(tagFab, findsOneWidget);

      await tester.tap(tagFab);
      await tester.pumpAndSettle();

      // System tags (seeded by migration) + user tag should appear
      expect(find.text('pendiente'), findsOneWidget);
      expect(find.text('completada'), findsOneWidget);
      expect(find.text('favorito'), findsOneWidget);
      expect(find.text('archivado'), findsOneWidget);
      expect(find.text('work'), findsOneWidget);
    });
  });

  group('Search with FTS5 unavailable', () {
    testWidgets('should_open_and_degrade_search_when_fts5_unavailable',
        (tester) async {
      // Simulate a device without FTS5: the entries_fts virtual table never
      // gets created, so the FTS query throws "no such table: entries_fts".
      await database.customStatement('DROP TABLE entries_fts');

      final dao = EntryDao(database);
      await dao.insert(Entry(
        id: 'fts-down-1',
        type: EntryType.note,
        title: 'Flutter notes',
        content: 'Some content about Flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
          ],
          child: const MaterialApp(home: HomeView()),
        ),
      );
      await tester.pumpAndSettle();

      // Open the search bar from the AppBar and type a query.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Flutter');
      await tester.pumpAndSettle();

      // Search degrades to LIKE instead of crashing: the matching entry shows
      // and no raw SQL error reaches the UI.
      expect(find.text('Flutter notes'), findsOneWidget);
      expect(find.textContaining('no such table'), findsNothing);
    });
  });
}
