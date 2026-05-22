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
          _buildChip(context, ref, null, 'Todas', selectedType == null),
          const SizedBox(width: 6),
          _buildChip(context, ref, EntryType.glossary, '📖', selectedType == EntryType.glossary),
          const SizedBox(width: 6),
          _buildChip(context, ref, EntryType.note, '📝', selectedType == EntryType.note),
          const SizedBox(width: 6),
          _buildChip(context, ref, EntryType.idea, '💡', selectedType == EntryType.idea),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, WidgetRef ref, EntryType? type, String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref.read(selectedTypeFilterProvider.notifier).state = type,
    );
  }
}
