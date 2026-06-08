import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/export/encrypted_export_service.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';

void main() {
  late EncryptedExportService service;
  late EntryAuthService authService;

  setUp(() {
    authService = EntryAuthService();
    service = EncryptedExportService(authService: authService);
  });

  Entry _makeEntry({String id = '1', String title = 'Test', String content = 'Hello'}) {
    return Entry(
      id: id,
      type: EntryType.note,
      title: title,
      content: content,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );
  }

  group('EncryptedExportService', () {
    test('should encrypt and decrypt round-trip', () async {
      final entries = [_makeEntry()];

      final encrypted = await service.exportEncrypted(
        entries: entries,
        passphrase: 'my-secret-passphrase',
      );

      // Verify it's encrypted (not plaintext)
      expect(encrypted, contains('"encrypted": true'));
      expect(encrypted, isNot(contains('Hello')));

      // Decrypt
      final decrypted = await service.decryptExport(
        encryptedJson: encrypted,
        passphrase: 'my-secret-passphrase',
      );

      expect(decrypted, isNotNull);
      final data = jsonDecode(decrypted!) as Map<String, dynamic>;
      expect(data['entryCount'], 1);
      expect(data['entries'][0]['title'], 'Test');
    });

    test('should fail with wrong passphrase', () async {
      final entries = [_makeEntry()];

      final encrypted = await service.exportEncrypted(
        entries: entries,
        passphrase: 'correct-passphrase',
      );

      final decrypted = await service.decryptExport(
        encryptedJson: encrypted,
        passphrase: 'wrong-passphrase',
      );

      expect(decrypted, null);
    });

    test('should fail with tampered ciphertext', () async {
      final entries = [_makeEntry()];

      final encrypted = await service.exportEncrypted(
        entries: entries,
        passphrase: 'passphrase',
      );

      // Tamper with ciphertext
      final envelope = jsonDecode(encrypted) as Map<String, dynamic>;
      final cipherHex = envelope['ciphertextHex'] as String;
      envelope['ciphertextHex'] = cipherHex.substring(2) + 'ff';
      final tampered = jsonEncode(envelope);

      final decrypted = await service.decryptExport(
        encryptedJson: tampered,
        passphrase: 'passphrase',
      );

      expect(decrypted, null);
    });

    test('should handle non-encrypted input gracefully', () async {
      final result = await service.decryptExport(
        encryptedJson: '{"version": 1, "entries": []}',
        passphrase: 'passphrase',
      );

      expect(result, null);
    });

    test('should include metadata in encrypted export', () async {
      final entries = [_makeEntry()];

      final encrypted = await service.exportEncrypted(
        entries: entries,
        passphrase: 'passphrase',
      );

      final envelope = jsonDecode(encrypted) as Map<String, dynamic>;
      expect(envelope['version'], 1);
      expect(envelope['encrypted'], true);
      expect(envelope['saltHex'], isA<String>());
      expect(envelope['nonceHex'], isA<String>());
      expect(envelope['tagHex'], isA<String>());
      expect(envelope['ciphertextHex'], isA<String>());
    });
  });
}
