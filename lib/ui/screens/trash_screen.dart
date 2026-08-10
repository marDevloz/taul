import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:taul/core/errors/error_mapper.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/widgets/entry_card.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashAsync = ref.watch(trashListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Papelera'),
        actions: [
          trashAsync.when(
            data: (entries) => entries.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: 'Vaciar papelera',
                    onPressed: () => _confirmEmptyTrash(context, ref),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: trashAsync.when(
        data: (entries) => entries.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: entries.length,
                itemBuilder: (_, index) =>
                    _buildTrashItem(context, ref, entries[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          Logger().e('Trash list failed', error: err);
          return Center(child: Text(const ErrorMapper().toUserMessage(err)));
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'La papelera está vacía',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Las entradas eliminadas aparecerán aquí',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrashItem(BuildContext context, WidgetRef ref, Entry entry) {
    final theme = Theme.of(context);
    final deletedDate = entry.deletedAt!;

    return EntryCard(
      entry: entry,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Eliminado: ${_formatDate(deletedDate)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
      trailingAction: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) =>
            _handleAction(context, ref, entry, value),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'restore',
            child: ListTile(
              leading: Icon(Icons.restore),
              title: Text('Restaurar'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text(
                'Eliminar permanentemente',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
    String value,
  ) async {
    if (value == 'restore') {
      await _restoreEntry(context, ref, entry);
    } else if (value == 'delete') {
      await _permanentlyDelete(context, ref, entry);
    }
  }

  Future<void> _restoreEntry(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
  ) async {
    await ref.read(restoreEntryProvider).call(entry.id);
    ref.invalidate(trashListProvider);
    ref.invalidate(entryListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrada restaurada')),
      );
    }
  }

  Future<void> _permanentlyDelete(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar permanentemente'),
        content: const Text(
          'Esta acción no se puede deshacer. '
          'La entrada se borrará de forma permanente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(entryRepositoryProvider).hardDelete(entry.id);
    ref.invalidate(trashListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrada eliminada permanentemente')),
      );
    }
  }

  Future<void> _confirmEmptyTrash(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar papelera'),
        content: const Text(
          '¿Eliminar todas las entradas de la papelera '
          'permanentemente? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final count = await ref.read(emptyTrashProvider).call();
    ref.invalidate(trashListProvider);
    ref.invalidate(entryListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count entradas eliminadas permanentemente')),
      );
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
