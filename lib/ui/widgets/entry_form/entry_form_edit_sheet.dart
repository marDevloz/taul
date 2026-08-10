import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:taul/core/errors/error_mapper.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';
import 'package:taul/ui/widgets/entry_form/entry_type_selector.dart';
import 'package:taul/ui/widgets/entry_form/tag_autocomplete_field.dart';
import 'package:taul/ui/widgets/rich_text_editor.dart';

/// Bottom sheet for editing an existing entry.
///
/// Receives controllers and editor key from the orchestrator.
class EntryFormEditSheet extends ConsumerStatefulWidget {
  final GlobalKey<RichTextEditorState> editorKey;
  final TextEditingController titleCtrl;
  final TextEditingController tagsCtrl;
  final String? editorHashTagPartial;
  final String tagsFieldPartial;
  final ValueChanged<String> onContentChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onAcceptSuggestion;
  final Entry entry;
  final String entryId;

  const EntryFormEditSheet({
    super.key,
    required this.editorKey,
    required this.titleCtrl,
    required this.tagsCtrl,
    required this.editorHashTagPartial,
    required this.tagsFieldPartial,
    required this.onContentChanged,
    required this.onTagsChanged,
    required this.onAcceptSuggestion,
    required this.entry,
    required this.entryId,
  });

  @override
  ConsumerState<EntryFormEditSheet> createState() =>
      _EntryFormEditSheetState();
}

class _EntryFormEditSheetState extends ConsumerState<EntryFormEditSheet> {
  EntryType? _selectedType;
  bool _isSaving = false;
  String _richContent = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.entry.type;
    _richContent = widget.entry.content;
    widget.titleCtrl.text = widget.entry.title;
    widget.tagsCtrl.text = widget.entry.tags.join(', ');
  }

  Future<void> _saveEdit() async {
    final entry = widget.entry;
    setState(() => _isSaving = true);
    try {
      final plainText = RichTextHelper.documentToPlainText(
        RichTextHelper.getDocument(_richContent),
      );
      final extracted = RichTextHelper.extractTags(plainText);
      final contentTags = extracted.tags;
      final content = RichTextHelper.stripTagsFromContent(
        _richContent,
        contentTags,
      );

      final manualTags = widget.tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final tags = {...manualTags, ...contentTags}.toList();

      await ref.read(updateEntryProvider).call(
        entry,
        title: widget.titleCtrl.text,
        content: content,
        tags: tags,
        type: _selectedType ?? entry.type,
      );
      ref.invalidate(entryDetailProvider(widget.entryId));
      ref.invalidate(entryListProvider);
      ref.invalidate(tagSettingsListProvider);
      ref.invalidate(tagSettingsMapProvider);
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      Logger().e('Failed to save entry edit', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              const ErrorMapper().toUserMessage(
                e,
                actionMessage: ErrorMapper.saveErrorMessage,
              ),
            ),
          ),
        );
      }
    }
  }

  void _onTypeSelected(EntryType? value) {
    if (value == EntryType.credential) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => CredentialFormSheet(entry: widget.entry),
      );
      return;
    }
    setState(() => _selectedType = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),

            // 1. Title
            TextField(
              controller: widget.titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 3. Content (rich text editor)
            const Text('Contenido', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            RichTextEditor(
              key: widget.editorKey,
              initialContent: _richContent,
              onChanged: (json) {
                widget.onContentChanged(json);
                setState(() => _richContent = json);
              },
              maxHeight: 200,
            ),
            const SizedBox(height: 4),

            // 4. Unified autocomplete suggestion
            TagAutocompleteField(
              editorHashTagPartial: widget.editorHashTagPartial,
              tagsFieldPartial: widget.tagsFieldPartial,
              tagsText: widget.tagsCtrl.text,
              onAcceptSuggestion: widget.onAcceptSuggestion,
            ),

            // 5. Tags
            const SizedBox(height: 4),
            TextField(
              controller: widget.tagsCtrl,
              onChanged: widget.onTagsChanged,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'separados por coma',
                border: OutlineInputBorder(),
              ),
            ),

            // Buttons
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSaving ? null : _saveEdit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final currentType = _selectedType ?? widget.entry.type;
    return Row(
      children: [
        const Icon(Icons.edit_note, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child:
              Text('Editar entrada', style: theme.textTheme.titleMedium),
        ),
        EntryTypeSelector(
          currentType: currentType,
          isManual: _selectedType != null,
          onSelected: _onTypeSelected,
        ),
      ],
    );
  }
}
