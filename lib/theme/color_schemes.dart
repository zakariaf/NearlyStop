/// The Material 3 role map, hand-authored for every palette.
///
/// **Never `ColorScheme.fromSeed`, never `dynamic_color`.** Daybreak's light
/// `primary` measures 2.76:1 and its `border` about 1.35:1, so a seed would
/// hand Material some forty derived roles that nothing ever measured; per-role
/// overrides do not propagate through a seed, and wallpaper-derived colour is
/// untestable at build time.
///
/// Two mappings carry the whole epic, and both are asserted by
/// `test/theme/color_schemes_test.dart` rather than trusted from this comment.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/primitives.dart';

/// Builds the `ColorScheme` for [colors] at [brightness].
///
/// **`outline` is `borderStrong` (3.65:1), never `border`.** Material draws
/// every `TextField`, `Switch`, `Checkbox` and `OutlinedButton` boundary from
/// `outline`; the decorative hairline there ships controls whose edges a
/// 78-year-old cannot see, and nothing in the app will report it. `border` is
/// `outlineVariant` and nothing else.
///
/// **`ColorScheme.primary` is `primaryDeep`, never `DaybreakColors.primary`.**
/// Material paints *text and icons* with the `primary` role — `TextButton`
/// labels, `FilledButton.tonal` foregrounds, the `TextField` focus label.
/// Mapping the 2.76:1 decorative coral there would put failing text on screen
/// through a path no widget in this repo wrote.
///
/// **`ColorScheme.onPrimary` and [DaybreakColors.onPrimary] are different
/// colours on purpose.** This one sits on `ColorScheme.primary` (= the deep
/// coral) and is `bg` in light, ≈5.6:1. [DaybreakColors.onPrimary] is `clay11`,
/// the only foreground allowed on the coral **fill** and the sunrise gradient,
/// 6.04:1 at the gradient's worst stop — where white measures 2.76:1 and fails.
/// Two roles, two grounds, two colours.
ColorScheme daybreakColorScheme(
  Brightness brightness,
  DaybreakColors colors,
) {
  final isDark = brightness == Brightness.dark;
  return ColorScheme(
    brightness: brightness,
    primary: colors.primaryDeep,
    onPrimary: isDark ? colors.onPrimary : colors.bg,
    primaryContainer: colors.tintPrimary,
    onPrimaryContainer: colors.primaryDeep,
    secondary: colors.warning,
    onSecondary: isDark ? colors.onPrimary : colors.bg,
    secondaryContainer: colors.tintWarning,
    onSecondaryContainer: colors.warning,
    tertiary: colors.success,
    onTertiary: isDark ? colors.onPrimary : colors.bg,
    tertiaryContainer: colors.tintSuccess,
    onTertiaryContainer: colors.success,
    error: colors.danger,
    onError: isDark ? colors.onPrimary : colors.bg,
    errorContainer: colors.tintDanger,
    onErrorContainer: colors.danger,
    surface: colors.surface,
    onSurface: colors.ink,
    surfaceDim: colors.bg,
    surfaceBright: colors.surface,
    surfaceContainerLowest: colors.surfaceSunken,
    surfaceContainerLow: colors.bg,
    surfaceContainer: colors.surfaceRaised,
    surfaceContainerHigh: colors.surfaceRaised,
    surfaceContainerHighest: colors.surfaceRaised,
    onSurfaceVariant: colors.inkMuted,
    outline: colors.borderStrong,
    outlineVariant: colors.border,
    scrim: colors.overlay,
    shadow: isDark ? Primitives.plum01 : Primitives.clay42,
    inverseSurface: colors.ink,
    onInverseSurface: colors.surface,
    inversePrimary: colors.primary,
  );
}
