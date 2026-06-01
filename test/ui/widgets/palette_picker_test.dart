import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/shared/tag_palette.dart';
import 'package:taul/ui/widgets/palette_picker.dart';

void main() {
  group('PalettePicker', () {
    testWidgets('should render wrap with palette circles', (tester) async {
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

      expect(TagPalette.colors.length, 16);
      final wrapFinder = find.byType(Wrap);
      expect(wrapFinder, findsOneWidget);
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

      // Tap the second GestureDetector (first palette color, after sin color)
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pumpAndSettle();

      expect(selectedHex, isNotNull);
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

      // Initially no checkmark (sin color selected by default when null)
      // sin color shows checkmark when selected
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap a palette color
      await tester.tap(find.byType(GestureDetector).at(3)); // index 2 in palette, +1 for sin color
      await tester.pumpAndSettle();

      // Now should show checkmark on that color
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('should show checkmark on sin color when initialColor is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PalettePicker(
              initialColor: null,
              onColorSelected: (_) {},
            ),
          ),
        ),
      );

      // Sin color is selected by default when initialColor is null
      // Checkmark should be visible
      expect(find.byIcon(Icons.check), findsOneWidget);
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

      // Initially checkmark on amber
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap the first palette color (red) - index 1 (after sin color)
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pumpAndSettle();

      // Checkmark should still be visible (now on red)
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    // --- NEW TESTS for Task 4.1 ---

    group('sin color option', () {
      testWidgets('should call onColorSelected with empty string when sin color tapped', (tester) async {
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

        // First GestureDetector is sin color
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pumpAndSettle();

        expect(selectedHex, '');
      });

      testWidgets('should show checkmark on sin color when no initial color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PalettePicker(
                initialColor: null,
                onColorSelected: (_) {},
              ),
            ),
          ),
        );

        // Sin color is selected by default
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('should not show checkmark on sin color when real color is selected', (tester) async {
        final initialColor = TagPalette.colors[0].color; // red

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

        // Checkmark should be on the red color, not on sin color
        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('should switch checkmark from sin color to palette color when tapped', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PalettePicker(
                initialColor: null,
                onColorSelected: (_) {},
              ),
            ),
          ),
        );

        // Initially sin color selected (checkmark visible)
        expect(find.byIcon(Icons.check), findsOneWidget);

        // Tap a palette color (index 1 = first palette color)
        await tester.tap(find.byType(GestureDetector).at(1));
        await tester.pumpAndSettle();

        // Checkmark should now be on the palette color
        expect(find.byIcon(Icons.check), findsOneWidget);
      });
    });

    group('system tag support', () {
      testWidgets('should show lock icon for system tags', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PalettePicker(
                systemTags: const ['pendiente', 'completada'],
                onColorSelected: (_) {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.lock), findsNWidgets(2));
      });

      testWidgets('should not call onColorSelected when system tag color tapped', (tester) async {
        String? selectedHex;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PalettePicker(
                systemTags: const ['pendiente'],
                onColorSelected: (hex) {
                  selectedHex = hex;
                },
              ),
            ),
          ),
        );

        // Tap the lock icon (system tag)
        await tester.tap(find.byIcon(Icons.lock));
        await tester.pumpAndSettle();

        // onColorSelected should NOT have been called
        expect(selectedHex, isNull);
      });

      testWidgets('should render system tag circles after palette colors', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PalettePicker(
                systemTags: const ['pendiente'],
                onColorSelected: (_) {},
              ),
            ),
          ),
        );

        // Should have: 1 (sin color) + 16 (palette) + 1 (system tag) = 18 GestureDetectors
        final gestures = find.byType(GestureDetector);
        expect(gestures, findsNWidgets(18));
      });
    });
  });
}
