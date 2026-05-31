import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taul/core/credential_parser.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/widgets/entry_expanded_content.dart';

class EntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;
  final bool isGrid;
  final Widget? trailingAction;
  final Widget? subtitle;
  final Color? displayColor;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final bool isSecure;
  final VoidCallback? onTapGated;
  final VoidCallback? onDoubleTapGated;
  final bool isSelected;
  final VoidCallback? onLongPress;

  const EntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isGrid = false,
    this.trailingAction,
    this.subtitle,
    this.displayColor,
    this.isExpanded = false,
    this.onToggle,
    this.isSecure = false,
    this.onTapGated,
    this.onDoubleTapGated,
    this.isSelected = false,
    this.onLongPress,
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

  bool get _isExpandable => entry.type != EntryType.credential;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isGrid) return _buildGridCard(theme);
    return _buildListCard(context, theme);
  }

  Widget _buildListCard(BuildContext context, ThemeData theme) {
    final radius = BorderRadius.circular(12);
    return GestureDetector(
      onTap: isSecure ? onTapGated : (!_isExpandable ? onTap : onToggle),
      onDoubleTap: isSecure ? onDoubleTapGated ?? onTap : onTap,
      onLongPress: onLongPress,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : (displayColor?.withValues(alpha: 0.15) ?? theme.colorScheme.surface),
              ),
            ),
            if (displayColor != null && !isSelected)
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
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      if (isSecure)
                        Row(
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Esta entrada está protegida',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (!isExpanded)
                        Text(
                          _displayContent,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  trailing: trailingAction ??
                      (isExpanded
                          ? SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                icon: Icon(Icons.copy, size: 16, color: theme.colorScheme.primary),
                                onPressed: () {
                                  final text = '${entry.title}\n\n${entry.content}';
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                    const SnackBar(
                                      content: Text('Contenido copiado'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                tooltip: 'Copiar título y contenido',
                              ),
                            )
                          : Text(
                              _formatDate(entry.updatedAt),
                              style: theme.textTheme.labelSmall,
                            )),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: isExpanded
                      ? EntryExpandedContent(
                          entry: entry,
                          isSecure: isSecure,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
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
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : (displayColor?.withValues(alpha: 0.15) ?? theme.colorScheme.surface),
            ),
          ),
          if (displayColor != null && !isSelected)
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
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
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
                  if (isSecure)
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Esta entrada está protegida',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
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
