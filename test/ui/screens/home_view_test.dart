import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/home_view.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() {
    database.close();
  });

  Widget createTestApp() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: const MaterialApp(home: HomeView()),
    );
  }

  testWidgets('should_render_home_view_with_title', (tester) async {
    await tester.pumpWidget(createTestApp());

    expect(find.text('Taúl'), findsOneWidget);
  });

  testWidgets('should_show_empty_state_when_no_entries', (tester) async {
    await tester.pumpWidget(createTestApp());

    // The in-memory DB resolves synchronously, so data is available immediately
    await tester.pump();

    expect(find.text('No entries yet. Tap + to create one.'), findsOneWidget);
  });

  testWidgets('should_have_add_button', (tester) async {
    await tester.pumpWidget(createTestApp());

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
