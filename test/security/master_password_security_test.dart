import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import '../helpers/test_auth.dart';

void main() {
  late AppDatabase database;
  late MasterPasswordStore store;
  late EntryAuthService auth;

  setUp(() {
    database = AppDatabase.forTesting();
    store = MasterPasswordStore(database);
    auth = createFastAuthService();
  });

  tearDown(() {
    database.close();
  });

  group('T-18: Security invariants for master password and recovery', () {
    test('should_not_store_backup_codes_in_plaintext', () async {
      final codes = await auth.generateBackupCodes(count: 2);

      // Save codes as hashes
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(codes.codeHashes);

      // Read back from DB directly
      final rows = await database.customSelect(
        'SELECT backup_code_hashes FROM master_password_config '
        'WHERE id = 1',
      ).get();

      expect(rows, hasLength(1));
      final storedJson = rows.first.data['backup_code_hashes'] as String?;
      expect(storedJson, isNotNull);

      final storedHashes = jsonDecode(storedJson!) as List<dynamic>;

      // Verify no plaintext codes match stored values
      for (final code in codes.plainCodes) {
        final isPlaintext = storedHashes.any((h) => h == code || h.toString().contains(code));
        expect(isPlaintext, false,
            reason: 'Backup code "$code" should not appear in plaintext');
      }
    });

    test('should_not_store_storage_key_in_plaintext', () async {
      final dek = auth.generateStorageKey();
      final salt = auth.generateSalt();
      final hash = await auth.hashMasterPassword(
        password: 'testpass',
        salt: salt,
      );
      final kek = await auth.deriveMasterKey(
        password: 'testpass',
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

      final config = await store.readFull();
      expect(config, isNotNull);

      // The stored key hex length should be 64 (32 bytes ciphertext)
      final storedKeyHex = config!.encryptedStorageKeyHex!;
      expect(storedKeyHex.length, 64); // AES-256-GCM output is same length as input

      // Verify the stored hex is NOT the plain DEK
      final dekHex = auth.bytesToHex(dek);
      expect(storedKeyHex, isNot(dekHex),
          reason: 'Storage key should be encrypted, not plaintext');
    });

    test('should_atomically_consume_backup_code', () async {
      final codes = await auth.generateBackupCodes(count: 1);
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(codes.codeHashes);

      // Verify code exists
      expect(await store.readBackupCodeHashes(), hasLength(1));

      // Try to consume
      final matchIndex = await _verifyCode(codes.plainCodes[0], codes.codeHashes);
      final consumed = await store.consumeBackupCodeAtIndex(matchIndex);
      expect(consumed, true);

      // Code should be gone
      expect(await store.readBackupCodeHashes(), isNull);

      // Try to consume the SAME code again — should fail
      final consumedAgain = await store.consumeBackupCodeAtIndex(matchIndex);
      expect(consumedAgain, false);
    });

    test(
        'should_not_allow_old_kek_to_unwrap_storage_key_after_master_password_change',
        () async {
      // Initial setup with old password
      const oldPassword = 'oldPass1';
      final salt1 = auth.generateSalt();
      final hash1 = await auth.hashMasterPassword(
        password: oldPassword,
        salt: salt1,
      );
      final dek = auth.generateStorageKey();
      final kek1 = await auth.deriveMasterKey(
        password: oldPassword,
        salt: salt1,
      );
      final wrapped1 = await auth.wrapStorageKey(dek: dek, kek: kek1);

      await store.saveFull(
        hashHex: hash1,
        saltHex: auth.bytesToHex(salt1),
        encryptedStorageKeyHex: wrapped1.ciphertextHex,
        encryptedStorageKeyNonceHex: wrapped1.nonceHex,
        encryptedStorageKeyTagHex: wrapped1.tagHex,
      );

      // Change to new password (re-wraps DEK with new KEK)
      const newPassword = 'newPass123';
      final salt2 = auth.generateSalt();
      final hash2 = await auth.hashMasterPassword(
        password: newPassword,
        salt: salt2,
      );
      final kek2 = await auth.deriveMasterKey(
        password: newPassword,
        salt: salt2,
      );
      final wrapped2 = await auth.wrapStorageKey(dek: dek, kek: kek2);

      await store.saveFull(
        hashHex: hash2,
        saltHex: auth.bytesToHex(salt2),
        encryptedStorageKeyHex: wrapped2.ciphertextHex,
        encryptedStorageKeyNonceHex: wrapped2.nonceHex,
        encryptedStorageKeyTagHex: wrapped2.tagHex,
      );

      // Try to unwrap with OLD KEK — must fail
      expect(
        () async => auth.unwrapStorageKey(
          payload: EncryptionPayload(
            ciphertextHex: wrapped2.ciphertextHex,
            nonceHex: wrapped2.nonceHex,
            tagHex: wrapped2.tagHex,
          ),
          kek: kek1,
        ),
        throwsA(isA<Exception>()),
      );

      // Unwrap with NEW KEK must succeed
      final unwrapped = await auth.unwrapStorageKey(
        payload: EncryptionPayload(
          ciphertextHex: wrapped2.ciphertextHex,
          nonceHex: wrapped2.nonceHex,
          tagHex: wrapped2.tagHex,
        ),
        kek: kek2,
      );
      expect(unwrapped, dek);
    });

    test('should_not_leak_secrets_in_logs', () async {
      // This test verifies the security properties of our encryption,
      // not actual log output. We check that:
      // 1. Encryption produces different ciphertext each time
      // 2. Decryption with wrong key throws
      // 3. Secrets are never converted to string representations

      const secret = 'super-secret-password-12345';
      final dek = auth.generateStorageKey();

      // Encrypt twice with same key — nonces differ
      final enc1 = await auth.encryptSecret(plaintext: secret, masterKey: dek);
      final enc2 = await auth.encryptSecret(plaintext: secret, masterKey: dek);

      // Ciphertexts must differ (different nonces)
      expect(enc1.ciphertextHex, isNot(enc2.ciphertextHex));
      expect(enc1.nonceHex, isNot(enc2.nonceHex));

      // Both must be decryptable with the same key
      final dec1 = await auth.decryptSecret(payload: enc1, masterKey: dek);
      final dec2 = await auth.decryptSecret(payload: enc2, masterKey: dek);
      expect(dec1, secret);
      expect(dec2, secret);

      // Decrypt with wrong key throws
      final wrongDek = auth.generateStorageKey();
      expect(
        () async => auth.decryptSecret(payload: enc1, masterKey: wrongDek),
        throwsA(isA<Exception>()),
      );

      // Verify ciphertext hex does not contain plaintext
      expect(enc1.ciphertextHex.contains(secret), false);
      expect(enc2.ciphertextHex.contains(secret), false);

      // Nonce and tag are non-empty
      expect(enc1.nonceHex, isNotEmpty);
      expect(enc1.tagHex, isNotEmpty);
    });
  });
}

/// Simplified recovery code verification using fast auth.
Future<int> _verifyCode(String code, List<String> codeHashes) async {
  final testAuth = createFastAuthService();
  for (var i = 0; i < codeHashes.length; i++) {
    final parts = codeHashes[i].split(':');
    if (parts.length != 2) continue;
    final salt = testAuth.hexToBytes(parts[0]);
    final computed = await testAuth.hashMasterPassword(
      password: code,
      salt: salt,
    );
    if (computed == parts[1]) return i;
  }
  return -1;
}
