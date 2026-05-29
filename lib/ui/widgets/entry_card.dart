import 'package:flutter/material.dart';
import 'package:taul/core/credential_parser.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';

class EntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;
  final bool isGrid;
  final Widget? trailingAction;
  final Widget? subtitle;

  const EntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isGrid = false,
    this.trailingAction,
    this.subtitle,
  });

  IconData get _typeIcon {
    return switch (entry.type) {
      EntryType.glossary => Icons.book,
      EntryType.note => Icons.description,
      EntryType.idea => Icons.lightbulb,
      EntryType.credential => Icons.lock,
    };
  }

  String get _displayContent {
    if (entry.type == EntryType.credential && entry.metadata.containsKey('username')) {
      return CredentialParser.maskUsername(entry.metadata['username']!);
    }
    return entry.content;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isGrid) return _buildGridCard(theme);
    return _buildListCard(theme);
  }

  Widget _buildListCard(ThemeData theme) {
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
        subtitle: subtitle ?? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _displayContent,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: trailingAction ?? Text(
          _formatDate(entry.updatedAt),
          style: theme.textTheme.labelSmall,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildGridCard(ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(_typeIcon, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
              Text(
                entry.type.label,
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                _formatDate(entry.updatedAt),
                style: theme.textTheme.labelSmall,
              ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _displayContent,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
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

