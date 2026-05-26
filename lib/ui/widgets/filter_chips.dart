import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Fila de chips para filtrar por tema.
class TopicFilterChips extends ConsumerWidget {
  const TopicFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsListProvider);
    final selectedTopic = ref.watch(selectedTopicFilterProvider);

    if (topics.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: topics.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _TopicChip(
                label: 'Temas',
                selected: selectedTopic == null,
                onSelected: () =>
                    ref.read(selectedTopicFilterProvider.notifier).state = null,
                color: theme.colorScheme.secondaryContainer,
              );
            }
            final topic = topics[index - 1];
            return _TopicChip(
              label: topic,
              selected: selectedTopic == topic,
              onSelected: () =>
                  ref.read(selectedTopicFilterProvider.notifier).state = topic,
            );
          },
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: color ?? Theme.of(context).colorScheme.secondaryContainer,
    );
  }
}

class FilterChipsRow extends ConsumerWidget {
  const FilterChipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(selectedTypeFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _buildChip(
            context: context,
            ref: ref,
            type: null,
            icon: Icons.all_inclusive,
            label: 'Todas',
            selected: selectedType == null,
          ),
          const SizedBox(width: 6),
          _buildChip(
            context: context,
            ref: ref,
            type: EntryType.glossary,
            icon: Icons.book,
            label: 'Glosario',
            selected: selectedType == EntryType.glossary,
          ),
          const SizedBox(width: 6),
          _buildChip(
            context: context,
            ref: ref,
            type: EntryType.note,
            icon: Icons.description,
            label: 'Nota',
            selected: selectedType == EntryType.note,
          ),
          const SizedBox(width: 6),
          _buildChip(
            context: context,
            ref: ref,
            type: EntryType.idea,
            icon: Icons.lightbulb,
            label: 'Idea',
            selected: selectedType == EntryType.idea,
          ),
          const SizedBox(width: 6),
          _buildChip(
            context: context,
            ref: ref,
            type: EntryType.credential,
            icon: Icons.lock,
            label: 'Credencial',
            selected: selectedType == EntryType.credential,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required WidgetRef ref,
    required EntryType? type,
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    return FilterChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref.read(selectedTypeFilterProvider.notifier).state = type,
      showCheckmark: false,
    );
  }
}
