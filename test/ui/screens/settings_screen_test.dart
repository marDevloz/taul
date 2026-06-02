import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/settings_screen.dart';
import '../../helpers/test_auth.dart';

void main() {
  late AppDatabase database;
  late MasterPasswordStore store;

  setUp(() {
    database = AppDatabase.forTesting();
    store = MasterPasswordStore(database);
  });

  tearDown(() {
    database.close();
  });

  Widget createTestApp() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        entryAuthServiceProvider.overrideWithValue(createFakeAuthService()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  group('T-13: SettingsScreen widget tests', () {
    testWidgets('should_render_not_configured_when_no_mp', (tester) async {
      await tester.pumpWidget(createTestApp());
      // Let the FutureProvider resolve
      await tester.pump();

      expect(find.text('No configurada'), findsOneWidget);
      expect(find.text('Configurar Contraseña Maestra'), findsOneWidget);
      expect(find.text('Contraseña Maestra'), findsOneWidget);
    });

    testWidgets('should_show_setup_button_when_not_configured', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      final setupButton = find.text('Configurar Contraseña Maestra');
      expect(setupButton, findsOneWidget);

      // Verify it's a filled button
      final button = find.byType(FilledButton);
      expect(button, findsOneWidget);
    });

    testWidgets('should_render_configured_when_mp_is_set', (tester) async {
      // Seed DB with full config BEFORE building widget tree
      await store.saveFull(
        hashHex: 'abc123',
        saltHex: 'def456',
        encryptedStorageKeyHex: 'ciphertexthex',
        encryptedStorageKeyNonceHex: 'noncehex',
        encryptedStorageKeyTagHex: 'taghex',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('Configurada'), findsOneWidget);
      expect(find.text('La contraseña maestra está activa'), findsOneWidget);
    });

    testWidgets('should_show_hint_when_configured', (tester) async {
      await store.saveFull(
        hashHex: 'hash',
        saltHex: 'salt',
        hint: 'my recovery hint',
        encryptedStorageKeyHex: 'key',
        encryptedStorageKeyNonceHex: 'nonce',
        encryptedStorageKeyTagHex: 'tag',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('my recovery hint'), findsOneWidget);
      expect(find.text('Pista'), findsOneWidget);
    });

    testWidgets('should_show_remaining_codes_count', (tester) async {
      await store.saveFull(
        hashHex: 'hash',
        saltHex: 'salt',
        backupCodeHashesJson: jsonEncode(['a:1', 'b:2', 'c:3']),
        encryptedStorageKeyHex: 'key',
        encryptedStorageKeyNonceHex: 'nonce',
        encryptedStorageKeyTagHex: 'tag',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.textContaining('3 códigos disponibles'), findsOneWidget);
    });

    testWidgets('should_show_change_mp_option_when_configured',
        (tester) async {
      await store.saveFull(
        hashHex: 'hash',
        saltHex: 'salt',
        encryptedStorageKeyHex: 'key',
        encryptedStorageKeyNonceHex: 'nonce',
        encryptedStorageKeyTagHex: 'tag',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(
        find.text('Cambiar Contraseña Maestra'),
        findsOneWidget,
      );
    });

    testWidgets('should_show_edit_hint_option_when_configured',
        (tester) async {
      await store.saveFull(
        hashHex: 'hash',
        saltHex: 'salt',
        encryptedStorageKeyHex: 'key',
        encryptedStorageKeyNonceHex: 'nonce',
        encryptedStorageKeyTagHex: 'tag',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('Editar Pista'), findsOneWidget);
    });

    testWidgets('should_show_regenerate_button_when_configured',
        (tester) async {
      await store.saveFull(
        hashHex: 'hash',
        saltHex: 'salt',
        encryptedStorageKeyHex: 'key',
        encryptedStorageKeyNonceHex: 'nonce',
        encryptedStorageKeyTagHex: 'tag',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('Regenerar Códigos de Respaldo'), findsOneWidget);
    });

    testWidgets('should_show_delete_button_when_configured', (tester) async {
      await store.saveFull(
        hashHex: 'hash',
        saltHex: 'salt',
        encryptedStorageKeyHex: 'key',
        encryptedStorageKeyNonceHex: 'nonce',
        encryptedStorageKeyTagHex: 'tag',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Scroll down to reveal the delete button at the bottom of the ListView
      final deleteButton = find.text('Eliminar Contraseña Maestra');
      await tester.scrollUntilVisible(deleteButton, 200.0);
      expect(deleteButton, findsOneWidget);
    });

    testWidgets('should_show_delete_confirmation_dialog', (tester) async {
      await store.saveFull(
        hashHex: 'hash',
        saltHex: 'salt',
        encryptedStorageKeyHex: 'key',
        encryptedStorageKeyNonceHex: 'nonce',
        encryptedStorageKeyTagHex: 'tag',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Scroll down to reveal the delete button at the bottom of the ListView
      final deleteButton = find.text('Eliminar Contraseña Maestra');
      await tester.scrollUntilVisible(deleteButton, 200.0);

      // Tap the "Delete Master Password" button
      await tester.tap(deleteButton);
      // Wait for the async method to read protected count
      // then show the dialog
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The DeleteMpDialog should now be shown
      expect(find.text('¿Eliminar Contraseña Maestra?'), findsOneWidget);
      expect(find.text('Cancelar'), findsWidgets);
      expect(find.text('Eliminar'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 10)));

    testWidgets('should_not_show_configured_actions_when_not_configured',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // These should NOT exist
      expect(find.text('Cambiar Contraseña Maestra'), findsNothing);
      expect(find.text('Editar Pista'), findsNothing);
      expect(find.text('Regenerar Códigos de Respaldo'), findsNothing);
      expect(find.text('Eliminar Contraseña Maestra'), findsNothing);
    });

    testWidgets('should_navigate_back_on_back_button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            entryAuthServiceProvider.overrideWithValue(createFakeAuthService()),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      // The back button should exist
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
    });

    testWidgets('should_show_mp_prompt_when_regenerating_codes',
        (tester) async {
      await store.saveFull(
        hashHex: 'abc123',
        saltHex: 'def456',
        encryptedStorageKeyHex: 'ciphertexthex',
        encryptedStorageKeyNonceHex: 'noncehex',
        encryptedStorageKeyTagHex: 'taghex',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Tap regenerar
      await tester.tap(find.text('Regenerar Códigos de Respaldo'));
      await tester.pump();

      // Confirmation dialog
      expect(find.text('Regenerar códigos de respaldo'), findsOneWidget);
      expect(find.text('Regenerar'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Regenerar'));
      await tester.pump();

      // MP prompt should appear (title: 'Master password')
      expect(find.text('Master password'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
    });

    testWidgets('should_handle_cancel_at_mp_prompt_when_regenerating',
        (tester) async {
      await store.saveFull(
        hashHex: 'abc123',
        saltHex: 'def456',
        encryptedStorageKeyHex: 'ciphertexthex',
        encryptedStorageKeyNonceHex: 'noncehex',
        encryptedStorageKeyTagHex: 'taghex',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Tap regenerar → confirm → get MP prompt
      await tester.tap(find.text('Regenerar Códigos de Respaldo'));
      await tester.pump();
      await tester.tap(find.text('Regenerar'));
      await tester.pump();

      // Verify MP prompt is showing
      expect(find.text('Master password'), findsOneWidget);

      // Tap cancelar
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // MP prompt should be gone, back to settings
      expect(find.text('Master password'), findsNothing);
      expect(find.text('Regenerar Códigos de Respaldo'), findsOneWidget);
    });
  });
}
