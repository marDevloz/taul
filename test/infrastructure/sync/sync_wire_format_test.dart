import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/sync/sync_wire_format.dart';

void main() {
  final now = DateTime.now();
  final entry = Entry(
    id: 'entry-1',
    type: EntryType.note,
    title: 'Test Entry',
    content: 'Hello world',
    tags: ['tag1', 'tag2'],
    createdAt: now,
    updatedAt: now,
  );

  group('SyncRequest', () {
    test('should_serialize_to_json', () {
      final request = SyncRequest(
        deviceId: 'device-1',
        lastSyncAt: now,
        entries: [entry],
      );

      final json = jsonDecode(jsonEncode(request.toJson())) as Map<String, dynamic>;
      expect(json['deviceId'], 'device-1');
      expect(json['entries'], hasLength(1));
      expect((json['entries'] as List).first['id'], 'entry-1');
    });

    test('should_roundtrip_through_json', () {
      final request = SyncRequest(
        deviceId: 'device-1',
        lastSyncAt: now,
        entries: [entry],
      );

      final encoded = jsonEncode(request.toJson());
      final restored = SyncRequest.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
      expect(restored.deviceId, 'device-1');
      expect(restored.lastSyncAt, now);
      expect(restored.entries, hasLength(1));
      expect(restored.entries.first.id, 'entry-1');
    });

    test('should_handle_empty_entries', () {
      final request = SyncRequest(deviceId: 'device-1');
      final json = jsonDecode(jsonEncode(request.toJson())) as Map<String, dynamic>;
      final restored = SyncRequest.fromJson(Map<String, dynamic>.from(json));
      expect(restored.entries, isEmpty);
      expect(restored.lastSyncAt, isNull);
    });
  });

  group('SyncResponse', () {
    test('should_serialize_to_json', () {
      final response = SyncResponse(
        deviceId: 'device-1',
        entriesReceived: 5,
        conflictsCount: 2,
        serverLastSyncAt: now,
      );

      final json = response.toJson();
      expect(json['deviceId'], 'device-1');
      expect(json['entriesReceived'], 5);
      expect(json['conflictsCount'], 2);
    });

    test('should_roundtrip_through_json', () {
      final response = SyncResponse(
        deviceId: 'device-1',
        entriesReceived: 5,
        conflictsCount: 2,
        serverLastSyncAt: now,
      );

      final restored = SyncResponse.fromJson(response.toJson());
      expect(restored.deviceId, 'device-1');
      expect(restored.entriesReceived, 5);
      expect(restored.conflictsCount, 2);
      expect(restored.serverLastSyncAt, now);
    });
  });

  group('SyncErrorResponse', () {
    test('should_serialize_to_json', () {
      final error = SyncErrorResponse(code: 401, message: 'Invalid code');
      final json = error.toJson();
      expect(json['code'], 401);
      expect(json['message'], 'Invalid code');
    });

    test('should_roundtrip_through_json', () {
      final error = SyncErrorResponse(code: 429, message: 'Rate limited');
      final restored = SyncErrorResponse.fromJson(error.toJson());
      expect(restored.code, 429);
      expect(restored.message, 'Rate limited');
    });
  });
}
