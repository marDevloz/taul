import 'package:taul/domain/entities/entry.dart';

class MergeService {
  /// Concatenates multiple entries into a single text document.
  /// Format: "-- {title} --\n\n{content}\n\n" per entry
  /// Throws if >20 entries.
  static String concatenate(List<Entry> entries) {
    if (entries.length > 20) {
      throw ArgumentError('Cannot merge more than 20 entries');
    }
    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer.writeln(
        '-- ${entry.title.isEmpty ? "(sin título)" : entry.title} --',
      );
      buffer.writeln();
      buffer.writeln(entry.content);
      buffer.writeln();
    }
    return buffer.toString();
  }
}
