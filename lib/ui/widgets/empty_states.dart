import 'package:flutter/material.dart';
import 'package:taul/domain/entities/entry_type.dart';

/// Empty state when there are no entries at all (no filter, no search).
class EmptyStateAll extends StatelessWidget {
  const EmptyStateAll({super.key, this.onCreateEntry});

  final VoidCallback? onCreateEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_note_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Todavía no hay entradas',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tocá + para crear tu primera nota, idea o glosario',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onCreateEntry != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: onCreateEntry,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Crear primera entrada'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state when a type filter is active and there are no matching entries.
class EmptyStateFiltered extends StatelessWidget {
  const EmptyStateFiltered({super.key, required this.type});

  final EntryType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (icon, typeName) = _typeInfo(type);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay entradas de tipo $typeName',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Probá cambiando el filtro o creá una nueva',
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

  (IconData, String) _typeInfo(EntryType t) => switch (t) {
    EntryType.glossary => (Icons.book, 'glosario'),
    EntryType.note => (Icons.description, 'nota'),
    EntryType.idea => (Icons.lightbulb, 'idea'),
    EntryType.credential => (Icons.lock, 'credencial'),
    EntryType.task => (Icons.checklist, 'tarea'),
  };
}

/// Empty state when a search returns no results.
class EmptyStateSearch extends StatelessWidget {
  const EmptyStateSearch({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron resultados',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Probá con otros términos',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
