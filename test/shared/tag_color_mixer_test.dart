import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taul/shared/tag_color_mixer.dart';
import 'package:taul/shared/tag_palette.dart';

void main() {
  group('TagColorMixer.mix', () {
    test('should return defaultGrey when list is empty', () {
      final result = TagColorMixer.mix([]);
      expect(result, TagPalette.defaultGrey);
    });

    test('should return the same color when list has one color', () {
      final color = const Color(0xFFE06C75);
      final result = TagColorMixer.mix([color]);
      expect(result, color);
    });

    test('should compute HSL circular mean for 3 colors', () {
      final red = const Color(0xFFE06C75);
      final blue = const Color(0xFF61AFEF);
      final green = const Color(0xFF98C379);

      final result = TagColorMixer.mix([red, blue, green]);

      // Compute expected values using the same algorithm
      final hslRed = HSLColor.fromColor(red);
      final hslBlue = HSLColor.fromColor(blue);
      final hslGreen = HSLColor.fromColor(green);

      var sinSum = 0.0;
      var cosSum = 0.0;
      var satSum = 0.0;
      var lightSum = 0.0;

      for (final hsl in [hslRed, hslBlue, hslGreen]) {
        final rad = hsl.hue * math.pi / 180;
        sinSum += math.sin(rad);
        cosSum += math.cos(rad);
        satSum += hsl.saturation;
        lightSum += hsl.lightness;
      }

      final avgHue =
          (math.atan2(sinSum / 3, cosSum / 3) * 180 / math.pi + 360) % 360;
      final avgSat = satSum / 3;
      final avgLight = lightSum / 3;

      final expected =
          HSLColor.fromAHSL(1.0, avgHue, avgSat, avgLight).toColor();

      expect(result, expected);
    });

    test('should handle edge hues (0° and 360°) with circular mean', () {
      // Colors with hues near 0° and 359°; circular mean should be ~0°
      final nearZero = HSLColor.fromAHSL(1.0, 1.0, 0.5, 0.5).toColor();
      final nearFull = HSLColor.fromAHSL(1.0, 359.0, 0.5, 0.5).toColor();

      final result = TagColorMixer.mix([nearZero, nearFull]);

      // The circular mean of 1° and 359° should be ~0° (or 360°), not 180°
      final hsl = HSLColor.fromColor(result);
      expect(hsl.hue, closeTo(0.0, 1.0));
    });

    test('should handle 10 colors without exceeding time budget', () {
      final colors = List<Color>.generate(
        10,
        (i) => HSLColor.fromAHSL(1.0, i * 36.0, 0.5, 0.5).toColor(),
      );

      final stopwatch = Stopwatch()..start();
      final result = TagColorMixer.mix(colors);
      stopwatch.stop();

      expect(result, isNotNull);
      expect(stopwatch.elapsedMicroseconds, lessThan(1000)); // <1ms per NFR-03
    });

    test('should handle saturation and lightness extremes', () {
      // Full saturation, extremes of lightness → mid lightness
      final highLight =
          HSLColor.fromAHSL(1.0, 200.0, 1.0, 1.0).toColor(); // white
      final lowLight =
          HSLColor.fromAHSL(1.0, 200.0, 1.0, 0.0).toColor(); // black

      final result = TagColorMixer.mix([highLight, lowLight]);
      final hsl = HSLColor.fromColor(result);

      expect(hsl.lightness, closeTo(0.5, 0.01));
    });
  });
}
