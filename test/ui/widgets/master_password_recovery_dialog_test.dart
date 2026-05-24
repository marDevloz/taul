import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/widgets/master_password_recovery_dialog.dart';
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

  Widget createTestApp() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        entryAuthServiceProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push<RecoveryResult>(
              context,
              MaterialPageRoute(
                builder: (_) => const MasterPasswordRecoveryDialog(),
                fullscreenDialog: true,
              ),
            ),
            child: const Text('Open Recovery'),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Open Recovery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('T-15: MasterPasswordRecoveryDialog widget tests', () {
    testWidgets('should_render_code_entry_field', (tester) async {
      // Seed config with some backup codes
      final codes = await auth.generateBackupCodes(count: 2);
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(codes.codeHashes);

      await tester.pumpWidget(createTestApp());
      await openDialog(tester);

      expect(find.text('Recover Master Password'), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_outlined), findsOneWidget);
      expect(find.text('Backup code'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should_show_remaining_codes_count', (tester) async {
      final codes = await auth.generateBackupCodes(count: 3);
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(codes.codeHashes);

      await tester.pumpWidget(createTestApp());
      await openDialog(tester);

      // Should show "3 backup codes remaining."
      expect(find.textContaining('3 backup codes'), findsOneWidget);
    });

    testWidgets('should_show_error_for_empty_code', (tester) async {
      await store.save(hashHex: 'hash', saltHex: 'salt');

      await tester.pumpWidget(createTestApp());
      await openDialog(tester);

      // Tap Verify with empty field
      await tester.tap(find.text('Verify'));
      await tester.pump();

      expect(find.text('Enter a backup code'), findsOneWidget);
    });

    testWidgets('should_show_error_for_wrong_code', (tester) async {
      final codes = await auth.generateBackupCodes(count: 2);
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(codes.codeHashes);

      await tester.pumpWidget(createTestApp());
      await openDialog(tester);

      // Enter a wrong code
      await tester.enterText(
        find.widgetWithText(TextField, 'Backup code'),
        'ZZZZ-9999',
      );

      await tester.tap(find.text('Verify'));
      await tester.pump();

      // Wait for Argon2id verification (10 codes to scan)
      await tester.runAsync(() async {
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should show error about invalid code
      expect(find.textContaining('Invalid code'), findsOneWidget);
    });

    testWidgets('should_navigate_to_new_mp_form_on_valid_code',
        (tester) async {
      // Generate backup codes and save them
      final codes = await auth.generateBackupCodes(count: 2);
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(codes.codeHashes);

      await tester.pumpWidget(createTestApp());
      await openDialog(tester);

      // Enter a valid backup code
      await tester.enterText(
        find.widgetWithText(TextField, 'Backup code'),
        codes.plainCodes[0],
      );

      await tester.tap(find.text('Verify'));
      await tester.pump();

      // Wait for verification (scan fast hashes) + consumption (DB write)
      await tester.runAsync(() async {
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should show new MP form
      expect(find.text('Set New Master Password'), findsOneWidget);
      expect(find.text('Code verified. Create your new master password.'),
          findsOneWidget);
      expect(find.text('New master password'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);
      expect(find.text('Hint (optional)'), findsOneWidget);
      expect(find.text('Set Password'), findsOneWidget);
    });

    testWidgets('should_have_cancel_button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            entryAuthServiceProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: MasterPasswordRecoveryDialog(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The Cancel button should exist
      expect(find.text('Cancel'), findsOneWidget);
      // The dialog title should be visible
      expect(find.text('Recover Master Password'), findsOneWidget);
    });

    testWidgets('should_show_error_when_no_backup_codes', (tester) async {
      // Save config WITHOUT backup codes
      await store.save(hashHex: 'hash', saltHex: 'salt');

      await tester.pumpWidget(createTestApp());
      await openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Backup code'),
        'ABCD-1234',
      );

      await tester.tap(find.text('Verify'));
      await tester.pump();

      expect(
        find.text('No backup codes remaining. Recovery is not possible.'),
        findsOneWidget,
      );
    });
  });
}
