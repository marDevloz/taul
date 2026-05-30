import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';

class MergeEditorScreen extends ConsumerStatefulWidget {
  final String initialText;
  final List<Entry> sourceEntries;

  const MergeEditorScreen({
    super.key,
    required this.initialText,
    required this.sourceEntries,
  });

  @override
  ConsumerState<MergeEditorScreen> createState() => _MergeEditorScreenState();
}

class _MergeEditorScreenState extends ConsumerState<MergeEditorScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Combinar entradas'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Guardar como nota'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final createEntry = ref.read(createEntryProvider);
    final now = DateTime.now();
    final title =
        'Merge ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Collect all unique tags and merge tagsColors from source entries
    final allTags = <String>{};
    final mergedTagsColors = <String, String>{};
    for (final entry in widget.sourceEntries) {
      allTags.addAll(entry.tags);
      mergedTagsColors.addAll(entry.tagsColors);
    }

    try {
      await createEntry(
        title: title,
        content: _controller.text,
        type: EntryType.note,
        tags: allTags.toList(),
        tagsColors: mergedTagsColors,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota combinada guardada')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }
}
