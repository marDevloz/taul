import 'dart:async';
import 'dart:ui';
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

/// A FAB that snake-expands upward into a scrollable list of filter pills.
///
/// Items appear one-by-one as the user scrolls (scroll-driven reveal).
/// The panel is transparent — no background color.
/// Collapsed state shows icon + label for clear identification.
class SnakeFab extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget collapsedIcon;
  final String? collapsedLabel;
  final List<SnakeFabItem> items;
  final String? selectedValue;
  final ValueChanged<String?> onItemSelected;
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
    this.maxHeight = 240,
  });

  @override
  State<SnakeFab> createState() => _SnakeFabState();
}

class _SnakeFabState extends State<SnakeFab> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _revealedIndices = {};
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.isExpanded) {
      _startRevealAnimation();
    }
  }

  @override
  void didUpdateWidget(SnakeFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && !oldWidget.isExpanded) {
      _revealedIndices.clear();
      _startRevealAnimation();
    } else if (!widget.isExpanded) {
      _revealTimer?.cancel();
      _revealedIndices.clear();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Staggered reveal: items appear one by one with a short delay.
  void _startRevealAnimation() {
    _revealTimer?.cancel();
    var index = 0;
    void revealNext() {
      if (!widget.isExpanded || index >= widget.items.length) return;
      setState(() => _revealedIndices.add(index));
      index++;
      if (index < widget.items.length) {
        Timer(const Duration(milliseconds: 60), revealNext);
      }
    }
    // Small initial delay so the panel opening is visible first
    _revealTimer = Timer(const Duration(milliseconds: 100), revealNext);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // As user scrolls down, reveal items that come into view
    final pixel = _scrollController.offset;
    final itemsPerRow = _estimateItemsPerRow();
    const rowHeight = 44.0; // approx pill height + spacing
    final visibleRows = (pixel / rowHeight).floor();
    final visibleIndex = (visibleRows + 1) * itemsPerRow;
    for (var i = 0; i < visibleIndex && i < widget.items.length; i++) {
      if (!_revealedIndices.contains(i)) {
        setState(() => _revealedIndices.add(i));
      }
    }
  }

  int _estimateItemsPerRow() {
    // Rough estimate: pills are ~100px wide, container ~280px wide
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expandable panel — transparent background
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: widget.isExpanded
              ? _buildExpandedPanel(theme)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        // Collapsed trigger FAB with label
        _buildCollapsedFab(theme),
      ],
    );
  }

  Widget _buildCollapsedFab(ThemeData theme) {
    final hasFilter =
        widget.selectedValue != null && widget.selectedValue!.isNotEmpty;

    return FloatingActionButton.small(
      heroTag: null,
      onPressed: widget.onTap,
      backgroundColor: hasFilter
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      foregroundColor: hasFilter
          ? theme.colorScheme.onSecondaryContainer
          : theme.colorScheme.onSurfaceVariant,
      elevation: hasFilter ? 2 : 1,
      child: widget.collapsedIcon,
    );
  }

  Widget _buildExpandedPanel(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  _buildRevealItem(i, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevealItem(int index, ThemeData theme) {
    final item = widget.items[index];
    final isSelected = widget.selectedValue == item.value;
    final isRevealed = _revealedIndices.contains(index);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      opacity: isRevealed ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        offset: isRevealed ? Offset.zero : const Offset(0, 0.4),
        child: _FabItemPill(
          label: item.label,
          icon: item.icon,
          color: item.color,
          selected: isSelected,
          onTap: () => widget.onItemSelected(
            isSelected ? null : item.value,
          ),
        ),
      ),
    );
  }
}

/// Returns black or white depending on the luminance of [color].
Color _contrastColor(Color color) {
  return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
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
    final hasColor = color != null;
    final bgColor = hasColor
        ? color!
        : selected
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest;
    final fgColor = hasColor
        ? _contrastColor(color!)
        : selected
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (hasColor ? color! : theme.colorScheme.shadow).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
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
                Icon(icon, size: 15, color: fgColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: fgColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
