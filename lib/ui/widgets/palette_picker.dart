import 'package:flutter/material.dart';
import 'package:taul/shared/tag_palette.dart';

/// A 4×4 grid picker for selecting a color from the fixed palette.
///
/// Shows a "sin color" option first, then 16 colored circles, then
/// optional system tag colors at the end.
///
/// The selected color is indicated by a white checkmark overlay and a 2px border.
class PalettePicker extends StatefulWidget {
  /// The initially selected color (if any).
  final Color? initialColor;

  /// Called when the user selects a color. Returns the hex string.
  /// Empty string means "sin color" (no color).
  final ValueChanged<String> onColorSelected;

  /// System tag names whose colors should appear at the end (locked).
  final List<String> systemTags;

  const PalettePicker({
    super.key,
    this.initialColor,
    required this.onColorSelected,
    this.systemTags = const [],
  });

  @override
  State<PalettePicker> createState() => _PalettePickerState();
}

class _PalettePickerState extends State<PalettePicker> {
  late Color? _selectedColor;
  late bool _isSinColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _isSinColor = widget.initialColor == null;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // "Sin color" option — first item
        _buildSinColorOption(),
        // 16 palette colors
        for (final paletteColor in TagPalette.colors)
          _buildPaletteCircle(paletteColor),
        // System tag colors (locked)
        for (final tagName in widget.systemTags)
          _buildSystemTagCircle(tagName),
      ],
    );
  }

  Widget _buildSinColorOption() {
    final isSelected = _isSinColor;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = null;
          _isSinColor = true;
        });
        widget.onColorSelected('');
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Diagonal line through circle (no color indicator)
            CustomPaint(
              size: const Size(48, 48),
              painter: _SinColorPainter(),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaletteCircle(PaletteColor paletteColor) {
    final isSelected = _selectedColor == paletteColor.color && !_isSinColor;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = paletteColor.color;
          _isSinColor = false;
        });
        widget.onColorSelected(paletteColor.hex);
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: paletteColor.color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 24,
              )
            : null,
      ),
    );
  }

  Widget _buildSystemTagCircle(String tagName) {
    final defaultColor = TagPalette.systemTagDefaults[tagName]?.color ??
        TagPalette.defaultGrey;
    final systemDefaultHex = TagPalette.systemTagDefaults[tagName]?.hex;
    // Check if current color matches the system default
    final isSystemDefaultColor = systemDefaultHex != null &&
        _selectedColor != null &&
        _selectedColor == defaultColor;

    return GestureDetector(
      // System tag colors are not directly selectable via tap
      // (users change them through the tag management screen)
      onTap: null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: defaultColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.transparent,
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.lock,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

/// Custom painter for the "sin color" diagonal line.
class _SinColorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
