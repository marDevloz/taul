import 'package:taul/domain/entities/tag_setting.dart';

/// Filters [allTags] by a case-insensitive, accent-insensitive substring
/// match against [query], excluding tags already in [selectedTags].
///
/// Returns at most [maxSuggestions] results (default 8).
List<TagSetting> filterTagSuggestions({
  required String query,
  required List<TagSetting> allTags,
  required List<String> selectedTags,
  int maxSuggestions = 8,
}) {
  if (query.isEmpty) {
    return allTags
        .where((t) => !selectedTags.contains(t.name))
        .take(maxSuggestions)
        .toList();
  }

  final normalizedQuery = _normalize(query);
  final selectedSet = selectedTags.toSet();

  final matches = <TagSetting>[];
  for (final tag in allTags) {
    if (selectedSet.contains(tag.name)) continue;
    if (_normalize(tag.name).contains(normalizedQuery)) {
      matches.add(tag);
      if (matches.length >= maxSuggestions) break;
    }
  }

  // Sort: prefix matches first, then substring matches.
  matches.sort((a, b) {
    final aStarts = _normalize(a.name).startsWith(normalizedQuery);
    final bStarts = _normalize(b.name).startsWith(normalizedQuery);
    if (aStarts && !bStarts) return -1;
    if (!aStarts && bStarts) return 1;
    return a.name.compareTo(b.name);
  });

  return matches;
}

/// Parses a comma-separated tag string into a list of trimmed, non-empty tags.
List<String> parseCommaSeparatedTags(String raw) {
  return raw
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

/// Removes accents and lowercases for accent-insensitive matching.
String _normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[áà]'), 'a')
      .replaceAll(RegExp(r'[éè]'), 'e')
      .replaceAll(RegExp(r'[íì]'), 'i')
      .replaceAll(RegExp(r'[óò]'), 'o')
      .replaceAll(RegExp(r'[úù]'), 'u')
      .replaceAll(RegExp(r'[ñ]'), 'n');
}
