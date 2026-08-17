import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:taul/core/constants.dart';
import 'package:taul/shared/tag_palette.dart';
import 'package:logger/logger.dart';

import 'conflicts_table.dart';
import 'entries_table.dart';
import 'master_password_config_table.dart';
import 'tag_settings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Entries, MasterPasswordConfig, TagSettings, Conflicts])
class AppDatabase extends _$AppDatabase {
  AppDatabase({Uint8List? dek}) : super(_openConnection(dek: dek));

  /// Creates an in-memory database for testing.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  /// Creates an instance with a custom executor (e.g., for migration tests).
  AppDatabase.custom(super.executor);

  @override
  int get schemaVersion => 11;

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
            await customInsert(
              'ALTER TABLE entries ADD COLUMN tags_color TEXT',
            );
          }
          if (from < 7) {
            // Create tag_settings table
            await m.createTable(tagSettings);

            // Copy existing per-entry tag colors into tag_settings.
            // Use raw SQL because tags_color column is dropped at v10 and no
            // longer present in the Drift table definition.
            final entryRows = await customSelect(
              'SELECT id, tags, tags_color FROM entries',
            ).get();
            final seenTags = <String, String?>{}; // tag name → color
            for (final row in entryRows) {
              final tagsRaw = row.read<String>('tags');
              final tagsList =
                  List<String>.from(jsonDecode(tagsRaw) as List);
              final tagsColorRaw = row.read<String?>('tags_color');
              if (tagsColorRaw != null) {
                final colors = Map<String, String>.from(
                  Map<String, dynamic>.from(
                    jsonDecode(tagsColorRaw) as Map,
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
          if (from < 9) {
            // Data-fill: migrate colors from entries.tags_color to tag_settings.
            // Only fills where tag_settings.color is null — idempotent.
            // Use raw SQL because tags_color column is dropped at v10 and no
            // longer present in the Drift table definition.
            final entryRows = await customSelect(
              'SELECT id, tags, tags_color FROM entries',
            ).get();
            final seen = <String, String?>{};
            for (final row in entryRows) {
              final tagsColorRaw = row.read<String?>('tags_color');
              if (tagsColorRaw == null) continue;
              final colors = Map<String, String>.from(
                Map<String, dynamic>.from(
                  jsonDecode(tagsColorRaw) as Map,
                ).map((k, v) => MapEntry(k, v as String)),
              );
              for (final tagName in colors.keys) {
                seen.putIfAbsent(tagName, () => colors[tagName]);
              }
            }
            for (final entry in seen.entries) {
              if (entry.value == null) continue;
              final existing = await (select(tagSettings)
                ..where((t) => t.name.equals(entry.key)))
                .getSingleOrNull();
              if (existing == null || existing.color == null) {
                await into(tagSettings).insertOnConflictUpdate(
                  TagSettingsCompanion.insert(
                    name: entry.key,
                    color: Value(entry.value!),
                  ),
                );
              }
            }
          }
          if (from < 10) {
            await m.dropColumn(entries, 'tags_color');
          }
          if (from < 11) {
            await m.createTable(conflicts);
          }
        },
        beforeOpen: (_) async {
          // Crear la tabla FTS5 siempre que se abre la DB,
          // no solo en onCreate (por si la DB ya existe de antes)
          await _createFtsTable();
        },
      );

  Future<void> _createFtsTable() async {
    try {
      await customInsert(
        'CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5('
        'id UNINDEXED, title, content, tags, '
        "tokenize='unicode61')",
      );
    } catch (e) {
      // FTS5 may not be available (e.g., on Android system SQLite).
      // The app continues to work — full-text search is simply unavailable.
    }
  }
}

QueryExecutor _openConnection({Uint8List? dek}) {
  final log = Logger(printer: PrettyPrinter(methodCount: 0));
  log.i('[DB] _openConnection — dek=${dek != null ? '${dek.length} bytes' : 'null'}');

  // Android: use sqflite (system SQLite, no SQLCipher yet)
  if (Platform.isAndroid) {
    log.i('[DB] _openConnection — Android path (sqflite, no SQLCipher)');
    return SqfliteQueryExecutor.inDatabaseFolder(
      path: AppConstants.databaseName,
      logStatements: false,
    );
  }

  // Desktop: use NativeDatabase with sqlite3mc (SQLCipher via PRAGMA key)
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File('${dbFolder.path}/${AppConstants.databaseName}');

    // When no DEK is provided but an encrypted DB exists on disk, opening it
    // without PRAGMA key triggers SqliteException(26).  Return an empty
    // in-memory database so the app can still read the schema (lock-screen
    // config check) without crashing.  Once the user authenticates and the DEK
    // is supplied, databaseProvider rebuilds with the real key.
    if (dek == null && file.existsSync()) {
      final header = file.openSync(mode: FileMode.read);
      try {
        final magic = header.readSync(16);
        // SQLite files always start with "SQLite format 3\000" (16 bytes).
        const sqliteHeader = [0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66,
          0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00];
        final isPlaintext = magic.length == 16 &&
            !List.generate(16, (i) => magic[i] != sqliteHeader[i]).any((e) => e);
        if (!isPlaintext) {
          debugPrint('[DB] _openConnection — encrypted file on disk but no DEK '
              'provided; returning in-memory DB to avoid SqliteException(26)');
          return NativeDatabase.memory();
        }
      } finally {
        header.close();
      }
    }

    if (dek != null) {
      _migratePlaintextToEncrypted(file, dek);
    }
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // NOTE: runs in background isolate — Logger is NOT sendable.
        // Use debugPrint only.
        debugPrint('[DB] _openConnection — setup: dek=${dek != null ? '${dek.length} bytes' : 'null'}');
        if (dek != null) {
          try {
            final hasCipher = _debugCheckHasCipher(rawDb);
            if (!hasCipher) {
              throw StateError(
                'SQLCipher is not available in this build: the sqlite3mc build '
                'hook did not produce an encrypted-capable library. '
                'Run flutter pub get && flutter build windows to regenerate assets.',
              );
            }
            final keyHex = _dekToHex(dek);
            rawDb.execute("PRAGMA key = \"x'$keyHex'\";");
            debugPrint('[DB] _openConnection — PRAGMA key OK');
          } catch (e) {
            debugPrint('[DB] _openConnection — PRAGMA key FAILED: $e');
            if (e is StateError) rethrow;
            throw StateError('Failed to configure SQLCipher key: $e');
          }
        } else {
          debugPrint('[DB] _openConnection — NO DEK! Opening unencrypted file.');
        }
      },
    );
  });
}

/// Cifra la DB en texto plano in-place. No-op si ya está cifrada o no existe.
void _migratePlaintextToEncrypted(File file, Uint8List dek) {
  if (!file.existsSync() || file.lengthSync() == 0) return;
  final header = _readDbHeader(file);
  // "SQLite format 3\0" → texto plano
  if (!header.startsWith('SQLite format 3')) return; // ya cifrada
  final keyHex = _dekToHex(dek);
  final db = sqlite3.open(file.path);
  try {
    db.execute("PRAGMA rekey = \"x'$keyHex'\";");
  } finally {
    db.close();
  }
}

String _dekToHex(Uint8List dek) =>
    dek.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String _readDbHeader(File file) {
  final raf = file.openSync(mode: FileMode.read);
  try {
    final bytes = raf.readSync(16);
    return String.fromCharCodes(bytes);
  } finally {
    raf.closeSync();
  }
}

bool _debugCheckHasCipher(Database database) {
  try {
    return database.select('PRAGMA cipher;').isNotEmpty;
  } catch (_) {
    return false;
  }
}
