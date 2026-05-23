import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';

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
