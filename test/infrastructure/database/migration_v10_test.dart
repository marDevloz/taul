import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taul/infrastructure/database/app_database.dart';

/// Creates a raw sqlite3 in-memory database with schema matching v9
/// (where `tags_color` column still exists).
Database _createV9RawDb() {
  final db = sqlite3.openInMemory();

  // Create entries table with tags_color column (as it existed after v7)
  db.execute('''
    CREATE TABLE entries (
      id TEXT NOT NULL PRIMARY KEY,
      type TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      metadata TEXT NOT NULL,
      tags TEXT NOT NULL,
      tags_color TEXT,
      secret TEXT,
      requires_auth INTEGER NOT NULL DEFAULT 0,
      encrypted_secret TEXT,
      cipher_nonce TEXT,
      cipher_tag TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      deleted_at INTEGER
    )
  ''');

  // Create tag_settings table matching actual v9 schema
  // (v8 added is_system column, v9 has no column changes)
  db.execute('''
    CREATE TABLE tag_settings (
      name TEXT NOT NULL PRIMARY KEY,
      color TEXT,
      is_secure INTEGER NOT NULL DEFAULT 0,
      is_system INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // Create master_password_config table
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

  // Set user_version to 9 so Drift triggers migration from < 10
  db.execute('PRAGMA user_version = 9');

  return db;
}

void main() {
  group('Migration v10 — drop tags_color column', () {
    test('should drop tags_color column from entries table', () async {
      final rawDb = _createV9RawDb();

      // Verify tags_color exists before migration
      final columnsBefore = rawDb.select("PRAGMA table_info('entries')");
      final hasTagsColorBefore =
          columnsBefore.any((row) => row['name'] == 'tags_color');
      expect(hasTagsColorBefore, isTrue,
          reason: 'tags_color column should exist before migration');

      // Open with AppDatabase — triggers migration from 9 to 10
      final database = AppDatabase.custom(NativeDatabase.opened(rawDb));

      // Issue a Drift query to trigger lazy initialization and migration
      await database.customSelect('SELECT 1').get();

      // Query PRAGMA table_info via rawDb to verify tags_color is gone
      final columnsAfter = rawDb.select("PRAGMA table_info('entries')");
      final columnNames =
          columnsAfter.map((row) => row['name'] as String).toList();
      expect(columnNames, isNot(contains('tags_color')),
          reason: 'tags_color column should be removed after v10 migration');

      await database.close();
    });

    test('should preserve all other columns after dropping tags_color',
        () async {
      final rawDb = _createV9RawDb();
      final database = AppDatabase.custom(NativeDatabase.opened(rawDb));

      // Trigger lazy initialization
      await database.customSelect('SELECT 1').get();

      final columnsAfter = rawDb.select("PRAGMA table_info('entries')");
      final columnNames =
          columnsAfter.map((row) => row['name'] as String).toList();

      // Core columns that must survive
      expect(columnNames, contains('id'));
      expect(columnNames, contains('type'));
      expect(columnNames, contains('title'));
      expect(columnNames, contains('content'));
      expect(columnNames, contains('metadata'));
      expect(columnNames, contains('tags'));
      expect(columnNames, contains('secret'));
      expect(columnNames, contains('requires_auth'));
      expect(columnNames, contains('encrypted_secret'));
      expect(columnNames, contains('cipher_nonce'));
      expect(columnNames, contains('cipher_tag'));
      expect(columnNames, contains('created_at'));
      expect(columnNames, contains('updated_at'));
      expect(columnNames, contains('version'));
      expect(columnNames, contains('deleted_at'));

      // Should NOT contain the dropped column
      expect(columnNames, isNot(contains('tags_color')));

      await database.close();
    });

    test('should handle v10 migration — tags_color absent', () async {
      final rawDb = _createV9RawDb();

      // Run migration: opens DB, triggers v10, drops tags_color, sets user_version to 10
      final database = AppDatabase.custom(NativeDatabase.opened(rawDb));
      await database.customSelect('SELECT 1').get();

      // Verify user_version was bumped to 10
      final version = rawDb.userVersion;
      expect(version, 11, reason: 'user_version should be 11 after v11 migration');

      // Verify column is gone
      final columnsAfter = rawDb.select("PRAGMA table_info('entries')");
      final columnNames =
          columnsAfter.map((row) => row['name'] as String).toList();
      expect(columnNames, isNot(contains('tags_color')));

      await database.close();
    });
  });
}
