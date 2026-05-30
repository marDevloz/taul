import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/shared/tag_color_mixer.dart';
import 'package:taul/shared/tag_palette.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Pre-computes the mixed display color for an entry.
///
/// Returns null if the entry has no tags or no color assignments.
/// Returns [TagPalette.defaultGrey] if the entry has tags but none have
/// colors assigned (matching spec Escenario 3).
///
/// Uses [TagColorMixer.mix] for HSL circular-mean averaging when there
/// are multiple colored tags.
final entryDisplayColorProvider =
    Provider.autoDispose.family<Color?, String>((ref, entryId) {
  final entry = ref.watch(entryDetailProvider(entryId)).valueOrNull;
  if (entry == null || entry.tags.isEmpty) return null;

  final matched = entry.tags
      .map((t) => entry.tagsColors[t])
      .whereType<String>()
      .map(_parseHex)
      .toList();

  if (matched.isEmpty) return TagPalette.defaultGrey;
  return TagColorMixer.mix(matched);
});

/// Resolves the color for a specific tag within a specific entry.
///
/// Parameters: (entryId, tag).
/// Returns null if the tag has no color assigned in that entry.
final tagColorForEntryProvider =
    Provider.autoDispose.family<Color?, (String entryId, String tag)>(
  (ref, params) {
    final (entryId, tag) = params;
    final entry = ref.watch(entryDetailProvider(entryId)).valueOrNull;
    if (entry == null) return null;
    final hex = entry.tagsColors[tag];
    if (hex == null) return null;
    return _parseHex(hex);
  },
);

/// Builds a global map of tag → first-assigned Color found across all visible
/// entries. Used by the filter row to show colored tag pills.
///
/// Scans all non-deleted entries in [entryListProvider] and picks the first
/// color assigned to each tag. If no entry assigns a color to a particular
/// tag, that tag is omitted from the map (no background color in the pill).
final tagColorMapProvider = Provider.autoDispose<Map<String, Color>>((ref) {
  final entries = ref.watch(entryListProvider).valueOrNull ?? [];
  final result = <String, Color>{};
  for (final entry in entries) {
    for (final tag in entry.tags) {
      if (result.containsKey(tag)) continue;
      final hex = entry.tagsColors[tag];
      if (hex != null) {
        result[tag] = _parseHex(hex);
      }
    }
  }
  return result;
});

Color _parseHex(String hex) {
  return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
}
