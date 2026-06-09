import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';

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

  group('BackupCodeEntry', () {
    test('should_round_trip_json', () {
      const entry = BackupCodeEntry(
        saltHex: 'a1b2c3d4e5f6a7b8c9d0e1f2',
        hashHex: 'deadbeef0123456789abcdef',
        dekCipherHex: 'ciphertexthex',
        dekNonceHex: '1234567890ab',
        dekTagHex: '1234567890abcdef',
      );

      final json = entry.toJson();
      final parsed = BackupCodeEntry.fromJson(json);

      expect(parsed.saltHex, entry.saltHex);
      expect(parsed.hashHex, entry.hashHex);
      expect(parsed.dekCipherHex, entry.dekCipherHex);
      expect(parsed.dekNonceHex, entry.dekNonceHex);
      expect(parsed.dekTagHex, entry.dekTagHex);
    });

    test('should_parse_from_snake_case_json', () {
      final json = {
        'salt': 'aabbccdd11223344',
        'hash': '55667788',
        'dek_cipher': 'cipher01',
        'dek_nonce': 'nonce01',
        'dek_tag': 'tag01',
      };

      final parsed = BackupCodeEntry.fromJson(json);

      expect(parsed.saltHex, 'aabbccdd11223344');
      expect(parsed.hashHex, '55667788');
      expect(parsed.dekCipherHex, 'cipher01');
      expect(parsed.dekNonceHex, 'nonce01');
      expect(parsed.dekTagHex, 'tag01');
    });

    test('should_produce_snake_case_json_keys', () {
      const entry = BackupCodeEntry(
        saltHex: 'aaa',
        hashHex: 'bbb',
        dekCipherHex: 'ccc',
        dekNonceHex: 'ddd',
        dekTagHex: 'eee',
      );

      final json = entry.toJson();

      expect(json['salt'], 'aaa');
      expect(json['hash'], 'bbb');
      expect(json['dek_cipher'], 'ccc');
      expect(json['dek_nonce'], 'ddd');
      expect(json['dek_tag'], 'eee');
    });
  });

  group('MasterPasswordStore (v4 schema — backup_code_data)', () {
    test('should_return_null_when_no_backup_code_data', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      final data = await store.readBackupCodeData();
      expect(data, isNull);
    });

    test('should_consume_both_arrays_atomically_at_index', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      final hashes = ['h1', 'h2', 'h3'];
      final entries = [
        const BackupCodeEntry(
          saltHex: 's1', hashHex: 'h1',
          dekCipherHex: 'c1', dekNonceHex: 'n1', dekTagHex: 't1',
        ),
        const BackupCodeEntry(
          saltHex: 's2', hashHex: 'h2',
          dekCipherHex: 'c2', dekNonceHex: 'n2', dekTagHex: 't2',
        ),
        const BackupCodeEntry(
          saltHex: 's3', hashHex: 'h3',
          dekCipherHex: 'c3', dekNonceHex: 'n3', dekTagHex: 't3',
        ),
      ];

      await store.saveBackupCodeHashes(hashes);
      await database.customUpdate(
        'UPDATE master_password_config SET backup_code_data = ? WHERE id = 1',
        variables: [
          Variable.withString(jsonEncode(entries.map((e) => e.toJson()).toList())),
        ],
      );

      // Consume at index 1 (middle)
      final consumed = await store.consumeBackupCodeAtIndexAndData(1);
      expect(consumed, true);

      // Both arrays should have shrunk
      final remainingHashes = await store.readBackupCodeHashes();
      expect(remainingHashes, isNotNull);
      expect(remainingHashes!.length, 2);
      expect(remainingHashes[0], 'h1');
      expect(remainingHashes[1], 'h3');

      final remainingData = await store.readBackupCodeData();
      expect(remainingData, isNotNull);
      expect(remainingData!.length, 2);
      expect(remainingData[0].saltHex, 's1');
      expect(remainingData[1].saltHex, 's3');
    });

    test('should_consume_both_arrays_when_backup_code_data_is_null', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(['h1', 'h2']);

      // backup_code_data is null — consume should still work (backward compat)
      final consumed = await store.consumeBackupCodeAtIndexAndData(0);
      expect(consumed, true);

      final remaining = await store.readBackupCodeHashes();
      expect(remaining, isNotNull);
      expect(remaining!.length, 1);
      expect(remaining[0], 'h2');
    });

    test('should_save_full_with_backup_code_data_json', () async {
      final entries = [
        const BackupCodeEntry(
          saltHex: 's1', hashHex: 'h1',
          dekCipherHex: 'c1', dekNonceHex: 'n1', dekTagHex: 't1',
        ),
      ];
      await store.saveFull(
        hashHex: 'hash',
        saltHex: 'salt',
        backupCodeHashesJson: jsonEncode(['h1']),
        backupCodeDataJson: jsonEncode(entries.map((e) => e.toJson()).toList()),
      );

      final data = await store.readBackupCodeData();
      expect(data, isNotNull);
      expect(data!.length, 1);
      expect(data[0].saltHex, 's1');

      final hashes = await store.readBackupCodeHashes();
      expect(hashes, isNotNull);
      expect(hashes!.length, 1);
      expect(hashes[0], 'h1');
    });

    test('should_save_full_with_null_backup_code_data', () async {
      await store.saveFull(
        hashHex: 'hash',
        saltHex: 'salt',
        backupCodeHashesJson: jsonEncode(['h1']),
      );

      final data = await store.readBackupCodeData();
      expect(data, isNull);

      final hashes = await store.readBackupCodeHashes();
      expect(hashes, isNotNull);
      expect(hashes!.length, 1);
    });

    test('should_read_backup_code_data_after_save', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      final entries = [
        const BackupCodeEntry(
          saltHex: 's1', hashHex: 'h1',
          dekCipherHex: 'c1', dekNonceHex: 'n1', dekTagHex: 't1',
        ),
        const BackupCodeEntry(
          saltHex: 's2', hashHex: 'h2',
          dekCipherHex: 'c2', dekNonceHex: 'n2', dekTagHex: 't2',
        ),
      ];
      final json = jsonEncode(entries.map((e) => e.toJson()).toList());

      // Write directly via raw SQL since saveFull isn't modified yet
      await database.customUpdate(
        'UPDATE master_password_config SET backup_code_data = ? WHERE id = 1',
        variables: [Variable.withString(json)],
      );

      final data = await store.readBackupCodeData();
      expect(data, isNotNull);
      expect(data!.length, 2);
      expect(data[0].saltHex, 's1');
      expect(data[1].saltHex, 's2');
    });
  });

  group('Schema version', () {
    test('schema_version_should_be_11', () {
      expect(database.schemaVersion, 11);
    });

    test('should_have_backup_code_data_column_available', () async {
      // Verify the column exists and can be written to
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await database.customUpdate(
        'UPDATE master_password_config SET backup_code_data = ? WHERE id = 1',
        variables: [
          Variable.withString(jsonEncode([{
            'salt': 's1', 'hash': 'h1',
            'dek_cipher': 'c1', 'dek_nonce': 'n1', 'dek_tag': 't1',
          }])),
        ],
      );
      final data = await store.readBackupCodeData();
      expect(data, isNotNull);
      expect(data!.length, 1);
      expect(data[0].saltHex, 's1');
    });
  });

  group('MasterPasswordStore (v3 schema)', () {
    test('should_read_full_config_after_save', () async {
      await store.saveFull(
        hashHex: 'abc123',
        saltHex: 'def456',
        hint: 'my hint',
        backupCodeHashesJson: jsonEncode([
          'salt1:hash1',
          'salt2:hash2',
        ]),
        encryptedStorageKeyHex: 'keyhex',
        encryptedStorageKeyNonceHex: 'noncehex',
        encryptedStorageKeyTagHex: 'taghex',
      );

      final config = await store.readFull();
      expect(config, isNotNull);
      expect(config!.hashHex, 'abc123');
      expect(config.saltHex, 'def456');
      expect(config.passwordHint, 'my hint');
      expect(config.backupCodeHashes, isNotNull);
      expect(config.backupCodeHashes!.length, 2);
      expect(config.backupCodeHashes![0], 'salt1:hash1');
      expect(config.backupCodeHashes![1], 'salt2:hash2');
      expect(config.encryptedStorageKeyHex, 'keyhex');
      expect(config.encryptedStorageKeyNonceHex, 'noncehex');
      expect(config.encryptedStorageKeyTagHex, 'taghex');
    });

    test('should_read_null_when_no_config', () async {
      final config = await store.readFull();
      expect(config, isNull);
    });

    test('should_save_hint_and_read_back', () async {
      // First save minimal config so row exists
      await store.save(hashHex: 'hash', saltHex: 'salt');

      await store.saveHint('my password hint');
      final hint = await store.readHint();
      expect(hint, 'my password hint');
    });

    test('should_return_null_hint_when_not_set', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      final hint = await store.readHint();
      expect(hint, isNull);
    });

    test('should_clear_hint_by_saving_null', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveHint('some hint');
      await store.saveHint(null);

      final hint = await store.readHint();
      expect(hint, isNull);
    });

    test('should_save_and_read_backup_code_hashes', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');

      final hashes = ['a1:b1', 'a2:b2', 'a3:b3'];
      await store.saveBackupCodeHashes(hashes);

      final read = await store.readBackupCodeHashes();
      expect(read, isNotNull);
      expect(read!.length, 3);
      expect(read[0], 'a1:b1');
      expect(read[2], 'a3:b3');
    });

    test('should_return_null_when_no_backup_codes', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      final hashes = await store.readBackupCodeHashes();
      expect(hashes, isNull);
    });

    test('should_consume_code_at_index_atomically', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      final hashes = ['a1:b1', 'a2:b2', 'a3:b3'];
      await store.saveBackupCodeHashes(hashes);

      final consumed = await store.consumeBackupCodeAtIndex(1);
      expect(consumed, true);

      final remaining = await store.readBackupCodeHashes();
      expect(remaining, isNotNull);
      expect(remaining!.length, 2);
      expect(remaining[0], 'a1:b1');
      // Index 1 ('a2:b2') should be gone
      expect(remaining[1], 'a3:b3');
    });

    test('should_consume_first_code_atomically', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      final hashes = ['first:code', 'second:code'];
      await store.saveBackupCodeHashes(hashes);

      final consumed = await store.consumeBackupCodeAtIndex(0);
      expect(consumed, true);

      final remaining = await store.readBackupCodeHashes();
      expect(remaining!.length, 1);
      expect(remaining[0], 'second:code');
    });

    test('should_consume_last_code_atomically', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      final hashes = ['first:code', 'second:code'];
      await store.saveBackupCodeHashes(hashes);

      final consumed = await store.consumeBackupCodeAtIndex(1);
      expect(consumed, true);

      final remaining = await store.readBackupCodeHashes();
      expect(remaining!.length, 1);
      expect(remaining[0], 'first:code');
    });

    test('should_return_false_when_consume_index_out_of_bounds', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(['a1:b1']);

      final consumed = await store.consumeBackupCodeAtIndex(5);
      expect(consumed, false);

      // Verify nothing was deleted
      final remaining = await store.readBackupCodeHashes();
      expect(remaining!.length, 1);

      // Also test negative index
      final consumedNeg = await store.consumeBackupCodeAtIndex(-1);
      expect(consumedNeg, false);
    });

    test('should_return_false_when_no_codes_to_consume', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      // No backup codes saved

      final consumed = await store.consumeBackupCodeAtIndex(0);
      expect(consumed, false);
    });

    test('should_persist_encrypted_storage_key', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');

      await store.saveEncryptedStorageKey(
        keyHex: 'ciphertexthex',
        nonceHex: 'noncehex',
        tagHex: 'taghex',
      );

      final result = await store.readEncryptedStorageKey();
      expect(result, isNotNull);
      expect(result!.keyHex, 'ciphertexthex');
      expect(result.nonceHex, 'noncehex');
      expect(result.tagHex, 'taghex');
    });

    test('should_return_null_when_no_storage_key', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      final result = await store.readEncryptedStorageKey();
      expect(result, isNull);
    });

    test('should_update_existing_hint_with_upsert', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveHint('hint v1');
      await store.saveHint('hint v2');

      final hint = await store.readHint();
      expect(hint, 'hint v2');
    });

    test('should_update_existing_backup_codes_atomically', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(['old:hash']);
      await store.saveBackupCodeHashes(['new1:hash', 'new2:hash']);

      final codes = await store.readBackupCodeHashes();
      expect(codes!.length, 2);
      expect(codes[0], 'new1:hash');
    });

    test('should_update_existing_encrypted_storage_key', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveEncryptedStorageKey(
        keyHex: 'oldkey', nonceHex: 'oldnonce', tagHex: 'oldtag',
      );
      await store.saveEncryptedStorageKey(
        keyHex: 'newkey', nonceHex: 'newnonce', tagHex: 'newtag',
      );

      final result = await store.readEncryptedStorageKey();
      expect(result!.keyHex, 'newkey');
      expect(result.nonceHex, 'newnonce');
      expect(result.tagHex, 'newtag');
    });

    test('should_consume_code_via_string_search', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes([
        'salt1:hash1',
        'salt2:hash2',
        'salt3:hash3',
      ]);

      // Consume the one that contains 'hash2'
      final consumed = await store.consumeBackupCode('salt2:hash2');
      expect(consumed, true);

      final remaining = await store.readBackupCodeHashes();
      expect(remaining!.length, 2);
      expect(remaining[0], 'salt1:hash1');
      expect(remaining[1], 'salt3:hash3');
    });

    test('should_not_consume_code_that_does_not_exist', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(['salt1:hash1']);

      final consumed = await store.consumeBackupCode('nonexistent:code');
      expect(consumed, false);

      // Nothing was removed
      final remaining = await store.readBackupCodeHashes();
      expect(remaining!.length, 1);
    });

    test('should_save_full_with_null_optionals', () async {
      // Save with only hash+salt, all optionals null
      await store.saveFull(
        hashHex: 'hashonly',
        saltHex: 'saltonly',
      );

      final config = await store.readFull();
      expect(config, isNotNull);
      expect(config!.hashHex, 'hashonly');
      expect(config.saltHex, 'saltonly');
      expect(config.passwordHint, isNull);
      expect(config.backupCodeHashes, isNull);
      expect(config.encryptedStorageKeyHex, isNull);
      expect(config.encryptedStorageKeyNonceHex, isNull);
      expect(config.encryptedStorageKeyTagHex, isNull);

      // Now update with all values set
      await store.saveFull(
        hashHex: 'hashonly',
        saltHex: 'saltonly',
        hint: 'a hint',
        backupCodeHashesJson: jsonEncode(['c1:h1']),
        encryptedStorageKeyHex: 'ekey',
        encryptedStorageKeyNonceHex: 'enonce',
        encryptedStorageKeyTagHex: 'etag',
      );

      final updated = await store.readFull();
      expect(updated!.passwordHint, 'a hint');
      expect(updated.backupCodeHashes!.length, 1);
      expect(updated.encryptedStorageKeyHex, 'ekey');

      // Then clear optionals back to null
      await store.saveFull(
        hashHex: 'hashonly',
        saltHex: 'saltonly',
      );

      final cleared = await store.readFull();
      expect(cleared!.passwordHint, isNull);
      expect(cleared.backupCodeHashes, isNull);
      expect(cleared.encryptedStorageKeyHex, isNull);
    });

    test('should_consume_code_atomically_within_transaction', () async {
      await store.save(hashHex: 'hash', saltHex: 'salt');
      await store.saveBackupCodeHashes(['a:x', 'b:y', 'c:z']);

      // Consume middle code
      final result = await store.consumeBackupCode('b:y');
      expect(result, true);

      // Verify: should have 2 remaining
      final remaining = await store.readBackupCodeHashes();
      expect(remaining!.length, 2);
      expect(remaining[0], 'a:x');
      expect(remaining[1], 'c:z');

      // Consume another
      final result2 = await store.consumeBackupCode('a:x');
      expect(result2, true);

      final remaining2 = await store.readBackupCodeHashes();
      expect(remaining2!.length, 1);
      expect(remaining2[0], 'c:z');

      // Consume last
      final result3 = await store.consumeBackupCode('c:z');
      expect(result3, true);

      final remaining3 = await store.readBackupCodeHashes();
      expect(remaining3, isNull);
    });
  });
}
