import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  group('T-17: Integration tests', () {
    group('v2→v3 migration simulation', () {
      test('should_simulate_v2_to_v3_migration_preserving_existing_data',
          () async {
        // Simulate v2 schema: create v2 tables without new columns
        await database.customInsert(
          'CREATE TABLE IF NOT EXISTS master_password_config_v2 ('
          'id INTEGER PRIMARY KEY, '
          'password_hash_argon2 TEXT NOT NULL, '
          'salt_hex TEXT NOT NULL, '
          'created_at TEXT NOT NULL, '
          'updated_at TEXT NOT NULL)',
        );

        // Insert v2-style data
        await database.customInsert(
          'INSERT INTO master_password_config_v2 '
          '(id, password_hash_argon2, salt_hex, created_at, updated_at) '
          'VALUES (1, \'v2hash\', \'v2salt\', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)',
        );

        // Simulate v3 migration: ALTER TABLE ADD COLUMN
        await database.customInsert(
          'ALTER TABLE master_password_config_v2 '
          'ADD COLUMN password_hint TEXT',
        );
        await database.customInsert(
          'ALTER TABLE master_password_config_v2 '
          'ADD COLUMN backup_code_hashes TEXT',
        );
        await database.customInsert(
          'ALTER TABLE master_password_config_v2 '
          'ADD COLUMN encrypted_storage_key TEXT',
        );
        await database.customInsert(
          'ALTER TABLE master_password_config_v2 '
          'ADD COLUMN encrypted_storage_key_nonce TEXT',
        );
        await database.customInsert(
          'ALTER TABLE master_password_config_v2 '
          'ADD COLUMN encrypted_storage_key_tag TEXT',
        );

        // Verify existing data survives
        final rows = await database.customSelect(
          'SELECT * FROM master_password_config_v2 WHERE id = 1',
        ).get();
        expect(rows, hasLength(1));
        expect(rows.first.data['password_hash_argon2'], 'v2hash');
        expect(rows.first.data['salt_hex'], 'v2salt');

        // Verify NEW columns are NULL
        expect(rows.first.data['password_hint'], isNull);
        expect(rows.first.data['backup_code_hashes'], isNull);
        expect(rows.first.data['encrypted_storage_key'], isNull);
        expect(rows.first.data['encrypted_storage_key_nonce'], isNull);
        expect(rows.first.data['encrypted_storage_key_tag'], isNull);
      });
    });

    group('full setup flow', () {
      test('should_create_all_records_correctly_on_setup', () async {
        // Simulate the full setup flow from CredentialProtectionController
        final testPassword = 'mystrongpassword1';
        final testHint = 'first pet name';
        final dek = auth.generateStorageKey();
        final salt = auth.generateSalt();
        final hash = await auth.hashMasterPassword(
          password: testPassword,
          salt: salt,
        );
        final kek = await auth.deriveMasterKey(
          password: testPassword,
          salt: salt,
        );
        final wrapped = await auth.wrapStorageKey(dek: dek, kek: kek);

        // Generate backup codes
        final codesResult = await auth.generateBackupCodes(count: 2);
        final codesJson = jsonEncode(codesResult.codeHashes);

        // Save all to DB (same as _onConfirmSetup does)
        await store.saveFull(
          hashHex: hash,
          saltHex: auth.bytesToHex(salt),
          hint: testHint,
          backupCodeHashesJson: codesJson,
          encryptedStorageKeyHex: wrapped.ciphertextHex,
          encryptedStorageKeyNonceHex: wrapped.nonceHex,
          encryptedStorageKeyTagHex: wrapped.tagHex,
        );

        // Verify all records
        final config = await store.readFull();
        expect(config, isNotNull);
        expect(config!.hashHex, hash);
        expect(config.passwordHint, testHint);
        expect(config.backupCodeHashes, isNotNull);
        expect(config.backupCodeHashes!.length, 2);
        expect(config.encryptedStorageKeyHex, wrapped.ciphertextHex);

        // Verify DEK round-trip: unwrap with same password
        final kek2 = await auth.deriveMasterKey(
          password: testPassword,
          salt: salt,
        );
        final unwrappedDek = await auth.unwrapStorageKey(
          payload: EncryptionPayload(
            ciphertextHex: config.encryptedStorageKeyHex!,
            nonceHex: config.encryptedStorageKeyNonceHex ?? '',
            tagHex: config.encryptedStorageKeyTagHex ?? '',
          ),
          kek: kek2,
        );
        expect(unwrappedDek, dek);

        // Verify hint can be read
        final hint = await store.readHint();
        expect(hint, testHint);

        // Verify backup codes can be verified
        final recoveryService =
            _TestRecoveryService(codeHashes: codesResult.codeHashes);
        final matchIndex = await recoveryService.verifyCode(
          codesResult.plainCodes[0],
          auth,
        );
        expect(matchIndex, 0);
      });

      test('should_encrypt_entry_with_mp_configured', () async {
        // Setup MP first
        final password = 'encryptTest1';
        final dek = auth.generateStorageKey();
        final salt = auth.generateSalt();
        final hash = await auth.hashMasterPassword(
          password: password,
          salt: salt,
        );
        final kek = await auth.deriveMasterKey(
          password: password,
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

        // Unwrap the DEK (simulating "verify MP" step)
        final kek2 = await auth.deriveMasterKey(
          password: password,
          salt: salt,
        );
        final unwrappedDek = await auth.unwrapStorageKey(
          payload: EncryptionPayload(
            ciphertextHex: wrapped.ciphertextHex,
            nonceHex: wrapped.nonceHex,
            tagHex: wrapped.tagHex,
          ),
          kek: kek2,
        );

        // Encrypt a secret with the DEK
        const secret = 'my-credential-password-123';
        final payload = await auth.encryptSecret(
          plaintext: secret,
          masterKey: unwrappedDek,
        );

        // Verify the ciphertext is different from plaintext
        expect(payload.ciphertextHex, isNot(secret));

        // Create entry in DB
        await database.customInsert(
          'INSERT INTO entries (id, type, title, content, metadata, tags, '
          'requires_auth, encrypted_secret, cipher_nonce, cipher_tag, '
          'created_at, updated_at, version) '
          'VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, '
          'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 1)',
          variables: [
            Variable.withString('test-enc-entry'),
            Variable.withString('credential'),
            Variable.withString('Encrypted Service'),
            Variable.withString(''),
            Variable.withString(jsonEncode({'username': 'encuser'})),
            Variable.withString(jsonEncode([])),
            Variable.withString(payload.ciphertextHex),
            Variable.withString(payload.nonceHex),
            Variable.withString(payload.tagHex),
          ],
        );

        // Decrypt using the DEK
        final result = await auth.decryptSecret(
          payload: payload,
          masterKey: unwrappedDek,
        );
        expect(result, secret);
      });

      test('should_encrypt_entry_with_mp_and_decrypt_with_dek', () async {
        // Full flow: setup → encrypt → decrypt

        // 1. Generate MP parameters
        final password = 'testpass42';
        final dek = auth.generateStorageKey();
        final salt = auth.generateSalt();
        final hash = await auth.hashMasterPassword(
          password: password,
          salt: salt,
        );
        final kek = await auth.deriveMasterKey(
          password: password,
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

        // 2. Simulate session: user enters MP → unwrap DEK
        final verifySalt = auth.hexToBytes(
          (await store.readFull())!.saltHex,
        );
        final isVerified = await auth.verifyMasterPassword(
          password: password,
          salt: verifySalt,
          expectedHashHex: hash,
        );
        expect(isVerified, true);

        final sessionKek = await auth.deriveMasterKey(
          password: password,
          salt: verifySalt,
        );
        final config = await store.readFull();
        final sessionDek = await auth.unwrapStorageKey(
          payload: EncryptionPayload(
            ciphertextHex: config!.encryptedStorageKeyHex!,
            nonceHex: config.encryptedStorageKeyNonceHex ?? '',
            tagHex: config.encryptedStorageKeyTagHex ?? '',
          ),
          kek: sessionKek,
        );
        expect(sessionDek, dek);

        // 3. Encrypt secret
        const secret = 'S3cr3t!';
        final encrypted = await auth.encryptSecret(
          plaintext: secret,
          masterKey: sessionDek,
        );

        // 4. Decrypt secret
        final decrypted = await auth.decryptSecret(
          payload: encrypted,
          masterKey: sessionDek,
        );
        expect(decrypted, secret);

        // 5. Verify WRONG master password fails
        final wrongKek = await auth.deriveMasterKey(
          password: 'wrongpassword',
          salt: verifySalt,
        );
        expect(
          () async => auth.unwrapStorageKey(
            payload: EncryptionPayload(
              ciphertextHex: config.encryptedStorageKeyHex!,
              nonceHex: config.encryptedStorageKeyNonceHex ?? '',
              tagHex: config.encryptedStorageKeyTagHex ?? '',
            ),
            kek: wrongKek,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should_recover_and_set_new_mp_then_decrypt_new_entry',
          () async {
        // Simulate: user has MP → forgets it → uses backup code → sets new MP
        // → encrypts a NEW entry with new DEK

        // Phase 1: Initial setup with backup codes
        final initialPassword = 'initialPass1';
        final dek = auth.generateStorageKey();
        final salt = auth.generateSalt();
        final hash = await auth.hashMasterPassword(
          password: initialPassword,
          salt: salt,
        );
        final kek = await auth.deriveMasterKey(
          password: initialPassword,
          salt: salt,
        );
        final wrapped = await auth.wrapStorageKey(dek: dek, kek: kek);
        final codesResult = await auth.generateBackupCodes(count: 2);

        // Encrypt an entry with the initial DEK
        const oldSecret = 'old-encrypted-secret';
        final oldEncrypted = await auth.encryptSecret(
          plaintext: oldSecret,
          masterKey: dek,
        );

        await store.saveFull(
          hashHex: hash,
          saltHex: auth.bytesToHex(salt),
          backupCodeHashesJson: jsonEncode(codesResult.codeHashes),
          encryptedStorageKeyHex: wrapped.ciphertextHex,
          encryptedStorageKeyNonceHex: wrapped.nonceHex,
          encryptedStorageKeyTagHex: wrapped.tagHex,
        );

        // Phase 2: Recovery — verify a backup code
        final recoveryService =
            _TestRecoveryService(codeHashes: codesResult.codeHashes);
        final matchIndex = await recoveryService.verifyCode(
          codesResult.plainCodes[0],
          auth,
        );
        expect(matchIndex, 0);

        // Consume the code
        final consumed = await store.consumeBackupCodeAtIndex(matchIndex);
        expect(consumed, true);

        // Verify code is gone
        final remaining = await store.readBackupCodeHashes();
        expect(remaining, isNotNull);
        expect(remaining!.length, 1);

        // Phase 3: Set new MP (generates new DEK — old entries become unreachable)
        final newPassword = 'newPass1234';
        final newDek = auth.generateStorageKey();
        final newSalt = auth.generateSalt();
        final newHash = await auth.hashMasterPassword(
          password: newPassword,
          salt: newSalt,
        );
        final newKek = await auth.deriveMasterKey(
          password: newPassword,
          salt: newSalt,
        );
        final newWrapped = await auth.wrapStorageKey(
          dek: newDek,
          kek: newKek,
        );

        // Generate new backup codes
        final newCodes = await auth.generateBackupCodes(count: 2);
        final newCodesJson = jsonEncode(newCodes.codeHashes);

        await store.saveFull(
          hashHex: newHash,
          saltHex: auth.bytesToHex(newSalt),
          hint: 'recovery hint',
          backupCodeHashesJson: newCodesJson,
          encryptedStorageKeyHex: newWrapped.ciphertextHex,
          encryptedStorageKeyNonceHex: newWrapped.nonceHex,
          encryptedStorageKeyTagHex: newWrapped.tagHex,
        );

        // Phase 4: Decrypt a NEW entry with the new DEK
        const newSecret = 'new-secret-after-recovery';
        final newEncrypted = await auth.encryptSecret(
          plaintext: newSecret,
          masterKey: newDek,
        );

        // Save new entry
        await database.customInsert(
          'INSERT INTO entries (id, type, title, content, metadata, tags, '
          'requires_auth, encrypted_secret, cipher_nonce, cipher_tag, '
          'created_at, updated_at, version) '
          'VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, '
          'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 1)',
          variables: [
            Variable.withString('recovery-entry'),
            Variable.withString('credential'),
            Variable.withString('Post-Recovery Entry'),
            Variable.withString(''),
            Variable.withString(jsonEncode({'username': 'recovered'})),
            Variable.withString(jsonEncode([])),
            Variable.withString(newEncrypted.ciphertextHex),
            Variable.withString(newEncrypted.nonceHex),
            Variable.withString(newEncrypted.tagHex),
          ],
        );

        // Decrypt with new DEK
        final decryptedNew = await auth.decryptSecret(
          payload: newEncrypted,
          masterKey: newDek,
        );
        final decryptedNew2 = decryptedNew;
        expect(decryptedNew2, newSecret);

        // Verify old DEK can still decrypt old entry (it's still a valid key)
        final decryptedOld = await auth.decryptSecret(
          payload: oldEncrypted,
          masterKey: dek,
        );
        final decryptedOld2 = decryptedOld;
        expect(decryptedOld2, oldSecret);

        // Verify new DEK CANNOT decrypt old entry (different keys)
        expect(
          () async => auth.decryptSecret(
            payload: oldEncrypted,
            masterKey: newDek,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should_consume_backup_code_only_once', () async {
        // Setup with one backup code
        final codes = await auth.generateBackupCodes(count: 1);
        await store.save(hashHex: 'hash', saltHex: 'salt');
        await store.saveBackupCodeHashes(codes.codeHashes);

        // First consumption should succeed
        final recoveryService =
            _TestRecoveryService(codeHashes: codes.codeHashes);
        final match = await recoveryService.verifyCode(
          codes.plainCodes[0],
          auth,
        );
        expect(match, 0);

        final consumed1 = await store.consumeBackupCodeAtIndex(match);
        expect(consumed1, true);

        // After consumption, no codes remain
        final remaining = await store.readBackupCodeHashes();
        expect(remaining, isNull);

        // Second consumption attempt on empty list should fail
        final consumed2 = await store.consumeBackupCodeAtIndex(0);
        expect(consumed2, false);
      });
    });
  });
}

/// Simple helper class to verify backup codes against stored hashes.
class _TestRecoveryService {
  _TestRecoveryService({required List<String> codeHashes})
      : _codeHashes = codeHashes;

  final List<String> _codeHashes;

  Future<int> verifyCode(String code, EntryAuthService auth) async {
    for (var i = 0; i < _codeHashes.length; i++) {
      final parts = _codeHashes[i].split(':');
      if (parts.length != 2) continue;
      final salt = auth.hexToBytes(parts[0]);
      final computed = await auth.hashMasterPassword(
        password: code,
        salt: salt,
      );
      if (computed == parts[1]) return i;
    }
    return -1;
  }
}
