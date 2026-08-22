/// The one theme builder.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/color_schemes.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/daybreak_type.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

/// The shared button silhouette.
///
/// A `minimumSize` floor and **no fixed size**: at 200% text scale the label
/// has to grow the button rather than be clipped by it, which is why
/// `fixedSize` is stated as null instead of left to a component default.
ButtonStyle _buttonStyle(TextTheme text) => ButtonStyle(
  minimumSize: const WidgetStatePropertyAll<Size>(
    Size(minimumTapTarget, minimumTapTarget),
  ),
  fixedSize: const WidgetStatePropertyAll<Size?>(null),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsetsDirectional.symmetric(
      horizontal: daybreakShapes.s6,
      vertical: daybreakShapes.s3,
    ),
  ),
  shape: WidgetStatePropertyAll<OutlinedBorder>(daybreakShapes.pillShape()),
  textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
);

/// The minimum height of any tap target, in logical pixels.
///
/// 48dp is the Material floor and the larger of the two platform minimums (iOS
/// asks 44pt). `SPEC.md` §5.4 requires it, and for this audience it is not a
/// guideline. Buttons get a `minimumSize` and **no fixed height**: at 200% text
/// scale the label must grow the button, not be clipped by it.
const double minimumTapTarget = 48;

/// Builds the app's `ThemeData`.
///
/// All three arguments are load-bearing:
///
/// * [brightness] picks the light or dark palette.
/// * [script] is the entire mechanism by which the Persian type transform
///   reaches a screen — a builder that ignored it would render Vazirmatn's
///   metrics with Nunito's line heights and nothing else in the suite would
///   notice. EPIC-03 supplies the locale → script mapping.
/// * [highContrast] is how EPIC-11's toggle reaches a palette rather than
///   nothing. It swaps the colours only: type size, spacing and hit targets are
///   the text-scale and 48dp floors, which are always on.
///
/// [boldText] steps every weight one stop up the ladder, in the same one
/// theme-level transform as the Persian lift, so a call site never sees it.
/// Callers read it from `MediaQuery.boldTextOf(context)`.
ThemeData buildDaybreakTheme(
  Brightness brightness,
  DaybreakScript script, {
  bool highContrast = false,
  bool boldText = false,
}) {
  final colors = daybreakColorsFor(brightness, highContrast: highContrast);
  final elevation = daybreakElevationFor(brightness);
  final scheme = daybreakColorScheme(brightness, colors);
  final text = daybreakTextTheme(script, colors: colors, boldText: boldText);
  final typography = daybreakTypography(
    text: text,
    script: script,
    colors: colors,
  );

  final buttonStyle = _buttonStyle(text);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.bg,
    // Bundled, licence-registered faces. NEVER google_fonts: this app is
    // offline and account-free, and a font CDN is a network call.
    fontFamily: fontFamilyFor(script),
    fontFamilyFallback: fontFamilyFallbackFor(script),
    textTheme: text,
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0, // Material's neutral shadow is grey dirt on a cream ground.
      shape: daybreakShapes.cardShape(),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.tintPrimary,
      // No `height:` on purpose. Pinning one is the same mistake the button
      // style refuses two fields above: Flutter's default (80) already clears
      // the 48dp floor and leaves the room a 15px label needs at the 1.3x
      // NavigationBar clamps to — and the five German destination names are the
      // longest strings in the app.
      labelTextStyle: WidgetStatePropertyAll<TextStyle?>(text.labelMedium),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll<Color>(colors.borderStrong),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceRaised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(daybreakShapes.radiusSm),
        borderSide: BorderSide(color: colors.borderStrong),
      ),
      labelStyle: text.bodyMedium?.copyWith(color: colors.inkMuted),
    ),
    extensions: <ThemeExtension<dynamic>>[
      colors,
      daybreakShapes,
      elevation,
      daybreakMotion,
      typography,
    ],
  );
}
