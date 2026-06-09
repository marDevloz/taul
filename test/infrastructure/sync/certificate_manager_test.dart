import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/sync/certificate_manager.dart';

void main() {
  late Directory tempDir;
  late CertificateManager manager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cert_test_');
    manager = CertificateManager(appDir: tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('CertificateManager', () {
    test('should_generate_cert_files_on_first_getContext', () async {
      final context = await manager.getContext();

      expect(context, isA<SecurityContext>());
      expect(
        await File('${tempDir.path}/sync_cert.pem').exists(),
        isTrue,
      );
      expect(
        await File('${tempDir.path}/sync_key.pem').exists(),
        isTrue,
      );
    });

    test('should_load_existing_cert_on_subsequent_calls', () async {
      await manager.getContext();
      final certContent =
          await File('${tempDir.path}/sync_cert.pem').readAsString();

      // Second call should reuse existing cert
      final context = await manager.getContext();
      expect(context, isA<SecurityContext>());

      final certAfter =
          await File('${tempDir.path}/sync_cert.pem').readAsString();
      expect(certAfter, equals(certContent));
    });

    test('should_regenerate_when_cert_file_is_corrupt', () async {
      await manager.getContext();
      // Corrupt the cert file
      await File('${tempDir.path}/sync_cert.pem').writeAsString('CORRUPT');

      final context = await manager.getContext();
      expect(context, isA<SecurityContext>());

      // Should have been regenerated with valid PEM
      final certContent =
          await File('${tempDir.path}/sync_cert.pem').readAsString();
      expect(certContent, contains('BEGIN CERTIFICATE'));
    });

    test('should_regenerate_when_cert_file_missing', () async {
      await manager.getContext();
      await File('${tempDir.path}/sync_cert.pem').delete();

      final context = await manager.getContext();
      expect(context, isA<SecurityContext>());
    });

    test('should_return_fingerprint', () async {
      final fingerprint = await manager.getFingerprint();
      expect(fingerprint, isNotEmpty);
    });
  });
}
