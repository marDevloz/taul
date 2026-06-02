import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';

void main() {
  group('Entry', () {
    final now = DateTime.now();
    final baseEntry = Entry(
      id: 'test-id',
      type: EntryType.note,
      title: 'Test',
      content: 'Content',
      createdAt: now,
      updatedAt: now,
    );

    test('should_create_with_null_completedAt', () {
      expect(baseEntry.completedAt, isNull);
    });

    test('should_create_with_non_null_completedAt', () {
      final completedAt = DateTime(2025, 6, 1, 10, 0, 0);
      final entry = Entry(
        id: 'test-id',
        type: EntryType.task,
        title: 'Task',
        content: 'Do something',
        createdAt: now,
        updatedAt: now,
        completedAt: completedAt,
      );
      expect(entry.completedAt, completedAt);
    });

    test('should_preserve_completedAt_in_json_roundtrip', () {
      final completedAt = DateTime(2025, 6, 1, 10, 0, 0, 123, 456);
      final entry = Entry(
        id: 'test-id',
        type: EntryType.task,
        title: 'Task',
        content: 'Do something',
        createdAt: now,
        updatedAt: now,
        completedAt: completedAt,
      );
      final json = entry.toJson();
      final restored = Entry.fromJson(json);
      expect(restored.completedAt, completedAt);
    });
  });
}
