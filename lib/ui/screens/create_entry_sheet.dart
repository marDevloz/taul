import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/controllers/create_entry_controller.dart';
import 'package:taul/ui/providers/entry_draft_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';
import 'package:taul/ui/widgets/rich_text_editor.dart';

/// Full entry creation sheet with title, rich text editor, tags, and type.
///
/// Ported parsing logic from [QuickAddSheet]: auto-detect type from content
/// (regex `\w:` for glossary, `*` for credential, `!` for idea), extract
/// `Title# ` for auto-title, extract `-#tag` for auto-tags, and parse
/// credentials with [CredentialParser] at save time.
class CreateEntrySheet extends ConsumerStatefulWidget {
  final Future<void> Function()? onCredentialRequested;

  const CreateEntrySheet({super.key, this.onCredentialRequested});

  @override
  ConsumerState<CreateEntrySheet> createState() => _CreateEntrySheetState();
}

class _CreateEntrySheetState extends ConsumerState<CreateEntrySheet> {
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _didSaveSuccessfully = false;
  late final EntryDraftNotifier _draftNotifier;
  late final CreateEntryController _controller;
  CreateEntryState? _pendingDisposeState;

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
    _pendingDisposeState = ref.read(createEntryControllerProvider);

    // Diferir restauración de draft para evitar modificar providers
    // durante la construcción del árbol en tests.
    Future.microtask(() {
      if (!mounted) return;
      _restoreDraft();
    });
  }

  void _restoreDraft() {
    final draft = ref.read(entryDraftProvider);
    if (draft != null) {
      _titleCtrl.text = draft.title;
      _tagsCtrl.text = draft.tags;
      _controller.loadDraft(draft);
      if (draft.content.isNotEmpty) {
        _controller.detectTypeFromContent(draft.content);
      }
    }
  }

  @override
  void dispose() {
    if (!_didSaveSuccessfully) {
      final hasContent = _titleCtrl.text.isNotEmpty ||
          _pendingDisposeState!.content.isNotEmpty ||
          _tagsCtrl.text.isNotEmpty;
      if (hasContent) {
        final draft = EntryDraft(
          title: _titleCtrl.text,
          content: _pendingDisposeState!.content,
          tags: _tagsCtrl.text,
          manualType: _pendingDisposeState!.manualType,
        );
        // Diferir para evitar modificar provider durante el unmount del árbol
        Future.microtask(() {
          try {
            _draftNotifier.save(draft);
          } catch (_) {}
        });
      } else {
        Future.microtask(() {
          try {
            _draftNotifier.clear();
          } catch (_) {}
        });
      }
    }
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(createEntryControllerProvider);

    // Escuchar errores y mostrar snackbar
    ref.listen(createEntryControllerProvider.select((s) => s.error), (_, error) {
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        children: [
          // Formulario: ocupa el espacio vertical disponible
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header con selector de tipo
                Row(
                  children: [
                    const Icon(Icons.add, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Nueva entrada', style: theme.textTheme.titleMedium),
                    ),
                    // Botón ayuda - siempre visible
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        tooltip: 'Comandos rápidos',
                        icon: const Icon(Icons.help_outline, size: 20),
                        onPressed: _showQuickCommands,
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<EntryType?>(
                      onSelected: (value) {
                        if (value == EntryType.credential) {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const CredentialFormSheet(),
                          );
                        } else {
                          _controller.setManualType(value);
                        }
                      },
                      tooltip: 'Cambiar tipo',
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 110),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: state.isManual
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_iconForType(state.effectiveType), size: 14),
                            const SizedBox(width: 4),
                            Text(_labelForType(state.effectiveType), style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                      itemBuilder: (_) => [
                        ...EntryType.values.map(
                              (t) => PopupMenuItem(
                                value: t,
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(_iconForType(t), size: 18),
                                  title: Text(_labelForType(t), style: const TextStyle(fontSize: 13)),
                                  trailing: state.effectiveType == t && state.isManual
                                      ? Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                                      : null,
                                ),
                              ),
                            ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: null,
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.sync, size: 18),
                            title: const Text('Auto', style: TextStyle(fontSize: 13)),
                            subtitle: const Text('detectar del contenido', style: TextStyle(fontSize: 11)),
                            trailing: !state.isManual
                                ? Icon(Icons.check, size: 16, color: theme.colorScheme.primary)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Título
                TextField(
                  controller: _titleCtrl,
                  onChanged: _controller.setTitle,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'o escribí Titulo# en el contenido',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Tags (arriba del editor)
                TextField(
                  controller: _tagsCtrl,
                  onChanged: _controller.setTags,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'o usá -#tag en el contenido',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Contenido rich text (con scroll interno)
                const Text('Contenido', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Expanded(
                  child: RichTextEditor(
                    initialContent: state.content,
                    onChanged: _controller.detectTypeFromContent,
                    hintText: state.detectedType != null
                        ? _typeHints[state.detectedType]
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Botones (siempre visibles al final)
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: state.isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: state.isSaving ? null : _save,
                child: state.isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ],
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
              Text('Comandos rápidos', style: Theme.of(context).textTheme.titleMedium),
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
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    try {
      final saved = await _controller.save();
      if (saved) {
        _didSaveSuccessfully = true;
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      // Error is handled by the ref.listen above
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers de UI
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

/// Widget auxiliar para el diálogo de comandos rápidos.
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
