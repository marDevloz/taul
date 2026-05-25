import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taul/core/constants.dart';

import 'entries_table.dart';
import 'master_password_config_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Entries, MasterPasswordConfig])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Creates an in-memory database for testing.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  /// Creates an instance with a custom executor (e.g., for migration tests).
  AppDatabase.custom(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFtsTable();
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
