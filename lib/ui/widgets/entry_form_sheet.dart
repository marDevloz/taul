import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/ui/controllers/create_entry_controller.dart';
import 'package:taul/ui/providers/entry_draft_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';
import 'package:taul/ui/widgets/rich_text_editor.dart';
import 'package:taul/ui/widgets/tag_suggestions.dart';

/// Unified entry form sheet for both creating and editing entries.
///
/// When [entry] is null, operates in create mode with draft support.
/// When [entry] is non-null, operates in edit mode.
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

  // Create mode — nullable, only initialized when !_isEditing
  bool _didSaveSuccessfully = false;
  EntryDraftNotifier? _draftNotifier;
  CreateEntryController? _controller;
  CreateEntryState? _pendingDisposeState;

  // Tag autocomplete
  String? _editorHashTagPartial;
  String _tagsFieldPartial = '';

  // Edit mode — nullable, only initialized when _isEditing
  EntryType? _selectedType;
  bool _isSaving = false;
  String _richContent = '';

  bool get _isEditing => widget.entry != null;

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
    if (_isEditing) {
      final entry = widget.entry!;
      _selectedType = entry.type;
      _richContent = entry.content;
      _titleCtrl.text = entry.title;
      _tagsCtrl.text = entry.tags.join(', ');
    } else {
      _draftNotifier = ref.read(entryDraftProvider.notifier);
      _controller = ref.read(createEntryControllerProvider.notifier);
      _pendingDisposeState = ref.read(createEntryControllerProvider);
      Future.microtask(() {
        if (!mounted) return;
        _restoreDraft();
      });
    }
  }

  void _restoreDraft() {
    final draft = ref.read(entryDraftProvider);
    if (draft != null) {
      _titleCtrl.text = draft.title;
      _tagsCtrl.text = draft.tags;
      _controller!.loadDraft(draft);
      if (draft.content.isNotEmpty) {
        _controller!.detectTypeFromContent(draft.content);
      }
    }
  }

  @override
  void dispose() {
    if (!_isEditing && !_didSaveSuccessfully) {
      final hasContent =
          _titleCtrl.text.isNotEmpty ||
          (_pendingDisposeState?.content ?? '').isNotEmpty ||
          _tagsCtrl.text.isNotEmpty;
      if (hasContent) {
        final draft = EntryDraft(
          title: _titleCtrl.text,
          content: _pendingDisposeState?.content ?? '',
          tags: _tagsCtrl.text,
          manualType: _pendingDisposeState?.manualType,
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
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Editor & tag query detection
  // ---------------------------------------------------------------------------

  void _onContentChanged(String content) {
    if (_isEditing) {
      setState(() => _richContent = content);
    } else {
      _controller?.detectTypeFromContent(content);
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
      _controller?.setTags(text);
    }
    final parts = text.split(',');
    final partial = parts.last.trim();
    if (partial != _tagsFieldPartial) {
      setState(() => _tagsFieldPartial = partial);
    }
  }

  /// Unified suggestion: editor `-#` takes priority, then tags field partial.
  TagSetting? _unifiedSuggestion(List<TagSetting> allTags) {
    final selectedTags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // Editor -# tag has priority
    if (_editorHashTagPartial != null && _editorHashTagPartial!.isNotEmpty) {
      final suggestions = filterTagSuggestions(
        query: _editorHashTagPartial!,
        allTags: allTags,
        selectedTags: selectedTags,
        maxSuggestions: 1,
      );
      if (suggestions.isNotEmpty) return suggestions.first;
    }

    // Tags field partial
    if (_tagsFieldPartial.isNotEmpty) {
      final suggestions = filterTagSuggestions(
        query: _tagsFieldPartial,
        allTags: allTags,
        selectedTags: selectedTags,
        maxSuggestions: 1,
      );
      if (suggestions.isNotEmpty) return suggestions.first;
    }

    return null;
  }

  void _acceptSuggestion(TagSetting tag) {
    final editorState = _editorKey.currentState;
    if (editorState != null && _editorHashTagPartial != null) {
      editorState.acceptTagSuggestion(tag.name);
      setState(() => _editorHashTagPartial = null);
    } else {
      final currentText = _tagsCtrl.text;
      final parts = currentText.split(',');
      if (parts.length > 1) {
        parts[parts.length - 1] = ' ${tag.name},';
      } else {
        parts[parts.length - 1] = '${tag.name},';
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
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _saveCreate() async {
    try {
      final saved = await _controller!.save();
      if (saved) {
        _didSaveSuccessfully = true;
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      // Error is handled by the ref.listen in build
    }
  }

  Future<void> _saveEdit() async {
    final entry = widget.entry!;
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

      final manualTags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final tags = {...manualTags, ...contentTags}.toList();

      await ref.read(updateEntryProvider).call(
        entry,
        title: _titleCtrl.text,
        content: content,
        tags: tags,
        type: _selectedType ?? entry.type,
      );
      ref.invalidate(entryDetailProvider(widget.entryId!));
      ref.invalidate(entryListProvider);
      ref.invalidate(tagSettingsListProvider);
      ref.invalidate(tagSettingsMapProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isEditing) {
      return _buildEditForm(theme);
    }
    return _buildCreateForm(theme);
  }

  Widget _buildCreateForm(ThemeData theme) {
    final state = ref.watch(createEntryControllerProvider);
    final allTags = ref.watch(tagSettingsListProvider).valueOrNull ?? [];

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

    final suggestion = _unifiedSuggestion(allTags);

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
            _buildHeader(theme, Icons.add, 'Nueva entrada'),
            const SizedBox(height: 16),

            // 1. Title
            TextField(
              controller: _titleCtrl,
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
              key: _editorKey,
              initialContent: state.content,
              onChanged: _onContentChanged,
              maxHeight: 200,
              hintText: state.detectedType != null
                  ? _typeHints[state.detectedType]
                  : null,
            ),
            const SizedBox(height: 4),

            // 3. Unified autocomplete suggestion
            if (suggestion != null)
              GestureDetector(
                onTap: () => _acceptSuggestion(suggestion),
                child: _buildSuggestionChip(theme, suggestion),
              ),

            // 4. Tags
            const SizedBox(height: 4),
            TextField(
              controller: _tagsCtrl,
              onChanged: _onTagsChanged,
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
                          _draftNotifier?.clear();
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

  Widget _buildEditForm(ThemeData theme) {
    final allTags = ref.watch(tagSettingsListProvider).valueOrNull ?? [];
    final suggestion = _unifiedSuggestion(allTags);

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
            _buildHeader(theme, Icons.edit_note, 'Editar entrada'),
            const SizedBox(height: 16),

            // 1. Title
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Type selector
            _buildTypeSelector(theme),
            const SizedBox(height: 12),

            // 3. Content (rich text editor)
            const Text('Contenido', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            RichTextEditor(
              key: _editorKey,
              initialContent: _richContent,
              onChanged: _onContentChanged,
              maxHeight: 200,
            ),
            const SizedBox(height: 4),

            // 4. Unified autocomplete suggestion
            if (suggestion != null)
              GestureDetector(
                onTap: () => _acceptSuggestion(suggestion),
                child: _buildSuggestionChip(theme, suggestion),
              ),

            // 5. Tags
            const SizedBox(height: 4),
            TextField(
              controller: _tagsCtrl,
              onChanged: _onTagsChanged,
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

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _buildHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        if (!_isEditing)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Comandos rápidos',
              icon: const Icon(Icons.help_outline, size: 20),
              onPressed: _showQuickCommands,
              style: IconButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ),
        if (!_isEditing) const SizedBox(width: 4),
        _buildTypeSelectorButton(theme),
      ],
    );
  }

  Widget _buildTypeSelectorButton(ThemeData theme) {
    final EntryType effectiveType;
    final bool isManual;

    if (_isEditing) {
      effectiveType = _selectedType ?? widget.entry!.type;
      isManual = true;
    } else {
      final state = ref.watch(createEntryControllerProvider);
      effectiveType = state.effectiveType;
      isManual = state.isManual;
    }

    return PopupMenuButton<EntryType?>(
      onSelected: _onTypeSelected,
      tooltip: 'Cambiar tipo',
      child: Container(
        constraints: const BoxConstraints(minWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isManual
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForType(effectiveType), size: 14),
            const SizedBox(width: 4),
            Text(
              _labelForType(effectiveType),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (_) => _buildTypeMenuItems(theme),
    );
  }

  List<PopupMenuEntry<EntryType?>> _buildTypeMenuItems(ThemeData theme) {
    final EntryType effectiveType;
    final bool isManual;

    if (_isEditing) {
      effectiveType = _selectedType ?? widget.entry!.type;
      isManual = true;
    } else {
      final state = ref.watch(createEntryControllerProvider);
      effectiveType = state.effectiveType;
      isManual = state.isManual;
    }

    return [
      ...EntryType.values.map(
        (t) => PopupMenuItem(
          value: t,
          child: ListTile(
            dense: true,
            leading: Icon(_iconForType(t), size: 18),
            title: Text(
              _labelForType(t),
              style: const TextStyle(fontSize: 13),
            ),
            trailing: effectiveType == t && isManual
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.primary,
                  )
                : null,
          ),
        ),
      ),
      if (!_isEditing) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: null,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.sync, size: 18),
            title: const Text(
              'Auto',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'detectar del contenido',
              style: TextStyle(fontSize: 11),
            ),
            trailing: !isManual
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.primary,
                  )
                : null,
          ),
        ),
      ],
    ];
  }

  void _onTypeSelected(EntryType? value) {
    if (value == EntryType.credential) {
      Navigator.pop(context);
      if (_isEditing) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => CredentialFormSheet(entry: widget.entry),
        );
      } else {
        widget.onCredentialRequested?.call();
      }
      return;
    }

    if (_isEditing) {
      setState(() => _selectedType = value);
    } else {
      _controller?.setManualType(value);
    }
  }

  Widget _buildTypeSelector(ThemeData theme) {
    final currentType = _selectedType ?? widget.entry!.type;
    return Row(
      children: [
        Text('Tipo:', style: theme.textTheme.bodySmall),
        const SizedBox(width: 8),
        PopupMenuButton<EntryType>(
          onSelected: (t) {
            if (t == EntryType.credential) {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => CredentialFormSheet(entry: widget.entry),
              );
            } else {
              setState(() => _selectedType = t);
            }
          },
          child: Container(
            constraints: const BoxConstraints(minWidth: 110),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconForType(currentType), size: 14),
                const SizedBox(width: 4),
                Text(
                  _labelForType(currentType),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          itemBuilder: (_) => EntryType.values
              .map(
                (t) => PopupMenuItem(
                  value: t,
                  child: ListTile(
                    dense: true,
                    leading: Icon(_iconForType(t), size: 18),
                    title: Text(
                      _labelForType(t),
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: currentType == t
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(ThemeData theme, TagSetting suggestion) {
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

  // ---------------------------------------------------------------------------
  // Quick commands help
  // ---------------------------------------------------------------------------

  void _showQuickCommands() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comandos rápidos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: const [
                    _CommandEntry(
                      prefix: '! ',
                      example: '!idea genial',
                      description: 'Crear idea',
                    ),
                    _CommandEntry(
                      prefix: '[] ',
                      example: '[] Comprar leche',
                      description: 'Crear tarea (o múltiples líneas con [])',
                    ),
                    _CommandEntry(
                      prefix: '',
                      example: 'Término: definición',
                      description: 'Crear glosario',
                    ),
                    _CommandEntry(
                      prefix: '',
                      example: 'servicio*user*pass*url -#tag',
                      description: 'Crear credencial (opcional url y tags)',
                    ),
                    _CommandEntry(
                      prefix: 'Título# ',
                      example: 'Mi título# contenido',
                      description: 'Título explícito para cualquier tipo',
                    ),
                    _CommandEntry(
                      prefix: '-#',
                      example: 'texto -#tag1 -#tag2',
                      description: 'Agregar tags a cualquier entrada',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  IconData _iconForType(EntryType type) {
    return switch (type) {
      EntryType.note => Icons.description,
      EntryType.idea => Icons.lightbulb,
      EntryType.glossary => Icons.book,
      EntryType.credential => Icons.lock,
      EntryType.task => Icons.checklist,
    };
  }

  String _labelForType(EntryType type) {
    return switch (type) {
      EntryType.note => 'Nota',
      EntryType.idea => 'Idea',
      EntryType.glossary => 'Glosario',
      EntryType.credential => 'Credencial',
      EntryType.task => 'Tarea',
    };
  }
}

class _CommandEntry extends StatelessWidget {
  final String prefix;
  final String example;
  final String description;

  const _CommandEntry({
    required this.prefix,
    required this.example,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                prefix,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  example,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
