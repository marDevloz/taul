import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'tag_palette.dart';

/// Utility for mixing multiple colors into a single display color using
/// HSL circular-mean averaging.
///
/// Used to compute a single accent color for entries that have multiple tags
/// with different colors assigned.
class TagColorMixer {
  const TagColorMixer._();

  /// Mixes [colors] into a single color using HSL circular-mean averaging.
  ///
  /// - Empty list → [TagPalette.defaultGrey]
  /// - Single color → returns that color
  /// - Multiple colors → circular mean of hues, arithmetic mean of
  ///   saturation and lightness
  static Color mix(List<Color> colors) {
    if (colors.isEmpty) return TagPalette.defaultGrey;
    if (colors.length == 1) return colors.first;

    double sinSum = 0;
    double cosSum = 0;
    double satSum = 0;
    double lightSum = 0;
    final count = colors.length;

    for (final c in colors) {
      final hsl = HSLColor.fromColor(c);
      final hueRad = hsl.hue * math.pi / 180;
      sinSum += math.sin(hueRad);
      cosSum += math.cos(hueRad);
      satSum += hsl.saturation;
      lightSum += hsl.lightness;
    }

    final avgSin = sinSum / count;
    final avgCos = cosSum / count;
    var avgHue = math.atan2(avgSin, avgCos) * 180 / math.pi;
    if (avgHue < 0) avgHue += 360;
    final avgSat = satSum / count;
    final avgLight = lightSum / count;

    return HSLColor.fromAHSL(1.0, avgHue, avgSat, avgLight).toColor();
  }
}
