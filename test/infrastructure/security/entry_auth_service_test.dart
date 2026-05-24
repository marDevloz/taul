import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';

void main() {
  late EntryAuthService auth;

  setUp(() {
    auth = EntryAuthService();
  });

  group('T-03: KEK/DEK Wrapping', () {
    test('should_generate_32_byte_storage_key', () {
      final key = auth.generateStorageKey();
      expect(key.lengthInBytes, 32);
    });

    test('should_generate_unique_storage_keys', () {
      final key1 = auth.generateStorageKey();
      final key2 = auth.generateStorageKey();

      expect(key1, isNot(equals(key2)));
    });

    test('should_wrap_and_unwrap_storage_key_roundtrip', () async {
      final dek = auth.generateStorageKey();
      final kek = auth.generateStorageKey(); // any 32 bytes as KEK for testing

      final payload = await auth.wrapStorageKey(dek: dek, kek: kek);
      final unwrapped = await auth.unwrapStorageKey(payload: payload, kek: kek);

      expect(unwrapped, equals(dek));
    });

    test('should_fail_unwrap_with_wrong_kek', () async {
      final dek = auth.generateStorageKey();
      final kek = auth.generateStorageKey();
      final wrongKek = auth.generateStorageKey();

      final payload = await auth.wrapStorageKey(dek: dek, kek: kek);

      // Unwrapping with wrong key should throw
      expect(
        () async => auth.unwrapStorageKey(payload: payload, kek: wrongKek),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'wrap_should_produce_encryption_payload_with_all_fields',
      () async {
        final dek = auth.generateStorageKey();
        final kek = auth.generateStorageKey();

        final payload = await auth.wrapStorageKey(dek: dek, kek: kek);

        expect(payload.ciphertextHex, isNotEmpty);
        expect(payload.nonceHex, isNotEmpty);
        expect(payload.tagHex, isNotEmpty);

        // DEK is 32 bytes → ciphertext should be 32 bytes = 64 hex chars
        expect(payload.ciphertextHex.length, 64);
        // nonce is 12 bytes = 24 hex chars
        expect(payload.nonceHex.length, 24);
        // tag (MAC) is 16 bytes = 32 hex chars (AES-GCM)
        expect(payload.tagHex.length, 32);
      },
    );
  });

  group('T-04: Backup Codes Generation', () {
    test('should_generate_10_codes_by_default', () async {
      final result = await auth.generateBackupCodes();

      expect(result.plainCodes.length, 10);
      expect(result.codeHashes.length, 10);
    });

    test('should_generate_specified_number_of_codes', () async {
      final result = await auth.generateBackupCodes(count: 3);

      expect(result.plainCodes.length, 3);
      expect(result.codeHashes.length, 3);
    });

    test('should_generate_unique_codes', () async {
      final result = await auth.generateBackupCodes(count: 10);

      // All plain codes should be unique
      final uniqueCodes = result.plainCodes.toSet();
      expect(uniqueCodes.length, 10);
    });

    test('should_generate_unique_hashes_per_code', () async {
      final result = await auth.generateBackupCodes(count: 5);

      // All hashes should be different (different salts per code)
      final uniqueHashes = result.codeHashes.toSet();
      expect(uniqueHashes.length, 5);
    });

    test('should_format_codes_as_XXXX_DASH_XXXX', () async {
      final result = await auth.generateBackupCodes(count: 5);
      // Pattern: 4 alphanumeric chars, dash, 4 alphanumeric chars (uppercase)
      final regex = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$');

      for (final code in result.plainCodes) {
        expect(code, matches(regex));
      }
    });

    test('should_store_hashes_in_salt_hex_colon_hash_hex_format', () async {
      final result = await auth.generateBackupCodes(count: 3);
      // Each hash entry should be "<salt_hex>:<hash_hex>"
      final regex = RegExp(r'^[a-f0-9]+:[a-f0-9]+$');

      for (final hashEntry in result.codeHashes) {
        expect(hashEntry, matches(regex));
        // Salt should be 16 hex chars (8 bytes)
        final parts = hashEntry.split(':');
        expect(parts[0].length, 16); // 8 bytes = 16 hex chars
        expect(parts[1].length, 64); // 32 bytes Argon2id output = 64 hex chars
      }
    });

    test('should_verify_code_against_its_hash', () async {
      final result = await auth.generateBackupCodes(count: 3);

      // For each code, verify that Argon2id produces the same hash
      for (var i = 0; i < result.plainCodes.length; i++) {
        final parts = result.codeHashes[i].split(':');
        final saltHex = parts[0];
        final expectedHash = parts[1];

        // Recompute hash using same method
        final salt = auth.hexToBytes(saltHex);
        final recomputed = await auth.hashMasterPassword(
          password: result.plainCodes[i],
          salt: salt,
        );

        expect(recomputed, equals(expectedHash));
      }
    });
  });
}
