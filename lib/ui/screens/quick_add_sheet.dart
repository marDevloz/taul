import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/core/credential_parser.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  final VoidCallback? onCredentialRequested;

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
    EntryType.idea: '! idea genial',
    EntryType.glossary: 'Término: definición',
    EntryType.credential: 'servicio,*usuario,*contraseña,#tag1,tag2',
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

  void _onTextChanged(String text) {
    setState(() {
      if (text.startsWith('!')) {
        _detectedType = EntryType.idea;
      } else if (text.contains('*')) {
        _detectedType = EntryType.credential;
      } else if (text.contains(':')) {
        _detectedType = EntryType.glossary;
      } else {
        _detectedType = EntryType.note;
      }
    });
  }

  /// Extrae los #tags de un texto y devuelve el texto limpio + los tags.
  ({String clean, List<String> tags}) _extractTags(String raw) {
    final re = RegExp(r'#(\w+)');
    final matches = re.allMatches(raw);
    final tags = matches.map((m) => m.group(1)!).toList();
    final clean = raw.replaceAll(re, '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return (clean: clean, tags: tags);
  }

  Future<void> _save() async {
    final rawText = _controller.text.trim();
    if (rawText.isEmpty) return;

    setState(() => _isSaving = true);

    // Extraer #tags de todo el texto primero (aplica a todos los tipos)
    final extracted = _extractTags(rawText);
    final text = extracted.clean;
    List<String> tags = extracted.tags;

    final type = _effectiveType;
    String title;
    String content;
    Map<String, String> metadata = {};
    String? secret;
    bool requiresAuth = false;

    switch (type) {
      case EntryType.idea:
        title = text.substring(1).trim();
        content = title;
      case EntryType.glossary:
        final splitIdx = text.indexOf(':');
        title = text.substring(0, splitIdx).trim();
        content = text.substring(splitIdx + 1).trim();
      case EntryType.credential:
        final parsed = CredentialParser.parse(rawText);
        if (parsed != null) {
          title = parsed.service;
          content = parsed.username.isNotEmpty ? 'Usuario: ${parsed.username}' : parsed.service;
          metadata = {'username': parsed.username};
          secret = parsed.password;
          requiresAuth = true;
          // Fusionar tags sin duplicar: _extractTags ya atrapó #tag,
          // CredentialParser además atrapa el formato #tag1,tag2
          tags = {...tags, ...parsed.tags}.toList();
        } else {
          title = text;
          content = text;
        }
      case EntryType.note:
        title = text;
        content = text;
    }

    try {
      await ref.read(createEntryProvider).call(
        title: title,
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
                  label: const Text('! idea', style: TextStyle(fontSize: 10)),
                  avatar: const Icon(Icons.lightbulb, size: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _selectHint('! idea genial'),
                ),
                ActionChip(
                  label: const Text('Término: definición', style: TextStyle(fontSize: 10)),
                  avatar: const Icon(Icons.book, size: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _selectHint('Término: definición'),
                ),
                ActionChip(
                  label: const Text('🔒 Credencial', style: TextStyle(fontSize: 10)),
                  avatar: const Icon(Icons.lock, size: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCredentialRequested?.call();
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

          // Text input
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onTextChanged,
            decoration: const InputDecoration(
              hintText: 'Escribí algo...',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            minLines: 1,
          ),
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
    };
  }

  String _labelForType(EntryType type) {
    return switch (type) {
      EntryType.note => 'Nota',
      EntryType.idea => 'Idea',
      EntryType.glossary => 'Glosario',
      EntryType.credential => 'Credencial',
    };
  }
}
