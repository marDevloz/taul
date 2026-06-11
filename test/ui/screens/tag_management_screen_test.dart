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

/// Extended stub that allows controlling which tags fail on delete.
class _ControllableDeleteRepo extends _StubTagSettingsRepository {
  final Set<String> failOnDelete;

  _ControllableDeleteRepo({this.failOnDelete = const {}});

  @override
  Future<void> delete(String name) async {
    if (failOnDelete.contains(name.toLowerCase())) {
      throw Exception('Simulated delete failure for $name');
    }
  }
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

    // --- SYSTEM TAGS ---

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

        expect(find.text('Tags del sistema'), findsOneWidget);
        expect(find.text('Tags personalizados'), findsOneWidget);

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

        await tester.longPress(find.text('pendiente'));
        await tester.pumpAndSettle();

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

        await tester.tap(find.text('pendiente'));
        await tester.pumpAndSettle();

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
        final dialog = find.byType(AlertDialog);
        final tappableInDialog = find.descendant(
          of: dialog,
          matching: find.byWidgetPredicate(
            (w) => w is GestureDetector && w.onTap != null,
          ),
        );
        await tester.tap(tappableInDialog.at(1));
        await tester.pumpAndSettle();

        expect(find.text('Color para "favorito"'), findsNothing);
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

        expect(find.text('Tags del sistema'), findsNothing);
        expect(find.text('Tags personalizados'), findsOneWidget);
      });
    });

    // --- MULTI-SELECT MODE ---

    group('multi-select mode', () {
      testWidgets('should_enter_selection_mode_on_long_press', (tester) async {
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

        // Normal mode: title shows 'Gestionar etiquetas'
        expect(find.text('Gestionar etiquetas'), findsOneWidget);

        // Long-press user tag → enters selection mode
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();

        // Shows checkmark on selected tag
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        // Action bar appears with delete button
        expect(find.byKey(const Key('delete_selected')), findsOneWidget);
        // Count label
        expect(find.text('1 tag seleccionado'), findsOneWidget);
        // AppBar shows selection count instead of title
        expect(find.text('Gestionar etiquetas'), findsNothing);
        // Close button in AppBar
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.close),
          ),
          findsOneWidget,
        );
        // Old delete dialog should NOT appear
        expect(find.text('Eliminar etiqueta'), findsNothing);
      });

      testWidgets('should_toggle_selection_on_tap_in_selection_mode',
          (tester) async {
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

        // Enter selection mode by long-pressing first tag
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('1 tag seleccionado'), findsOneWidget);

        // Tap second tag (while in selection mode) → toggles it on
        await tester.tap(find.text('personal'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
        expect(find.text('2 tags seleccionados'), findsOneWidget);

        // Tap second tag again → toggles it off
        await tester.tap(find.text('personal'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('1 tag seleccionado'), findsOneWidget);
      });

      testWidgets('should_not_select_system_tags', (tester) async {
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

        // Enter selection mode by long-pressing user tag
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();

        expect(find.text('1 tag seleccionado'), findsOneWidget);

        // Tap system tag → should NOT toggle selection
        await tester.tap(find.text('pendiente'));
        await tester.pumpAndSettle();

        // Still only 1 selected
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('1 tag seleccionado'), findsOneWidget);
      });

      testWidgets('should_exit_selection_via_back_button', (tester) async {
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

        // Enter selection mode with 2 tags
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('personal'));
        await tester.pumpAndSettle();

        expect(find.text('2 tags seleccionados'), findsOneWidget);

        // Tap close icon in AppBar
        final appBarClose = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.close),
        );
        await tester.tap(appBarClose);
        await tester.pumpAndSettle();

        // Selection cleared, normal UI restored
        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(find.byKey(const Key('delete_selected')), findsNothing);
        expect(find.text('Gestionar etiquetas'), findsOneWidget);
      });

      testWidgets('should_exit_selection_on_last_deselect', (tester) async {
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

        // Enter selection mode with 1 tag
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();

        expect(find.text('1 tag seleccionado'), findsOneWidget);

        // Tap the same tag to deselect (last one)
        await tester.tap(find.text('work'));
        await tester.pumpAndSettle();

        // Selection cleared, normal UI restored
        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(find.byKey(const Key('delete_selected')), findsNothing);
        expect(find.text('Gestionar etiquetas'), findsOneWidget);
      });

      testWidgets('should_update_count_in_action_bar', (tester) async {
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

        // Select first tag
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();

        expect(find.text('1 tag seleccionado'), findsOneWidget);

        // Select second tag → count updates
        await tester.tap(find.text('personal'));
        await tester.pumpAndSettle();

        expect(find.text('2 tags seleccionados'), findsOneWidget);
      });

      testWidgets('should_hide_action_bar_on_cancel', (tester) async {
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

        // Enter selection mode
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('delete_selected')), findsOneWidget);

        // Tap cancel in action bar
        await tester.tap(find.byKey(const Key('cancel_selection')));
        await tester.pumpAndSettle();

        // Selection cleared, action bar gone
        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(find.byKey(const Key('delete_selected')), findsNothing);
        expect(find.text('Gestionar etiquetas'), findsOneWidget);
      });
    });

    // --- BATCH DELETE ---

    group('batch delete', () {
      final List<TagSetting> twoUserTags = [
        TagSetting(
          name: 'work',
          color: '#E06C75',
          isSecure: false,
          createdAt: DateTime(2024, 1, 1),
        ),
        TagSetting(
          name: 'personal',
          color: '#98C379',
          isSecure: false,
          createdAt: DateTime(2024, 1, 2),
        ),
      ];

      testWidgets('should_show_batch_confirmation', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tagSettingsListProvider.overrideWith(
                (ref) => Future.value(twoUserTags),
              ),
              tagUsageCountProvider.overrideWith(
                (ref) => {'work': 2, 'personal': 1},
              ),
            ],
            child: const MaterialApp(home: TagManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Select both tags
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('personal'));
        await tester.pumpAndSettle();

        // Tap delete in action bar
        await tester.tap(find.byKey(const Key('delete_selected')));
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(find.text('¿Eliminar tags?'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('Se eliminar'),
          ),
          findsOneWidget,
        );
        expect(find.text('Cancelar'), findsWidgets);
        expect(find.text('Eliminar'), findsOneWidget);
      });

      testWidgets('should_stay_in_selection_on_cancel_confirmation',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tagSettingsListProvider.overrideWith(
                (ref) => Future.value(twoUserTags),
              ),
              tagUsageCountProvider.overrideWith(
                (ref) => {'work': 0, 'personal': 0},
              ),
            ],
            child: const MaterialApp(home: TagManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Select both tags
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('personal'));
        await tester.pumpAndSettle();

        // Tap delete → confirmation dialog
        await tester.tap(find.byKey(const Key('delete_selected')));
        await tester.pumpAndSettle();

        // Cancel in dialog
        await tester.tap(find.text('Cancelar').last);
        await tester.pumpAndSettle();

        // Should still be in selection mode
        expect(find.text('2 tags seleccionados'), findsOneWidget);
        expect(find.byKey(const Key('delete_selected')), findsOneWidget);
      });

      testWidgets('should_show_snackbar_on_batch_delete', (tester) async {
        final stubRepo = _ControllableDeleteRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tagSettingsListProvider.overrideWith(
                (ref) => Future.value(twoUserTags),
              ),
              tagUsageCountProvider.overrideWith(
                (ref) => {'work': 0, 'personal': 0},
              ),
              tagSettingsRepositoryProvider.overrideWith(
                (ref) => stubRepo,
              ),
              removeTagFromEntriesProvider.overrideWith(
                (ref) => (String name) async => ['entry-1'],
              ),
            ],
            child: const MaterialApp(home: TagManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Select both tags
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('personal'));
        await tester.pumpAndSettle();

        // Tap delete → confirm
        await tester.tap(find.byKey(const Key('delete_selected')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        // SnackBar with success message
        expect(find.text('2 tags eliminados'), findsOneWidget);
        // Selection cleared
        expect(find.byIcon(Icons.check_circle), findsNothing);
      });

      testWidgets('should_handle_partial_failure', (tester) async {
        // 'personal' will fail on delete
        final stubRepo = _ControllableDeleteRepo(
          failOnDelete: {'personal'},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tagSettingsListProvider.overrideWith(
                (ref) => Future.value(twoUserTags),
              ),
              tagUsageCountProvider.overrideWith(
                (ref) => {'work': 0, 'personal': 0},
              ),
              tagSettingsRepositoryProvider.overrideWith(
                (ref) => stubRepo,
              ),
              removeTagFromEntriesProvider.overrideWith(
                (ref) => (String name) async => ['entry-1'],
              ),
            ],
            child: const MaterialApp(home: TagManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Select both tags
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('personal'));
        await tester.pumpAndSettle();

        // Tap delete → confirm
        await tester.tap(find.byKey(const Key('delete_selected')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        // Partial success SnackBar
        expect(find.text('Se eliminaron 1 de 2 tags'), findsOneWidget);
      });

      testWidgets('should_handle_all_fail', (tester) async {
        // Both tags fail on delete
        final stubRepo = _ControllableDeleteRepo(
          failOnDelete: {'work', 'personal'},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tagSettingsListProvider.overrideWith(
                (ref) => Future.value(twoUserTags),
              ),
              tagUsageCountProvider.overrideWith(
                (ref) => {'work': 0, 'personal': 0},
              ),
              tagSettingsRepositoryProvider.overrideWith(
                (ref) => stubRepo,
              ),
              removeTagFromEntriesProvider.overrideWith(
                (ref) => (String name) async => ['entry-1'],
              ),
            ],
            child: const MaterialApp(home: TagManagementScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Select both tags
        await tester.longPress(find.text('work'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('personal'));
        await tester.pumpAndSettle();

        // Tap delete → confirm
        await tester.tap(find.byKey(const Key('delete_selected')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        // All-fail SnackBar
        expect(find.text('No se pudieron eliminar tags'), findsOneWidget);
      });
    });
  });
}
