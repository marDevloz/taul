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
  final Color? displayColor;

  const EntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isGrid = false,
    this.trailingAction,
    this.subtitle,
    this.displayColor,
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
    final radius = BorderRadius.circular(12);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: displayColor?.withValues(alpha: 0.15) ?? theme.colorScheme.surface,
            ),
          ),
          if (displayColor != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      displayColor!,
                      displayColor!.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
          ListTile(
            leading: Icon(_typeIcon, color: theme.colorScheme.primary),
            title: Text(
              entry.title.isNotEmpty ? entry.title : '(sin título)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontStyle: entry.title.isEmpty ? FontStyle.italic : null,
                color: entry.title.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
              ),
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
        ],
      ),
    );
  }

  Widget _buildGridCard(ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: displayColor?.withValues(alpha: 0.15) ?? theme.colorScheme.surface,
            ),
          ),
          if (displayColor != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      displayColor!,
                      displayColor!.withValues(alpha: 0.4),
                    ],
                  ),
                ),
              ),
            ),
          InkWell(
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
                    entry.title.isNotEmpty ? entry.title : '(sin título)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontStyle: entry.title.isEmpty ? FontStyle.italic : null,
                      color: entry.title.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
                    ),
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
        ],
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
