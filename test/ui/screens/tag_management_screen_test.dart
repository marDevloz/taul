import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/tag_management_screen.dart';

void main() {
  group('TagManagementScreen', () {
    testWidgets('should_render_empty_state_when_no_tags', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagSettingsListProvider.overrideWith(
              (ref) => Future.value(<TagSetting>[]),
            ),
          ],
          child: const MaterialApp(home: TagManagementScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay etiquetas'), findsOneWidget);
      expect(find.text('Agregá una etiqueta con el botón +'), findsOneWidget);
    });

    testWidgets('should_render_tag_list', (tester) async {
      final tags = [
        TagSetting(
          name: 'work',
          color: '#E06C75',
          isSecure: false,
          createdAt: DateTime(2024, 1, 1),
        ),
        TagSetting(
          name: 'personal',
          color: '#98C379',
          isSecure: true,
          createdAt: DateTime(2024, 1, 2),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagSettingsListProvider.overrideWith(
              (ref) => Future.value(tags),
            ),
          ],
          child: const MaterialApp(home: TagManagementScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('work'), findsOneWidget);
      expect(find.text('personal'), findsOneWidget);
      expect(find.text('Requiere autenticación'), findsOneWidget);
    });

    testWidgets('should_show_add_dialog_when_plus_tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagSettingsListProvider.overrideWith(
              (ref) => Future.value(<TagSetting>[]),
            ),
          ],
          child: const MaterialApp(home: TagManagementScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the + button in the AppBar
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Dialog should show
      expect(find.text('Nueva etiqueta'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Crear'), findsOneWidget);
      // Palette picker should be present (16 color circles)
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('should_show_add_dialog_validation_error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagSettingsListProvider.overrideWith(
              (ref) => Future.value(<TagSetting>[]),
            ),
          ],
          child: const MaterialApp(home: TagManagementScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Open add dialog
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Tap Crear without entering a name
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      // Error message should appear
      expect(find.text('El nombre no puede estar vacío'), findsOneWidget);
    });

    testWidgets('should_show_rename_dialog_when_tapping_tag', (tester) async {
      final tags = [
        TagSetting(
          name: 'work',
          color: '#E06C75',
          isSecure: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagSettingsListProvider.overrideWith(
              (ref) => Future.value(tags),
            ),
          ],
          child: const MaterialApp(home: TagManagementScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the tag
      await tester.tap(find.text('work'));
      await tester.pumpAndSettle();

      // Rename dialog should show
      expect(find.text('Renombrar etiqueta'), findsOneWidget);
      expect(find.text('Renombrar'), findsOneWidget);
    });

    testWidgets('should_show_delete_confirmation_on_long_press',
        (tester) async {
      final tags = [
        TagSetting(
          name: 'work',
          color: '#E06C75',
          isSecure: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagSettingsListProvider.overrideWith(
              (ref) => Future.value(tags),
            ),
          ],
          child: const MaterialApp(home: TagManagementScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Long press the tag
      await tester.longPress(find.text('work'));
      await tester.pumpAndSettle();

      // Delete confirmation should show
      expect(find.text('Eliminar etiqueta'), findsOneWidget);
      expect(find.textContaining('¿Eliminar la etiqueta'), findsOneWidget);
    });

    testWidgets('should_render_secure_toggle', (tester) async {
      final tags = [
        TagSetting(
          name: 'work',
          color: '#E06C75',
          isSecure: true,
          createdAt: DateTime(2024, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagSettingsListProvider.overrideWith(
              (ref) => Future.value(tags),
            ),
          ],
          child: const MaterialApp(home: TagManagementScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Switch should be present and toggled on
      final switches = find.byType(Switch);
      expect(switches, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switches);
      expect(switchWidget.value, isTrue);
    });
  });
}
