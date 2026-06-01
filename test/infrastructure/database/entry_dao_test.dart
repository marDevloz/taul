import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';

void main() {
  late AppDatabase database;
  late EntryDao dao;

  setUp(() {
    database = AppDatabase.forTesting();
    dao = EntryDao(database);
  });

  tearDown(() {
    database.close();
  });

  group('EntryDao tagsColors round-trip', () {
    test('should round-trip tagsColors with 3 entries', () async {
      final tagsColors = <String, String>{
        'urgent': '#E06C75',
        'work': '#61AFEF',
        'personal': '#98C379',
      };

      final entry = Entry(
        id: 'test-id-1',
        type: EntryType.note,
        title: 'Test tagsColors',
        content: 'Content with colored tags',
        tags: ['urgent', 'work', 'personal'],
        tagsColors: tagsColors,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);
      final retrieved = await dao.get('test-id-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.tagsColors, tagsColors);
    });

    test('should store null in DB when tagsColors is empty', () async {
      final entry = Entry(
        id: 'test-id-2',
        type: EntryType.note,
        title: 'Empty tagsColors',
        content: 'Content without tag colors',
        tags: ['general'],
        tagsColors: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);

      // Verify via raw query that tags_color is NULL in the database
      final rows = await database.customSelect(
        'SELECT tags_color FROM entries WHERE id = ?',
        variables: [Variable.withString('test-id-2')],
      ).get();

      expect(rows, hasLength(1));
      expect(rows.first.data['tags_color'], isNull);
    });

    test('should return empty map when tags_color is NULL (legacy)', () async {
      // Insert a row with a raw INSERT that sets tags_color to NULL.
      // DateTime columns must use Unix timestamps (seconds since epoch) for
      // Drift's default type mapping.
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await database.customInsert(
        'INSERT INTO entries (id, type, title, content, metadata, tags, '
        'tags_color, secret, requires_auth, created_at, updated_at, version) '
        'VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?, ?, ?)',
        variables: [
          Variable.withString('legacy-id'),
          Variable.withString('note'),
          Variable.withString('Legacy Entry'),
          Variable.withString('This entry has no tags_color'),
          Variable.withString('{}'),
          Variable.withString('["old"]'),
          Variable.withInt(0),
          Variable.withInt(now),
          Variable.withInt(now),
          Variable.withInt(1),
        ],
      );

      final retrieved = await dao.get('legacy-id');

      expect(retrieved, isNotNull);
      expect(retrieved!.tagsColors, isEmpty);
    });

    test('should handle insert-update-read cycle for tagsColors', () async {
      final initialColors = <String, String>{
        'tag1': '#C678DD',
      };

      final entry = Entry(
        id: 'test-id-3',
        type: EntryType.note,
        title: 'Update tagsColors',
        content: 'Testing tagsColors update',
        tags: ['tag1'],
        tagsColors: initialColors,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);

      // Update with additional colors
      final updatedColors = <String, String>{
        'tag1': '#C678DD',
        'tag2': '#D19A66',
      };
      final updated = entry.copyWith(
        tagsColors: updatedColors,
        updatedAt: DateTime.now(),
      );

      await dao.update(updated);
      final retrieved = await dao.get('test-id-3');

      expect(retrieved, isNotNull);
      expect(retrieved!.tagsColors, updatedColors);
    });
  });

  group('EntryDao completedAt', () {
    test('should persist completedAt as null for new entry', () async {
      final entry = Entry(
        id: 'task-1',
        type: EntryType.task,
        title: 'New task',
        content: 'Task content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);
      final retrieved = await dao.get('task-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.completedAt, isNull);
    });

    test('should round-trip completedAt when set', () async {
      final completedTime = DateTime(2026, 5, 31, 12, 0, 0);
      final entry = Entry(
        id: 'task-2',
        type: EntryType.task,
        title: 'Completed task',
        content: 'Done',
        completedAt: completedTime,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);
      final retrieved = await dao.get('task-2');

      expect(retrieved, isNotNull);
      expect(retrieved!.completedAt, completedTime);
    });

    test('should persist completedAt after update', () async {
      final entry = Entry(
        id: 'task-3',
        type: EntryType.task,
        title: 'Task to complete',
        content: 'Pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insert(entry);

      final completedTime = DateTime(2026, 5, 31, 14, 30, 0);
      final updated = entry.copyWith(
        completedAt: completedTime,
        updatedAt: DateTime.now(),
      );
      await dao.update(updated);

      final retrieved = await dao.get('task-3');
      expect(retrieved!.completedAt, completedTime);
    });
  });

  group('EntryDao excludeArchived', () {
    test('should include all entries when excludeArchived is false', () async {
      // Insert entries with and without archivado tag
      await dao.insert(Entry(
        id: 'entry-1',
        type: EntryType.note,
        title: 'Normal entry',
        content: 'Content',
        tags: ['work'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await dao.insert(Entry(
        id: 'entry-2',
        type: EntryType.note,
        title: 'Archived entry',
        content: 'Content',
        tags: ['archivado'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final entries = await dao.list(excludeArchived: false);
      expect(entries, hasLength(2));
    });

    test('should exclude entries with archivado tag when excludeArchived is true', () async {
      await dao.insert(Entry(
        id: 'entry-3',
        type: EntryType.note,
        title: 'Normal entry',
        content: 'Content',
        tags: ['work'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await dao.insert(Entry(
        id: 'entry-4',
        type: EntryType.note,
        title: 'Archived entry',
        content: 'Content',
        tags: ['archivado'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final entries = await dao.list(excludeArchived: true);
      expect(entries, hasLength(1));
      expect(entries.first.id, 'entry-3');
    });

    test('should exclude entries with archivado among multiple tags', () async {
      await dao.insert(Entry(
        id: 'entry-5',
        type: EntryType.note,
        title: 'Multi-tag archived',
        content: 'Content',
        tags: ['work', 'archivado', 'urgent'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await dao.insert(Entry(
        id: 'entry-6',
        type: EntryType.note,
        title: 'Not archived',
        content: 'Content',
        tags: ['work', 'urgent'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final entries = await dao.list(excludeArchived: true);
      expect(entries, hasLength(1));
      expect(entries.first.id, 'entry-6');
    });
  });

  group('Migration 7→8', () {
    test('should have completed_at column in entries table', () async {
      final columns = await database.customSelect(
        "PRAGMA table_info(entries)",
      ).get();
      final columnNames = columns.map((c) => c.data['name'] as String).toList();
      expect(columnNames, contains('completed_at'));
    });

    test('should have is_system column in tag_settings table', () async {
      final columns = await database.customSelect(
        "PRAGMA table_info(tag_settings)",
      ).get();
      final columnNames = columns.map((c) => c.data['name'] as String).toList();
      expect(columnNames, contains('is_system'));
    });

    test('should seed 4 system tags on database creation', () async {
      final tags = await database.select(database.tagSettings).get();
      final systemTags = tags.where((t) => t.isSystem).toList();
      expect(systemTags, hasLength(4));

      final names = systemTags.map((t) => t.name).toSet();
      expect(names, containsAll(['pendiente', 'completada', 'favorito', 'archivado']));
    });

    test('should set isSystem true for system tags', () async {
      final pendiente = await (database.select(database.tagSettings)
            ..where((t) => t.name.equals('pendiente')))
          .getSingleOrNull();
      expect(pendiente, isNotNull);
      expect(pendiente!.isSystem, true);
    });

    test('should set isSystem false for user-created tags', () async {
      // Insert a user tag via DAO
      await database.into(database.tagSettings).insert(
        TagSettingsCompanion.insert(
          name: 'mytag',
          color: const Value('#FF0000'),
        ),
      );

      final mytag = await (database.select(database.tagSettings)
            ..where((t) => t.name.equals('mytag')))
          .getSingleOrNull();
      expect(mytag, isNotNull);
      expect(mytag!.isSystem, false);
    });
  });

  group('Migration 7→8 (simulated upgrade)', () {
    test('should migrate from v7 to v8 adding columns and seeding system tags', () async {
      // Create a temp database file for the v7 simulation
      final tempDir = Directory.systemTemp.createTempSync('taul_test_');
      try {
        final dbPath = '${tempDir.path}/v7_test.db';

        // Use raw sqlite3 to create a v7 database (without v8 columns)
        final rawDb = sqlite3.open(dbPath);

        try {
          // Create entries table (v7: NO completed_at column)
          rawDb.execute('''
            CREATE TABLE entries (
              id TEXT NOT NULL PRIMARY KEY,
              type TEXT NOT NULL,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              metadata TEXT NOT NULL DEFAULT '{}',
              tags TEXT NOT NULL DEFAULT '[]',
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
          // Create tag_settings table (v7: NO is_system column)
          // DEFAULT (strftime('%s', 'now')) is required because Drift's migration
          // seeds system tags via insertOnConflictUpdate without providing
          // created_at, relying on the SQL-level default. We use strftime to
          // produce an integer-compatible value matching Drift's integer storage
          // for DateTime columns.
          rawDb.execute('''
            CREATE TABLE tag_settings (
              name TEXT NOT NULL PRIMARY KEY,
              color TEXT,
              is_secure INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
            )
          ''');
          // Create master_password_config table (unchanged in v8)
          rawDb.execute('''
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
          // Insert v7 test data to verify data survives migration
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          rawDb.execute(
            'INSERT INTO entries (id, type, title, content, metadata, tags, created_at, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            ['v7-entry-1', 'note', 'Pre-migration entry', 'v7 content',
             '{}', '[]', now, now],
          );
          rawDb.execute(
            'INSERT INTO tag_settings (name, color, is_secure, created_at) '
            'VALUES (?, ?, ?, ?)',
            ['legacy-tag', '#FF0000', 0, now],
          );
          // Set PRAGMA user_version to 7 so Drift detects old schema
          rawDb.execute('PRAGMA user_version = 7');
        } finally {
          rawDb.dispose();
        }

        // Open with AppDatabase (schema 8) — triggers migration from 7 to 8
        final migratedDb = AppDatabase.custom(NativeDatabase(File(dbPath)));
        try {
          // Trigger initialization by running a query
          await migratedDb.customSelect('SELECT 1').get();

          // Verify completed_at column was added to entries
          final entryColumns = await migratedDb.customSelect(
            "PRAGMA table_info(entries)",
          ).get();
          final entryNames =
              entryColumns.map((c) => c.data['name'] as String).toList();
          expect(entryNames, contains('completed_at'));

          // Verify is_system column was added to tag_settings
          final tagColumns = await migratedDb.customSelect(
            "PRAGMA table_info(tag_settings)",
          ).get();
          final tagNames =
              tagColumns.map((c) => c.data['name'] as String).toList();
          expect(tagNames, contains('is_system'));

          // Verify pre-migration data survived
          final entries = await migratedDb.customSelect(
            "SELECT id, title FROM entries WHERE id = 'v7-entry-1'",
          ).get();
          expect(entries, hasLength(1));
          expect(entries.first.data['title'], 'Pre-migration entry');

          // Verify 4 system tags were seeded during migration
          final tags = await migratedDb.select(migratedDb.tagSettings).get();
          final systemTags = tags.where((t) => t.isSystem).toList();
          expect(systemTags, hasLength(4));

          final systemNames = systemTags.map((t) => t.name).toSet();
          expect(systemNames, containsAll(
            ['pendiente', 'completada', 'favorito', 'archivado'],
          ));
        } finally {
          await migratedDb.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should_preserve_legacy_tag_isSecure_when_migrating_from_v7', () async {
      final tempDir = Directory.systemTemp.createTempSync('taul_test_');
      try {
        final dbPath = '${tempDir.path}/v7_secure_test.db';
        final rawDb = sqlite3.open(dbPath);

        try {
          rawDb.execute('''
            CREATE TABLE entries (
              id TEXT NOT NULL PRIMARY KEY,
              type TEXT NOT NULL,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              metadata TEXT NOT NULL DEFAULT '{}',
              tags TEXT NOT NULL DEFAULT '[]',
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
          rawDb.execute('''
            CREATE TABLE tag_settings (
              name TEXT NOT NULL PRIMARY KEY,
              color TEXT,
              is_secure INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
            )
          ''');
          rawDb.execute('''
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
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          // Insert a secure legacy tag
          rawDb.execute(
            'INSERT INTO tag_settings (name, color, is_secure, created_at) '
            'VALUES (?, ?, ?, ?)',
            ['secure-tag', '#E53935', 1, now],
          );
          rawDb.execute('PRAGMA user_version = 7');
        } finally {
          rawDb.dispose();
        }

        final migratedDb = AppDatabase.custom(NativeDatabase(File(dbPath)));
        try {
          await migratedDb.customSelect('SELECT 1').get();

          // Verify legacy data survived with is_secure intact
          final rows = await migratedDb.customSelect(
            "SELECT name, is_secure FROM tag_settings WHERE name = 'secure-tag'",
          ).get();
          expect(rows, hasLength(1));
          // sqlite3 returns integers for boolean columns
          expect(rows.first.data['is_secure'], equals(1));
        } finally {
          await migratedDb.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
