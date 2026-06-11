import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/widgets/tag_suggestions.dart';

/// Computes a unified suggestion from both editor `-#` and tags field partial.
///
/// Editor `-#` takes priority over the tags field partial.
TagSetting? unifiedSuggestion({
  required String? editorHashTagPartial,
  required String tagsFieldPartial,
  required String tagsText,
  required List<TagSetting> allTags,
}) {
  final selectedTags = tagsText
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  // Editor -# tag has priority
  if (editorHashTagPartial != null && editorHashTagPartial.isNotEmpty) {
    final suggestions = filterTagSuggestions(
      query: editorHashTagPartial,
      allTags: allTags,
      selectedTags: selectedTags,
      maxSuggestions: 1,
    );
    if (suggestions.isNotEmpty) return suggestions.first;
  }

  // Tags field partial
  if (tagsFieldPartial.isNotEmpty) {
    final suggestions = filterTagSuggestions(
      query: tagsFieldPartial,
      allTags: allTags,
      selectedTags: selectedTags,
      maxSuggestions: 1,
    );
    if (suggestions.isNotEmpty) return suggestions.first;
  }

  return null;
}

/// Displays a unified tag autocomplete suggestion chip.
///
/// Watches [tagSettingsListProvider] to compute suggestions based on:
/// 1. The editor's `-#` partial (takes priority)
/// 2. The tags field's current partial
class TagAutocompleteField extends ConsumerStatefulWidget {
  /// Current partial from the editor's `-#` tag, or null.
  final String? editorHashTagPartial;

  /// Current partial being typed in the tags field.
  final String tagsFieldPartial;

  /// Current text value of the tags field (for selected tags computation).
  final String tagsText;

  /// Called when the user taps the suggestion chip.
  /// Receives the accepted tag name.
  final ValueChanged<String> onAcceptSuggestion;

  const TagAutocompleteField({
    super.key,
    required this.editorHashTagPartial,
    required this.tagsFieldPartial,
    required this.tagsText,
    required this.onAcceptSuggestion,
  });

  @override
  ConsumerState<TagAutocompleteField> createState() =>
      _TagAutocompleteFieldState();
}

class _TagAutocompleteFieldState extends ConsumerState<TagAutocompleteField> {
  @override
  Widget build(BuildContext context) {
    final allTags = ref.watch(tagSettingsListProvider).valueOrNull ?? [];
    final suggestion = unifiedSuggestion(
      editorHashTagPartial: widget.editorHashTagPartial,
      tagsFieldPartial: widget.tagsFieldPartial,
      tagsText: widget.tagsText,
      allTags: allTags,
    );

    if (suggestion == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => widget.onAcceptSuggestion(suggestion.name),
      child: _buildSuggestionChip(context, suggestion),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, TagSetting suggestion) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            suggestion.name,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
