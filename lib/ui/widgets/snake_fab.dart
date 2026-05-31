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

/// A FAB that snake-expands into a train of filter pills.
///
/// Pills slide in from the right one by one, like a train emerging
/// from the FAB. Each pill follows the previous with a short delay.
/// The panel is transparent with a subtle blur.
class SnakeFab extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget collapsedIcon;
  final String? collapsedLabel;
  final List<SnakeFabItem> items;
  final String? selectedValue;
  final ValueChanged<String?> onItemSelected;
  final double maxHeight;
  final int itemsPerRow;

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
    this.itemsPerRow = 3,
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

  /// Snake reveal: pills appear one by one with a short delay,
  /// like a train emerging from the FAB.
  void _startRevealAnimation({int initialCount = 3}) {
    _revealTimer?.cancel();
    var index = 0;
    void revealNext() {
      if (!widget.isExpanded || index >= widget.items.length || index >= initialCount) return;
      setState(() => _revealedIndices.add(index));
      index++;
      if (index < initialCount && index < widget.items.length) {
        Timer(const Duration(milliseconds: 80), revealNext);
      }
    }
    _revealTimer = Timer(const Duration(milliseconds: 100), revealNext);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pixel = _scrollController.offset;
    const rowHeight = 44.0;
    final visibleRows = (pixel / rowHeight).floor();
    final visibleIndex = (visibleRows + 1) * widget.itemsPerRow;
    var changed = false;
    for (var i = 0; i < visibleIndex && i < widget.items.length; i++) {
      if (!_revealedIndices.contains(i)) {
        _revealedIndices.add(i);
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  /// Build rows of pills (3 per row) for the snake layout.
  List<List<int>> _buildRows() {
    final rows = <List<int>>[];
    for (var i = 0; i < widget.items.length; i += widget.itemsPerRow) {
      final end = (i + widget.itemsPerRow).clamp(0, widget.items.length);
      rows.add(List.generate(end - i, (j) => i + j));
    }
    return rows;
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
        // Collapsed trigger FAB
        _buildCollapsedFab(theme),
      ],
    );
  }

  Widget _buildCollapsedFab(ThemeData theme) {
    final hasFilter =
        widget.selectedValue != null && widget.selectedValue!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FloatingActionButton.small(
        heroTag: null,
        onPressed: widget.onTap,
        backgroundColor: hasFilter
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.85)
            : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
        foregroundColor: hasFilter
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onSurfaceVariant,
        elevation: 0,
        child: widget.collapsedIcon,
      ),
    );
  }

  Widget _buildExpandedPanel(ThemeData theme) {
    final rows = _buildRows();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var rowIdx = 0; rowIdx < rows.length; rowIdx++)
                  _buildSnakeRow(rows[rowIdx], rowIdx, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A single row of pills that slides in from the right like a train car.
  Widget _buildSnakeRow(List<int> indices, int rowIndex, ThemeData theme) {
    // Each row starts after the previous row's pills have appeared
    final baseDelay = rowIndex * widget.itemsPerRow * 80;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < indices.length; i++)
            _buildTrainItem(indices[i], i, baseDelay, theme),
        ],
      ),
    );
  }

  /// A single pill that slides in from the right with staggered delay.
  Widget _buildTrainItem(int index, int posInRow, int baseDelay, ThemeData theme) {
    final item = widget.items[index];
    final isSelected = widget.selectedValue == item.value;
    final isRevealed = _revealedIndices.contains(index);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      opacity: isRevealed ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        offset: isRevealed ? Offset.zero : const Offset(1.5, 0),
        child: Padding(
          padding: EdgeInsets.only(right: posInRow < 2 ? 8 : 0),
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
    final borderColor = hasColor
        ? _contrastColor(color!).withValues(alpha: 0.2)
        : selected
            ? theme.colorScheme.primary.withValues(alpha: 0.4)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
          ),
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
      ),
    );
  }
}
