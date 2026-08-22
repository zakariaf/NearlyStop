/// Colour measurement oracles for the theme tests.
///
/// Both functions are **independent of the code under test**: they implement
/// the published formulae from first principles rather than calling
/// `Color.computeLuminance()`, so a linearisation bug in one cannot make the
/// other agree with it. Each is pinned against published values before it is
/// trusted with a table.
library;

import 'dart:math' as math;
import 'dart:ui';

/// sRGB → linear, the WCAG 2.1 / IEC 61966-2-1 transfer function.
double _linearise(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

/// CIE relative luminance Y of [color], in 0..1.
double relativeLuminance(Color color) =>
    0.2126 * _linearise(color.r) +
    0.7152 * _linearise(color.g) +
    0.0722 * _linearise(color.b);

/// The WCAG contrast ratio between [a] and [b], in 1..21.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// CIE L\* (perceptual lightness) of [color], in 0..100.
///
/// This is the number a primitive's name claims: `clay19` promises L\* 19.
double lStar(Color color) {
  final y = relativeLuminance(color);
  const epsilon = 216 / 24389; // (6/29)^3
  const kappa = 24389 / 27; // (29/3)^3
  final f = y > epsilon
      ? math.pow(y, 1 / 3).toDouble()
      : (kappa * y + 16) / 116;
  return 116 * f - 16;
}

/// The hue angle of [color] in degrees, 0..360.
///
/// Used only to assert that the high-contrast palette **darkened** a tone
/// rather than recolouring it: high contrast changes luminance, never the
/// emotional register.
double hueDegrees(Color color) {
  final max = math.max(color.r, math.max(color.g, color.b));
  final min = math.min(color.r, math.min(color.g, color.b));
  final delta = max - min;
  if (delta == 0) return 0;
  final double hue;
  if (max == color.r) {
    hue = 60 * (((color.g - color.b) / delta) % 6);
  } else if (max == color.g) {
    hue = 60 * ((color.b - color.r) / delta + 2);
  } else {
    hue = 60 * ((color.r - color.g) / delta + 4);
  }
  return hue < 0 ? hue + 360 : hue;
}
