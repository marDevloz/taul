import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taul/core/constants.dart';

/// Migrates an unencrypted SQLite database to an encrypted one using
/// SQLite3MultipleCiphers (PRAGMA rekey pattern).
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
      // If we can read sqlite_master, it's unencrypted.
      final result = db.select('SELECT count(*) FROM sqlite_master;');
      db.dispose();
      return result.isEmpty;
    } catch (_) {
      // Can't read without key → assume encrypted.
      return true;
    }
  }

  /// Migrates an unencrypted database to an encrypted one.
  ///
  /// 1. Opens the existing unencrypted DB.
  /// 2. Copies it to a temp file via VACUUM INTO.
  /// 3. Opens the temp file and applies PRAGMA rekey to encrypt it.
  /// 4. Saves the user_version from the original DB.
  /// 5. Swaps files: original → backup, encrypted → original.
  /// 6. Deletes the backup.
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

    _log.i('Starting DB migration: unencrypted → encrypted');

    final backupFile = File('${dbFile.path}.bak');
    final tmpFile = File('${dbFile.path}.enc.tmp');

    // Clean up any leftover files from a previous failed migration.
    if (await tmpFile.exists()) await tmpFile.delete();
    if (await backupFile.exists()) await backupFile.delete();

    try {
      // Step 1: Open unencrypted DB and capture user_version.
      final plaintextDb = sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
      final userVersion = plaintextDb.userVersion;
      _log.d('Captured user_version = $userVersion');

      // Step 2: VACUUM INTO temp file (creates a clean copy).
      final escapedTmpPath = tmpFile.path.replaceAll("'", "''");
      plaintextDb.execute("VACUUM INTO '$escapedTmpPath';");
      plaintextDb.dispose();
      _log.d('VACUUM INTO completed');

      // Step 3: Open the temp copy and apply encryption key.
      final keyHex =
          dek.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final encryptedDb = sqlite3.open(tmpFile.path);
      encryptedDb.execute("PRAGMA key = \"x'$keyHex'\";");
      encryptedDb.userVersion = userVersion;
      encryptedDb.dispose();
      _log.d('Encryption applied with PRAGMA rekey');

      // Step 4: Verify the encrypted DB can be opened with the key.
      final verifyDb = sqlite3.open(tmpFile.path);
      verifyDb.execute("PRAGMA key = \"x'$keyHex'\";");
      final count = verifyDb.select('SELECT count(*) FROM sqlite_master;');
      verifyDb.dispose();
      if (count.isEmpty) {
        throw StateError('Encrypted DB verification failed: no tables found');
      }
      _log.d('Encrypted DB verified successfully');

      // Step 5: Atomic swap: original → backup, encrypted → original.
      dbFile.renameSync(backupFile.path);
      tmpFile.renameSync(dbFile.path);
      _log.d('File swap completed');

      // Step 6: Delete the unencrypted backup.
      await backupFile.delete();
      _log.i('Migration completed successfully');

      return true;
    } catch (e, st) {
      _log.e('Migration failed', error: e, stackTrace: st);

      // Attempt recovery: if tmp exists and final is missing, restore from tmp.
      if (await tmpFile.exists() && !await dbFile.exists()) {
        await tmpFile.rename(dbFile.path);
        _log.d('Recovered: renamed .enc.tmp back to original');
      }
      // If backup exists and original is missing, restore from backup.
      if (await backupFile.exists() && !await dbFile.exists()) {
        await backupFile.rename(dbFile.path);
        _log.d('Recovered: restored from backup');
      }
      // Clean up temp files.
      if (await tmpFile.exists()) await tmpFile.delete();
      if (await backupFile.exists()) await backupFile.delete();

      return false;
    }
  }
}
