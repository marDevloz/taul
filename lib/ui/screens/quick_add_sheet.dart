import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _controller = TextEditingController();
  EntryType? _detectedType;
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    setState(() {
      if (text.startsWith('!')) {
        _detectedType = EntryType.idea;
      } else if (text.startsWith('+')) {
        _detectedType = EntryType.credential;
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

    String title;
    String content;

    if (text.startsWith('!')) {
      title = text.substring(1).trim();
      content = title;
    } else if (text.startsWith('+')) {
      final parts = text.substring(1).trim().split(' ');
      title = parts.isNotEmpty ? parts[0] : 'Credential';
      content = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    } else if (text.contains(':')) {
      final splitIdx = text.indexOf(':');
      title = text.substring(0, splitIdx).trim();
      content = text.substring(splitIdx + 1).trim();
    } else {
      title = text;
      content = text;
    }

    try {
      await ref.read(createEntryProvider).call(title: title, content: content);
      ref.invalidate(entryListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Text('Quick Add', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_detectedType != null)
                Chip(label: Text(_detectedType!.label, style: const TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onTextChanged,
            decoration: const InputDecoration(
              hintText: 'Type something...',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            minLines: 1,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }
}
