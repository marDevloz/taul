import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/credential_protection_controller.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  late AppDatabase database;
  late MasterPasswordStore store;
  late EntryAuthService auth;
  late MasterPasswordNotifier notifier;
  late CredentialProtectionController controller;

  setUp(() {
    database = AppDatabase.forTesting();
    store = MasterPasswordStore(database);
    auth = EntryAuthService();
    notifier = MasterPasswordNotifier();
    controller = CredentialProtectionController(
      authService: auth,
      passwordStore: store,
      masterPasswordNotifier: notifier,
    );
  });

  tearDown(() {
    database.close();
  });

  group('T-07: CredentialProtectionController', () {
    group('isConfigured', () {
      test('should_return_false_when_no_config', () async {
        final configured = await controller.isConfigured();
        expect(configured, false);
      });

      test('should_return_false_when_config_without_encrypted_key', () async {
        await store.save(hashHex: 'hash', saltHex: 'salt');
        final configured = await controller.isConfigured();
        expect(configured, false);
      });

      test('should_return_true_when_config_has_encrypted_key', () async {
        await store.saveFull(
          hashHex: 'hash',
          saltHex: 'salt',
          encryptedStorageKeyHex: 'keyhex',
          encryptedStorageKeyNonceHex: 'noncehex',
          encryptedStorageKeyTagHex: 'taghex',
        );
        final configured = await controller.isConfigured();
        expect(configured, true);
      });

      test('should_return_false_when_key_fields_are_empty', () async {
        // Edge case: save with empty strings instead of null
        await store.saveFull(
          hashHex: 'hash',
          saltHex: 'salt',
          encryptedStorageKeyHex: '',
          encryptedStorageKeyNonceHex: '',
          encryptedStorageKeyTagHex: '',
        );
        final configured = await controller.isConfigured();
        expect(configured, false);
      });
    });

    group('getHint', () {
      test('should_return_null_when_no_hint_stored', () async {
        final hint = await controller.getHint();
        expect(hint, isNull);
      });

      test('should_return_hint_when_stored', () async {
        await store.save(hashHex: 'hash', saltHex: 'salt');
        await store.saveHint('my recovery hint');
        final hint = await controller.getHint();
        expect(hint, 'my recovery hint');
      });

      test('should_return_null_after_hint_cleared', () async {
        await store.save(hashHex: 'hash', saltHex: 'salt');
        await store.saveHint('temp hint');
        await store.saveHint(null);
        final hint = await controller.getHint();
        expect(hint, isNull);
      });
    });

    group('getRemainingCodeCount', () {
      test('should_return_zero_when_no_codes', () async {
        final count = await controller.getRemainingCodeCount();
        expect(count, 0);
      });

      test('should_return_count_of_stored_codes', () async {
        await store.save(hashHex: 'hash', saltHex: 'salt');
        await store.saveBackupCodeHashes(['a:1', 'b:2', 'c:3', 'd:4']);
        final count = await controller.getRemainingCodeCount();
        expect(count, 4);
      });

      test('should_decrease_after_code_consumed', () async {
        await store.save(hashHex: 'hash', saltHex: 'salt');
        await store.saveBackupCodeHashes(['a:1', 'b:2', 'c:3']);
        await store.consumeBackupCodeAtIndex(1);
        final count = await controller.getRemainingCodeCount();
        expect(count, 2);
      });

      test('should_return_zero_when_all_codes_consumed', () async {
        await store.save(hashHex: 'hash', saltHex: 'salt');
        await store.saveBackupCodeHashes(['only:code']);
        await store.consumeBackupCodeAtIndex(0);
        final count = await controller.getRemainingCodeCount();
        expect(count, 0);
      });

      test('should_handle_many_codes', () async {
        final manyCodes = List.generate(10, (i) => 'salt$i:hash$i');
        await store.save(hashHex: 'hash', saltHex: 'salt');
        await store.saveBackupCodeHashes(manyCodes);
        final count = await controller.getRemainingCodeCount();
        expect(count, 10);
      });
    });

    group('ensureConfigured', () {
      test('should_return_true_when_already_configured', () async {
        // Set up full config with encrypted storage key
        await store.saveFull(
          hashHex: 'hash',
          saltHex: 'salt',
          encryptedStorageKeyHex: 'keyhex',
          encryptedStorageKeyNonceHex: 'noncehex',
          encryptedStorageKeyTagHex: 'taghex',
        );

        // When already configured, context is never accessed
        final mockContext = MockBuildContext();
        when(() => mockContext.mounted).thenReturn(true);

        final result = await controller.ensureConfigured(mockContext);
        expect(result, true);
      });
    });

    group('ensureProtectionConfigured', () {
      test('should_return_true_when_dek_cached', () async {
        // When DEK is cached, context is never accessed
        final dek = Uint8List(32);
        notifier.setMasterPassword(dek);

        final mockContext = MockBuildContext();
        when(() => mockContext.mounted).thenReturn(true);

        final result = await controller.ensureProtectionConfigured(mockContext);
        expect(result, true);
      });
    });
  });
}
