import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isSaving = false;

  static const _typeHints = {
    EntryType.note: 'Texto libre',
    EntryType.idea: '! idea genial',
    EntryType.glossary: 'Término: definición',
  };

  void _selectHint(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _onTextChanged(text);
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
      } else if (text.contains(':')) {
        _detectedType = EntryType.glossary;
      } else {
        _detectedType = EntryType.note;
      }
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);

    final detectedType = _detectedType ?? EntryType.note;
    String title;
    String content;

    switch (detectedType) {
      case EntryType.idea:
        title = text.substring(1).trim();
        content = title;
      case EntryType.glossary:
        final splitIdx = text.indexOf(':');
        title = text.substring(0, splitIdx).trim();
        content = text.substring(splitIdx + 1).trim();
      case EntryType.note:
        title = text;
        content = text;
      case EntryType.credential:
        // Credenciales van por formulario separado
        title = text;
        content = text;
    }

    try {
      // Le pasamos el tipo explícito para que no se pierda al sacar prefijos
      await ref.read(createEntryProvider).call(
        title: title,
        content: content,
        type: detectedType,
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
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
              if (detectedType != null)
                Chip(
                  avatar: Icon(_iconForType(detectedType), size: 16),
                  label: Text(_labelForType(detectedType), style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Hints
          if (detectedType == null)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: const Text('Texto libre', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.description, size: 14),
                  onPressed: () => _selectHint('Texto libre'),
                ),
                ActionChip(
                  label: const Text('! idea', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.lightbulb, size: 14),
                  onPressed: () => _selectHint('! idea genial'),
                ),
                ActionChip(
                  label: const Text('Término: definición', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.book, size: 14),
                  onPressed: () => _selectHint('Término: definición'),
                ),
                ActionChip(
                  label: const Text('🔒 Credencial', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.lock, size: 14),
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
          const SizedBox(height: 8),

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
