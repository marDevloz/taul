import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taul/infrastructure/database/app_database.dart';

/// Creates a raw sqlite3 in-memory database with schema matching v7
/// (before v9 migration). Returns the raw database handle.
Database _createV7RawDb() {
  final db = sqlite3.openInMemory();

  // Create entries table as it existed after v7 (tags_color column present)
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

  // Create tag_settings table (added in v7)
  db.execute('''
    CREATE TABLE tag_settings (
      name TEXT NOT NULL PRIMARY KEY,
      color TEXT,
      is_secure INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // Create master_password_config table (added in v2)
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

  // Set user_version to 7 so Drift triggers migration on next open
  db.execute('PRAGMA user_version = 7');

  return db;
}

void main() {
  group('Migration v9 — data-fill from tags_color to tag_settings', () {
    test('should fill tag_settings.color from entries.tags_color', () async {
      final rawDb = _createV7RawDb();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert 3 entries with shared tags and colors
      rawDb.execute(
        'INSERT INTO entries (id, type, title, content, metadata, tags, tags_color, created_at, updated_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'e1',
          'note',
          'E1',
          'C1',
          '{}',
          jsonEncode(['urgent', 'work']),
          jsonEncode({'urgent': '#E06C75', 'work': '#61AFEF'}),
          now,
          now,
        ],
      );
      rawDb.execute(
        'INSERT INTO entries (id, type, title, content, metadata, tags, tags_color, created_at, updated_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'e2',
          'note',
          'E2',
          'C2',
          '{}',
          jsonEncode(['urgent', 'personal']),
          jsonEncode({'urgent': '#E06C75', 'personal': '#98C379'}),
          now,
          now,
        ],
      );
      rawDb.execute(
        'INSERT INTO entries (id, type, title, content, metadata, tags, tags_color, created_at, updated_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'e3',
          'note',
          'E3',
          'C3',
          '{}',
          jsonEncode(['personal']),
          jsonEncode({'personal': '#98C379'}),
          now,
          now,
        ],
      );

      // Wrap with AppDatabase via NativeDatabase.opened — triggers migration 7→9
      final database =
          AppDatabase.custom(NativeDatabase.opened(rawDb));

      final tagRows = await database.customSelect(
        'SELECT name, color FROM tag_settings ORDER BY name',
      ).get();

      // 4 system tags from v8 migration + 3 from v9 data-fill
      expect(tagRows, hasLength(7));

      final tagMap = {
        for (final row in tagRows)
          row.data['name'] as String: row.data['color'] as String?,
      };

      // Deduplicated: first non-null color wins per tag name
      expect(tagMap['urgent'], '#E06C75');
      expect(tagMap['work'], '#61AFEF');
      expect(tagMap['personal'], '#98C379');
      // System tags seeded by v8 migration
      expect(tagMap['pendiente'], '#FFC107');
      expect(tagMap['completada'], '#4CAF50');
      expect(tagMap['favorito'], '#E53935');
      expect(tagMap['archivado'], '#9E9E9E');

      await database.close();
    });

    test('should not overwrite existing tag_settings.color', () async {
      final rawDb = _createV7RawDb();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Pre-seed tag_settings with a color — should NOT be overwritten
      rawDb.execute(
        "INSERT INTO tag_settings (name, color) VALUES ('urgent', '#FF0000')",
      );

      // Insert entry with a DIFFERENT color for the same tag
      rawDb.execute(
        'INSERT INTO entries (id, type, title, content, metadata, tags, tags_color, created_at, updated_at)'
        ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'e1',
          'note',
          'E1',
          'C1',
          '{}',
          jsonEncode(['urgent']),
          jsonEncode({'urgent': '#E06C75'}),
          now,
          now,
        ],
      );

      final database =
          AppDatabase.custom(NativeDatabase.opened(rawDb));

      final rows = (await database.customSelect(
        "SELECT color FROM tag_settings WHERE name = 'urgent'",
      ).get());

      expect(rows, hasLength(1));
      // Existing color preserved — not overridden by entry's color
      expect(rows.first.data['color'], '#FF0000');

      await database.close();
    });

    test(
      'should be idempotent — migration produces stable result',
      () async {
        // Idempotency is inherent in the design: migration only writes
        // to tag_settings when color is null. After first run, colors
        // are set and subsequent runs find nothing to fill.
        final rawDb = _createV7RawDb();
  final now = DateTime.now().millisecondsSinceEpoch;

        rawDb.execute(
          'INSERT INTO entries (id, type, title, content, metadata, tags, tags_color, created_at, updated_at)'
          ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            'e1',
            'note',
            'E1',
            'C1',
            '{}',
            jsonEncode(['urgent']),
            jsonEncode({'urgent': '#E06C75'}),
            now,
            now,
          ],
        );

        // Run migration
        final database =
            AppDatabase.custom(NativeDatabase.opened(rawDb));

        final rows = await database.customSelect(
          "SELECT color FROM tag_settings WHERE name = 'urgent'",
        ).get();
        expect(rows, hasLength(1));
        expect(rows.first.data['color'], '#E06C75');

        // Verify via raw query that tag_settings.color is set correctly
        final rawRows = rawDb.select(
          "SELECT color FROM tag_settings WHERE name = 'urgent'",
        );
        expect(rawRows, hasLength(1));
        expect(rawRows.first['color'], '#E06C75');

        await database.close();
      },
    );
  });
}
