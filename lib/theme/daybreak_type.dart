/// The Daybreak type scale, projected into a fully-assigned Material 3
/// `TextTheme` for each script.
///
/// Seven authored roles — display 72 · title 34 · heading 24 · body-lg 20 ·
/// body 17 · label 15 · caption 14 — mapped onto **all fifteen** M3 slots. An
/// unassigned `labelSmall` defaults to 11px, and a `Chip` or `NavigationBar`
/// will smuggle it onto a screen that never declared it: a 17px-floor violation
/// nobody wrote.
///
/// Two conversions that are easy to get wrong, and both are silent:
///
/// * **`letterSpacing` is logical pixels; CSS tracking is `em`.** `-0.045em` at
///   72 is `-3.24`, not `-0.045`. The `em` value passes any "is it negative"
///   check and is 72× too small.
/// * **`fontWeight` alone does not move a variable font.** Both faces ship as a
///   single variable TTF declared with no `weight:` entries, which is *one*
///   declared asset — `fontWeight` selects among declared assets and otherwise
///   leaves the default instance. Nunito's default instance is `wght` **200**
///   (ExtraLight), so every heading would render feather-thin. The axis is
///   reached through [TextStyle.fontVariations], derived here in the one
///   theme-level transform and never at a call site.
///
/// The Persian projection is the same transform: `height += 0.14`, every
/// negative tracking reset to `0` (Perso-Arabic is a joined script — tracking
/// snaps the joins), and display hand-set to **58 / 1.15** rather than taking
/// the uniform lift, because `1.05 + 0.14` is loose for a single-line numeral.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_script.dart';

/// The Latin face. Bundled, never fetched — `google_fonts` is banned.
const String latinFontFamily = 'Nunito';

/// The Perso-Arabic face.
const String persoFontFamily = 'Vazirmatn';

/// The largest `wght` both shipped faces support.
///
/// Nunito's axis is 200–1000 and Vazirmatn's is 100–900, so 900 is the common
/// ceiling. [boldTextStep] is what enforces it — its top arm returns
/// [FontWeight.w900] rather than stepping past it, so Flutter is never asked to
/// synthesise faux bold, which smears Perso-Arabic joins.
const double maxSupportedWeight = 900;

/// The family cascade for [script].
///
/// The fallback is always the **other bundled face**, never a system font: a
/// missing glyph must land on something the app shipped and licensed.
List<String> fontFamilyFallbackFor(DaybreakScript script) => switch (script) {
  DaybreakScript.latin => const <String>[persoFontFamily],
  DaybreakScript.perso => const <String>[latinFontFamily],
};

/// The primary family for [script].
String fontFamilyFor(DaybreakScript script) => switch (script) {
  DaybreakScript.latin => latinFontFamily,
  DaybreakScript.perso => persoFontFamily,
};

/// One step up the weight ladder, clamped at [maxSupportedWeight].
///
/// 400 → 600 → 700 → 800 → 900. Applied when the OS reports `boldText`, in the
/// same theme-level transform as everything else, so a call site never sees it.
FontWeight boldTextStep(FontWeight weight) => switch (weight.value) {
  <= 400 => FontWeight.w600,
  <= 600 => FontWeight.w700,
  <= 700 => FontWeight.w800,
  _ => FontWeight.w900,
};

/// Derives `fontVariations` from [style]'s weight and applies the script
/// transform. The single place either happens.
TextStyle _project(
  TextStyle style,
  DaybreakScript script, {
  required bool boldText,
  double? persoFontSize,
  double? persoHeight,
}) {
  var weight = style.fontWeight ?? FontWeight.w400;
  if (boldText) weight = boldTextStep(weight);

  final isPerso = script == DaybreakScript.perso;
  final spacing = isPerso ? 0.0 : style.letterSpacing;
  final height = isPerso
      ? (persoHeight ?? (style.height! + 0.14))
      : style.height;
  final size = isPerso ? (persoFontSize ?? style.fontSize) : style.fontSize;

  return style.copyWith(
    // The family is set on EVERY style, not left to ThemeData to fold in.
    // ThemeData folds it into `textTheme` only — a style handed straight to a
    // component theme (a button's textStyle, a NavigationBar's label) keeps a
    // null family and renders in the platform default face. In fa/ckb that is a
    // system Perso-Arabic face or tofu, on every screen, silently breaking the
    // bundled-and-licensed promise.
    fontFamily: fontFamilyFor(script),
    fontFamilyFallback: fontFamilyFallbackFor(script),
    fontSize: size,
    height: height,
    letterSpacing: spacing,
    fontWeight: weight,
    fontVariations: <FontVariation>[
      FontVariation('wght', weight.value.toDouble()),
    ],
  );
}

/// The seven authored roles, before the script transform.
///
/// Sizes and tracking come from
/// `daybreak-bilingual-type/references/type-scale.md`, which is authoritative:
/// a number that disagrees with it is a bug, not a variant. Tracking is written
/// as `em × size` so the multiplication is visible at the point it happens.
TextTheme daybreakTextTheme(
  DaybreakScript script, {
  required DaybreakColors colors,
  bool boldText = false,
}) {
  TextStyle project(
    TextStyle style, {
    double? persoFontSize,
    double? persoHeight,
  }) => _project(
    style,
    script,
    boldText: boldText,
    persoFontSize: persoFontSize,
    persoHeight: persoHeight,
  );

  // display 72 / 1.05 / -0.045em, weight 800 — the Today hero dose numeral and
  // nothing else. Persian steps down to 58 / 1.15: Vazirmatn's digits carry
  // more ink at the same point size, so `۹` at 72 optically outweighs `9`.
  final display = project(
    TextStyle(
      fontSize: 72,
      height: 1.05,
      letterSpacing: -0.045 * 72,
      fontWeight: FontWeight.w800,
      color: colors.ink,
    ),
    persoFontSize: 58,
    persoHeight: 1.15,
  );

  // title 34 / 1.25 / -0.03em, weight 800.
  final title = project(
    TextStyle(
      fontSize: 34,
      height: 1.25,
      letterSpacing: -0.03 * 34,
      fontWeight: FontWeight.w800,
      color: colors.ink,
    ),
  );

  // heading 24 / 1.25 / -0.02em, weight 800.
  final heading = project(
    TextStyle(
      fontSize: 24,
      height: 1.25,
      letterSpacing: -0.02 * 24,
      fontWeight: FontWeight.w800,
      color: colors.ink,
    ),
  );

  // body-lg 20 / 1.55 / -0.01em, weight 400.
  final bodyLarge = project(
    TextStyle(
      fontSize: 20,
      height: 1.55,
      letterSpacing: -0.01 * 20,
      fontWeight: FontWeight.w400,
      color: colors.ink,
    ),
  );

  // body-lg at weight 800 — the button label role.
  final bodyLargeStrong = project(
    TextStyle(
      fontSize: 20,
      height: 1.55,
      letterSpacing: -0.01 * 20,
      fontWeight: FontWeight.w800,
      color: colors.ink,
    ),
  );

  // body 17 / 1.60 / -0.01em, weight 400 — every sentence in the product.
  final body = project(
    TextStyle(
      fontSize: 17,
      height: 1.60,
      letterSpacing: -0.01 * 17,
      fontWeight: FontWeight.w400,
      color: colors.ink,
    ),
  );

  // body at weight 700 — the emphatic variant.
  final bodyStrong = project(
    TextStyle(
      fontSize: 17,
      height: 1.60,
      letterSpacing: -0.01 * 17,
      fontWeight: FontWeight.w700,
      color: colors.ink,
    ),
  );

  // label 15 / 1.40 / +0.01em, weight 700.
  final label = project(
    TextStyle(
      fontSize: 15,
      height: 1.40,
      letterSpacing: 0.01 * 15,
      fontWeight: FontWeight.w700,
      color: colors.ink,
    ),
  );

  // caption 14 / 1.45 / +0.02em, weight 600 — badges and tablet breakdowns.
  // Never a full sentence.
  final caption = project(
    TextStyle(
      fontSize: 14,
      height: 1.45,
      letterSpacing: 0.02 * 14,
      fontWeight: FontWeight.w600,
      color: colors.inkMuted,
    ),
  );

  return TextTheme(
    displayLarge: display,
    displayMedium: title,
    displaySmall: title,
    headlineLarge: title,
    headlineMedium: title,
    headlineSmall: heading,
    titleLarge: heading,
    titleMedium: bodyLarge,
    titleSmall: bodyStrong,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: label,
    labelLarge: bodyLargeStrong,
    labelMedium: label,
    labelSmall: caption,
  );
}
