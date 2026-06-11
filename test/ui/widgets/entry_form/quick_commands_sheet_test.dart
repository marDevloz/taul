import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/ui/widgets/entry_form/quick_commands_sheet.dart';

void main() {
  group('QuickCommandsSheet', () {
    testWidgets('should show the title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => QuickCommandsSheet.show(context),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Comandos rápidos'), findsOneWidget);
    });

    testWidgets('should render 6 command entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => QuickCommandsSheet.show(context),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find all QuickCommandTile instances in the widget tree
      expect(find.byType(QuickCommandTile), findsNWidgets(6));
    });

    testWidgets('should contain the idea command example', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => QuickCommandsSheet.show(context),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('!idea genial'), findsOneWidget);
      expect(find.text('Crear idea'), findsOneWidget);
    });
  });
}
