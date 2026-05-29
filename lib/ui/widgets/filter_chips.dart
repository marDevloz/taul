import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry_type.dart';
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
