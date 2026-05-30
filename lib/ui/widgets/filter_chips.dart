import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/color_providers.dart';
import 'package:taul/ui/providers/entry_providers.dart';

class FilterChipsRow extends ConsumerWidget {
  const FilterChipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(selectedTypeFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 26,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (context, index) {
            final (type, label, icon, active) = switch (index) {
              0 => (null, 'Todas', Icons.all_inclusive, selectedType == null),
              1 => (EntryType.glossary, 'Glosario', Icons.book, selectedType == EntryType.glossary),
              2 => (EntryType.note, 'Nota', Icons.description, selectedType == EntryType.note),
              3 => (EntryType.idea, 'Idea', Icons.lightbulb, selectedType == EntryType.idea),
              4 => (EntryType.credential, 'Credencial', Icons.lock, selectedType == EntryType.credential),
              _ => throw StateError('unreachable'),
            };
            return _TinyPill(
              icon: icon,
              label: label,
              selected: active,
              onTap: () => ref.read(selectedTypeFilterProvider.notifier).state = type,
            );
          },
        ),
      ),
    );
  }
}

/// Fila de tags compacta con animación de aparición.
/// Solo se muestra si hay tags disponibles.
/// Limita los tags visibles a [maxVisible] (ordenados por frecuencia),
/// con un botón "x más" para expandir.
class TagFilterRow extends ConsumerStatefulWidget {
  const TagFilterRow({super.key});

  @override
  ConsumerState<TagFilterRow> createState() => _TagFilterRowState();
}

class _TagFilterRowState extends ConsumerState<TagFilterRow> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsListProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final tagColors = ref.watch(tagColorMapProvider);
    final hasFilter = selectedTag != null && selectedTag.isNotEmpty;
    const maxVisible = 12;

    if (tags.isEmpty) return const SizedBox.shrink();

    final visible = _expanded ? tags : tags.take(maxVisible).toList();
    final hiddenCount = tags.length - visible.length;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          height: 22,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (hasFilter)
                _TagPill(
                  label: '✕ Todas',
                  selected: false,
                  color: Theme.of(context).colorScheme.errorContainer,
                  onTap: () {
                    ref.read(selectedTagFilterProvider.notifier).state = null;
                    setState(() => _expanded = false);
                  },
                )
              else
                const _TagPill(label: '🏷', selected: false, onTap: null),
              const SizedBox(width: 4),
              ...visible.map((tag) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _TagPill(
                  label: tag,
                  selected: selectedTag == tag,
                  color: tagColors[tag],
                  onTap: () =>
                      ref.read(selectedTagFilterProvider.notifier).state =
                          selectedTag == tag ? null : tag,
                ),
              )),
              if (hiddenCount > 0)
                _TagPill(
                  label: '+$hiddenCount',
                  selected: false,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  onTap: () => setState(() => _expanded = true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TinyPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  const _TagPill({
    required this.label,
    required this.selected,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = color ??
        (selected
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest);
    final fgColor = selected
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: fgColor, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
