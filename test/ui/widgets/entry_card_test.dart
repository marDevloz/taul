import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/widgets/entry_card.dart';

void main() {
  final testEntry = Entry(
    id: 'test-1',
    type: EntryType.note,
    title: 'Test Note',
    content: 'Test content',
    tags: ['tag1'],
    tagsColors: {},
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    version: 1,
  );

  group('EntryCard grid mode — accent bar', () {
    testWidgets('should_show_left_border_when_displayColor_provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(
              entry: testEntry,
              isGrid: true,
              displayColor: Colors.red,
            ),
          ),
        ),
      );

      // The card is wrapped in a Container with a left border
      // Verify the Container decoration exists
      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration?;

      expect(decoration, isNotNull);
      expect(decoration!.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.left.color, Colors.red);
      expect(border.left.width, 4);
    });

    testWidgets('should_hide_left_border_when_displayColor_is_null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(
              entry: testEntry,
              isGrid: true,
              displayColor: null,
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration?;

      expect(decoration, isNotNull);
      final border = decoration!.border as Border;
      expect(border.left.color, Colors.transparent);
    });
  });

  group('EntryCard list mode — colored dot', () {
    testWidgets('should_show_colored_dot_when_displayColor_provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(
              entry: testEntry,
              isGrid: false,
              displayColor: Colors.blue,
            ),
          ),
        ),
      );

      // Look for the small colored dot container
      final dotFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == Colors.blue &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            w.constraints?.maxWidth == 8,
      );

      expect(dotFinder, findsOneWidget);
    });

    testWidgets('should_hide_dot_when_displayColor_is_null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(
              entry: testEntry,
              isGrid: false,
              displayColor: null,
            ),
          ),
        ),
      );

      // The dot Container should not exist in the tree
      final dotFinder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            w.constraints?.maxWidth == 8,
      );

      expect(dotFinder, findsNothing);
    });
  });
}
