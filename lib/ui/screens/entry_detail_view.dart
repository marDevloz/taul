import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/ui/providers/entry_providers.dart';

class EntryDetailView extends ConsumerWidget {
  final String entryId;

  const EntryDetailView({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(entryDetailProvider(entryId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: entryAsync.when(
        data: (entry) => _EntryContent(entry: entry),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final entry = ref.read(entryDetailProvider(entryId)).valueOrNull;
    if (entry == null) return;

    final titleCtrl = TextEditingController(text: entry.title);
    final contentCtrl = TextEditingController(text: entry.content);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Content'), maxLines: 5),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(updateEntryProvider).call(
                entry,
                title: titleCtrl.text,
                content: contentCtrl.text,
              );
              ref.invalidate(entryDetailProvider(entryId));
              ref.invalidate(entryListProvider);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Move to trash? You can restore later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              await ref.read(deleteEntryProvider).call(entryId);
              ref.invalidate(entryListProvider);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _EntryContent extends StatelessWidget {
  final Entry entry;

  const _EntryContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(label: Text(entry.type.label)),
          const SizedBox(height: 8),
          Text(entry.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(entry.content, style: theme.textTheme.bodyLarge),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              children: entry.tags.map((t) => Chip(label: Text(t))).toList(),
            ),
          ],
          if (entry.topicKey != null) ...[
            const SizedBox(height: 8),
            Text('Topic: ${entry.topicKey}', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 24),
          Text('Created: ${_formatDate(entry.createdAt)}', style: theme.textTheme.bodySmall),
          Text('Updated: ${_formatDate(entry.updatedAt)}', style: theme.textTheme.bodySmall),
          Text('Version: ${entry.version}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
