import 'package:flutter/material.dart';

/// Data model for a single item inside a [SnakeFab].
class SnakeFabItem {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  const SnakeFabItem({
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });
}

/// A FAB that snake-expands upward into a grid of filter pills.
///
/// When [isExpanded] is true, items slide in one-by-one with a staggered
/// [SlideTransition] inside a scrollable panel. When collapsed, only the
/// FAB trigger button is visible, showing the [collapsedIcon].
///
/// The parent is responsible for mutual exclusion via [isExpanded].
class SnakeFab extends StatefulWidget {
  /// Whether this FAB is currently expanded.
  final bool isExpanded;

  /// Called when the collapsed FAB is tapped (expand/collapse).
  final VoidCallback onTap;

  /// Icon shown on the collapsed FAB button.
  final Widget collapsedIcon;

  /// Label shown next to the collapsed icon (optional).
  final String? collapsedLabel;

  /// Items to display when expanded.
  final List<SnakeFabItem> items;

  /// The currently selected value. Used to highlight the matching item and
  /// to toggle it off on re-tap.
  final String? selectedValue;

  /// Called when a filter item is tapped.
  /// `null` value means the item was already selected (toggle off).
  final ValueChanged<String?> onItemSelected;

  /// Max height of the expanded panel before it becomes scrollable.
  final double maxHeight;

  const SnakeFab({
    super.key,
    required this.isExpanded,
    required this.onTap,
    required this.collapsedIcon,
    this.collapsedLabel,
    required this.items,
    this.selectedValue,
    required this.onItemSelected,
    this.maxHeight = 200,
  });

  @override
  State<SnakeFab> createState() => _SnakeFabState();
}

class _SnakeFabState extends State<SnakeFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(SnakeFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expandable panel with staggered animation
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.bottomCenter,
          child: widget.isExpanded
              ? _buildExpandedPanel(theme)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 4),
        // Collapsed trigger FAB
        FloatingActionButton.small(
          heroTag: null,
          onPressed: widget.onTap,
          backgroundColor:
              widget.selectedValue != null && widget.selectedValue!.isNotEmpty
                  ? theme.colorScheme.secondaryContainer
                  : null,
          child: widget.collapsedIcon,
        ),
      ],
    );
  }

  Widget _buildExpandedPanel(ThemeData theme) {
    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              _buildAnimatedItem(i),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(int index) {
    final item = widget.items[index];
    final isSelected = widget.selectedValue == item.value;
    final count = widget.items.length;
    final staggerFraction = count > 1 ? 1.0 / count : 1.0;
    final start = index * staggerFraction * 0.5;
    final end = (start + 0.5).clamp(0.01, 1.0);

    return SlideTransition(
      position: _controller.drive(
        CurveTween(curve: Interval(start.clamp(0.0, 0.99), end)),
      ).drive(
        Tween<Offset>(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ),
      ),
      child: _FabItemPill(
        label: item.label,
        icon: item.icon,
        color: item.color,
        selected: isSelected,
        onTap: () => widget.onItemSelected(
          isSelected ? null : item.value,
        ),
      ),
    );
  }
}

/// A single pill/chip inside an expanded [SnakeFab] panel.
class _FabItemPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FabItemPill({
    required this.label,
    required this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = color ??
        (selected
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest);
    final fgColor = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fgColor),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: fgColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
