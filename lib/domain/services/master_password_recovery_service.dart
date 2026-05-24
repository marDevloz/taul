import 'package:taul/infrastructure/security/entry_auth_service.dart';

/// Domain service for master password recovery operations.
///
/// Provides backup code verification and consumption logic.
/// Relies on [EntryAuthService] for Argon2id hash verification.
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
}
