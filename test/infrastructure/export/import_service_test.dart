import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/database/app_database.dart' hide Entry;
import 'package:taul/infrastructure/database/entry_dao.dart';
import 'package:taul/infrastructure/database/entry_repository_impl.dart';
import 'package:taul/infrastructure/export/encrypted_export_service.dart';
import 'package:taul/infrastructure/export/import_service.dart';
import '../../helpers/test_auth.dart';

/// Unit tests for [ImportService.importEncryptedJson] — the encrypted restore
/// entry point used by the Settings UI. Exercises the REAL services end-to-end
/// (export -> decrypt -> import into a fresh vault).
void main() {
  late AppDatabase database;
  late EntryRepositoryImpl repository;
  late ImportService importService;
  late EncryptedExportService exportService;

  setUp(() {
    database = AppDatabase.forTesting();
    repository = EntryRepositoryImpl(dao: EntryDao(database));
    importService = ImportService(repository: repository);
    exportService = EncryptedExportService(authService: createFastAuthService());
  });

  tearDown(() {
    database.close();
  });

  Entry entry() => Entry(
        id: 'import-1',
        type: EntryType.note,
        title: 'Restaurada desde cifrado',
        content: 'Contenido que debe sobrevivir al cifrado.',
        tags: const ['restore'],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

  group('ImportService.importEncryptedJson', () {
    test('should_import_entries_when_passphrase_is_correct', () async {
      final encrypted = await exportService.exportEncrypted(
        entries: [entry()],
        passphrase: 'correct-passphrase',
      );

      final result = await importService.importEncryptedJson(
        encrypted,
        passphrase: 'correct-passphrase',
        exportService: exportService,
      );

      expect(result.imported, 1);
      expect(result.skipped, 0);
      expect(result.hasErrors, isFalse);

      final entries = await repository.list();
      expect(entries.length, 1);
      expect(entries.single.id, 'import-1');
      expect(entries.single.title, 'Restaurada desde cifrado');
      expect(entries.single.tags, ['restore']);
    });

    test('should_return_error_result_when_passphrase_is_wrong', () async {
      final encrypted = await exportService.exportEncrypted(
        entries: [entry()],
        passphrase: 'correct-passphrase',
      );

      final result = await importService.importEncryptedJson(
        encrypted,
        passphrase: 'wrong-passphrase',
        exportService: exportService,
      );

      expect(result.imported, 0);
      expect(result.skipped, 0);
      expect(result.hasErrors, isTrue);
      expect(
        result.errors.single,
        ImportService.wrongPassphraseErrorMessage,
      );

      final entries = await repository.list();
      expect(entries, isEmpty);
    });

    test('should_return_error_result_for_non_encrypted_json', () async {
      final result = await importService.importEncryptedJson(
        '{"version": 1, "entries": []}',
        passphrase: 'passphrase',
        exportService: exportService,
      );

      expect(result.imported, 0);
      expect(result.skipped, 0);
      expect(result.hasErrors, isTrue);
      expect(result.errors, isNotEmpty);

      final entries = await repository.list();
      expect(entries, isEmpty);
    });

    test('should_import_entries_when_wrong_passphrase_only_after_retry',
        () async {
      final encrypted = await exportService.exportEncrypted(
        entries: [entry()],
        passphrase: 'correct-passphrase',
      );

      final failed = await importService.importEncryptedJson(
        encrypted,
        passphrase: 'wrong-passphrase',
        exportService: exportService,
      );
      expect(failed.hasErrors, isTrue);

      final retried = await importService.importEncryptedJson(
        encrypted,
        passphrase: 'correct-passphrase',
        exportService: exportService,
      );
      expect(retried.imported, 1);

      final entries = await repository.list();
      expect(entries.length, 1);
    });
  });
}
