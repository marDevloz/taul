import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taul/infrastructure/database/app_database.dart';

Database _createV10RawDb() {
  final db = sqlite3.openInMemory();

  db.execute('''
    CREATE TABLE entries (
      id TEXT NOT NULL PRIMARY KEY,
      type TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      metadata TEXT NOT NULL,
      tags TEXT NOT NULL,
      secret TEXT,
      requires_auth INTEGER NOT NULL DEFAULT 0,
      encrypted_secret TEXT,
      cipher_nonce TEXT,
      cipher_tag TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      deleted_at INTEGER,
      completed_at INTEGER
    )
  ''');

  db.execute('''
    CREATE TABLE tag_settings (
      name TEXT NOT NULL PRIMARY KEY,
      color TEXT,
      is_secure INTEGER NOT NULL DEFAULT 0,
      is_system INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT 0
    )
  ''');

  db.execute('''
    CREATE TABLE master_password_config (
      id INTEGER NOT NULL PRIMARY KEY,
      password_hash_argon2 TEXT NOT NULL,
      salt_hex TEXT NOT NULL,
      password_hint TEXT,
      backup_code_hashes TEXT,
      backup_code_data TEXT,
      encrypted_storage_key TEXT,
      encrypted_storage_key_nonce TEXT,
      encrypted_storage_key_tag TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  db.execute('PRAGMA user_version = 10');
  return db;
}

void main() {
  group('Migration v11 — create conflicts table', () {
    test('should create conflicts table with correct schema', () async {
      final rawDb = _createV10RawDb();

      // Verify conflicts table does NOT exist before migration
      final tablesBefore = rawDb.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='conflicts'",
      );
      expect(tablesBefore, isEmpty,
          reason: 'conflicts table should not exist before migration');

      // Open with AppDatabase — triggers migration from 10 to 11
      final database = AppDatabase.custom(NativeDatabase.opened(rawDb));
      await database.customSelect('SELECT 1').get();

      // Verify conflicts table exists
      final tablesAfter = rawDb.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='conflicts'",
      );
      expect(tablesAfter.length, 1,
          reason: 'conflicts table should exist after migration');

      // Verify columns
      final columns = rawDb.select("PRAGMA table_info('conflicts')");
      final columnNames = columns.map((row) => row['name'] as String).toList();
      expect(columnNames, contains('id'));
      expect(columnNames, contains('entry_id'));
      expect(columnNames, contains('local_version'));
      expect(columnNames, contains('remote_version'));
      expect(columnNames, contains('resolution'));
      expect(columnNames, contains('peer_device_id'));
      expect(columnNames, contains('created_at'));
      expect(columnNames, contains('resolved_at'));

      // Verify indexes
      final indexes = rawDb.select(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='conflicts'",
      );
      final indexNames = indexes.map((row) => row['name'] as String).toList();
      expect(indexNames, isNot(contains('idx_conflicts_entry_id')),
          reason: 'Drift creates indexes with auto-generated names');

      await database.close();
    });

    test('should bump user_version to 11', () async {
      final rawDb = _createV10RawDb();
      final database = AppDatabase.custom(NativeDatabase.opened(rawDb));
      await database.customSelect('SELECT 1').get();

      final version = rawDb.userVersion;
      expect(version, 11,
          reason: 'user_version should be 11 after v11 migration');

      await database.close();
    });

    test('should preserve existing tables after migration', () async {
      final rawDb = _createV10RawDb();
      final database = AppDatabase.custom(NativeDatabase.opened(rawDb));
      await database.customSelect('SELECT 1').get();

      // Verify existing tables still exist
      final tables = rawDb.select(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final tableNames = tables.map((row) => row['name'] as String).toList();
      expect(tableNames, contains('entries'));
      expect(tableNames, contains('tag_settings'));
      expect(tableNames, contains('master_password_config'));
      expect(tableNames, contains('conflicts'));

      await database.close();
    });
  });
}