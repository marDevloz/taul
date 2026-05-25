import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:taul/infrastructure/database/app_database.dart';

class BackupCodeEntry {
  const BackupCodeEntry({
    required this.saltHex,
    required this.hashHex,
    required this.dekCipherHex,
    required this.dekNonceHex,
    required this.dekTagHex,
  });

  final String saltHex;
  final String hashHex;
  final String dekCipherHex;
  final String dekNonceHex;
  final String dekTagHex;

  factory BackupCodeEntry.fromJson(Map<String, dynamic> json) {
    return BackupCodeEntry(
      saltHex: json['salt'] as String,
      hashHex: json['hash'] as String,
      dekCipherHex: json['dek_cipher'] as String,
      dekNonceHex: json['dek_nonce'] as String,
      dekTagHex: json['dek_tag'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'salt': saltHex,
        'hash': hashHex,
        'dek_cipher': dekCipherHex,
        'dek_nonce': dekNonceHex,
        'dek_tag': dekTagHex,
      };
}

class MasterPasswordRecord {
  const MasterPasswordRecord({
    required this.hashHex,
    required this.saltHex,
    this.passwordHint,
    this.backupCodeHashes,
    this.encryptedStorageKeyHex,
    this.encryptedStorageKeyNonceHex,
    this.encryptedStorageKeyTagHex,
  });

  final String hashHex;
  final String saltHex;
  final String? passwordHint;
  final String? backupCodeHashes;
  final String? encryptedStorageKeyHex;
  final String? encryptedStorageKeyNonceHex;
  final String? encryptedStorageKeyTagHex;
}

class EncryptedStorageKeyData {
  const EncryptedStorageKeyData({
    required this.keyHex,
    required this.nonceHex,
    required this.tagHex,
  });

  final String keyHex;
  final String nonceHex;
  final String tagHex;
}

class MasterPasswordFullConfig {
  const MasterPasswordFullConfig({
    required this.hashHex,
    required this.saltHex,
    this.passwordHint,
    this.backupCodeHashes,
    this.encryptedStorageKeyHex,
    this.encryptedStorageKeyNonceHex,
    this.encryptedStorageKeyTagHex,
  });

  final String hashHex;
  final String saltHex;
  final String? passwordHint;
  final List<String>? backupCodeHashes;
  final String? encryptedStorageKeyHex;
  final String? encryptedStorageKeyNonceHex;
  final String? encryptedStorageKeyTagHex;
}

class MasterPasswordStore {
  const MasterPasswordStore(this._database);

  final AppDatabase _database;

  /// Reads only hash+ salt (backward-compatible).
  Future<MasterPasswordRecord?> read() async {
    final rows = await _database.customSelect(
      'SELECT password_hash_argon2, salt_hex FROM master_password_config WHERE id = 1 LIMIT 1',
    ).get();

    if (rows.isEmpty) return null;
    final row = rows.first.data;
    return MasterPasswordRecord(
      hashHex: row['password_hash_argon2'] as String,
      saltHex: row['salt_hex'] as String,
    );
  }

  /// Saves hash + salt (backward-compatible).
  Future<void> save({
    required String hashHex,
    required String saltHex,
  }) async {
    await _database.customInsert(
      'INSERT INTO master_password_config (id, password_hash_argon2, salt_hex, created_at, updated_at) '
      'VALUES (1, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) '
      'ON CONFLICT(id) DO UPDATE SET '
      'password_hash_argon2 = excluded.password_hash_argon2, '
      'salt_hex = excluded.salt_hex, '
      'updated_at = CURRENT_TIMESTAMP',
      variables: [
        Variable.withString(hashHex),
        Variable.withString(saltHex),
      ],
    );
  }

  /// Reads all columns from the singleton config row.
  Future<MasterPasswordFullConfig?> readFull() async {
    final rows = await _database.customSelect(
      'SELECT password_hash_argon2, salt_hex, password_hint, '
      'backup_code_hashes, encrypted_storage_key, '
      'encrypted_storage_key_nonce, encrypted_storage_key_tag '
      'FROM master_password_config WHERE id = 1 LIMIT 1',
    ).get();

    if (rows.isEmpty) return null;
    final row = rows.first.data;

    List<String>? parsedCodes;
    final rawCodes = row['backup_code_hashes'] as String?;
    if (rawCodes != null && rawCodes.isNotEmpty) {
      final decoded = jsonDecode(rawCodes);
      if (decoded is List && decoded.isNotEmpty) {
        parsedCodes = decoded.cast<String>();
      }
    }

    return MasterPasswordFullConfig(
      hashHex: row['password_hash_argon2'] as String,
      saltHex: row['salt_hex'] as String,
      passwordHint: row['password_hint'] as String?,
      backupCodeHashes: parsedCodes,
      encryptedStorageKeyHex: row['encrypted_storage_key'] as String?,
      encryptedStorageKeyNonceHex: row['encrypted_storage_key_nonce'] as String?,
      encryptedStorageKeyTagHex: row['encrypted_storage_key_tag'] as String?,
    );
  }

  /// Upserts all fields in one call.
  /// When optional fields are null/empty, the corresponding SQL column is set to NULL.
  Future<void> saveFull({
    required String hashHex,
    required String saltHex,
    String? hint,
    String? backupCodeHashesJson,
    String? backupCodeDataJson,
    String? encryptedStorageKeyHex,
    String? encryptedStorageKeyNonceHex,
    String? encryptedStorageKeyTagHex,
  }) async {
    await _database.customInsert(
      'INSERT INTO master_password_config '
      '(id, password_hash_argon2, salt_hex, password_hint, '
      'backup_code_hashes, backup_code_data, '
      'encrypted_storage_key, '
      'encrypted_storage_key_nonce, encrypted_storage_key_tag, '
      'created_at, updated_at) '
      'VALUES (1, ?, ?, '
      'NULLIF(?, \'\'), '
      'NULLIF(?, \'\'), '
      'NULLIF(?, \'\'), '
      'NULLIF(?, \'\'), '
      'NULLIF(?, \'\'), '
      'NULLIF(?, \'\'), '
      'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) '
      'ON CONFLICT(id) DO UPDATE SET '
      'password_hash_argon2 = excluded.password_hash_argon2, '
      'salt_hex = excluded.salt_hex, '
      'password_hint = excluded.password_hint, '
      'backup_code_hashes = excluded.backup_code_hashes, '
      'backup_code_data = excluded.backup_code_data, '
      'encrypted_storage_key = excluded.encrypted_storage_key, '
      'encrypted_storage_key_nonce = excluded.encrypted_storage_key_nonce, '
      'encrypted_storage_key_tag = excluded.encrypted_storage_key_tag, '
      'updated_at = CURRENT_TIMESTAMP',
      variables: [
        Variable.withString(hashHex),
        Variable.withString(saltHex),
        Variable.withString(hint ?? ''),
        Variable.withString(backupCodeHashesJson ?? ''),
        Variable.withString(backupCodeDataJson ?? ''),
        Variable.withString(encryptedStorageKeyHex ?? ''),
        Variable.withString(encryptedStorageKeyNonceHex ?? ''),
        Variable.withString(encryptedStorageKeyTagHex ?? ''),
      ],
    );
  }

  // ── Hint ──

  /// Returns the password hint, or null if not set.
  Future<String?> readHint() async {
    final rows = await _database.customSelect(
      'SELECT password_hint FROM master_password_config WHERE id = 1 LIMIT 1',
    ).get();

    if (rows.isEmpty) return null;
    final hint = rows.first.data['password_hint'] as String?;
    if (hint == null || hint.isEmpty) return null;
    return hint;
  }

  /// Saves (or clears) the password hint.
  /// Pass null to clear the hint (sets SQL NULL).
  Future<void> saveHint(String? hint) async {
    if (hint != null && hint.isNotEmpty) {
      await _database.customInsert(
        'INSERT INTO master_password_config (id, password_hash_argon2, salt_hex, '
        'password_hint, created_at, updated_at) '
        'VALUES (1, \'\', \'\', ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) '
        'ON CONFLICT(id) DO UPDATE SET '
        'password_hint = excluded.password_hint, '
        'updated_at = CURRENT_TIMESTAMP',
        variables: [
          Variable.withString(hint),
        ],
      );
    } else {
      await _database.customUpdate(
        'UPDATE master_password_config SET '
        'password_hint = NULL, updated_at = CURRENT_TIMESTAMP '
        'WHERE id = 1',
      );
    }
  }

  // ── Backup Codes ──

  /// Reads the backup code hashes JSON array. Returns null if none stored.
  Future<List<String>?> readBackupCodeHashes() async {
    final rows = await _database.customSelect(
      'SELECT backup_code_hashes FROM master_password_config WHERE id = 1 LIMIT 1',
    ).get();

    if (rows.isEmpty) return null;
    final raw = rows.first.data['backup_code_hashes'] as String?;
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is List) {
      if (decoded.isEmpty) return null;
      return decoded.cast<String>();
    }
    return null;
  }

  /// Saves (replaces) the backup code hashes as a JSON array.
  Future<void> saveBackupCodeHashes(List<String> hashes) async {
    final json = jsonEncode(hashes);
    await _database.customInsert(
      'INSERT INTO master_password_config (id, password_hash_argon2, salt_hex, '
      'backup_code_hashes, created_at, updated_at) '
      'VALUES (1, \'\', \'\', ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) '
      'ON CONFLICT(id) DO UPDATE SET '
      'backup_code_hashes = excluded.backup_code_hashes, '
      'updated_at = CURRENT_TIMESTAMP',
      variables: [
        Variable.withString(json),
      ],
    );
  }

  // ── Backup Code Data (DEK wraps per backup code) ──

  /// Atomically removes the hash at [index] from both `backup_code_hashes`
  /// AND `backup_code_data` arrays in a single transaction.
  /// Returns true if the code was consumed, false if index is out of bounds
  /// or no codes exist. Handles null `backup_code_data` gracefully (backward compat).
  Future<bool> consumeBackupCodeAtIndexAndData(int index) async {
    return _database.transaction<bool>(() async {
      final rows = await _database.customSelect(
        'SELECT backup_code_hashes, backup_code_data FROM master_password_config '
        'WHERE id = 1 LIMIT 1',
      ).get();

      if (rows.isEmpty) return false;
      final row = rows.first.data;
      final rawHashes = row['backup_code_hashes'] as String?;
      if (rawHashes == null || rawHashes.isEmpty) return false;

      final decoded = jsonDecode(rawHashes);
      if (decoded is! List) return false;

      final hashes = decoded.cast<String>();
      if (index < 0 || index >= hashes.length) return false;

      hashes.removeAt(index);
      final updatedHashesJson = jsonEncode(hashes);

      // Handle backup_code_data if it exists
      final rawData = row['backup_code_data'] as String?;
      String? updatedDataJson;
      if (rawData != null && rawData.isNotEmpty) {
        final dataDecoded = jsonDecode(rawData);
        if (dataDecoded is List) {
          final data = dataDecoded.cast<Map<String, dynamic>>();
          if (index < data.length) {
            data.removeAt(index);
            updatedDataJson = jsonEncode(data);
          }
        }
      }

      final dataValue = updatedDataJson ?? rawData;

      await _database.customUpdate(
        'UPDATE master_password_config SET '
        'backup_code_hashes = ?, '
        'backup_code_data = ?, '
        'updated_at = CURRENT_TIMESTAMP '
        'WHERE id = 1',
        variables: [
          Variable.withString(updatedHashesJson),
          Variable.withString(dataValue ?? ''),
        ],
      );

      return true;
    });
  }

  /// Reads the backup_code_data JSON array. Returns null if none stored.
  Future<List<BackupCodeEntry>?> readBackupCodeData() async {
    final rows = await _database.customSelect(
      'SELECT backup_code_data FROM master_password_config WHERE id = 1 LIMIT 1',
    ).get();

    if (rows.isEmpty) return null;
    final raw = rows.first.data['backup_code_data'] as String?;
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is List) {
      if (decoded.isEmpty) return null;
      return decoded
          .map((e) => BackupCodeEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return null;
  }

  /// Atomically removes the hash at [index] from the backup codes array.
  /// Returns true if the code was consumed, false if index is out of bounds
  /// or no codes exist.
  Future<bool> consumeBackupCodeAtIndex(int index) async {
    return _database.transaction<bool>(() async {
      final rows = await _database.customSelect(
        'SELECT backup_code_hashes FROM master_password_config '
        'WHERE id = 1 LIMIT 1',
      ).get();

      if (rows.isEmpty) return false;
      final raw = rows.first.data['backup_code_hashes'] as String?;
      if (raw == null || raw.isEmpty) return false;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return false;

      final codes = decoded.cast<String>();
      if (index < 0 || index >= codes.length) return false;

      codes.removeAt(index);

      final updatedJson = jsonEncode(codes);
      await _database.customUpdate(
        'UPDATE master_password_config SET '
        'backup_code_hashes = ?, updated_at = CURRENT_TIMESTAMP '
        'WHERE id = 1',
        variables: [Variable.withString(updatedJson)],
      );

      return true;
    });
  }

  /// Searches the backup codes for an exact string match and removes it
  /// atomically. Returns true if found and consumed.
  Future<bool> consumeBackupCode(String code) async {
    return _database.transaction<bool>(() async {
      final rows = await _database.customSelect(
        'SELECT backup_code_hashes FROM master_password_config '
        'WHERE id = 1 LIMIT 1',
      ).get();

      if (rows.isEmpty) return false;
      final raw = rows.first.data['backup_code_hashes'] as String?;
      if (raw == null || raw.isEmpty) return false;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return false;

      final codes = decoded.cast<String>();
      final index = codes.indexOf(code);
      if (index == -1) return false;

      codes.removeAt(index);

      final updatedJson = jsonEncode(codes);
      await _database.customUpdate(
        'UPDATE master_password_config SET '
        'backup_code_hashes = ?, updated_at = CURRENT_TIMESTAMP '
        'WHERE id = 1',
        variables: [Variable.withString(updatedJson)],
      );

      return true;
    });
  }

  // ── Encrypted Storage Key (DEK wrapped with KEK) ──

  /// Reads the encrypted storage key (DEK) components.
  /// Returns null if no storage key is stored.
  Future<EncryptedStorageKeyData?> readEncryptedStorageKey() async {
    final rows = await _database.customSelect(
      'SELECT encrypted_storage_key, encrypted_storage_key_nonce, '
      'encrypted_storage_key_tag '
      'FROM master_password_config WHERE id = 1 LIMIT 1',
    ).get();

    if (rows.isEmpty) return null;
    final row = rows.first.data;
    final keyHex = row['encrypted_storage_key'] as String?;
    final nonceHex = row['encrypted_storage_key_nonce'] as String?;
    final tagHex = row['encrypted_storage_key_tag'] as String?;

    if (keyHex == null || keyHex.isEmpty) return null;

    return EncryptedStorageKeyData(
      keyHex: keyHex,
      nonceHex: nonceHex ?? '',
      tagHex: tagHex ?? '',
    );
  }

  /// Deletes the entire master password config row.
  Future<void> delete() async {
    await _database.customUpdate(
      'DELETE FROM master_password_config WHERE id = 1',
    );
  }

  /// Saves (upserts) the encrypted storage key components.
  Future<void> saveEncryptedStorageKey({
    required String keyHex,
    required String nonceHex,
    required String tagHex,
  }) async {
    await _database.customInsert(
      'INSERT INTO master_password_config (id, password_hash_argon2, salt_hex, '
      'encrypted_storage_key, encrypted_storage_key_nonce, '
      'encrypted_storage_key_tag, created_at, updated_at) '
      'VALUES (1, \'\', \'\', ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) '
      'ON CONFLICT(id) DO UPDATE SET '
      'encrypted_storage_key = excluded.encrypted_storage_key, '
      'encrypted_storage_key_nonce = excluded.encrypted_storage_key_nonce, '
      'encrypted_storage_key_tag = excluded.encrypted_storage_key_tag, '
      'updated_at = CURRENT_TIMESTAMP',
      variables: [
        Variable.withString(keyHex),
        Variable.withString(nonceHex),
        Variable.withString(tagHex),
      ],
    );
  }
}
