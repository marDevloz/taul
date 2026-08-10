import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/controllers/create_entry_controller.dart';
import 'package:taul/ui/providers/entry_draft_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';
import 'package:taul/ui/widgets/entry_form/entry_type_selector.dart';
import 'package:taul/ui/widgets/entry_form/quick_commands_sheet.dart';
import 'package:taul/ui/widgets/entry_form/tag_autocomplete_field.dart';
import 'package:taul/ui/widgets/rich_text_editor.dart';

/// Bottom sheet for creating a new entry.
///
/// Manages draft lifecycle: restores draft on init, auto-saves on dismiss.
class EntryFormCreateSheet extends ConsumerStatefulWidget {
  final GlobalKey<RichTextEditorState> editorKey;
  final TextEditingController titleCtrl;
  final TextEditingController tagsCtrl;
  final String? editorHashTagPartial;
  final String tagsFieldPartial;
  final ValueChanged<String> onContentChanged;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String> onAcceptSuggestion;

  const EntryFormCreateSheet({
    super.key,
    required this.editorKey,
    required this.titleCtrl,
    required this.tagsCtrl,
    required this.editorHashTagPartial,
    required this.tagsFieldPartial,
    required this.onContentChanged,
    required this.onTagsChanged,
    required this.onAcceptSuggestion,
  });

  @override
  ConsumerState<EntryFormCreateSheet> createState() =>
      _EntryFormCreateSheetState();
}

class _EntryFormCreateSheetState extends ConsumerState<EntryFormCreateSheet> {
  bool _didSaveSuccessfully = false;
  bool _didCancel = false;
  EntryDraftNotifier? _draftNotifier;
  CreateEntryController? _controller;
  CreateEntryState? _lastKnownState;

  static const _typeHints = {
    EntryType.note: 'Escribí algo...  -#tag  Título# contenido',
    EntryType.idea: '!idea genial  -#tag  Título# contenido',
    EntryType.task: '[] Comprar leche  -#tag  Título# contenido',
    EntryType.glossary: 'Término: definición  -#tag  Título# contenido',
    EntryType.credential: 'servicio*user*pass*url  -#tag  Título# contenido',
  };

  @override
  void initState() {
    super.initState();
    _draftNotifier = ref.read(entryDraftProvider.notifier);
    _controller = ref.read(createEntryControllerProvider.notifier);
    _lastKnownState = ref.read(createEntryControllerProvider);
    Future.microtask(() {
      if (!mounted) return;
      _restoreDraft();
    });
  }

  void _restoreDraft() {
    final draft = ref.read(entryDraftProvider);
    if (draft != null) {
      widget.titleCtrl.text = draft.title;
      widget.tagsCtrl.text = draft.tags;
      _controller!.loadDraft(draft);
      if (draft.content.isNotEmpty) {
        _controller!.detectTypeFromContent(draft.content);
      }
    }
  }

  @override
  void dispose() {
    if (!_didSaveSuccessfully && !_didCancel) {
      final hasContent = widget.titleCtrl.text.isNotEmpty ||
          (_lastKnownState?.content ?? '').isNotEmpty ||
          widget.tagsCtrl.text.isNotEmpty;
      if (hasContent) {
        final draft = EntryDraft(
          title: widget.titleCtrl.text,
          content: _lastKnownState?.content ?? '',
          tags: widget.tagsCtrl.text,
          manualType: _lastKnownState?.manualType,
        );
        Future.microtask(() {
          try {
            _draftNotifier?.save(draft);
          } catch (e) {
            // Draft save is best-effort — don't crash dispose
          }
        });
      } else {
        Future.microtask(() {
          try {
            _draftNotifier?.clear();
          } catch (e) {
            // Draft clear is best-effort — don't crash dispose
          }
        });
      }
    }
    super.dispose();
  }

  Future<void> _saveCreate() async {
    try {
      final saved = await _controller!.save();
      if (saved) {
        _didSaveSuccessfully = true;
        _controller!.reset();
        try { _draftNotifier?.clear(); } catch (_) { /* best-effort */ }
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      // Error is handled by the ref.listen in build
    }
  }

  void _onTypeSelected(EntryType? value) {
    if (value == EntryType.credential) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const CredentialFormSheet(),
      );
      return;
    }
    _controller?.setManualType(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(createEntryControllerProvider);
    _lastKnownState = state;

    ref.listen(createEntryControllerProvider.select((s) => s.error), (
      _,
      error,
    ) {
      if (error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    });

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
            _buildHeader(theme, state),
            const SizedBox(height: 16),

            // 0. Detected type hint (ported from quick_add_sheet)
            if (state.detectedType != null) ...[
              _buildDetectedTypeBanner(theme, state.detectedType!),
              const SizedBox(height: 12),
            ],

            // 1. Title
            TextField(
              controller: widget.titleCtrl,
              onChanged: _controller?.setTitle,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'o escribí Titulo# en el contenido',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Content (rich text editor)
            const Text('Contenido', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            RichTextEditor(
              key: widget.editorKey,
              initialContent: state.content,
              onChanged: widget.onContentChanged,
              maxHeight: 200,
              hintText: state.detectedType != null
                  ? _typeHints[state.detectedType]
                  : null,
            ),
            const SizedBox(height: 4),

            // 3. Unified autocomplete suggestion
            TagAutocompleteField(
              editorHashTagPartial: widget.editorHashTagPartial,
              tagsFieldPartial: widget.tagsFieldPartial,
              tagsText: widget.tagsCtrl.text,
              onAcceptSuggestion: widget.onAcceptSuggestion,
            ),

            // 4. Tags
            const SizedBox(height: 4),
            TextField(
              controller: widget.tagsCtrl,
              onChanged: widget.onTagsChanged,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'separados por coma: dev, personal',
                border: OutlineInputBorder(),
              ),
            ),

            // Buttons
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: state.isSaving
                      ? null
                      : () {
                          _didCancel = true;
                          _controller!.reset();
                          try { _draftNotifier?.clear(); } catch (_) { /* best-effort */ }
                          Navigator.pop(context);
                        },
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: state.isSaving ? null : _saveCreate,
                  child: state.isSaving
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

  Widget _buildHeader(
    ThemeData theme,
    CreateEntryState state,
  ) {
    return Row(
      children: [
        const Icon(Icons.add, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child:
              Text('Nueva entrada', style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: 'Comandos rápidos',
            icon: const Icon(Icons.help_outline, size: 20),
            onPressed: () => QuickCommandsSheet.show(context),
            style: IconButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ),
        const SizedBox(width: 4),
        EntryTypeSelector(
          currentType: state.effectiveType,
          isManual: state.isManual,
          showAutoOption: true,
          onSelected: _onTypeSelected,
        ),
      ],
    );
  }

  /// Banner compacto que muestra el tipo de entrada detectado del contenido.
  /// Portado del antiguo quick_add_sheet.
  Widget _buildDetectedTypeBanner(ThemeData theme, EntryType detected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            iconForType(detected),
            size: 14,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Detectado: ${labelForType(detected)} — ${_typeHints[detected]}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
