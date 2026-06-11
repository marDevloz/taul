import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/widgets/entry_form/entry_type_selector.dart';

void main() {
  group('EntryTypeSelector', () {
    testWidgets('should show the current type label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryTypeSelector(
              currentType: EntryType.note,
              isManual: true,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Nota'), findsOneWidget);
    });

    testWidgets('should list all 5 entry types when opened', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryTypeSelector(
              currentType: EntryType.note,
              isManual: true,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      // Tap to open the popup menu
      await tester.tap(find.byType(PopupMenuButton<EntryType?>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // All 5 types should be listed
      expect(find.text('Nota'), findsWidgets);
      expect(find.text('Idea'), findsOneWidget);
      expect(find.text('Tarea'), findsOneWidget);
      expect(find.text('Glosario'), findsOneWidget);
      expect(find.text('Credencial'), findsOneWidget);
    });

    testWidgets('should fire onSelected when credential is tapped',
        (tester) async {
      EntryType? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryTypeSelector(
              currentType: EntryType.note,
              isManual: true,
              onSelected: (type) => selected = type,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<EntryType?>));
      await tester.pumpAndSettle();

      // Tap the Credencial ListTile specifically
      await tester.tap(find.widgetWithText(ListTile, 'Credencial'));
      await tester.pump();

      expect(selected, EntryType.credential);
    });

    testWidgets('should show the Auto option when showAutoOption is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryTypeSelector(
              currentType: EntryType.note,
              isManual: false,
              showAutoOption: true,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<EntryType?>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('detectar del contenido'), findsOneWidget);
    });

    testWidgets('should not show Auto option when showAutoOption is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryTypeSelector(
              currentType: EntryType.note,
              isManual: true,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<EntryType?>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Auto'), findsNothing);
    });
  });
}
