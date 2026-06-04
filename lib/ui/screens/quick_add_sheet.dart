import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/core/credential_parser.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  final Future<void> Function()? onCredentialRequested;

  const QuickAddSheet({super.key, this.onCredentialRequested});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _controller = TextEditingController();
  EntryType? _detectedType;
  EntryType? _manualType;
  bool _isSaving = false;

  static const _typeHints = {
    EntryType.note: 'Texto libre',
    EntryType.idea: '!idea genial',
    EntryType.task: '[] Comprar leche',
    EntryType.glossary: 'Término:definición',
    EntryType.credential: 'servicio*user*pass*url(opcional) -#tag',
  };

  /// Tipo efectivo: si el usuario eligió uno manual, ese; si no, el auto-detectado.
  EntryType get _effectiveType => _manualType ?? _detectedType ?? EntryType.note;

  bool get _isManual => _manualType != null;

  void _selectHint(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _onTextChanged(text);
  }

  void _setType(EntryType? type) {
    setState(() => _manualType = type);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Busca "Title# " al inicio del texto y devuelve title + el resto.
  /// El separador es `#` solo — tags ahora usan `-#` así que no hay colisión.
  /// Ej: "Salsa# !idea genial" → (title:"Salsa", rest:"!idea genial")
  ({String title, String rest}) _splitTitle(String raw) {
    for (int i = 0; i < raw.length; i++) {
      if (raw[i] == '#' && i + 1 < raw.length && raw[i + 1] == ' ') {
        return (
          title: raw.substring(0, i).trim(),
          rest: raw.substring(i + 1).trim(),
        );
      }
    }
    return (title: '', rest: raw);
  }

  void _onTextChanged(String text) {
    // Ignorar el Title# para la detección de tipo
    final rest = _splitTitle(text).rest;
    setState(() {
      if (rest.startsWith('!')) {
        _detectedType = EntryType.idea;
      } else if (RichTextHelper.startsWithTaskMarker(rest)) {
        _detectedType = EntryType.task;
      } else if (rest.contains('*')) {
        _detectedType = EntryType.credential;
      } else if (RegExp(r'\w:').hasMatch(rest)) {
        // Detect "word:" pattern for glossary (no space before :)
        _detectedType = EntryType.glossary;
      } else {
        _detectedType = EntryType.note;
      }
    });
  }

  /// Extrae los -#tags de un texto y devuelve el texto limpio + los tags.
  /// El formato exacto es `-#tag` — el `-` antes de `#` es el marker.
  /// Los tags pueden contener guiones: `-#gol-caracol`.
  ({String clean, List<String> tags}) _extractTags(String raw) =>
      RichTextHelper.extractTags(raw);

  /// Vista previa del parseo: muestra tipo detectado, título y tags.
  Widget _buildParsePreview() {
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) return const SizedBox.shrink();

    final extracted = _extractTags(rawText);
    final parsed = _splitTitle(extracted.clean);
    final type = _effectiveType;
    final tags = extracted.tags;

    // Build preview chips
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
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) return;

    setState(() => _isSaving = true);

    // --- Multi-task: varias líneas con []  → cada una es una entrada Tarea ---
    final taskLines = RichTextHelper.extractTaskLines(rawText);
    if (taskLines.isNotEmpty) {
      try {
        for (final line in taskLines) {
          final clean = RichTextHelper.stripTaskMarker(line).trim();
          final extracted = _extractTags(clean);
          await ref.read(createEntryProvider).call(
                title: extracted.clean,
                content: extracted.clean,
                type: EntryType.task,
                tags: extracted.tags,
              );
        }
        ref.invalidate(entryListProvider);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e')),
          );
        }
      }
      return;
    }

    // --- Single entry ---
    final extracted = _extractTags(rawText);
    final text = extracted.clean;
    List<String> tags = extracted.tags;

    final parsed = _splitTitle(text);
    String entryTitle = parsed.title;
    final body = parsed.rest;

    var type = _effectiveType;
    String content;
    Map<String, String> metadata = {};
    String? secret;
    bool requiresAuth = false;

    switch (type) {
      case EntryType.idea:
        content = body.startsWith('!') ? body.substring(1).trim() : body;
      case EntryType.glossary:
        final splitIdx = body.indexOf(':');
        if (splitIdx >= 0) {
          if (entryTitle.isEmpty) {
            entryTitle = body.substring(0, splitIdx).trim();
          }
          content = body.substring(splitIdx + 1).trim();
        } else {
          content = body;
        }
      case EntryType.credential:
        final parsedCred = CredentialParser.parse(rawText);
        if (parsedCred != null) {
          if (entryTitle.isEmpty) entryTitle = parsedCred.service;
          content = parsedCred.username.isNotEmpty
              ? 'Usuario: ${parsedCred.username}'
              : parsedCred.service;
          metadata = {
            if (parsedCred.username.isNotEmpty) 'username': parsedCred.username,
            if (parsedCred.url.isNotEmpty) 'url': parsedCred.url,
          };
          secret = parsedCred.password;
          requiresAuth = true;
          tags = {...tags, ...parsedCred.tags}.toList();
        } else {
          type = EntryType.note;
          content = body;
        }
      case EntryType.note:
        content = body;
      case EntryType.task:
        content = RichTextHelper.stripTaskMarker(body).trim();
    }

    try {
      await ref.read(createEntryProvider).call(
            title: entryTitle,
            content: content,
            type: type,
            secret: secret,
            requiresAuth: requiresAuth,
            metadata: metadata,
            tags: tags,
          );
      ref.invalidate(entryListProvider);
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

  @override
  Widget build(BuildContext context) {
    final detectedType = _detectedType;

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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isManual
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconForType(_effectiveType), size: 14),
                      const SizedBox(width: 4),
                      Text(_labelForType(_effectiveType), style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey.shade600),
                    ],
                  ),
                ),
                itemBuilder: (_) => [
                  ...EntryType.values.where((t) => t != EntryType.credential).map(
                    (t) => PopupMenuItem(
                      value: t,
                      child: ListTile(
                        dense: true,
                        leading: Icon(_iconForType(t), size: 18),
                        title: Text(_labelForType(t), style: const TextStyle(fontSize: 13)),
                        trailing: _effectiveType == t
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
                      trailing: !_isManual
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
          if (detectedType == null)
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
          if (detectedType != null)
            Text(
              _typeHints[detectedType]!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          const SizedBox(height: 6),

          // Text input — estilo papel de notas
          TextField(
            controller: _controller,
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
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
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
