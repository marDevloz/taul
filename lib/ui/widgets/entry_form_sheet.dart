import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/widgets/entry_form/entry_form_create_sheet.dart';
import 'package:taul/ui/widgets/entry_form/entry_form_edit_sheet.dart';
import 'package:taul/ui/widgets/rich_text_editor.dart';

/// Unified entry form sheet for both creating and editing entries.
///
/// When [entry] is null, operates in create mode with draft support.
/// When [entry] is non-null, operates in edit mode.
///
/// Delegates layout to [EntryFormCreateSheet] or [EntryFormEditSheet]
/// while managing shared state: editor key, controllers, and tag partials.
class EntryFormSheet extends ConsumerStatefulWidget {
  final Entry? entry;
  final String? entryId;
  final Future<void> Function()? onCredentialRequested;

  const EntryFormSheet({
    super.key,
    this.entry,
    this.entryId,
    this.onCredentialRequested,
  });

  @override
  ConsumerState<EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends ConsumerState<EntryFormSheet> {
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _editorKey = GlobalKey<RichTextEditorState>();

  // Tag autocomplete — owned here, passed down to mode widgets
  String? _editorHashTagPartial;
  String _tagsFieldPartial = '';

  bool get _isEditing => widget.entry != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Editor & tag query detection
  // ---------------------------------------------------------------------------

  void _onContentChanged(String content) {
    if (_isEditing) {
      // No state update needed for edit — content tracked by edit widget
    } else {
      ref.read(createEntryControllerProvider.notifier).detectTypeFromContent(
        content,
      );
    }
    _updateEditorHashTag();
  }

  void _updateEditorHashTag() {
    final editorState = _editorKey.currentState;
    if (editorState == null) return;
    final partial = editorState.extractCurrentHashTag();
    if (partial != _editorHashTagPartial) {
      setState(() => _editorHashTagPartial = partial);
    }
  }

  void _onTagsChanged(String text) {
    if (!_isEditing) {
      ref.read(createEntryControllerProvider.notifier).setTags(text);
    }
    final parts = text.split(',');
    final partial = parts.last.trim();
    if (partial != _tagsFieldPartial) {
      setState(() => _tagsFieldPartial = partial);
    }
  }

  void _acceptSuggestion(String tagName) {
    final editorState = _editorKey.currentState;
    if (editorState != null && _editorHashTagPartial != null) {
      editorState.acceptTagSuggestion(tagName);
      setState(() => _editorHashTagPartial = null);
    } else {
      final currentText = _tagsCtrl.text;
      final parts = currentText.split(',');
      if (parts.length > 1) {
        parts[parts.length - 1] = ' $tagName,';
      } else {
        parts[parts.length - 1] = '$tagName,';
      }
      final newText = parts.join(',');
      _tagsCtrl.text = newText;
      _tagsCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
      setState(() => _tagsFieldPartial = '');
    }
  }

  // ---------------------------------------------------------------------------
  // Build — delegate to mode-specific widgets
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    assert(
      _isEditing ? widget.entryId != null : true,
      'Editing requires entryId',
    );
    if (_isEditing) {
      return EntryFormEditSheet(
        editorKey: _editorKey,
        titleCtrl: _titleCtrl,
        tagsCtrl: _tagsCtrl,
        editorHashTagPartial: _editorHashTagPartial,
        tagsFieldPartial: _tagsFieldPartial,
        onContentChanged: _onContentChanged,
        onTagsChanged: _onTagsChanged,
        onAcceptSuggestion: _acceptSuggestion,
        entry: widget.entry!,
        entryId: widget.entryId!,
      );
    }

    return EntryFormCreateSheet(
      editorKey: _editorKey,
      titleCtrl: _titleCtrl,
      tagsCtrl: _tagsCtrl,
      editorHashTagPartial: _editorHashTagPartial,
      tagsFieldPartial: _tagsFieldPartial,
      onContentChanged: _onContentChanged,
      onTagsChanged: _onTagsChanged,
      onAcceptSuggestion: _acceptSuggestion,
      onCredentialRequested: widget.onCredentialRequested,
    );
  }
}
