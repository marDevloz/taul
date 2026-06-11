import 'package:flutter/material.dart';
import 'package:taul/domain/entities/entry_type.dart';

/// Icon for the given [EntryType].
IconData iconForType(EntryType type) {
  return switch (type) {
    EntryType.note => Icons.description,
    EntryType.idea => Icons.lightbulb,
    EntryType.glossary => Icons.book,
    EntryType.credential => Icons.lock,
    EntryType.task => Icons.checklist,
  };
}

/// Localized label for the given [EntryType].
String labelForType(EntryType type) {
  return switch (type) {
    EntryType.note => 'Nota',
    EntryType.idea => 'Idea',
    EntryType.glossary => 'Glosario',
    EntryType.credential => 'Credencial',
    EntryType.task => 'Tarea',
  };
}

/// A popup menu button that lets the user pick an [EntryType].
///
/// When [showAutoOption] is true, an additional "Auto" entry is shown
/// (used in create mode) to allow automatic type detection from content.
class EntryTypeSelector extends StatelessWidget {
  /// The currently selected type.
  final EntryType currentType;

  /// Whether the current type was manually selected (vs auto-detected).
  final bool isManual;

  /// Whether to show the "Auto" option for automatic type detection.
  final bool showAutoOption;

  /// Called when a type is selected. Receives `null` for "Auto".
  final ValueChanged<EntryType?> onSelected;

  const EntryTypeSelector({
    super.key,
    required this.currentType,
    required this.isManual,
    this.showAutoOption = false,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<EntryType?>(
      onSelected: onSelected,
      tooltip: 'Cambiar tipo',
      child: _buildButton(context),
      itemBuilder: (_) => _buildMenuItems(context),
    );
  }

  Widget _buildButton(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isManual
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForType(currentType), size: 14),
          const SizedBox(width: 4),
          Text(
            labelForType(currentType),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<EntryType?>> _buildMenuItems(BuildContext context) {
    final theme = Theme.of(context);
    return [
      ...EntryType.values.map(
        (t) => PopupMenuItem(
          value: t,
          child: ListTile(
            dense: true,
            leading: Icon(iconForType(t), size: 18),
            title: Text(
              labelForType(t),
              style: const TextStyle(fontSize: 13),
            ),
            trailing: currentType == t && isManual
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.primary,
                  )
                : null,
          ),
        ),
      ),
      if (showAutoOption) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: null,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.sync, size: 18),
            title: const Text(
              'Auto',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'detectar del contenido',
              style: TextStyle(fontSize: 11),
            ),
            trailing: !isManual
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.primary,
                  )
                : null,
          ),
        ),
      ],
    ];
  }
}
