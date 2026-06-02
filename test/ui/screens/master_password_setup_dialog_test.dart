import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/master_password_setup_dialog.dart';
import '../../helpers/test_auth.dart';

void main() {
  late AppDatabase database;
  late MasterPasswordStore store;
  late EntryAuthService auth;

  setUp(() {
    database = AppDatabase.forTesting();
    store = MasterPasswordStore(database);
    auth = createFakeAuthService();
  });

  tearDown(() {
    database.close();
  });

  Widget createTestApp({bool isChange = false}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        entryAuthServiceProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => MasterPasswordSetupDialog(isChange: isChange),
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Open Dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('T-14: MasterPasswordSetupDialog widget tests', () {
    group('setup mode', () {
      testWidgets('should_render_password_confirm_and_hint_fields_in_setup_mode',
          (tester) async {
        await tester.pumpWidget(createTestApp(isChange: false));
        await openDialog(tester);

        expect(find.text('Configurar Contraseña Maestra'), findsOneWidget);
        expect(find.text('Contraseña maestra'), findsOneWidget);
        expect(find.text('Confirmar contraseña'), findsOneWidget);
        expect(find.text('Pista (opcional)'), findsOneWidget);
        expect(find.text('Siguiente'), findsOneWidget);
        expect(find.text('Cancelar'), findsOneWidget);
      });

      testWidgets('should_show_validation_error_for_short_password',
          (tester) async {
        await tester.pumpWidget(createTestApp(isChange: false));
        await openDialog(tester);

        // Enter a short password
        await tester.enterText(
          find.widgetWithText(TextField, 'Contraseña maestra'),
          '1234567',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirmar contraseña'),
          '1234567',
        );

        // Tap Next
        await tester.tap(find.text('Siguiente'));
        await tester.pump();

        expect(find.text('Mínimo 8 caracteres'), findsWidgets);
      });

      testWidgets('should_show_error_when_passwords_do_not_match',
          (tester) async {
        await tester.pumpWidget(createTestApp(isChange: false));
        await openDialog(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Contraseña maestra'),
          'password123',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirmar contraseña'),
          'different123',
        );

        await tester.tap(find.text('Siguiente'));
        await tester.pump();

        expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      });

      testWidgets('should_advance_to_codes_step_after_valid_password',
          (tester) async {
        await tester.pumpWidget(createTestApp(isChange: false));
        await openDialog(tester);

        // Fill in valid password
        await tester.enterText(
          find.widgetWithText(TextField, 'Contraseña maestra'),
          'validpass123',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirmar contraseña'),
          'validpass123',
        );

        // Tap Next — this triggers generateBackupCodes
        await tester.tap(find.text('Siguiente'));
        await tester.pump();

        // Wait for async backup code generation (fake auth is instant)
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 500));
        });

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Should now show backup codes step
        expect(
          find.text(
            'Guardá estos códigos en un lugar seguro. '
            'Son tu ÚNICA forma de recuperar el acceso si olvidás tu contraseña maestra.',
          ),
          findsOneWidget,
        );
        expect(find.text('Copiar todo'), findsOneWidget);
        expect(find.text('Guardé mis códigos en un lugar seguro'), findsOneWidget);
        final confirmButton = find.text('Confirmar');
        expect(confirmButton, findsOneWidget);
      }, timeout: const Timeout(Duration(seconds: 30)));

      testWidgets('should_require_codes_confirmation_before_confirm',
          (tester) async {
        await tester.pumpWidget(createTestApp(isChange: false));
        await openDialog(tester);

        // Fill valid password and advance to codes step
        await tester.enterText(
          find.widgetWithText(TextField, 'Contraseña maestra'),
          'validpass123',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirmar contraseña'),
          'validpass123',
        );
        await tester.tap(find.text('Siguiente'));
        await tester.pump();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 500));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Should be on codes step
        expect(find.text('Copiar todo'), findsOneWidget);

        // Tap the checkbox to confirm
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        // Confirm button should exist after checkbox is checked
        expect(find.text('Confirmar'), findsOneWidget);
      }, timeout: const Timeout(Duration(seconds: 30)));

      testWidgets('should_store_backup_code_data_after_confirmation',
          (tester) async {
        await tester.pumpWidget(createTestApp(isChange: false));
        await openDialog(tester);

        // Fill valid password
        await tester.enterText(
          find.widgetWithText(TextField, 'Contraseña maestra'),
          'validpass123',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirmar contraseña'),
          'validpass123',
        );

        // Tap Next — this now generates DEK + codesWithWraps
        await tester.tap(find.text('Siguiente'));
        await tester.pump();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 1000));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Should be on codes step
        expect(find.text('Copiar todo'), findsOneWidget);

        // Check confirmation and tap Confirm
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.text('Confirmar'));
        await tester.pump();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 1000));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify backup_code_data was stored in the DB
        final storedData = await store.readBackupCodeData();
        expect(storedData, isNotNull);
        expect(storedData!.length, 10);
        for (final entry in storedData) {
          expect(entry.saltHex, isNotEmpty);
          expect(entry.hashHex, isNotEmpty);
          expect(entry.dekCipherHex, isNotEmpty);
          expect(entry.dekNonceHex, isNotEmpty);
          expect(entry.dekTagHex, isNotEmpty);
        }

        // Dialog should have popped
        expect(find.text('Configurar Contraseña Maestra'), findsNothing);
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('change mode', () {
      testWidgets('should_render_current_password_field_in_change_mode',
          (tester) async {
        await tester.pumpWidget(createTestApp(isChange: true));
        await openDialog(tester);

        expect(find.text('Cambiar Contraseña Maestra'), findsOneWidget);
        expect(find.text('Contraseña maestra actual'), findsOneWidget);
        expect(find.text('Verificar'), findsOneWidget);
      });

      testWidgets('should_show_validation_error_when_current_password_empty',
          (tester) async {
        await tester.pumpWidget(createTestApp(isChange: true));
        await openDialog(tester);

        // Tap Verify with empty password
        await tester.tap(find.text('Verificar'));
        await tester.pump();

        expect(
          find.text('Ingresá tu contraseña maestra actual'),
          findsOneWidget,
        );
      });

      testWidgets('should_render_new_password_fields_after_verification',
          (tester) async {
        // Seed the DB with a valid config using fast auth
        final salt = auth.generateSalt();
        final hash = await auth.hashMasterPassword(
          password: 'currentPass1',
          salt: salt,
        );
        final dek = auth.generateStorageKey();
        final kek = await auth.deriveMasterKey(
          password: 'currentPass1',
          salt: salt,
        );
        final wrapped = await auth.wrapStorageKey(dek: dek, kek: kek);
        await store.saveFull(
          hashHex: hash,
          saltHex: auth.bytesToHex(salt),
          encryptedStorageKeyHex: wrapped.ciphertextHex,
          encryptedStorageKeyNonceHex: wrapped.nonceHex,
          encryptedStorageKeyTagHex: wrapped.tagHex,
        );

        await tester.pumpWidget(createTestApp(isChange: true));
        await openDialog(tester);

        // Enter correct current password
        await tester.enterText(
          find.widgetWithText(TextField, 'Contraseña maestra actual'),
          'currentPass1',
        );

        await tester.tap(find.text('Verificar'));
        await tester.pump();

        // Wait for async verification (fake auth is instant)
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 500));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Should show new password form
        expect(find.text('Nueva contraseña maestra'), findsOneWidget);
        expect(find.text('Confirmar nueva contraseña'), findsOneWidget);
        expect(find.text('Cambiar'), findsOneWidget);
        expect(find.text('Volver'), findsOneWidget);
      });

      testWidgets('should_show_error_on_wrong_current_password',
          (tester) async {
        final salt = auth.generateSalt();
        final hash = await auth.hashMasterPassword(
          password: 'realPassword',
          salt: salt,
        );
        await store.saveFull(
          hashHex: hash,
          saltHex: auth.bytesToHex(salt),
          encryptedStorageKeyHex: 'dummykey',
          encryptedStorageKeyNonceHex: 'dummynonce',
          encryptedStorageKeyTagHex: 'dummytag',
        );

        await tester.pumpWidget(createTestApp(isChange: true));
        await openDialog(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Contraseña maestra actual'),
          'wrongPassword1',
        );

        await tester.tap(find.text('Verificar'));
        await tester.pump();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 500));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('La contraseña actual es incorrecta'), findsOneWidget);
      });
    });
  });
}
