import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/database/entry_repository_impl.dart';
import 'package:taul/infrastructure/export/encrypted_export_service.dart';
import 'package:taul/infrastructure/export/import_service.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';

/// Smoke test of the most critical data-safety flow — export an encrypted
/// backup, then restore it into a fresh vault.
///
/// Exercises the REAL services end-to-end (no mocks):
/// - [EncryptedExportService] for export + `readAndDecrypt` from a real file.
/// - [ImportService] for restore into a brand-new SQLite vault.
/// - Verifies every entry type survives with its content intact.
void main() {
  const passphrase = 'smoke-test-passphrase';
  const credentialSecret = r'router-admin:pa$@2026';

  late AppDatabase sourceDb;
  late AppDatabase freshDb;
  late EntryRepositoryImpl sourceRepository;
  late EntryRepositoryImpl freshRepository;
  late EncryptedExportService exportService;
  late ImportService importService;

  setUp(() {
    sourceDb = AppDatabase.forTesting();
    freshDb = AppDatabase.forTesting();
    sourceRepository = EntryRepositoryImpl(dao: EntryDao(sourceDb));
    freshRepository = EntryRepositoryImpl(dao: EntryDao(freshDb));
    exportService = EncryptedExportService(authService: EntryAuthService());
    importService = ImportService(repository: freshRepository);
  });

  tearDown(() {
    sourceDb.close();
    freshDb.close();
  });

  List<Entry> sampleEntries() {
    return [
      Entry(
        id: 'note-1',
        type: EntryType.note,
        title: 'Meeting notes',
        content: 'Discutir el roadmap del Q3 con el equipo de Taúl.',
        tags: const ['work', 'meeting'],
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 3),
      ),
      Entry(
        id: 'idea-1',
        type: EntryType.idea,
        title: 'Idea: offline sync',
        content: 'Sincronizar vaults por red local con pairing TLS.',
        metadata: const {'phase': 'prototype', 'priority': 'high'},
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 2),
      ),
      Entry(
        id: 'glossary-1',
        type: EntryType.glossary,
        title: 'Argon2id',
        content: 'Función de derivación de clave usada por la master passphrase.',
        tags: const ['security'],
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 2),
      ),
      Entry(
        id: 'credential-1',
        type: EntryType.credential,
        title: 'Wi-Fi router',
        content: 'Consola de administración del router del hogar',
        secret: credentialSecret,
        requiresAuth: true,
        metadata: const {'username': 'admin'},
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 2),
      ),
    ];
  }

  group('backup export -> import -> restore smoke test', () {
    test('should_restore_all_entry_types_with_content_intact', () async {
      final entries = sampleEntries();
      for (final entry in entries) {
        await sourceRepository.create(entry);
      }

      // 1. Export an encrypted backup with the real service.
      final encrypted = await exportService.exportEncrypted(
        entries: entries,
        passphrase: passphrase,
      );

      // The backup is genuinely encrypted: no plaintext content leaks.
      expect(encrypted, contains('"encrypted": true'));
      expect(encrypted, isNot(contains('Meeting notes')));
      expect(encrypted, isNot(contains(credentialSecret)));

      // 2. Persist it as a real file on disk (mirrors saveEncryptedToFile).
      final tempDir = await Directory.systemTemp.createTemp('taul-smoke-');
      addTearDown(() => tempDir.delete(recursive: true));
      final backupFile = File(
        '${tempDir.path}${Platform.pathSeparator}backup.json',
      );
      await backupFile.writeAsString(encrypted);

      // 3. Restore: decrypt the backup file, then import into a FRESH vault.
      final decrypted = await exportService.readAndDecrypt(
        filePath: backupFile.path,
        passphrase: passphrase,
      );
      expect(decrypted, isNotNull);

      // The backup carries an export timestamp and entry count that survive
      // encryption/decryption untouched.
      final backupJson = jsonDecode(decrypted!) as Map<String, dynamic>;
      expect(backupJson['entryCount'], 4);
      final exportedAt = DateTime.tryParse(backupJson['exportedAt'] as String);
      expect(exportedAt, isNotNull);
      expect(
        DateTime.now().toUtc().difference(exportedAt!.toUtc()).inSeconds.abs(),
        lessThan(60),
      );

      final result = await importService.importFromJsonString(decrypted);
      expect(result.imported, 4);
      expect(result.skipped, 0);
      expect(result.hasErrors, isFalse);

      // 4. Verify every entry survived with its content intact.
      final restored = await freshRepository.list();
      expect(restored.length, 4);
      final byId = {for (final entry in restored) entry.id: entry};

      final note = byId['note-1']!;
      expect(note.type, EntryType.note);
      expect(note.title, 'Meeting notes');
      expect(note.content, 'Discutir el roadmap del Q3 con el equipo de Taúl.');
      expect(note.tags, ['work', 'meeting']);
      expect(note.createdAt, DateTime(2026, 1, 2));
      expect(note.updatedAt, DateTime(2026, 1, 3));

      final idea = byId['idea-1']!;
      expect(idea.type, EntryType.idea);
      expect(idea.metadata, {'phase': 'prototype', 'priority': 'high'});

      final glossary = byId['glossary-1']!;
      expect(glossary.type, EntryType.glossary);
      expect(
        glossary.content,
        'Función de derivación de clave usada por la master passphrase.',
      );
      expect(glossary.tags, ['security']);

      final credential = byId['credential-1']!;
      expect(credential.type, EntryType.credential);
      expect(credential.content, 'Consola de administración del router del hogar');
      expect(credential.secret, credentialSecret);
      expect(credential.requiresAuth, isTrue);
      expect(credential.metadata, {'username': 'admin'});
    });

    test(
      'should_skip_duplicates_when_restoring_into_vault_that_already_has_them',
      () async {
        final entries = sampleEntries();
        for (final entry in entries) {
          await sourceRepository.create(entry);
        }
        final encrypted = await exportService.exportEncrypted(
          entries: entries,
          passphrase: passphrase,
        );
        final decrypted = (await exportService.decryptExport(
          encryptedJson: encrypted,
          passphrase: passphrase,
        ))!;

        final first = await importService.importFromJsonString(decrypted);
        expect(first.imported, 4);
        expect(first.skipped, 0);

        final second = await importService.importFromJsonString(decrypted);
        expect(second.imported, 0);
        expect(second.skipped, 4);
        expect(second.hasErrors, isFalse);

        final restored = await freshRepository.list();
        expect(restored.length, 4);
      },
    );
  });
}