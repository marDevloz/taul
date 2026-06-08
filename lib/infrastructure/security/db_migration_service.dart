import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';

/// Migrates an unencrypted SQLite database to an encrypted one using the
/// SQLCipher-documented plaintext -> encrypted export flow.
///
/// The migration is atomic: data is copied to a temp file, encrypted,
/// then swapped into place. If anything fails, the original DB is preserved.
class DbMigrationService {
  DbMigrationService({Logger? logger}) : _log = logger ?? Logger();

  final Logger _log;

  /// Returns the database file path for the given [dbFolder].
  File dbFile(Directory dbFolder) =>
      File('${dbFolder.path}/${AppConstants.databaseName}');

  /// Checks whether the database at [file] is encrypted by attempting to
  /// open it without a key and reading the schema.
  ///
  /// Returns `true` if the DB is already encrypted (schema read fails).
  bool isEncrypted(File file) {
    if (!file.existsSync()) return false;
    try {
      final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final result = db.select('SELECT count(*) FROM sqlite_master;');
      db.dispose();
      return result.isEmpty;
    } catch (_) {
      return true;
    }
  }

  String _toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  String _sqlStringLiteral(String value) => "'${value.replaceAll("'", "''")}'";

  /// Migrates an unencrypted database to an encrypted one.
  ///
  /// 1. Opens the existing unencrypted DB.
  /// 2. Attaches a new encrypted temp database.
  /// 3. Copies schema/data with sqlcipher_export().
  /// 4. Preserves user_version on the encrypted output.
  /// 5. Verifies the encrypted temp DB can be opened with the key.
  /// 6. Swaps files: original -> backup, encrypted -> original.
  /// 7. Deletes the backup.
  ///
  /// Returns `true` if migration succeeded, `false` if no migration was
  /// needed (DB doesn't exist or is already encrypted).
  Future<bool> migrateToEncrypted({
    required File dbFile,
    required Uint8List dek,
  }) async {
    if (!dbFile.existsSync()) {
      _log.d('DB file does not exist, nothing to migrate');
      return false;
    }

    if (isEncrypted(dbFile)) {
      _log.d('DB is already encrypted, skipping migration');
      return false;
    }

    _log.i('Starting DB migration: unencrypted -> encrypted');

    final backupFile = File('${dbFile.path}.bak');
    final tmpFile = File('${dbFile.path}.enc.tmp');
    final keyHex = _toHex(dek);
    final keyLiteral = "x'$keyHex'";

    if (await tmpFile.exists()) await tmpFile.delete();
    if (await backupFile.exists()) await backupFile.delete();

    try {
      final plaintextDb = sqlite3.open(dbFile.path);
      final userVersion = plaintextDb.userVersion;
      _log.d('Captured user_version = $userVersion');

      try {
        final escapedTmpPath = _sqlStringLiteral(tmpFile.path);
        plaintextDb.execute(
          'ATTACH DATABASE $escapedTmpPath AS encrypted KEY $keyLiteral;',
        );
        plaintextDb.execute("SELECT sqlcipher_export('encrypted');");
        plaintextDb.execute('PRAGMA encrypted.user_version = $userVersion;');
        plaintextDb.execute('DETACH DATABASE encrypted;');
      } finally {
        plaintextDb.dispose();
      }
      _log.d('Encrypted export completed with sqlcipher_export');

      final verifyDb = sqlite3.open(tmpFile.path);
      try {
        verifyDb.execute('PRAGMA key = $keyLiteral;');
        final count = verifyDb.select('SELECT count(*) FROM sqlite_master;');
        final verifiedUserVersion = verifyDb.userVersion;
        if (count.isEmpty || verifiedUserVersion != userVersion) {
          throw StateError('Encrypted DB verification failed');
        }
      } finally {
        verifyDb.dispose();
      }
      _log.d('Encrypted DB verified successfully');

      dbFile.renameSync(backupFile.path);
      tmpFile.renameSync(dbFile.path);
      _log.d('File swap completed');

      try {
        await backupFile.delete();
      } catch (e, st) {
        _log.w(
          'Could not delete backup after migration',
          error: e,
          stackTrace: st,
        );
      }

      _log.i('Migration completed successfully');
      return true;
    } catch (e, st) {
      _log.e('Migration failed', error: e, stackTrace: st);

      if (await tmpFile.exists() && !await dbFile.exists()) {
        await tmpFile.rename(dbFile.path);
        _log.d('Recovered: renamed .enc.tmp back to original');
      }
      if (await backupFile.exists() && !await dbFile.exists()) {
        await backupFile.rename(dbFile.path);
        _log.d('Recovered: restored from backup');
      }
      if (await tmpFile.exists()) await tmpFile.delete();
      if (await backupFile.exists()) await backupFile.delete();

      return false;
    }
  }

  /// Migrates an existing user who has a master password but an unencrypted DB.
  ///
  /// This handles users who set up a master password before DB encryption
  /// was available. The old scheme used the KEK directly as the master key
  /// for entry encryption. We need to:
  /// 1. Generate a new DEK
  /// 2. Re-encrypt all entries' secrets from oldKey to new DEK
  /// 3. Save the wrapped DEK to master_password_config
  /// 4. Encrypt the DB via sqlcipher_export
  /// 5. Return the new DEK
  ///
  /// [oldKey] is the current master key (KEK derived from password).
  /// [authService] is needed for encrypt/decrypt operations.
  /// [store] is needed to save the wrapped DEK.
  ///
  /// Returns the new DEK, or null if migration wasn't needed or failed.
  Future<Uint8List?> migrateExistingUser({
    required File dbFile,
    required Uint8List oldKey,
    required EntryAuthService authService,
    required MasterPasswordStore store,
    required MasterPasswordFullConfig config,
  }) async {
    if (!dbFile.existsSync()) return null;

    if (isEncrypted(dbFile)) {
      _log.d('DB is already encrypted, skipping existing user migration');
      return null;
    }

    // Check if migration is needed: no wrapped DEK means old user
    final hasDek = config.encryptedStorageKeyHex != null &&
        config.encryptedStorageKeyHex!.isNotEmpty;
    if (hasDek) {
      _log.d('User already has wrapped DEK, no re-encryption needed');
      return null;
    }

    _log.i('Starting existing user migration: re-encrypt entries + encrypt DB');

    // Step 1: Generate new DEK
    final dek = authService.generateStorageKey();
    _log.d('Generated new DEK');

    // Step 2: Re-encrypt entries from oldKey to dek
    final reEncryptedCount = await _reEncryptEntries(
      dbFile: dbFile,
      oldKey: oldKey,
      newKey: dek,
      authService: authService,
    );
    _log.d('Re-encrypted $reEncryptedCount entries');

    // Step 3: Save wrapped DEK to master_password_config (before DB encryption)
    final wrapped = await authService.wrapStorageKey(dek: dek, kek: oldKey);
    await store.saveEncryptedStorageKey(
      keyHex: wrapped.ciphertextHex,
      nonceHex: wrapped.nonceHex,
      tagHex: wrapped.tagHex,
    );
    _log.d('Saved wrapped DEK to master_password_config');

    // Step 4: Encrypt the DB
    final migrated = await migrateToEncrypted(dbFile: dbFile, dek: dek);
    if (!migrated) {
      _log.e('DB encryption failed during existing user migration');
      return null;
    }

    _log.i('Existing user migration completed successfully');
    return dek;
  }

  /// Re-encrypts all entries with encryptedSecret from [oldKey] to [newKey].
  ///
  /// This runs on the unencrypted DB before sqlcipher_export.
  /// Returns the number of entries re-encrypted.
  Future<int> _reEncryptEntries({
    required File dbFile,
    required Uint8List oldKey,
    required Uint8List newKey,
    required EntryAuthService authService,
  }) async {
    final db = sqlite3.open(dbFile.path);
    try {
      final entries = db.select(
        'SELECT id, encrypted_secret, cipher_nonce, cipher_tag '
        'FROM entries WHERE encrypted_secret IS NOT NULL',
      );

      var count = 0;
      for (final row in entries) {
        final id = row['id'] as String;
        final ciphertextHex = row['encrypted_secret'] as String;
        final nonceHex = row['cipher_nonce'] as String;
        final tagHex = row['cipher_tag'] as String;

        try {
          // Decrypt with old key
          final plaintext = await authService.decryptSecret(
            payload: EncryptionPayload(
              ciphertextHex: ciphertextHex,
              nonceHex: nonceHex,
              tagHex: tagHex,
            ),
            masterKey: oldKey,
          );

          // Encrypt with new DEK
          final newPayload = await authService.encryptSecret(
            plaintext: plaintext,
            masterKey: newKey,
          );

          // Update entry
          db.execute(
            'UPDATE entries SET encrypted_secret = ?, cipher_nonce = ?, cipher_tag = ? WHERE id = ?',
            [
              newPayload.ciphertextHex,
              newPayload.nonceHex,
              newPayload.tagHex,
              id,
            ],
          );
          count++;
        } catch (e) {
          _log.w('Failed to re-encrypt entry $id', error: e);
          // Continue with other entries — this entry will be inaccessible
          // but at least the rest of the data is preserved.
        }
      }

      return count;
    } finally {
      db.dispose();
    }
  }
}
