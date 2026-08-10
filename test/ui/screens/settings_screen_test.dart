import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/export/encrypted_export_service.dart';
import 'package:taul/infrastructure/export/import_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/settings_screen.dart';
import '../../helpers/test_auth.dart';

void main() {
  late AppDatabase database;
  late MasterPasswordStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting();
    store = MasterPasswordStore(database);
  });

  tearDown(() {
    database.close();
  });

  Widget createTestApp({EncryptedExportService? exportService}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        entryAuthServiceProvider.overrideWithValue(createFakeAuthService()),
        if (exportService != null)
          encryptedExportServiceProvider.overrideWithValue(exportService),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  Future<void> seedConfiguredMasterPassword() async {
    await store.saveFull(
      hashHex: 'abc123',
      saltHex: 'def456',
      encryptedStorageKeyHex: 'ciphertexthex',
      encryptedStorageKeyNonceHex: 'noncehex',
      encryptedStorageKeyTagHex: 'taghex',
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

  group('T-13b: backup status persistence and reminder', () {
    testWidgets(
        'should_persist_last_backup_timestamp_after_successful_export',
        (tester) async {
      await seedConfiguredMasterPassword();
      final exportService =
          _FakeExportService(authService: createFakeAuthService());

      await tester.pumpWidget(createTestApp(exportService: exportService));
      await tester.pump();
      await tester.pump();

      // Scroll to the Data section: no backup recorded yet.
      await tester.scrollUntilVisible(find.text('Exportar datos'), 200.0);
      expect(find.text('Última copia: nunca'), findsOneWidget);

      // Export flow: disclaimer -> passphrase -> encryption -> fake save.
      await tester.tap(find.text('Exportar datos'));
      await tester.pump();
      expect(find.text('Entendido, exportar'), findsOneWidget);
      await tester.tap(find.text('Entendido, exportar'));
      await tester.pump();

      expect(find.text('Contraseña de exportación'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'test-passphrase-123');
      await tester.enterText(find.byType(TextField).at(1), 'test-passphrase-123');
      await tester.tap(find.text('Cifrar y exportar'));
      await tester.pump();

      // Drain the async export, file save, and timestamp persistence.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Timestamp was persisted only on success.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_backup_at'), isNotNull);
      expect(
        DateTime.tryParse(prefs.getString('last_backup_at')!),
        isNotNull,
      );

      // Invalidation applied: UI now shows the last backup date.
      await tester.pump();
      await tester.pump();
      expect(find.text('Última copia: nunca'), findsNothing);
      expect(find.textContaining('Última copia:'), findsOneWidget);

      // Flush the snackbar timer before the test ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }, timeout: const Timeout(Duration(seconds: 20)));

    testWidgets(
        'should_show_stale_backup_reminder_when_backup_is_older_than_14_days',
        (tester) async {
      await seedConfiguredMasterPassword();
      SharedPreferences.setMockInitialValues({
        'last_backup_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 20))
            .toIso8601String(),
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Exportar datos'), 200.0);

      expect(find.textContaining('Última copia:'), findsOneWidget);
      expect(find.textContaining('tiene más de 14 días'), findsOneWidget);
      expect(find.textContaining('Exportá una copia nueva'), findsOneWidget);
    });

    testWidgets(
        'should_show_last_backup_date_without_stale_reminder_when_recent',
        (tester) async {
      await seedConfiguredMasterPassword();
      SharedPreferences.setMockInitialValues({
        'last_backup_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Exportar datos'), 200.0);

      expect(find.textContaining('Última copia:'), findsOneWidget);
      expect(find.text('Última copia: nunca'), findsNothing);
      expect(find.textContaining('tiene más de 14 días'), findsNothing);
    });
  });

  group('T-13c: encrypted backup restore via UI import', () {
    // Builds a REAL encrypted backup using the real EncryptedExportService,
    // then wires a fake FilePicker to return those bytes so the full UI
    // path (pick -> classify -> passphrase dialog -> decrypt -> import)
    // is exercised.
    Future<EncryptedExportService> seedEncryptedBackup(
      WidgetTester tester, {
      required String passphrase,
    }) async {
      await seedConfiguredMasterPassword();
      final exportService =
          EncryptedExportService(authService: createFakeAuthService());
      final encrypted = await exportService.exportEncrypted(
        entries: [
          Entry(
            id: 'restored-1',
            type: EntryType.note,
            title: 'Restaurada desde la UI',
            content: 'Contenido del backup cifrado.',
            tags: const ['backup'],
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 2),
          ),
        ],
        passphrase: passphrase,
      );

      mockFilePicker(tester, encrypted);

      return exportService;
    }

    testWidgets('should_restore_encrypted_backup_with_correct_passphrase',
        (tester) async {
      final exportService =
          await seedEncryptedBackup(tester, passphrase: 'test-passphrase-123');

      await tester.pumpWidget(createTestApp(exportService: exportService));
      await tester.pump();
      await tester.pump();

      // Scroll to the Data section and start the import flow.
      await tester.scrollUntilVisible(find.text('Importar datos'), 200.0);
      await tester.tap(find.text('Importar datos'));
      await tester.pump();

      // Confirmation dialog.
      expect(find.text('Importar datos'), findsWidgets);
      await tester.tap(find.text('Importar'));
      await tester.pump();
      await tester.pump();

      // Encrypted file detected -> passphrase dialog (not the plain import).
      expect(find.text('Contraseña del backup'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'test-passphrase-123');
      await tester.enterText(find.byType(TextField).at(1), 'test-passphrase-123');
      await tester.tap(find.text('Importar backup'));
      await tester.pump();

      // Drain decrypt + import async work.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Success message with imported count.
      expect(find.textContaining('Se importaron 1 entradas'), findsOneWidget);

      // Entry actually persisted in the vault.
      final dao = EntryDao(database);
      final restored = await dao.list();
      expect(restored, hasLength(1));
      expect(restored.single.id, 'restored-1');
      expect(restored.single.title, 'Restaurada desde la UI');

      // Flush snackbar timers before the test ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }, timeout: const Timeout(Duration(seconds: 20)));

    testWidgets('should_show_friendly_error_when_passphrase_is_wrong',
        (tester) async {
      // The file picked IS an encrypted backup, but the decrypt service
      // fails (deterministic stand-in for a wrong passphrase), so the UI
      // must surface the friendly error and import nothing.
      final failingService = _FailingDecryptService(
        authService: createFakeAuthService(),
      );
      await seedEncryptedBackup(
        tester,
        passphrase: 'test-passphrase-123',
      );

      await tester.pumpWidget(createTestApp(exportService: failingService));
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Importar datos'), 200.0);
      await tester.tap(find.text('Importar datos'));
      await tester.pump();
      await tester.tap(find.text('Importar'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Contraseña del backup'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'wrong-passphrase');
      await tester.enterText(find.byType(TextField).at(1), 'wrong-passphrase');
      await tester.tap(find.text('Importar backup'));
      await tester.pump();

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Friendly error, no entries imported.
      expect(
        find.text(ImportService.wrongPassphraseErrorMessage),
        findsOneWidget,
      );
      final dao = EntryDao(database);
      expect(await dao.list(), isEmpty);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }, timeout: const Timeout(Duration(seconds: 20)));

    testWidgets('should_import_plain_json_without_passphrase_dialog',
        (tester) async {
      await seedConfiguredMasterPassword();
      final plainJson = jsonEncode({
        'version': 1,
        'entries': [
          {
            'id': 'plain-1',
            'type': 'note',
            'title': 'Plana importada',
            'content': 'Sin cifrado.',
            'tags': <String>[],
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      });
      mockFilePicker(tester, plainJson);
      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Importar datos'), 200.0);
      await tester.tap(find.text('Importar datos'));
      await tester.pump();
      await tester.tap(find.text('Importar'));
      await tester.pump();
      await tester.pump();

      // Drain import async work (like the export flow tests).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // NO passphrase dialog for plain JSON.
      expect(find.text('Contraseña del backup'), findsNothing);
      expect(find.textContaining('Se importaron 1 entradas'), findsOneWidget);

      final dao = EntryDao(database);
      expect(await dao.list(), hasLength(1));

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}

/// EncryptedExportService that skips the real FilePicker save so the export
/// flow can be exercised in widget tests. Mirrors `saveEncryptedToFile's`
/// contract: returns a non-null path when the backup was saved.
class _FakeExportService extends EncryptedExportService {
  _FakeExportService({required super.authService});

  @override
  Future<String?> saveEncryptedToFile(
    String encryptedJson,
    BuildContext context,
  ) async {
    return '/tmp/fake-backup.json';
  }
}

/// Decrypt service that always fails — deterministic stand-in for a wrong
/// passphrase or corrupted file in widget tests (real crypto is exercised in
/// the infrastructure import service tests instead).
class _FailingDecryptService extends EncryptedExportService {
  _FailingDecryptService({required super.authService});

  @override
  Future<String?> decryptExport({
    required String encryptedJson,
    required String passphrase,
  }) async {
    return null;
  }
}

/// Mocks the file_picker platform channel so `FilePicker.pickFiles` returns
/// the given JSON content as a picked .json file (withData), letting the
/// import UI path run in widget tests without a native picker.
void mockFilePicker(WidgetTester tester, String jsonContent) {
  final bytes = Uint8List.fromList(utf8.encode(jsonContent));
  const channel = MethodChannel(
    'miguelruivo.flutter.plugins.filepicker',
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async {
      // file_picker invokes a method named after FileType.name ('custom')
      // and expects a List of Maps with name/size/bytes.
      return [
        {
          'name': 'backup.json',
          'size': bytes.length,
          'bytes': bytes,
        },
      ];
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
