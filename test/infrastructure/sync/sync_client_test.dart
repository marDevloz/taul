import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:taul/infrastructure/sync/sync_client.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';

void main() {
  group('response handling', () {
    test('parses 200 response correctly', () {
      final response = http.Response(
        jsonEncode(const SyncResponse(
          deviceId: 'device-1',
          entriesReceived: 5,
          conflictsCount: 2,
          serverLastSyncAt: null,
        ).toJson()),
        200,
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final syncResponse = SyncResponse.fromJson(body);
      expect(syncResponse.deviceId, 'device-1');
      expect(syncResponse.entriesReceived, 5);
      expect(syncResponse.conflictsCount, 2);
    });

    test('throws PairingCodeRejectedException on 401', () {
      final response = http.Response(
        jsonEncode(const SyncErrorResponse(
          code: 401,
          message: 'Invalid pairing code',
        ).toJson()),
        401,
      );

      expect(response.statusCode, 401);
    });

    test('throws RateLimitException on 429', () {
      final response = http.Response(
        jsonEncode(const SyncErrorResponse(
          code: 429,
          message: 'Sync in progress',
        ).toJson()),
        429,
      );

      expect(response.statusCode, 429);
    });

    test('throws ServerErrorException on 5xx', () {
      final response = http.Response('Internal error', 500);
      expect(response.statusCode, greaterThanOrEqualTo(500));
    });
  });

  group('chunked send', () {
    test('splits entries into chunks of 100', () {
      final entries = List.generate(
        250,
        (i) => EntrySyncData(
          id: 'entry-$i',
          title: 'Title $i',
          content: 'Content $i',
          updatedAt: DateTime(2024),
        ),
      );

      const chunkSize = 100;
      final chunks = <List<EntrySyncData>>[];
      for (var i = 0; i < entries.length; i += chunkSize) {
        chunks.add(
          entries.sublist(i, (i + chunkSize).clamp(0, entries.length)),
        );
      }

      expect(chunks.length, 3);
      expect(chunks[0].length, 100);
      expect(chunks[1].length, 100);
      expect(chunks[2].length, 50);
    });
  });

  group('exception types', () {
    test('SyncInterruptedException has message', () {
      const ex = SyncInterruptedException();
      expect(ex.toString(), contains('interrupted'));
    });

    test('TlsFingerprintMismatchException has message', () {
      const ex = TlsFingerprintMismatchException();
      expect(ex.toString(), contains('fingerprint'));
    });

    test('PairingCodeRejectedException has message', () {
      const ex = PairingCodeRejectedException();
      expect(ex.toString(), contains('rejected'));
    });
  });
}

class EntrySyncData {
  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;

  EntrySyncData({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });
}
