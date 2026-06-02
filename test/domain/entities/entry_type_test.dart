import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/entry_type.dart';

void main() {
  group('EntryType', () {
    test('should_have_task_value', () {
      expect(EntryType.values, contains(EntryType.task));
    });

    test('should_have_label_tarea', () {
      expect(EntryType.task.label, 'TAREA');
    });

    test('should_parse_from_label', () {
      expect(EntryType.fromLabel('TAREA'), EntryType.task);
      expect(EntryType.fromLabel('NOTA'), EntryType.note);
      expect(EntryType.fromLabel('UNKNOWN'), EntryType.note);
    });
  });
}
