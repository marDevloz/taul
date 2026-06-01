import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/shared/tag_palette.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/home_view.dart';
import 'package:taul/infrastructure/database/app_database.dart';

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
      final tags = ['pendiente', 'completada', 'favorito', 'archivado', 'work'];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            tagsListProvider.overrideWith((ref) => tags),
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

      // System tags should appear in the filter
      expect(find.text('pendiente'), findsOneWidget);
      expect(find.text('completada'), findsOneWidget);
      expect(find.text('favorito'), findsOneWidget);
      expect(find.text('archivado'), findsOneWidget);
      expect(find.text('work'), findsOneWidget);
    });
  });
}
