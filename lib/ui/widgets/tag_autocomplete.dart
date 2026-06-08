import 'package:flutter/material.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/ui/widgets/tag_suggestions.dart';

/// A text input with autocomplete suggestions for tags.
///
/// Shows matching tags as a fixed-height dropdown below the input as the user types.
/// Tapping a suggestion appends it to the comma-separated tag list.
/// If the typed text doesn't match any existing tag, a "Crear tag" option is shown.
class TagAutocompleteInput extends StatefulWidget {
  const TagAutocompleteInput({
    super.key,
    required this.allTags,
    required this.selectedTags,
    this.initialText = '',
    required this.onChanged,
  });

  final List<TagSetting> allTags;
  final List<String> selectedTags;
  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<TagAutocompleteInput> createState() => _TagAutocompleteInputState();
}

class _TagAutocompleteInputState extends State<TagAutocompleteInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText;
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant TagAutocompleteInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        widget.initialText != _controller.text) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _currentInput {
    final text = _controller.text;
    final parts = text.split(',');
    return parts.last.trim();
  }

  void _selectTag(String tagName) {
    final currentText = _controller.text;
    final parts = currentText.split(',');
    if (parts.length > 1) {
      parts[parts.length - 1] = ' $tagName,';
    } else {
      parts[parts.length - 1] = '$tagName,';
    }
    final newText = parts.join(',');
    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );
    widget.onChanged(newText);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = filterTagSuggestions(
      query: _currentInput,
      allTags: widget.allTags,
      selectedTags: widget.selectedTags,
    );

    final hasExactMatch = suggestions.any(
      (t) => t.name.toLowerCase() == _currentInput.toLowerCase(),
    );

    final showSuggestions = _focusNode.hasFocus &&
        (suggestions.isNotEmpty || _currentInput.isNotEmpty);

    final itemCount = suggestions.length +
        (_currentInput.isNotEmpty && !hasExactMatch ? 1 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Tags',
            hintText: 'o usá -#tag en el contenido',
            border: OutlineInputBorder(),
          ),
        ),
        if (showSuggestions && itemCount > 0)
          SizedBox(
            height: (itemCount * 48.0).clamp(0.0, 200.0),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index < suggestions.length) {
                      final tag = suggestions[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: tag.color != null
                            ? CircleAvatar(
                                radius: 8,
                                backgroundColor: Color(
                                  int.parse(
                                    'FF${tag.color!.replaceFirst('#', '')}',
                                  ),
                                ),
                              )
                            : const Icon(Icons.tag, size: 16),
                        title: Text(
                          tag.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () => _selectTag(tag.name),
                      );
                    }
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.add_circle_outline, size: 16),
                      title: Text(
                        'Crear tag: $_currentInput',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      onTap: () => _selectTag(_currentInput),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
