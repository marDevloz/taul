import 'package:flutter/material.dart';
import 'package:taul/shared/tag_palette.dart';

/// A 4×4 grid picker for selecting a color from the fixed palette.
///
/// Shows 16 colored circles in a grid. The selected color is indicated
/// by a white checkmark overlay and a 2px border.
class PalettePicker extends StatefulWidget {
  /// The initially selected color (if any).
  final Color? initialColor;

  /// Called when the user selects a color. Returns the hex string.
  final ValueChanged<String> onColorSelected;

  const PalettePicker({
    super.key,
    this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<PalettePicker> createState() => _PalettePickerState();
}

class _PalettePickerState extends State<PalettePicker> {
  late Color? _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final paletteColor in TagPalette.colors)
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedColor = paletteColor.color;
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
                  color: _selectedColor == paletteColor.color
                      ? Colors.white
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: _selectedColor == paletteColor.color
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}