import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taul/core/credential_parser.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/entities/search_match.dart';
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
  final VoidCallback? onToggleFavorito;
  final VoidCallback? onToggleArchivado;
  final VoidCallback? onToggleCompletado;
  final bool isFavorito;
  final bool isArchivado;

  /// Snippet de contexto de búsqueda: cuando no es nulo, reemplaza la preview
  /// de contenido por el snippet con los términos resaltados.
  final SearchSnippet? searchSnippet;

  /// Términos de búsqueda para resaltar en el título cuando el match cae ahí.
  final List<String> searchTerms;

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
    this.onToggleFavorito,
    this.onToggleArchivado,
    this.onToggleCompletado,
    this.isFavorito = false,
    this.isArchivado = false,
    this.searchSnippet,
    this.searchTerms = const [],
  });

  IconData get _typeIcon {
    if (entry.type == EntryType.task && entry.completedAt != null) {
      return Icons.check_circle;
    }
    return switch (entry.type) {
      EntryType.glossary => Icons.book,
      EntryType.note => Icons.description,
      EntryType.idea => Icons.lightbulb,
      EntryType.credential => Icons.lock,
      EntryType.task => Icons.checklist,
    };
  }

  String get _displayContent {
    if (entry.type == EntryType.credential && entry.metadata.containsKey('username')) {
      return CredentialParser.maskUsername(entry.metadata['username']!);
    }
    if (entry.content.isEmpty) return '';
    final doc = RichTextHelper.getDocument(entry.content);
    return RichTextHelper.documentToPlainText(doc);
  }

  bool get _isExpandable => !_isCompact && entry.type != EntryType.credential;

  bool get _isCompact =>
      entry.type == EntryType.task && entry.completedAt != null;

  /// Título de la tarjeta. En contexto de búsqueda resalta los [searchTerms]
  /// en negrita con el color primario; fuera de búsqueda es el Text plano de
  /// siempre (árbol de widgets idéntico).
  Widget _buildTitle(ThemeData theme) {
    final style = theme.textTheme.titleSmall;
    final ranges = _rangesForTerms(entry.title, searchTerms);
    if (ranges.isEmpty) {
      return Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Text.rich(
      _highlightedSpan(
        text: entry.title,
        ranges: ranges,
        baseStyle: style,
        highlightStyle: _highlightStyle(theme, style),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Preview de contenido: el snippet resaltado si la búsqueda lo proveyó,
  /// si no el texto plano de siempre.
  Widget _buildContentPreview(ThemeData theme, {required int maxLines}) {
    final style = theme.textTheme.bodySmall;
    final snippet = searchSnippet;
    if (snippet != null) {
      return Text.rich(
        _highlightedSpan(
          text: snippet.text,
          ranges: snippet.highlights,
          baseStyle: style,
          highlightStyle: _highlightStyle(theme, style),
        ),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(
      _displayContent,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  TextStyle _highlightStyle(ThemeData theme, TextStyle? baseStyle) {
    return baseStyle?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ) ??
        TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        );
  }

  /// Encuentra (case-insensitive) todas las ocurrencias de cada término en
  /// [text]. Devuelve una lista vacía si no hay ningún match.
  List<HighlightRange> _rangesForTerms(String text, List<String> terms) {
    if (text.isEmpty) return const [];
    final lower = text.toLowerCase();
    final ranges = <HighlightRange>[];
    for (final term in terms) {
      final t = term.toLowerCase();
      if (t.isEmpty) continue;
      var from = 0;
      while (true) {
        final idx = lower.indexOf(t, from);
        if (idx == -1) break;
        ranges.add((start: idx, end: idx + t.length));
        from = idx + t.length;
      }
    }
    return ranges;
  }

  /// Construye un [TextSpan] con los rangos resaltados sobre [text], mergeando
  /// rangos superpuestos y preservando [baseStyle] en el resto del texto.
  TextSpan _highlightedSpan({
    required String text,
    required List<HighlightRange> ranges,
    required TextStyle? baseStyle,
    required TextStyle highlightStyle,
  }) {
    if (ranges.isEmpty) return TextSpan(text: text, style: baseStyle);

    final sorted = List<HighlightRange>.from(ranges)
      ..sort((a, b) => a.start.compareTo(b.start));
    final merged = <HighlightRange>[];
    for (final r in sorted) {
      if (merged.isEmpty || r.start > merged.last.end) {
        merged.add(r);
      } else if (r.end > merged.last.end) {
        final last = merged.removeLast();
        merged.add((start: last.start, end: r.end));
      }
    }

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final r in merged) {
      if (r.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, r.start)));
      }
      children.add(
        TextSpan(text: text.substring(r.start, r.end), style: highlightStyle),
      );
      cursor = r.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: children);
  }

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
        margin: EdgeInsets.symmetric(vertical: _isCompact ? 2 : 4),
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
                  dense: _isCompact,
                  visualDensity: _isCompact
                      ? VisualDensity.compact
                      : null,
                  leading: Icon(_typeIcon, color: theme.colorScheme.primary),
                  title: _isCompact
                      ? Text(
                          _displayContent,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : _buildTitle(theme),
                  subtitle: _isCompact
                      ? null
                      : subtitle ?? Column(
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
                      else if (!isExpanded && !_isCompact)
                        _buildContentPreview(theme, maxLines: 2),
                      // Show completedAt timestamp if present
                      if (entry.completedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Completada: ${_formatDate(entry.completedAt!)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: trailingAction ?? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Completar toggle (solo tareas)
                      if (onToggleCompletado != null && entry.type == EntryType.task)
                        GestureDetector(
                          onTap: onToggleCompletado,
                          child: Icon(
                            entry.completedAt != null
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            size: 20,
                            color: entry.completedAt != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (onToggleCompletado != null && entry.type == EntryType.task)
                        const SizedBox(width: 4),
                      // Favorito toggle
                      if (onToggleFavorito != null)
                        GestureDetector(
                          onTap: onToggleFavorito,
                          child: Icon(
                            isFavorito ? Icons.star : Icons.star_border,
                            size: 20,
                            color: isFavorito ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(width: 4),
                      // Archivado toggle
                      if (onToggleArchivado != null)
                        GestureDetector(
                          onTap: onToggleArchivado,
                          child: Icon(
                            isArchivado ? Icons.archive : Icons.archive_outlined,
                            size: 20,
                            color: isArchivado ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(width: 4),
                      if (isExpanded)
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            icon: Icon(Icons.copy, size: 16, color: theme.colorScheme.primary),
                            onPressed: () {
                              final plainContent = RichTextHelper.documentToPlainText(
                                RichTextHelper.getDocument(entry.content),
                              );
                              final text = '${entry.title}\n\n$plainContent';
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
                      else
                        Text(
                          _formatDate(entry.updatedAt),
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
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
                  if (_isCompact)
                    Text(
                      _displayContent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    _buildTitle(theme),
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
                    _buildContentPreview(theme, maxLines: 3),
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
