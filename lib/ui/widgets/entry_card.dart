import 'package:flutter/material.dart';
import 'package:taul/domain/entities/entry.dart';

class EntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;

  const EntryCard({super.key, required this.entry, this.onTap});

  IconData get _typeIcon {
    switch (entry.type) {
      case var e when e.label == 'GLOSARIO':
        return Icons.book;
      case var e when e.label == 'NOTA':
        return Icons.description;
      case var e when e.label == 'IDEA':
        return Icons.lightbulb;
      case var e when e.label == 'CREDENCIAL':
        return Icons.lock;
      default:
        return Icons.article;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(_typeIcon, color: theme.colorScheme.primary),
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          entry.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          _formatDate(entry.updatedAt),
          style: theme.textTheme.labelSmall,
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }
}
