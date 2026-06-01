import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:taul/core/rich_text_helper.dart';

/// Renders entry content as rich text (Delta JSON) or plain text (legacy).
///
/// Read-only — users can select and copy text but not edit.
class RichTextDisplay extends StatefulWidget {
  /// Content from [Entry.content] — can be Delta JSON or legacy plain text.
  final String content;

  const RichTextDisplay({super.key, required this.content});

  @override
  State<RichTextDisplay> createState() => _RichTextDisplayState();
}

class _RichTextDisplayState extends State<RichTextDisplay> {
  QuillController _controller = _createEmptyController();

  static QuillController _createEmptyController() {
    return QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void initState() {
    super.initState();
    _initContent(widget.content);
  }

  @override
  void didUpdateWidget(RichTextDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content) {
      _initContent(widget.content);
    }
  }

  void _initContent(String content) {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    final doc = RichTextHelper.getDocument(content);
    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  void _onControllerChanged() {
    // no-op — read-only display, no callback needed
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuillEditor.basic(
      controller: _controller,
      config: const QuillEditorConfig(
        scrollable: false,
        padding: EdgeInsets.zero,
        enableInteractiveSelection: true,
        enableSelectionToolbar: true,
      ),
    );
  }
}
