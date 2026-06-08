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
      List<TagSetting>? tags,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: TagAutocompleteInput(
            allTags: tags ?? allTags,
            selectedTags: const [],
            initialText: initialText,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('should show first matching suggestion as chip', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), 'traba');
      await tester.pumpAndSettle();

      // Should show one chip with the first match
      expect(find.text('trabajo'), findsOneWidget);
    });

    testWidgets('should update suggestion as user types more', (tester) async {
      final moreTags = [
        TagSetting(name: 'proyecto-alpha', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
        TagSetting(name: 'proyecto-beta', isSecure: false, isSystem: false, createdAt: DateTime(2026)),
      ];
      await tester.pumpWidget(buildTestWidget(tags: moreTags));

      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pumpAndSettle();

      expect(find.text('proyecto-alpha'), findsOneWidget);
      expect(find.text('proyecto-beta'), findsNothing);
    });

    testWidgets('should add tag when chip tapped', (tester) async {
      String? changedValue;
      await tester.pumpWidget(buildTestWidget(onChanged: (v) => changedValue = v));

      await tester.enterText(find.byType(TextField), 'traba');
      await tester.pumpAndSettle();

      await tester.tap(find.text('trabajo'));
      await tester.pumpAndSettle();

      expect(changedValue, 'trabajo,');
    });

    testWidgets('should hide suggestion when input is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // No text typed — no suggestion chip
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('should hide suggestion when no match', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();

      // No suggestion chip should be visible
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('should not show already selected tags', (tester) async {
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

      await tester.enterText(find.byType(TextField), 'traba');
      await tester.pumpAndSettle();

      // "trabajo" is selected, should not appear as suggestion
      expect(find.text('trabajo'), findsNothing);
    });
  });
}
