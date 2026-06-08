import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:taul/core/rich_text_helper.dart';

/// A rich text editor using flutter_quill with a compact formatting toolbar.
///
/// Manages its own [QuillController] internally. Exposes the content as
/// Delta JSON via [onChanged].
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

  const RichTextEditor({
    super.key,
    this.initialContent = '',
    this.onChanged,
    this.showToolbar = true,
    this.maxHeight,
    this.placeholder = 'Escribí algo...',
    this.hintText,
  });

  @override
  State<RichTextEditor> createState() => RichTextEditorState();
}

class RichTextEditorState extends State<RichTextEditor> {
  QuillController _controller = _createEmptyController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static QuillController _createEmptyController() {
    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  /// Public access to the underlying QuillController for tag detection.
  QuillController get controller => _controller;

  /// Public access to the focus node.
  FocusNode get focusNode => _focusNode;

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

  /// Replaces the current `-#partial` with `-#tagName ` in the document.
  /// Called externally by the parent when a tag suggestion is tapped.
  void acceptTagSuggestion(String tagName) {
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

    final newOffset = replaceFrom + replacement.length;
    _controller.replaceText(
      replaceFrom,
      replaceTo - replaceFrom,
      replacement,
      TextSelection.collapsed(offset: newOffset),
    );
    _requestFocus();
  }

  /// Returns the partial text after `-#` at the cursor, or null if not in a `-#` context.
  /// Used by the parent form to drive tag autocomplete suggestions.
  String? extractCurrentHashTag() {
    final plainText = _controller.document.toPlainText();
    final selection = _controller.selection;
    if (!selection.isCollapsed) return null;

    final cursorOffset = selection.end;
    final textBeforeCursor = plainText.substring(0, cursorOffset);

    final lastHashTag = textBeforeCursor.lastIndexOf('-#');
    if (lastHashTag == -1) return null;

    final afterHash = textBeforeCursor.substring(lastHashTag + 2);
    if (afterHash.contains(' ')) return null;

    return afterHash;
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
      ],
    );
  }
}
