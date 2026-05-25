import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/services/master_password_recovery_service.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';

void main() {
  late EntryAuthService authService;
  late MasterPasswordRecoveryService recoveryService;

  setUp(() {
    authService = EntryAuthService();
    recoveryService = MasterPasswordRecoveryService(
      authService: authService,
    );
  });

  group('T-05: MasterPasswordRecoveryService', () {
    group('verifyBackupCode', () {
      test('should_return_index_when_code_matches', () async {
        // Generate just 2 codes to keep Argon2id time manageable
        // (each verify iterates through all hashes)
        final codes = await authService.generateBackupCodes(count: 2);

        // Verify first code against all hashes → finds at index 0
        final index0 = await recoveryService.verifyBackupCode(
          codes.plainCodes[0],
          codes.codeHashes,
        );
        expect(index0, 0);

        // Verify second code → finds at index 1
        final index1 = await recoveryService.verifyBackupCode(
          codes.plainCodes[1],
          codes.codeHashes,
        );
        expect(index1, 1);
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('should_return_negative_one_for_invalid_code', () async {
        final codes = await authService.generateBackupCodes(count: 3);

        final index = await recoveryService.verifyBackupCode(
          'INVALID-CODE',
          codes.codeHashes,
        );
        expect(index, -1);
      });

      test('should_return_negative_one_when_no_hashes', () async {
        final index = await recoveryService.verifyBackupCode(
          'ABCD-1234',
          [],
        );
        expect(index, -1);
      });

      test('should_not_match_wrong_code_against_any_hash', () async {
        final codes = await authService.generateBackupCodes(count: 3);

        // Use the second code's hash, but check the first code against it
        // This should not match since each code has a different salt+hashing
        final singleHash = [codes.codeHashes[1]];
        final index = await recoveryService.verifyBackupCode(
          codes.plainCodes[0],
          singleHash,
        );
        expect(index, -1);
      });
    });

    group('consumeBackupCode', () {
      test('should_remove_code_at_given_index', () {
        final hashes = ['salt1:hash1', 'salt2:hash2', 'salt3:hash3'];

        final updated = recoveryService.consumeBackupCode(1, hashes);

        expect(updated.length, 2);
        expect(updated[0], 'salt1:hash1');
        expect(updated[1], 'salt3:hash3');
      });

      test('should_remove_first_element', () {
        final hashes = ['first:code', 'second:code', 'third:code'];

        final updated = recoveryService.consumeBackupCode(0, hashes);

        expect(updated.length, 2);
        expect(updated[0], 'second:code');
      });

      test('should_remove_last_element', () {
        final hashes = ['first:code', 'second:code', 'third:code'];

        final updated = recoveryService.consumeBackupCode(2, hashes);

        expect(updated.length, 2);
        expect(updated[1], 'second:code');
      });

      test('should_return_unchanged_list_for_invalid_index', () {
        final hashes = ['salt1:hash1'];

        final updatedNegative = recoveryService.consumeBackupCode(-1, hashes);
        expect(updatedNegative.length, 1);
        expect(updatedNegative[0], 'salt1:hash1');

        final updatedOob = recoveryService.consumeBackupCode(5, hashes);
        expect(updatedOob.length, 1);
      });

      test('should_return_empty_list_when_consuming_last_item', () {
        final hashes = ['only:hash'];

        final updated = recoveryService.consumeBackupCode(0, hashes);

        expect(updated, isEmpty);
      });

      test('should_not_mutate_original_list', () {
        final hashes = ['a:1', 'b:2', 'c:3'];
        final originalLength = hashes.length;

        recoveryService.consumeBackupCode(1, hashes);

        // Original list should be unchanged
        expect(hashes.length, originalLength);
        expect(hashes[1], 'b:2');
      });
    });

    group('unwrapDekFromBackupCode', () {
      test(
        'should_return_dek_and_index_for_valid_code',
        () async {
          final dek = authService.generateStorageKey();

          final codesResult = await authService.generateBackupCodesWithDekWraps(
            dek,
            count: 3,
          );

          final result = await recoveryService.unwrapDekFromBackupCode(
            code: codesResult.plainCodes[0],
            codeHashes: codesResult.codeHashes,
            backupCodeData: codesResult.entries,
          );

          expect(result.codeIndex, 0);
          expect(result.dek, equals(dek));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'should_unwrap_at_correct_index_for_any_code',
        () async {
          final dek = authService.generateStorageKey();

          final codesResult = await authService.generateBackupCodesWithDekWraps(
            dek,
            count: 5,
          );

          // Test every code produces the same DEK
          for (var i = 0; i < codesResult.plainCodes.length; i++) {
            final result = await recoveryService.unwrapDekFromBackupCode(
              code: codesResult.plainCodes[i],
              codeHashes: codesResult.codeHashes,
              backupCodeData: codesResult.entries,
            );

            expect(result.codeIndex, i);
            expect(result.dek, equals(dek));
          }
        },
        timeout: const Timeout(Duration(seconds: 120)),
      );

      test(
        'should_throw_ArgumentError_for_invalid_code',
        () async {
          final dek = authService.generateStorageKey();
          final codesResult = await authService.generateBackupCodesWithDekWraps(
            dek,
            count: 2,
          );

          expect(
            () => recoveryService.unwrapDekFromBackupCode(
              code: 'INVALID-CODE',
              codeHashes: codesResult.codeHashes,
              backupCodeData: codesResult.entries,
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        'should_throw_StateError_when_backup_code_data_is_shorter_than_index',
        () async {
          final dek = authService.generateStorageKey();

          // Generate wraps for 2 codes
          final codesResult = await authService.generateBackupCodesWithDekWraps(
            dek,
            count: 2,
          );

          // Pass only 1 entry but 2 codeHashes — code[1] matches at index 1
          // which is >= 1 → StateError
          expect(
            () => recoveryService.unwrapDekFromBackupCode(
              code: codesResult.plainCodes[1],
              codeHashes: codesResult.codeHashes,
              backupCodeData: codesResult.entries.sublist(0, 1),
            ),
            throwsA(isA<StateError>()),
          );
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'should_throw_when_tampered_ciphertext_cannot_be_decrypted',
        () async {
          final dek = authService.generateStorageKey();

          final codesResult = await authService.generateBackupCodesWithDekWraps(
            dek,
            count: 2,
          );

          // Tamper the first entry's ciphertext
          final tampered = BackupCodeEntry(
            saltHex: codesResult.entries[0].saltHex,
            hashHex: codesResult.entries[0].hashHex,
            dekCipherHex: '00${codesResult.entries[0].dekCipherHex.substring(2)}',
            dekNonceHex: codesResult.entries[0].dekNonceHex,
            dekTagHex: codesResult.entries[0].dekTagHex,
          );

          final tamperedEntries = [tampered, codesResult.entries[1]];

          expect(
            () => recoveryService.unwrapDekFromBackupCode(
              code: codesResult.plainCodes[0],
              codeHashes: codesResult.codeHashes,
              backupCodeData: tamperedEntries,
            ),
            throwsA(isA<Exception>()),
          );
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    });
  });
}
