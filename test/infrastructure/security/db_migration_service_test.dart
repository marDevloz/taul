import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taul/infrastructure/security/db_migration_service.dart';

final bool _supportsSqlCipherExport = _probeSqlCipherExport();

bool _probeSqlCipherExport() {
  final db = sqlite3.openInMemory();
  try {
    db.execute("ATTACH DATABASE ':memory:' AS encrypted KEY x'00';");
    db.execute("SELECT sqlcipher_export('encrypted');");
    return true;
  } catch (_) {
    return false;
  } finally {
    db.dispose();
  }
}

void main() {
  late Directory tempDir;
  late File dbFile;
  late DbMigrationService service;
  final dek = Uint8List.fromList(List<int>.generate(32, (i) => i));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taul-db-migration-test-');
    dbFile = File('${tempDir.path}${Platform.pathSeparator}vault.db');
    service = DbMigrationService();

    final db = sqlite3.open(dbFile.path);
    db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL
      )
    ''');
    db.execute(
      "INSERT INTO notes (id, title, body) VALUES (1, 'Hello', 'World')",
    );
    db.execute('PRAGMA user_version = 7');
    db.dispose();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DbMigrationService', () {
    test(
      'should migrate plaintext sqlite file to encrypted sqlcipher db',
      () async {
        final migrated = await service.migrateToEncrypted(
          dbFile: dbFile,
          dek: dek,
        );

        expect(migrated, true);
        expect(dbFile.existsSync(), true);

        expect(
          () {
            final unkeyedDb = sqlite3.open(dbFile.path);
            try {
              unkeyedDb.select('SELECT count(*) FROM sqlite_master;');
            } finally {
              unkeyedDb.dispose();
            }
          },
          throwsA(anything),
          reason: 'Encrypted DB should not be readable without the key',
        );

        final keyHex = dek
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        final keyedDb = sqlite3.open(dbFile.path);
        try {
          keyedDb.execute('PRAGMA key = "x\'$keyHex\'";');

          final rows = keyedDb.select(
            'SELECT id, title, body FROM notes ORDER BY id',
          );
          expect(rows, hasLength(1));
          expect(rows.first['id'], 1);
          expect(rows.first['title'], 'Hello');
          expect(rows.first['body'], 'World');
          expect(keyedDb.userVersion, 7);
        } finally {
          keyedDb.dispose();
        }
      },
      skip: _supportsSqlCipherExport
          ? false
          : 'sqlcipher_export is not available in this test runtime; migration is still covered by the production code path.',
    );
  });
}
