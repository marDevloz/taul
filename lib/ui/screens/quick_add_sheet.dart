import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/core/credential_parser.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/controllers/create_entry_controller.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  final Future<void> Function()? onCredentialRequested;

  const QuickAddSheet({super.key, this.onCredentialRequested});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _textCtrl = TextEditingController();
  bool _multiTaskSaving = false;
  late final CreateEntryController _controller;

  static const _typeHints = {
    EntryType.note: 'Texto libre',
    EntryType.idea: '!idea genial',
    EntryType.task: '[] Comprar leche',
    EntryType.glossary: 'Término:definición',
    EntryType.credential: 'servicio*user*pass*url(opcional) -#tag',
  };

  @override
  void initState() {
    super.initState();
    _controller = ref.read(createEntryControllerProvider.notifier);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _selectHint(String text) {
    _textCtrl.text = text;
    _textCtrl.selection = TextSelection.collapsed(offset: text.length);
    _onTextChanged(text);
  }

  void _setType(EntryType? type) {
    if (type == EntryType.credential) {
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const CredentialFormSheet(),
      );
    } else {
      _controller.setManualType(type);
    }
  }

  void _onTextChanged(String text) {
    final doc = RichTextHelper.plainTextToDocument(text);
    final deltaJson = RichTextHelper.documentToJson(doc);
    _controller.detectTypeFromContent(deltaJson);
  }

  /// Vista previa del parseo: computada localmente del texto plano
  /// para evitar round-trip Delta JSON en cada tecla.
  Widget _buildParsePreview() {
    final rawText = _textCtrl.text.trim();
    if (rawText.isEmpty) return const SizedBox.shrink();

    final state = ref.read(createEntryControllerProvider);
    final extracted = CreateEntryController.extractTags(rawText);
    final parsed = CreateEntryController.splitTitle(extracted.clean);
    final type = state.effectiveType;
    final tags = extracted.tags;

    final chips = <Widget>[];

    // Type chip
    chips.add(_PreviewChip(
      icon: _iconForType(type),
      label: _labelForType(type),
      color: Theme.of(context).colorScheme.primaryContainer,
    ));

    // Title chip (only if explicitly set)
    if (parsed.title.isNotEmpty) {
      chips.add(_PreviewChip(
        icon: Icons.title,
        label: '"${parsed.title}"',
        color: Theme.of(context).colorScheme.tertiaryContainer,
      ));
    }

    // Tags chips
    for (final tag in tags) {
      chips.add(_PreviewChip(
        icon: Icons.tag,
        label: tag,
        color: Theme.of(context).colorScheme.secondaryContainer,
      ));
    }

    // Credential preview (service + masked user + url)
    if (type == EntryType.credential) {
      final cred = CredentialParser.parse(rawText);
      if (cred != null) {
        chips.add(_PreviewChip(
          icon: Icons.person,
          label: CredentialParser.maskUsername(cred.username),
          color: Theme.of(context).colorScheme.errorContainer,
        ));
        if (cred.url.isNotEmpty) {
          chips.add(_PreviewChip(
            icon: Icons.link,
            label: cred.url,
            color: Theme.of(context).colorScheme.tertiaryContainer,
          ));
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: chips,
      ),
    );
  }

  Future<void> _save() async {
    final rawText = _textCtrl.text.trim();
    if (rawText.isEmpty) return;

    // --- Multi-task: varias líneas con []  → cada una es una entrada Tarea ---
    final taskLines = RichTextHelper.extractTaskLines(rawText);
    if (taskLines.isNotEmpty) {
      setState(() => _multiTaskSaving = true);
      try {
        for (final line in taskLines) {
          final clean = RichTextHelper.stripTaskMarker(line).trim();
          final extracted = CreateEntryController.extractTags(clean);
          await ref.read(createEntryProvider).call(
                title: extracted.clean,
                content: extracted.clean,
                type: EntryType.task,
                tags: extracted.tags,
              );
        }
        ref.invalidate(entryListProvider);
        ref.invalidate(tagSettingsListProvider);
        ref.invalidate(tagSettingsMapProvider);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        setState(() => _multiTaskSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e')),
          );
        }
      }
      return;
    }

    // --- Single entry via controller ---
    try {
      final saved = await _controller.save();
      if (saved && mounted) Navigator.pop(context);
    } catch (_) {
      // Error is shown via the ref.listen in build
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createEntryControllerProvider);
    final isSaving = state.isSaving || _multiTaskSaving;

    // Escuchar errores y mostrar snackbar (para single-entry path)
    ref.listen(createEntryControllerProvider.select((s) => s.error), (_, error) {
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Text('Nueva entrada', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              // Selector de tipo — compacto
              PopupMenuButton<EntryType>(
                onSelected: _setType,
                tooltip: 'Cambiar tipo',
                child: Container(
                  constraints: const BoxConstraints(minWidth: 110),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: state.isManual
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconForType(state.effectiveType), size: 14),
                      const SizedBox(width: 4),
                      Text(_labelForType(state.effectiveType), style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
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
                            ? Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary)
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
                      subtitle: const Text('detectar automáticamente', style: TextStyle(fontSize: 11)),
                      trailing: !state.isManual
                          ? Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Hints compactos
          if (state.detectedType == null)
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                ActionChip(
                  label: const Text('Texto libre', style: TextStyle(fontSize: 10)),
                  avatar: const Icon(Icons.description, size: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _selectHint('Texto libre'),
                ),
                ActionChip(
                  label: const Text('!idea', style: TextStyle(fontSize: 10)),
                  avatar: const Icon(Icons.lightbulb, size: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _selectHint('!idea genial'),
                ),
                ActionChip(
                  label: const Text('Término:def', style: TextStyle(fontSize: 10)),
                  avatar: const Icon(Icons.book, size: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _selectHint('Término:definición'),
                ),
                ActionChip(
                  label: const Text('🔒 Credencial', style: TextStyle(fontSize: 10)),
                  avatar: const Icon(Icons.lock, size: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await widget.onCredentialRequested?.call();
                    if (mounted && context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          if (state.detectedType != null)
            Text(
              _typeHints[state.detectedType]!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          const SizedBox(height: 6),

          // Text input — estilo papel de notas
          TextField(
            controller: _textCtrl,
            autofocus: true,
            onChanged: _onTextChanged,
            decoration: InputDecoration(
              hintText: 'Escribí algo...',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            maxLines: 8,
            minLines: 3,
            style: const TextStyle(height: 1.5),
          ),

          // Parse preview
          _buildParsePreview(),

          const SizedBox(height: 12),

          // Save button
          FilledButton.icon(
            onPressed: isSaving ? null : _save,
            icon: isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(isSaving ? 'Guardando...' : 'Guardar'),
          ),
        ],
      ),
    );
  }

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

/// Chip compacto para el preview de parseo.
class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PreviewChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
