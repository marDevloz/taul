import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/ui/widgets/tag_suggestions.dart';

/// A rich text editor using flutter_quill with a compact formatting toolbar.
///
/// Manages its own [QuillController] internally. Exposes the content as
/// Delta JSON via [onChanged].
///
/// When [allTags] is provided, typing `-#` in the content triggers
/// a single inline tag suggestion chip below the editor.
class RichTextEditor extends StatefulWidget {
  /// Initial content (legacy plain text or Delta JSON).
  final String initialContent;

  /// Called whenever the content changes, with the Delta JSON string.
  final ValueChanged<String>? onChanged;

  /// Whether to show the formatting toolbar.
  final bool showToolbar;

  /// Maximum height of the editor content area. When exceeded, scrolling is enabled.
  /// Defaults to 60% of the screen height.
  final double? maxHeight;

  /// Placeholder text shown when the editor is empty.
  final String placeholder;

  /// Hint text shown below the toolbar (e.g. format guide).
  final String? hintText;

  /// Available tags for inline `-#tag` autocomplete suggestions.
  final List<TagSetting>? allTags;

  /// Tags already assigned to this entry (excluded from suggestions).
  final List<String> selectedTags;

  const RichTextEditor({
    super.key,
    this.initialContent = '',
    this.onChanged,
    this.showToolbar = true,
    this.maxHeight,
    this.placeholder = 'Escribí algo...',
    this.hintText,
    this.allTags,
    this.selectedTags = const [],
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  QuillController _controller = _createEmptyController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static QuillController _createEmptyController() {
    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void initState() {
    super.initState();
    _initController(widget.initialContent);
    _controller.addListener(_onControllerChanged);
  }

  void _initController(String content) {
    final nextDoc = RichTextHelper.getDocument(content);
    final currentJson = RichTextHelper.documentToJson(_controller.document);
    final nextJson = RichTextHelper.documentToJson(nextDoc);
    if (currentJson != nextJson) {
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _controller = QuillController(
        document: nextDoc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  void didUpdateWidget(RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialContent != oldWidget.initialContent) {
      _initController(widget.initialContent);
    }
  }

  void _onControllerChanged() {
    widget.onChanged?.call(RichTextHelper.documentToJson(_controller.document));
  }

  void _requestFocus() {
    _focusNode.requestFocus();
  }

  /// Extracts the plain text after the last `-#` on the current line.
  /// Returns the partial tag text the user is typing, or null if not in a `-#` context.
  String? _extractCurrentHashTag() {
    final plainText = _controller.document.toPlainText();
    final selection = _controller.selection;
    if (!selection.isCollapsed) return null;

    // Get text from start of current line to cursor
    final cursorOffset = selection.end;
    final textBeforeCursor = plainText.substring(0, cursorOffset);

    // Find last `-#` before cursor
    final lastHashTag = textBeforeCursor.lastIndexOf('-#');
    if (lastHashTag == -1) return null;

    // Check there's no space between `-#` and cursor (single word)
    final afterHash = textBeforeCursor.substring(lastHashTag + 2);
    if (afterHash.contains(' ')) return null;

    return afterHash;
  }

  /// Replaces the current `-#partial` with `-#tagName ` in the document.
  void _acceptTagSuggestion(String tagName) {
    final plainText = _controller.document.toPlainText();
    final selection = _controller.selection;
    if (!selection.isCollapsed) return;

    final cursorOffset = selection.end;
    final textBeforeCursor = plainText.substring(0, cursorOffset);
    final lastHashTag = textBeforeCursor.lastIndexOf('-#');
    if (lastHashTag == -1) return;

    final replacement = '-#$tagName ';
    final replaceFrom = lastHashTag;
    final replaceTo = cursorOffset;

    // Use Quill's replace to maintain document integrity
    final newOffset = replaceFrom + replacement.length;
    _controller.replaceText(
      replaceFrom,
      replaceTo - replaceFrom,
      replacement,
      TextSelection.collapsed(offset: newOffset),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Compute tag suggestion for `-#` autocomplete
    final currentPartialTag = widget.allTags != null
        ? _extractCurrentHashTag()
        : null;

    String? suggestedTagName;
    if (currentPartialTag != null && currentPartialTag.isNotEmpty) {
      final suggestions = filterTagSuggestions(
        query: currentPartialTag,
        allTags: widget.allTags!,
        selectedTags: widget.selectedTags,
        maxSuggestions: 1,
      );
      if (suggestions.isNotEmpty) {
        suggestedTagName = suggestions.first.name;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showToolbar)
          QuillSimpleToolbar(
            controller: _controller,
            config: QuillSimpleToolbarConfig(
              showBackgroundColorButton: false,
              showColorButton: false,
              showFontFamily: false,
              showFontSize: false,
              showSubscript: false,
              showSuperscript: false,
              showHeaderStyle: false,
              showListCheck: false,
              showListBullets: true,
              showListNumbers: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showQuote: false,
              showIndent: false,
              showAlignmentButtons: false,
              showLink: false,
              showSearchButton: false,
              showClearFormat: false,
              showDirection: false,
              showUndo: false,
              showRedo: false,
              showCodeBlock: false,
              multiRowsDisplay: true,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        if (widget.showToolbar) const SizedBox(height: 8),
        // Hint bar — always visible format guide
        if (widget.hintText != null && widget.hintText!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.hintText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        if (widget.hintText != null && widget.hintText!.isNotEmpty)
          const SizedBox(height: 6),
        // Editor
        GestureDetector(
          onTap: _requestFocus,
          child: Container(
            constraints: BoxConstraints(
              minHeight: 150,
              maxHeight: widget.maxHeight ?? MediaQuery.of(context).size.height * 0.6,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(8),
            child: QuillEditor.basic(
              controller: _controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: QuillEditorConfig(
                placeholder: widget.placeholder,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        // Inline `-#tag` suggestion chip
        if (suggestedTagName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: () {
                _acceptTagSuggestion(suggestedTagName!);
                _requestFocus();
              },
              child: Container(
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
                      '-#$suggestedTagName',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onPrimaryContainer,
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
