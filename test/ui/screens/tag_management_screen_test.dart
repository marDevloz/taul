import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/domain/repositories/i_tag_settings_repository.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/tag_management_screen.dart';

/// Minimal stub that implements ITagSettingsRepository for widget tests.
/// Does nothing on save — enough to prevent real DB calls.
class _StubTagSettingsRepository implements ITagSettingsRepository {
  @override
  Future<List<TagSetting>> getAll() => Future.value([]);

  @override
  Future<TagSetting?> getByName(String name) => Future.value(null);

  @override
  Future<void> save(String name,
      {String? color, bool isSecure = false, bool isSystem = false}) async {}

  @override
  Future<void> delete(String name) async {}

  @override
  Future<void> updateColor(String name, String? color) async {}

  @override
  Future<void> updateSecure(String name, bool isSecure) async {}

  @override
  Future<List<TagSetting>> getSystemTags() => Future.value([]);

  @override
  Future<List<TagSetting>> getUserTags() => Future.value([]);

  @override
  Future<void> seedSystemTags() async {}
}

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

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Nueva etiqueta'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Crear'), findsOneWidget);
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

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('work'));
      await tester.pumpAndSettle();

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

      await tester.longPress(find.text('work'));
      await tester.pumpAndSettle();

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

      final switches = find.byType(Switch);
      expect(switches, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switches);
      expect(switchWidget.value, isTrue);
    });

    // --- NEW TESTS for Task 4.2 ---

    group('system tags section', () {
      testWidgets('should show system tags in separate section', (tester) async {
        final tags = [
          TagSetting(
            name: 'pendiente',
            color: '#FFC107',
            isSecure: false,
            isSystem: true,
            createdAt: DateTime(2024, 1, 1),
          ),
          TagSetting(
            name: 'work',
            color: '#E06C75',
            isSecure: false,
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

        // Should show section headers
        expect(find.text('Tags del sistema'), findsOneWidget);
        expect(find.text('Tags personalizados'), findsOneWidget);

        // Both tags should be present
        expect(find.text('pendiente'), findsOneWidget);
        expect(find.text('work'), findsOneWidget);
      });

      testWidgets('should show lock icon for system tags', (tester) async {
        final tags = [
          TagSetting(
            name: 'pendiente',
            color: '#FFC107',
            isSecure: false,
            isSystem: true,
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

        // System tag should have a lock icon in the CircleAvatar
        expect(find.byIcon(Icons.lock), findsOneWidget);
      });

      testWidgets('should not show delete option for system tags', (tester) async {
        final tags = [
          TagSetting(
            name: 'pendiente',
            color: '#FFC107',
            isSecure: false,
            isSystem: true,
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

        // Long press on system tag should NOT show delete dialog
        await tester.longPress(find.text('pendiente'));
        await tester.pumpAndSettle();

        // Delete dialog should NOT appear
        expect(find.text('Eliminar etiqueta'), findsNothing);
      });

      testWidgets('should not show rename dialog for system tags', (tester) async {
        final tags = [
          TagSetting(
            name: 'pendiente',
            color: '#FFC107',
            isSecure: false,
            isSystem: true,
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

        // Tap on system tag should NOT show rename dialog
        await tester.tap(find.text('pendiente'));
        await tester.pumpAndSettle();

        // Rename dialog should NOT appear
        expect(find.text('Renombrar etiqueta'), findsNothing);
      });

      testWidgets(
          'should change color of system tag and never show rename dialog',
          (tester) async {
        final tag = TagSetting(
          name: 'favorito',
          color: '#E53935',
          isSecure: false,
          isSystem: true,
          createdAt: DateTime(2024, 1, 1),
        );

        final stubRepo = _StubTagSettingsRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tagSettingsListProvider.overrideWith(
                (ref) => Future.value([tag]),
              ),
              tagSettingsRepositoryProvider.overrideWith(
                (ref) => stubRepo,
              ),
            ],
            child: const MaterialApp(home: TagManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // ── Step 1: Tap system tag → color picker opens, rename does NOT ──
        await tester.tap(find.text('favorito'));
        await tester.pumpAndSettle();

        expect(find.text('Color para "favorito"'), findsOneWidget);
        expect(find.text('Renombrar etiqueta'), findsNothing);

        // ── Step 2: Select a palette color ──
        // PalettePicker inside AlertDialog: 1 sin-color + 16 palette GestureDetectors.
        // Index 0 = sin color, index 1 = first palette color.
        final dialog = find.byType(AlertDialog);
        final tappableInDialog = find.descendant(
          of: dialog,
          matching: find.byWidgetPredicate(
            (w) => w is GestureDetector && w.onTap != null,
          ),
        );
        await tester.tap(tappableInDialog.at(1));
        await tester.pumpAndSettle();

        // Dialog closed → color picker gone
        expect(find.text('Color para "favorito"'), findsNothing);
        // Rename never appeared
        expect(find.text('Renombrar etiqueta'), findsNothing);

        // ── Step 3: Tap system tag AGAIN → color picker, NOT rename ──
        await tester.tap(find.text('favorito'));
        await tester.pumpAndSettle();

        expect(find.text('Color para "favorito"'), findsOneWidget);
        expect(find.text('Renombrar etiqueta'), findsNothing);
      });

      testWidgets('should show only user tags when no system tags exist', (tester) async {
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

        // Should NOT show system tags section
        expect(find.text('Tags del sistema'), findsNothing);
        // Should show user tags section
        expect(find.text('Tags personalizados'), findsOneWidget);
      });
    });
  });
}
