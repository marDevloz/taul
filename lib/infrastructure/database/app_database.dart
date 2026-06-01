import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/shared/tag_palette.dart';

import 'entries_table.dart';
import 'master_password_config_table.dart';
import 'tag_settings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Entries, MasterPasswordConfig, TagSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Creates an in-memory database for testing.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  /// Creates an instance with a custom executor (e.g., for migration tests).
  AppDatabase.custom(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFtsTable();
          // Seed system tags for fresh databases
          for (final entry in TagPalette.systemTagDefaults.entries) {
            await into(tagSettings).insertOnConflictUpdate(
              TagSettingsCompanion.insert(
                name: entry.key,
                color: Value(entry.value.hex),
                isSecure: const Value(false),
                isSystem: const Value(true),
              ),
            );
          }
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(entries, entries.requiresAuth);
            await m.addColumn(entries, entries.encryptedSecret);
            await m.addColumn(entries, entries.cipherNonce);
            await m.addColumn(entries, entries.cipherTag);
            await m.createTable(masterPasswordConfig);
          }
          if (from < 3) {
            await m.addColumn(
              masterPasswordConfig,
              masterPasswordConfig.passwordHint,
            );
            await m.addColumn(
              masterPasswordConfig,
              masterPasswordConfig.backupCodeHashes,
            );
            await m.addColumn(
              masterPasswordConfig,
              masterPasswordConfig.encryptedStorageKey,
            );
            await m.addColumn(
              masterPasswordConfig,
              masterPasswordConfig.encryptedStorageKeyNonce,
            );
            await m.addColumn(
              masterPasswordConfig,
              masterPasswordConfig.encryptedStorageKeyTag,
            );
          }
          if (from < 4) {
            await customInsert(
              'ALTER TABLE master_password_config ADD COLUMN backup_code_data TEXT',
            );
          }
          if (from < 5) {
            await customInsert('ALTER TABLE entries DROP COLUMN topic_key');
          }
          if (from < 6) {
            await m.addColumn(entries, entries.tagsColor);
          }
          if (from < 7) {
            // Create tag_settings table
            await m.createTable(tagSettings);

            // Copy existing per-entry tag colors into tag_settings
            final entriesRows = await select(entries).get();
            final seenTags = <String, String?>{}; // tag name → color
            for (final entry in entriesRows) {
              final tagsList =
                  List<String>.from(jsonDecode(entry.tags) as List);
              if (entry.tagsColor != null) {
                final colors = Map<String, String>.from(
                  Map<String, dynamic>.from(
                    jsonDecode(entry.tagsColor!) as Map,
                  ).map((k, v) => MapEntry(k, v as String)),
                );
                for (final tag in tagsList) {
                  if (!seenTags.containsKey(tag)) {
                    seenTags[tag] = colors[tag];
                  }
                }
              } else {
                for (final tag in tagsList) {
                  seenTags.putIfAbsent(tag, () => null);
                }
              }
            }
            // Insert into tag_settings
            for (final entry in seenTags.entries) {
              await into(tagSettings).insertOnConflictUpdate(
                TagSettingsCompanion.insert(
                  name: entry.key,
                  color: Value.absentIfNull(entry.value),
                ),
              );
            }
          }
          if (from < 8) {
            // Add completed_at column to entries
            await m.addColumn(entries, entries.completedAt);
            // Add is_system column to tag_settings
            await m.addColumn(tagSettings, tagSettings.isSystem);
            // Seed 4 system tags with reserved default colors
            for (final entry in TagPalette.systemTagDefaults.entries) {
              await into(tagSettings).insertOnConflictUpdate(
                TagSettingsCompanion.insert(
                  name: entry.key,
                  color: Value(entry.value.hex),
                  isSecure: const Value(false),
                  isSystem: const Value(true),
                ),
              );
            }
          }
        },
        beforeOpen: (_) async {
          // Crear la tabla FTS5 siempre que se abre la DB,
          // no solo en onCreate (por si la DB ya existe de antes)
          await _createFtsTable();
        },
      );

  Future<void> _createFtsTable() async {
    await customInsert(
      'CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5('
      'id UNINDEXED, title, content, tags, '
      "tokenize='unicode61')",
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File('${dbFolder.path}/${AppConstants.databaseName}');
    return NativeDatabase(file);
  });
}
