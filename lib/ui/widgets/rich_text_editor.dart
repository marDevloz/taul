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

  const RichTextEditor({
    super.key,
    this.initialContent = '',
    this.onChanged,
    this.showToolbar = true,
    this.maxHeight,
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
  }

  void _initController(String content) {
    final doc = RichTextHelper.getDocument(content);
    if (_controller.document != doc) {
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _controller.addListener(_onControllerChanged);
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
    widget.onChanged?.call(
      RichTextHelper.documentToJson(_controller.document),
    );
  }

  void _requestFocus() {
    _focusNode.requestFocus();
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
    final screenHeight = MediaQuery.of(context).size.height;
    final maxH = widget.maxHeight ?? screenHeight * 0.6; // 60% of screen height

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
        GestureDetector(
          onTap: _requestFocus,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Container(
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
                  placeholder: 'Escribí algo...',
                  padding: EdgeInsets.zero,
                  minHeight: 120,
                  maxHeight: maxH - 16, // account for padding
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
