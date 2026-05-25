import 'dart:typed_data';

import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart' show BackupCodeEntry;

/// Domain service for master password recovery operations.
///
/// Provides backup code verification, consumption, and DEK unwrapping logic.
/// Relies on [EntryAuthService] for Argon2id hash verification and
/// AES-256-GCM key wrapping.
class MasterPasswordRecoveryService {
  const MasterPasswordRecoveryService({
    required EntryAuthService authService,
  }) : _authService = authService;

  final EntryAuthService _authService;

  /// Verifies a backup code against the stored [codeHashes].
  ///
  /// Each entry in [codeHashes] is expected to be in `salt_hex:hash_hex`
  /// format, where the salt is an 8-byte per-code salt.
  ///
  /// Returns the index of the matching hash, or -1 if no match is found.
  Future<int> verifyBackupCode(
    String code,
    List<String> codeHashes,
  ) async {
    for (var i = 0; i < codeHashes.length; i++) {
      final parts = codeHashes[i].split(':');
      if (parts.length != 2) continue;

      final saltHex = parts[0];
      final expectedHash = parts[1];
      final salt = _authService.hexToBytes(saltHex);

      final computed = await _authService.hashMasterPassword(
        password: code,
        salt: salt,
      );

      if (computed == expectedHash) {
        return i;
      }
    }
    return -1;
  }

  /// Removes the backup code hash at [index] from [codeHashes].
  ///
  /// Returns a new list without the consumed hash. The original list is not
  /// mutated. If [index] is out of bounds, returns the original list unchanged.
  List<String> consumeBackupCode(int index, List<String> codeHashes) {
    if (index < 0 || index >= codeHashes.length) return codeHashes;
    final updated = List<String>.of(codeHashes);
    updated.removeAt(index);
    return updated;
  }

  /// Finds the matching backup code in [codeHashes], derives the backup-KEK
  /// from the corresponding [BackupCodeEntry], and unwraps the preserved DEK.
  ///
  /// Returns the DEK bytes and the consumed code index, or throws if the code
  /// is invalid, the index is out of bounds, or AES-GCM decryption fails.
  Future<({Uint8List dek, int codeIndex})> unwrapDekFromBackupCode({
    required String code,
    required List<String> codeHashes,
    required List<BackupCodeEntry> backupCodeData,
  }) async {
    // 1. Verify code against hashes
    final index = await verifyBackupCode(code, codeHashes);
    if (index < 0) {
      throw ArgumentError('Backup code does not match');
    }
    if (index >= backupCodeData.length) {
      throw StateError('Backup code index $index out of bounds '
          '(${backupCodeData.length} entries)');
    }

    // 2. Read entry and derive backup-KEK
    final entry = backupCodeData[index];
    final salt = _authService.hexToBytes(entry.saltHex);
    final backupKek = await _authService.deriveMasterKey(
      password: code,
      salt: salt,
    );

    // 3. Unwrap DEK from the entry via AES-256-GCM
    final payload = EncryptionPayload(
      ciphertextHex: entry.dekCipherHex,
      nonceHex: entry.dekNonceHex,
      tagHex: entry.dekTagHex,
    );
    final dek = await _authService.unwrapStorageKey(
      payload: payload,
      kek: backupKek,
    );

    return (dek: dek, codeIndex: index);
  }
}
