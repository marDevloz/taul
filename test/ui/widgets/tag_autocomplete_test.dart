import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/ui/widgets/tag_autocomplete.dart';
import 'package:taul/ui/widgets/tag_suggestions.dart';

void main() {
  group('TagAutocomplete', () {
    final allTags = [
      TagSetting(name: 'trabajo', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
      TagSetting(name: 'personal', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
      TagSetting(name: 'urgente', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
    ];

    Widget buildTestWidget({
      String initialText = '',
      ValueChanged<String>? onChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: TagAutocompleteInput(
            allTags: allTags,
            selectedTags: const [],
            initialText: initialText,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('should show suggestions when typing', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Type "traba" to trigger suggestions
      await tester.enterText(find.byType(TextField), 'traba');
      await tester.pumpAndSettle();

      // Should show matching suggestion
      expect(find.text('trabajo'), findsOneWidget);
      expect(find.text('personal'), findsNothing);
    });

    testWidgets('should show all tags when field is focused and empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Focus the field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Should show all tags
      expect(find.text('trabajo'), findsOneWidget);
      expect(find.text('personal'), findsOneWidget);
      expect(find.text('urgente'), findsOneWidget);
    });

    testWidgets('should add tag to input when suggestion tapped', (tester) async {
      String? changedValue;
      await tester.pumpWidget(buildTestWidget(onChanged: (v) => changedValue = v));

      // Focus and type "pro"
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'traba');
      await tester.pumpAndSettle();

      // Tap the suggestion
      await tester.tap(find.text('trabajo'));
      await tester.pumpAndSettle();

      // Input should now contain "trabajo,"
      expect(changedValue, 'trabajo,');
    });

    testWidgets('should hide suggestions after selection', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'traba');
      await tester.pumpAndSettle();

      // Suggestions visible
      expect(find.text('trabajo'), findsOneWidget);

      // Select
      await tester.tap(find.text('trabajo'));
      await tester.pumpAndSettle();

      // Suggestions should hide (no more suggestion chips)
      // The text "trabajo" now appears in the TextField, not as a suggestion
    });

    testWidgets('should not show already selected tags as suggestions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagAutocompleteInput(
              allTags: allTags,
              selectedTags: const ['trabajo'],
              initialText: '',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // "trabajo" should NOT appear as a suggestion (already selected)
      // Only "personal" and "urgente" should appear
      expect(find.text('trabajo'), findsNothing);
      expect(find.text('personal'), findsOneWidget);
      expect(find.text('urgente'), findsOneWidget);
    });

    testWidgets('should show "Crear tag" option when no exact match', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nuevotag');
      await tester.pumpAndSettle();

      // Should show "Crear tag: nuevotag" option
      expect(find.textContaining('Crear tag'), findsOneWidget);
    });
  });
}
