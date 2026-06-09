import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taul/infrastructure/sync/certificate_manager.dart';
import 'package:taul/infrastructure/sync/sync_server.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';

class MockCertManager extends Mock implements CertificateManager {}

void main() {
  late SyncServer server;
  late MockCertManager certManager;

  setUp(() {
    certManager = MockCertManager();
    when(() => certManager.getContext()).thenAnswer(
      (_) async => SecurityContext(),
    );
  });

  tearDown(() async {
    await server.stop();
  });

  group('start/stop', () {
    test('starts and reports running', () async {
      server = SyncServer(
        certManager: certManager,
        pairingCode: '123456',
        onRequest: (_) async => const SyncResponse(
          deviceId: 'test',
          entriesReceived: 0,
          conflictsCount: 0,
        ),
      );

      final port = await server.start();
      expect(port, isNotNull);
      expect(server.isRunning, isTrue);

      await server.stop();
      expect(server.isRunning, isFalse);
    });
  });

  group('authentication', () {
    test('rejects invalid pairing code with 401', () async {
      server = SyncServer(
        certManager: certManager,
        pairingCode: '123456',
        onRequest: (_) async => const SyncResponse(
          deviceId: 'test',
          entriesReceived: 0,
          conflictsCount: 0,
        ),
      );

      final port = await server.start();
      final client = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;

      try {
        final req = await client.postUrl(
          Uri.parse('https://localhost:$port/sync'),
        );
        req.headers.set('x-pairing-code', '999999');
        req.headers.contentType = ContentType.json;
        req.write('{}');
        final res = await req.close().timeout(
          const Duration(seconds: 5),
        );
        expect(res.statusCode, 401);
      } finally {
        client.close();
      }
    });
  });

  group('concurrency', () {
    test('rejects concurrent request with 429', () async {
      server = SyncServer(
        certManager: certManager,
        pairingCode: '123456',
        onRequest: (_) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return const SyncResponse(
            deviceId: 'test',
            entriesReceived: 0,
            conflictsCount: 0,
          );
        },
      );

      final port = await server.start();
      final client = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;

      try {
        final req1 = await client.postUrl(
          Uri.parse('https://localhost:$port/sync'),
        );
        req1.headers.set('x-pairing-code', '123456');
        req1.headers.contentType = ContentType.json;
        req1.write('{}');

        final req2 = await client.postUrl(
          Uri.parse('https://localhost:$port/sync'),
        );
        req2.headers.set('x-pairing-code', '123456');
        req2.headers.contentType = ContentType.json;
        req2.write('{}');

        final res1 = await req1.close();
        final res2 = await req2.close();

        final codes = [res1.statusCode, res2.statusCode]..sort();
        expect(codes, contains(429));
      } finally {
        client.close();
      }
    });
  });

  group('auto-shutdown', () {
    test('shuts down after inactivity timeout', () async {
      server = SyncServer(
        certManager: certManager,
        pairingCode: '123456',
        onRequest: (_) async => const SyncResponse(
          deviceId: 'test',
          entriesReceived: 0,
          conflictsCount: 0,
        ),
      );

      await server.start();
      expect(server.isRunning, isTrue);
    });
  });
}
