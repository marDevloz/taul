import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/trash_screen.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() {
    database.close();
  });

  Future<void> seedTrashedEntries(int count) async {
    final now = DateTime.now();
    for (var i = 0; i < count; i++) {
      await database.into(database.entries).insert(
            Entry(
              id: 'trash-$i',
              type: 'NOTA',
              title: 'Entrada ${i + 1}',
              content: 'Contenido $i',
              metadata: '{}',
              tags: '[]',
              requiresAuth: false,
              createdAt: now,
              updatedAt: now,
              version: 1,
              deletedAt: now,
            ),
          );
    }
  }

  Widget createTestApp() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: const MaterialApp(home: TrashScreen()),
    );
  }

  Future<void> pumpTrash(WidgetTester tester) async {
    await tester.pumpWidget(createTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openEmptyTrashDialog(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.delete_sweep));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'should_show_trash_count_in_empty_trash_dialog_when_trash_has_entries',
      (tester) async {
    await seedTrashedEntries(3);

    await pumpTrash(tester);
    await openEmptyTrashDialog(tester);

    expect(find.text('Vaciar papelera'), findsOneWidget);
    expect(
      find.text(
        '¿Eliminar 3 entradas de la papelera permanentemente? '
        'Esta acción no se puede deshacer.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Vaciar'), findsOneWidget);
  });

  testWidgets(
      'should_show_singular_trash_count_in_dialog_when_trash_has_one_entry',
      (tester) async {
    await seedTrashedEntries(1);

    await pumpTrash(tester);
    await openEmptyTrashDialog(tester);

    expect(
      find.text(
        '¿Eliminar 1 entrada de la papelera permanentemente? '
        'Esta acción no se puede deshacer.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'should_delete_all_entries_and_show_snackbar_when_confirming_empty_trash',
      (tester) async {
    await seedTrashedEntries(2);

    await pumpTrash(tester);
    await openEmptyTrashDialog(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Vaciar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('2 entradas eliminadas permanentemente'), findsOneWidget);
    expect(find.text('La papelera está vacía'), findsOneWidget);

    final remaining = await database.select(database.entries).get();
    expect(remaining, isEmpty);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('should_hide_empty_trash_button_when_trash_is_empty',
      (tester) async {
    await pumpTrash(tester);

    expect(find.byIcon(Icons.delete_sweep), findsNothing);
    expect(find.text('La papelera está vacía'), findsOneWidget);
  });
}