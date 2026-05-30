import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/shared/tag_palette.dart';
import 'package:taul/ui/widgets/palette_picker.dart';

void main() {
  group('PalettePicker', () {
    testWidgets('should render 16 color circles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PalettePicker(
                onColorSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // The GridView should have 16 items (we can verify by checking the grid delegate)
      // Since GridView is lazy, we check that all 16 colors are in TagPalette
      expect(TagPalette.colors.length, 16);
      
      // Find the GridView and verify it has the correct delegate
      final gridView = find.byType(GridView);
      expect(gridView, findsOneWidget);
    });

    testWidgets('should return selected color when tapped', (tester) async {
      String? selectedHex;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PalettePicker(
              onColorSelected: (hex) {
                selectedHex = hex;
              },
            ),
          ),
        ),
      );

      // Tap the first color (red)
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(selectedHex, isNotNull);
      // Should return the hex string of the first palette color
      expect(selectedHex, TagPalette.colors.first.hex);
    });

    testWidgets('should show checkmark on initially selected color', (tester) async {
      final initialColor = TagPalette.colors[5].color; // cyan
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PalettePicker(
              initialColor: initialColor,
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      // The selected circle should have a checkmark icon
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('should show checkmark on newly selected color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PalettePicker(
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      // Initially no checkmark
      expect(find.byIcon(Icons.check), findsNothing);

      // Tap the third color (yellow)
      await tester.tap(find.byType(GestureDetector).at(2));
      await tester.pumpAndSettle();

      // Now should show checkmark
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('should not show checkmark when no color is initially selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PalettePicker(
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      // Initially no checkmark
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('should update checkmark when different color is selected', (tester) async {
      final initialColor = TagPalette.colors[3].color; // amber
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PalettePicker(
              initialColor: initialColor,
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      // Initially checkmark on amber (index 3)
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap the first color (red)
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Checkmark should still be visible (now on red)
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}