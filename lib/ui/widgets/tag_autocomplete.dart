import 'package:flutter/material.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/ui/widgets/tag_suggestions.dart';

/// A text input with a single inline tag suggestion.
///
/// As the user types, the first matching tag appears as a tappable chip
/// below the input. Tapping it adds the tag.
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

    final firstSuggestion = _currentInput.isNotEmpty && suggestions.isNotEmpty
        ? suggestions.first
        : null;

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
        if (firstSuggestion != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: () => _selectTag(firstSuggestion.name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      firstSuggestion.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
