import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/conflict.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';

void main() {
  group('Conflict', () {
    final now = DateTime.now();
    final entry = Entry(
      id: 'entry-1',
      type: EntryType.note,
      title: 'Test',
      content: 'Content',
      createdAt: now,
      updatedAt: now,
    );

    test('should_create_with_pending_resolution', () {
      final conflict = Conflict(
        id: 0,
        entryId: 'entry-1',
        localVersion: entry,
        remoteVersion: entry,
        peerDeviceId: 'device-2',
        createdAt: now,
      );
      expect(conflict.resolution, ConflictResolution.pending);
      expect(conflict.resolvedAt, isNull);
    });

    test('should_preserve_resolution_in_json_roundtrip', () {
      final conflict = Conflict(
        id: 1,
        entryId: 'entry-1',
        localVersion: entry,
        remoteVersion: entry,
        resolution: ConflictResolution.keepLocal,
        peerDeviceId: 'device-2',
        createdAt: now,
        resolvedAt: now,
      );
      final json = conflict.toJson();
      final restored = Conflict.fromJson(json);
      expect(restored.resolution, ConflictResolution.keepLocal);
      expect(restored.resolvedAt, now);
    });

    test('should_roundtrip_all_fields', () {
      final conflict = Conflict(
        id: 42,
        entryId: 'entry-2',
        localVersion: entry,
        remoteVersion: entry,
        resolution: ConflictResolution.keepBoth,
        peerDeviceId: 'device-3',
        createdAt: now,
        resolvedAt: now,
      );
      final json = conflict.toJson();
      final restored = Conflict.fromJson(json);
      expect(restored.id, 42);
      expect(restored.entryId, 'entry-2');
      expect(restored.peerDeviceId, 'device-3');
      expect(restored.resolution, ConflictResolution.keepBoth);
    });
  });

  group('ConflictResolution', () {
    test('should_convert_to_and_from_label', () {
      for (final res in ConflictResolution.values) {
        expect(ConflictResolution.fromLabel(res.label), res);
      }
    });

    test('should_return_pending_for_unknown_label', () {
      expect(ConflictResolution.fromLabel('UNKNOWN'), ConflictResolution.pending);
    });
  });
}