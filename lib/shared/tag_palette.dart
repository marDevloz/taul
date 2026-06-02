import 'package:flutter/painting.dart';

/// Represents a single color in the fixed 4×4 palette.
class PaletteColor {
  final String name;
  final Color color;
  final String hex;
  final double hue;
  final double saturation;
  final double lightness;

  const PaletteColor({
    required this.name,
    required this.color,
    required this.hex,
    required this.hue,
    required this.saturation,
    required this.lightness,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaletteColor && hex == other.hex;

  @override
  int get hashCode => hex.hashCode;
}

/// Fixed 4×4 palette of 16 colors for tag coloring.
///
/// Inspired by the One Dark Pro color scheme. Colors are organized in a
/// 4×4 grid: Reds/Oranges, Greens, Blues/Cyans, Purples/Pinks/Neutrals.
/// All HSL values are pre-computed constants for performance.
class TagPalette {
  const TagPalette._();

  /// The 16 fixed palette colors in a 4×4 grid layout.
  ///
  /// Layout (row-major order):
  ///  0:Reds    1:Oranges   2:Yellows   3:Ambers
  ///  4:Greens  5:Cyans     6:Emeralds  7:Limes
  ///  8:Blues   9:Teals    10:Indigos  11:Sky
  /// 12:Purples 13:Pinks   14:Maroons  15:Slates
  static const List<PaletteColor> colors = [
    // Row 1: Reds & Oranges
    PaletteColor(
      name: 'red',
      hex: '#E06C75',
      color: Color(0xFFE06C75),
      hue: 355.3,
      saturation: 0.6517,
      lightness: 0.6510,
    ),
    PaletteColor(
      name: 'orange',
      hex: '#D19A66',
      color: Color(0xFFD19A66),
      hue: 29.2,
      saturation: 0.5377,
      lightness: 0.6098,
    ),
    PaletteColor(
      name: 'yellow',
      hex: '#E5C07B',
      color: Color(0xFFE5C07B),
      hue: 39.1,
      saturation: 0.6709,
      lightness: 0.6902,
    ),
    PaletteColor(
      name: 'amber',
      hex: '#D4A574',
      color: Color(0xFFD4A574),
      hue: 30.6,
      saturation: 0.5275,
      lightness: 0.6431,
    ),
    // Row 2: Greens
    PaletteColor(
      name: 'green',
      hex: '#98C379',
      color: Color(0xFF98C379),
      hue: 94.9,
      saturation: 0.3814,
      lightness: 0.6196,
    ),
    PaletteColor(
      name: 'cyan',
      hex: '#56B6C2',
      color: Color(0xFF56B6C2),
      hue: 186.7,
      saturation: 0.4696,
      lightness: 0.5490,
    ),
    PaletteColor(
      name: 'emerald',
      hex: '#7EC8A0',
      color: Color(0xFF7EC8A0),
      hue: 147.6,
      saturation: 0.4022,
      lightness: 0.6392,
    ),
    PaletteColor(
      name: 'lime',
      hex: '#A8D86B',
      color: Color(0xFFA8D86B),
      hue: 86.4,
      saturation: 0.5829,
      lightness: 0.6333,
    ),
    // Row 3: Blues & Cyans
    PaletteColor(
      name: 'blue',
      hex: '#61AFEF',
      color: Color(0xFF61AFEF),
      hue: 207.0,
      saturation: 0.8161,
      lightness: 0.6588,
    ),
    PaletteColor(
      name: 'teal',
      hex: '#4EC9B0',
      color: Color(0xFF4EC9B0),
      hue: 167.8,
      saturation: 0.5325,
      lightness: 0.5471,
    ),
    PaletteColor(
      name: 'indigo',
      hex: '#7C8BC3',
      color: Color(0xFF7C8BC3),
      hue: 227.3,
      saturation: 0.3717,
      lightness: 0.6255,
    ),
    PaletteColor(
      name: 'sky',
      hex: '#8FBCBB',
      color: Color(0xFF8FBCBB),
      hue: 178.7,
      saturation: 0.2514,
      lightness: 0.6490,
    ),
    // Row 4: Purples, Pinks, Neutrals
    PaletteColor(
      name: 'purple',
      hex: '#C678DD',
      color: Color(0xFFC678DD),
      hue: 286.3,
      saturation: 0.5976,
      lightness: 0.6686,
    ),
    PaletteColor(
      name: 'pink',
      hex: '#E0529A',
      color: Color(0xFFE0529A),
      hue: 329.6,
      saturation: 0.6961,
      lightness: 0.6000,
    ),
    PaletteColor(
      name: 'maroon',
      hex: '#BE5046',
      color: Color(0xFFBE5046),
      hue: 5.0,
      saturation: 0.4800,
      lightness: 0.5098,
    ),
    PaletteColor(
      name: 'slate',
      hex: '#848B98',
      color: Color(0xFF848B98),
      hue: 219.0,
      saturation: 0.0885,
      lightness: 0.5569,
    ),
  ];

  /// Default grey used when no tags have colors assigned.
  static const Color defaultGrey = Color(0xFF9E9E9E);

  /// Default colors for the four system tags.
  ///
  /// These colors are OUTSIDE the normal 16-color palette, reserved exclusively
  /// for system-managed tags. Keys match tag names without the `#` prefix.
  static const Map<String, PaletteColor> systemTagDefaults = {
    'pendiente': PaletteColor(
      name: 'pendiente',
      hex: '#FFC107',
      color: Color(0xFFFFC107),
      hue: 45.0,
      saturation: 1.0,
      lightness: 0.5,
    ),
    'completada': PaletteColor(
      name: 'completada',
      hex: '#4CAF50',
      color: Color(0xFF4CAF50),
      hue: 120.0,
      saturation: 0.5,
      lightness: 0.5,
    ),
    'favorito': PaletteColor(
      name: 'favorito',
      hex: '#E53935',
      color: Color(0xFFE53935),
      hue: 4.0,
      saturation: 0.8,
      lightness: 0.5,
    ),
    'archivado': PaletteColor(
      name: 'archivado',
      hex: '#9E9E9E',
      color: Color(0xFF9E9E9E),
      hue: 0.0,
      saturation: 0.0,
      lightness: 0.6,
    ),
  };
}
