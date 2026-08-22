// Demonstrates the complete Daybreak token build for NearlyStop: the Tier-1
// Primitives pool (hue family + measured CIE L*, the ONLY place a raw Color(0x…)
// appears), the four Tier-2 ThemeExtensions (DaybreakColors / DaybreakShapes /
// DaybreakElevation / DaybreakMotion) with copyWith + honest lerp + an asserting
// of(context), hand-authored light AND dark ColorSchemes that keep the M3 role
// names, warm multi-layer shadows, the 138° sunrise gradient expressed with
// AlignmentDirectional so it mirrors in Persian, and buildDaybreakTheme(Brightness).
//
// In the real app this file is split across lib/theme/{primitives,colors,shapes,
// elevation,motion,theme}.dart. It is kept as one file here so the layering reads
// top to bottom. Per-script typography (Nunito / Vazirmatn, the Persian line-height
// bump) is daybreak-bilingual-type's; only the numeric scale appears here.
import 'dart:ui' show lerpDouble, lerpDuration;

import 'package:flutter/material.dart';

// ===========================================================================
// TIER 1 — PRIMITIVES. The only file allowed a raw Color(0x…).
//
// Naming: <hueFamily><L*>, where L* is CIE perceptual lightness rounded, and the
// family is a measured hue/chroma band:
//   clay  warm brown/cream, hue 15–35, chroma > 12     plum  dark mauve, hue 300–350
//   taupe same hue as clay, chroma < 12                coral hue 5–20, high chroma
//   amber hue 25–45          moss hue 140–165          rose  hue 0–8
// Never a rank ("brown700"), an appearance ("darkBrown"), or a brand ("brandCoral").
// ===========================================================================
abstract final class Primitives {
  // --- clay: the warm neutral spine of the light theme -----------------------
  static const clay100 = Color(0xFFFFFFFF); // surface (light)
  static const clay98 = Color(0xFFFFF9F2); //  bg (light)
  static const clay97 = Color(0xFFFFF4E9); //  surfaceRaised (light)
  static const clay95 = Color(0xFFFCEFE2); //  surfaceSunken (light)
  static const clay94 = Color(0xFFF9EBE2); //  ink (dark)
  static const clay89 = Color(0xFFF0DDCD); //  border (light) — decorative hairline
  static const clay73 = Color(0xFFC9AEA2); //  inkMuted (dark)
  static const clay59 = Color(0xFFA08A80); //  inkFaint (light) — decorative only
  static const clay56 = Color(0xFFA67D68); //  borderStrong + stateMissed (light)
  static const clay42 = Color(0xFF8C5438); //  shadow ink (light) — warm, never black
  static const clay41 = Color(0xFF755B50); //  inkMuted (light)
  static const clay19 = Color(0xFF3B2A25); //  ink (light) + overlay ink (light)
  static const clay11 = Color(0xFF2A1A16); //  onPrimary (both themes)

  // --- taupe: same hue as clay, markedly lower chroma ------------------------
  static const taupe56 = Color(0xFF9A8078); // inkFaint (dark) — decorative only

  // --- plum: the dark theme's neutral spine. Warm, never #000 ----------------
  static const plum01 = Color(0xFF080406); // shadow ink (dark)
  static const plum03 = Color(0xFF10090D); // overlay ink (dark)
  static const plum08 = Color(0xFF1D1418); // surfaceSunken (dark)
  static const plum11 = Color(0xFF241A20); // bg (dark)
  static const plum15 = Color(0xFF2E2229); // surface (dark)
  static const plum19 = Color(0xFF38292F); // surfaceRaised (dark)
  static const plum24 = Color(0xFF45333A); // border (dark)
  static const plum54 = Color(0xFF9A7A82); // borderStrong + stateMissed (dark)

  // --- coral: the brand hue --------------------------------------------------
  static const coral93 = Color(0xFFFFE7DE); // tintPrimary (light)
  static const coral70 = Color(0xFFFF8A66); // primary + primaryDeep + stateToday (dark)
  static const coral66 = Color(0xFFFF7A52); // glow ink (dark); also a sunrise stop
  static const coral64 = Color(0xFFF97350); // primary (light) — FILL ONLY, 2.76:1
  static const coral55 = Color(0xFFE2542F); // stateToday (light)
  static const coral43 = Color(0xFFB0402A); // primaryDeep (light) — accent TEXT, 5.56:1
  static const coral19 = Color(0xFF3E2A26); // tintPrimary (dark)

  // --- amber -----------------------------------------------------------------
  static const amber95 = Color(0xFFFFEFD2); // tintWarning (light)
  static const amber83 = Color(0xFFFFC470); // secondary + stateNewDose (dark)
  static const amber80 = Color(0xFFFFB84D); // secondary + warningFill (light)
  static const amber72 = Color(0xFFE7A54A); // warningFill (dark)
  static const amber42 = Color(0xFF8A5A00); // warning + stateNewDose (light)
  static const amber20 = Color(0xFF3A2E1E); // tintWarning (dark)

  // --- moss ------------------------------------------------------------------
  static const moss94 = Color(0xFFDFF3E8); // tintSuccess (light)
  static const moss78 = Color(0xFF6FD3A4); // success (dark)
  static const moss70 = Color(0xFF4FBF8B); // successFill + stateTaken (dark)
  static const moss52 = Color(0xFF2E8B63); // successFill + stateTaken (light)
  static const moss46 = Color(0xFF1F7A55); // success (light)
  static const moss22 = Color(0xFF25382F); // tintSuccess (dark)

  // --- rose ------------------------------------------------------------------
  static const rose92 = Color(0xFFFCE4E1); // tintDanger (light)
  static const rose70 = Color(0xFFFF8A80); // danger (dark)
  static const rose58 = Color(0xFFE0655A); // dangerFill (dark)
  static const rose47 = Color(0xFFC63F32); // dangerFill (light)
  static const rose40 = Color(0xFFA8352B); // danger (light)
  static const rose18 = Color(0xFF3E2624); // tintDanger (dark)

  // --- gradients -------------------------------------------------------------
  // A stop that appears ONLY inside a gradient stays inline here and gets no
  // primitive name: a named stop invites a widget to use it as a flat fill, and
  // the contrast budget never measured it as one.
  //
  // CSS `linear-gradient(138deg, …)` measures clockwise from "to top"; Flutter's
  // Alignment box is -1..1 with +y DOWNWARD, so the direction vector is
  // (sin 138°, -cos 138°) = (0.669, 0.743). AlignmentDirectional (not Alignment)
  // so the light falls from the LEADING top corner in Persian too.
  static const _begin = AlignmentDirectional(-0.669, -0.743);
  static const _end = AlignmentDirectional(0.669, 0.743);

  static const sunriseLight = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [Color(0xFFF9633F), coral64, Color(0xFFFF9A4D), Color(0xFFFFC46A)],
    stops: [0, 0.32, 0.68, 1],
  );

  static const sunriseDark = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [Color(0xFFE8613F), coral66, Color(0xFFFF9E52), amber83],
    stops: [0, 0.34, 0.70, 1],
  );

  // The page wash is vertical in both scripts — no directional component to mirror.
  static const washLight = LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: [Color(0xFFFFF7EE), clay100],
  );

  static const washDark = LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: [Color(0xFF3B2B31), plum15],
  );
}

// ===========================================================================
// TIER 2a — DaybreakColors. Widgets read THESE.
// ===========================================================================
@immutable
class DaybreakColors extends ThemeExtension<DaybreakColors> {
  const DaybreakColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.primary,
    required this.primaryDeep,
    required this.secondary,
    required this.onPrimary,
    required this.success,
    required this.successFill,
    required this.warning,
    required this.warningFill,
    required this.danger,
    required this.dangerFill,
    required this.tintPrimary,
    required this.tintSuccess,
    required this.tintWarning,
    required this.tintDanger,
    required this.border,
    required this.borderStrong,
    required this.overlay,
    required this.stateTaken,
    required this.stateMissed,
    required this.stateToday,
    required this.stateNewDose,
    required this.sunrise,
    required this.wash,
  });

  final Color bg, surface, surfaceRaised, surfaceSunken;
  final Color ink, inkMuted, inkFaint;

  /// FILL ONLY in the light theme (2.76:1 on [surface]). Accent text, links, the active
  /// tab label and the focus ring use [primaryDeep].
  final Color primary;
  final Color primaryDeep, secondary, onPrimary;
  final Color success, successFill, warning, warningFill, danger, dangerFill;
  final Color tintPrimary, tintSuccess, tintWarning, tintDanger;

  /// Decorative hairline (~1.35:1). Never the sole boundary of a control — that
  /// is [borderStrong] (3.65:1), which is what ColorScheme.outline maps to.
  final Color border;
  final Color borderStrong, overlay;

  /// The day-state quartet. Colour is DERIVED here and never the only channel:
  /// every state also carries a glyph, a word, and a shape (daybreak-components).
  /// [stateMissed] is warm taupe, deliberately not [danger] — a missed dose is
  /// never rendered as a failure.
  final Color stateTaken, stateMissed, stateToday, stateNewDose;

  final LinearGradient sunrise, wash;

  /// Assert, never `?? fallback`: a fallback ships a palette no contrast test
  /// ever measured, and loud-in-debug beats unreadable-on-a-bedside-table.
  static DaybreakColors of(BuildContext context) {
    final ext = Theme.of(context).extension<DaybreakColors>();
    assert(ext != null, 'DaybreakColors missing. Build via buildDaybreakTheme().');
    return ext!;
  }

  @override
  DaybreakColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? primary,
    Color? primaryDeep,
    Color? secondary,
    Color? onPrimary,
    Color? success,
    Color? successFill,
    Color? warning,
    Color? warningFill,
    Color? danger,
    Color? dangerFill,
    Color? tintPrimary,
    Color? tintSuccess,
    Color? tintWarning,
    Color? tintDanger,
    Color? border,
    Color? borderStrong,
    Color? overlay,
    Color? stateTaken,
    Color? stateMissed,
    Color? stateToday,
    Color? stateNewDose,
    LinearGradient? sunrise,
    LinearGradient? wash,
  }) {
    return DaybreakColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      primary: primary ?? this.primary,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      secondary: secondary ?? this.secondary,
      onPrimary: onPrimary ?? this.onPrimary,
      success: success ?? this.success,
      successFill: successFill ?? this.successFill,
      warning: warning ?? this.warning,
      warningFill: warningFill ?? this.warningFill,
      danger: danger ?? this.danger,
      dangerFill: dangerFill ?? this.dangerFill,
      tintPrimary: tintPrimary ?? this.tintPrimary,
      tintSuccess: tintSuccess ?? this.tintSuccess,
      tintWarning: tintWarning ?? this.tintWarning,
      tintDanger: tintDanger ?? this.tintDanger,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      overlay: overlay ?? this.overlay,
      stateTaken: stateTaken ?? this.stateTaken,
      stateMissed: stateMissed ?? this.stateMissed,
      stateToday: stateToday ?? this.stateToday,
      stateNewDose: stateNewDose ?? this.stateNewDose,
      sunrise: sunrise ?? this.sunrise,
      wash: wash ?? this.wash,
    );
  }

  /// Every field interpolates. A field added above but forgotten here is the
  /// classic design-system rot: it would snap while its neighbours cross-faded.
  @override
  DaybreakColors lerp(covariant DaybreakColors? other, double t) {
    if (other == null) return this;
    return DaybreakColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      success: Color.lerp(success, other.success, t)!,
      successFill: Color.lerp(successFill, other.successFill, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningFill: Color.lerp(warningFill, other.warningFill, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerFill: Color.lerp(dangerFill, other.dangerFill, t)!,
      tintPrimary: Color.lerp(tintPrimary, other.tintPrimary, t)!,
      tintSuccess: Color.lerp(tintSuccess, other.tintSuccess, t)!,
      tintWarning: Color.lerp(tintWarning, other.tintWarning, t)!,
      tintDanger: Color.lerp(tintDanger, other.tintDanger, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      stateTaken: Color.lerp(stateTaken, other.stateTaken, t)!,
      stateMissed: Color.lerp(stateMissed, other.stateMissed, t)!,
      stateToday: Color.lerp(stateToday, other.stateToday, t)!,
      stateNewDose: Color.lerp(stateNewDose, other.stateNewDose, t)!,
      // LinearGradient.lerp interpolates stop-by-stop and returns a LinearGradient
      // whenever both inputs are LinearGradients with the same stop count.
      sunrise: LinearGradient.lerp(sunrise, other.sunrise, t)!,
      wash: LinearGradient.lerp(wash, other.wash, t)!,
    );
  }
}

const lightDaybreakColors = DaybreakColors(
  bg: Primitives.clay98,
  surface: Primitives.clay100,
  surfaceRaised: Primitives.clay97,
  surfaceSunken: Primitives.clay95,
  ink: Primitives.clay19,
  inkMuted: Primitives.clay41,
  inkFaint: Primitives.clay59,
  primary: Primitives.coral64,
  primaryDeep: Primitives.coral43,
  secondary: Primitives.amber80,
  onPrimary: Primitives.clay11,
  success: Primitives.moss46,
  successFill: Primitives.moss52,
  warning: Primitives.amber42,
  warningFill: Primitives.amber80,
  danger: Primitives.rose40,
  dangerFill: Primitives.rose47,
  tintPrimary: Primitives.coral93,
  tintSuccess: Primitives.moss94,
  tintWarning: Primitives.amber95,
  tintDanger: Primitives.rose92,
  border: Primitives.clay89,
  borderStrong: Primitives.clay56,
  overlay: Color(0x8C3B2A25), // clay19 @ 55%
  stateTaken: Primitives.moss52,
  stateMissed: Primitives.clay56,
  stateToday: Primitives.coral55,
  stateNewDose: Primitives.amber42,
  sunrise: Primitives.sunriseLight,
  wash: Primitives.washLight,
);

// Dark is HAND-TUNED, not a flip: every accent is raised in luminance to clear AA
// on a dark ground, and the ground itself stays warm (plum11, never #000).
const darkDaybreakColors = DaybreakColors(
  bg: Primitives.plum11,
  surface: Primitives.plum15,
  surfaceRaised: Primitives.plum19,
  surfaceSunken: Primitives.plum08,
  ink: Primitives.clay94,
  inkMuted: Primitives.clay73,
  inkFaint: Primitives.taupe56,
  primary: Primitives.coral70,
  primaryDeep: Primitives.coral70, // in dark the fill and the text tone converge
  secondary: Primitives.amber83,
  onPrimary: Primitives.clay11,
  success: Primitives.moss78,
  successFill: Primitives.moss70,
  warning: Primitives.amber83,
  warningFill: Primitives.amber72,
  danger: Primitives.rose70,
  dangerFill: Primitives.rose58,
  tintPrimary: Primitives.coral19,
  tintSuccess: Primitives.moss22,
  tintWarning: Primitives.amber20,
  tintDanger: Primitives.rose18,
  border: Primitives.plum24,
  borderStrong: Primitives.plum54,
  overlay: Color(0xA810090D), // plum03 @ 66%
  stateTaken: Primitives.moss70,
  stateMissed: Primitives.plum54,
  stateToday: Primitives.coral70,
  stateNewDose: Primitives.amber83,
  sunrise: Primitives.sunriseDark,
  wash: Primitives.washDark,
);

// ===========================================================================
// TIER 2b — DaybreakShapes: radii, the spacing ramp, and silhouette factories.
// ===========================================================================
@immutable
class DaybreakShapes extends ThemeExtension<DaybreakShapes> {
  const DaybreakShapes({
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusPill,
    required this.hairlineWidth,
    required this.focusRingWidth,
  });

  final double radiusXs, radiusSm, radiusMd, radiusLg, radiusXl, radiusPill;
  final double hairlineWidth, focusRingWidth;

  // The spacing ramp is fixed across themes, so it is const rather than a lerped
  // field: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48.
  double get s1 => 4;
  double get s2 => 8;
  double get s3 => 12;
  double get s4 => 16;
  double get s5 => 20;
  double get s6 => 24;
  double get s7 => 32;
  double get s8 => 40;
  double get s9 => 48;

  static DaybreakShapes of(BuildContext context) {
    final ext = Theme.of(context).extension<DaybreakShapes>();
    assert(ext != null, 'DaybreakShapes missing. Build via buildDaybreakTheme().');
    return ext!;
  }

  /// Cards, day rows, taper-step blocks. Components ask for the silhouette, not
  /// the number, so re-shaping the system is one edit here.
  RoundedRectangleBorder cardShape({BorderSide side = BorderSide.none}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg), side: side);

  /// The dose hero and the disclaimer sheet's top corners.
  RoundedRectangleBorder heroShape() =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl));

  RoundedRectangleBorder sheetShape() => RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
      );

  /// Chips, the active tab pill, the "New dose day" badge.
  StadiumBorder pillShape({BorderSide side = BorderSide.none}) => StadiumBorder(side: side);

  @override
  DaybreakShapes copyWith({
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusPill,
    double? hairlineWidth,
    double? focusRingWidth,
  }) {
    return DaybreakShapes(
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusPill: radiusPill ?? this.radiusPill,
      hairlineWidth: hairlineWidth ?? this.hairlineWidth,
      focusRingWidth: focusRingWidth ?? this.focusRingWidth,
    );
  }

  @override
  DaybreakShapes lerp(covariant DaybreakShapes? other, double t) {
    if (other == null) return this;
    return DaybreakShapes(
      radiusXs: lerpDouble(radiusXs, other.radiusXs, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t)!,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t)!,
      hairlineWidth: lerpDouble(hairlineWidth, other.hairlineWidth, t)!,
      focusRingWidth: lerpDouble(focusRingWidth, other.focusRingWidth, t)!,
    );
  }
}

// Shapes are theme-independent — the same instance is attached to both ThemeDatas.
const daybreakShapes = DaybreakShapes(
  radiusXs: 8,
  radiusSm: 12,
  radiusMd: 16,
  radiusLg: 24,
  radiusXl: 32,
  radiusPill: 999,
  hairlineWidth: 1,
  focusRingWidth: 3,
);

// ===========================================================================
// TIER 2c — DaybreakElevation: warm, multi-layer shadows.
//
// Flutter has no multi-layer shadow token, so each level is a List<BoxShadow>.
// CSS blur `b` means sigma = b/2; Flutter's blurRadius `r` means
// sigma = 0.57735*r + 0.5. Solving: r ~= 0.866 * (b - 1). Writing the CSS number
// straight into blurRadius lands every shadow ~15% tight — a hard edge where the
// system wants a warm lift. Each BoxShadow below carries its CSS source.
// ===========================================================================
@immutable
class DaybreakElevation extends ThemeExtension<DaybreakElevation> {
  const DaybreakElevation({
    required this.level0,
    required this.level1,
    required this.level2,
    required this.level3,
    required this.glow,
  });

  final List<BoxShadow> level0, level1, level2, level3;

  /// Reserved for the one element per screen that carries the sunrise gradient.
  final List<BoxShadow> glow;

  static DaybreakElevation of(BuildContext context) {
    final ext = Theme.of(context).extension<DaybreakElevation>();
    assert(ext != null, 'DaybreakElevation missing. Build via buildDaybreakTheme().');
    return ext!;
  }

  @override
  DaybreakElevation copyWith({
    List<BoxShadow>? level0,
    List<BoxShadow>? level1,
    List<BoxShadow>? level2,
    List<BoxShadow>? level3,
    List<BoxShadow>? glow,
  }) {
    return DaybreakElevation(
      level0: level0 ?? this.level0,
      level1: level1 ?? this.level1,
      level2: level2 ?? this.level2,
      level3: level3 ?? this.level3,
      glow: glow ?? this.glow,
    );
  }

  @override
  DaybreakElevation lerp(covariant DaybreakElevation? other, double t) {
    if (other == null) return this;
    return DaybreakElevation(
      level0: BoxShadow.lerpList(level0, other.level0, t)!,
      level1: BoxShadow.lerpList(level1, other.level1, t)!,
      level2: BoxShadow.lerpList(level2, other.level2, t)!,
      level3: BoxShadow.lerpList(level3, other.level3, t)!,
      glow: BoxShadow.lerpList(glow, other.glow, t)!,
    );
  }
}

List<BoxShadow> _shadow(Color ink, List<(double dy, double cssBlur, double alpha)> layers) => [
      for (final (dy, cssBlur, alpha) in layers)
        BoxShadow(
          color: ink.withValues(alpha: alpha),
          offset: Offset(0, dy),
          blurRadius: 0.866 * (cssBlur - 1),
        ),
    ];

// Warm brown in light, plum-black in dark. NEVER Colors.black: a neutral shadow on
// a #FFF9F2 ground reads as grey dirt and drains the warmth the brief rests on.
final lightDaybreakElevation = DaybreakElevation(
  level0: const <BoxShadow>[],
  level1: _shadow(Primitives.clay42, const [(1.0, 2.0, .07), (2.0, 8.0, .06)]),
  level2: _shadow(Primitives.clay42, const [(2.0, 4.0, .07), (10.0, 24.0, .10)]),
  level3: _shadow(Primitives.clay42, const [(6.0, 12.0, .09), (22.0, 48.0, .14)]),
  glow: _shadow(Primitives.coral64, const [(8.0, 18.0, .22), (20.0, 44.0, .20)]),
);

final darkDaybreakElevation = DaybreakElevation(
  level0: const <BoxShadow>[],
  level1: _shadow(Primitives.plum01, const [(1.0, 2.0, .35), (2.0, 8.0, .30)]),
  level2: _shadow(Primitives.plum01, const [(2.0, 4.0, .40), (10.0, 24.0, .45)]),
  level3: _shadow(Primitives.plum01, const [(6.0, 12.0, .48), (22.0, 48.0, .55)]),
  glow: _shadow(Primitives.coral66, const [(8.0, 18.0, .24), (20.0, 44.0, .18)]),
);

// ===========================================================================
// TIER 2d — DaybreakMotion.
// ===========================================================================
@immutable
class DaybreakMotion extends ThemeExtension<DaybreakMotion> {
  const DaybreakMotion({
    required this.fast,
    required this.base,
    required this.slow,
    required this.easeOut,
    required this.easeInOut,
  });

  /// 120ms — a tap's own feedback.
  final Duration fast;

  /// 220ms — a state change the user caused (ticking a dose, opening a block).
  final Duration base;

  /// 420ms — the one celebratory moment: a taper step completing.
  final Duration slow;

  final Curve easeOut, easeInOut;

  static DaybreakMotion of(BuildContext context) {
    final ext = Theme.of(context).extension<DaybreakMotion>();
    assert(ext != null, 'DaybreakMotion missing. Build via buildDaybreakTheme().');
    return ext!;
  }

  @override
  DaybreakMotion copyWith({
    Duration? fast,
    Duration? base,
    Duration? slow,
    Curve? easeOut,
    Curve? easeInOut,
  }) {
    return DaybreakMotion(
      fast: fast ?? this.fast,
      base: base ?? this.base,
      slow: slow ?? this.slow,
      easeOut: easeOut ?? this.easeOut,
      easeInOut: easeInOut ?? this.easeInOut,
    );
  }

  /// Durations interpolate; Curves are not interpolable, so they SNAP at the
  /// midpoint. That is deliberate, not unfinished — a half-way curve has no
  /// meaning, and light/dark share these curves anyway.
  @override
  DaybreakMotion lerp(covariant DaybreakMotion? other, double t) {
    if (other == null) return this;
    return DaybreakMotion(
      fast: lerpDuration(fast, other.fast, t),
      base: lerpDuration(base, other.base, t),
      slow: lerpDuration(slow, other.slow, t),
      easeOut: t < 0.5 ? easeOut : other.easeOut,
      easeInOut: t < 0.5 ? easeInOut : other.easeInOut,
    );
  }
}

const daybreakMotion = DaybreakMotion(
  fast: Duration(milliseconds: 120),
  base: Duration(milliseconds: 220),
  slow: Duration(milliseconds: 420),
  easeOut: Cubic(0.22, 0.85, 0.34, 1),
  easeInOut: Cubic(0.65, 0, 0.35, 1),
);

/// The one place a widget asks "should I animate?". Reduced motion collapses to
/// ZERO — never a shorter duration, never a softer curve.
Duration resolveMotion(BuildContext context, Duration full) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : full;

// ===========================================================================
// THEME BUILDER — hand-authored ColorScheme for BOTH brightnesses.
// ===========================================================================
ThemeData buildDaybreakTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final c = isDark ? darkDaybreakColors : lightDaybreakColors;
  final e = isDark ? darkDaybreakElevation : lightDaybreakElevation;

  // NEVER ColorScheme.fromSeed and never dynamic_color: Daybreak's light primary
  // is 2.76:1 and its border is ~1.35:1, so a seed would hand Material ~40 derived
  // roles nothing ever measured. State every role the app consumes; unstated roles
  // fall back to ColorScheme's own defaults rather than a seed's opinion.
  final scheme = ColorScheme(
    brightness: brightness,
    // primary is the role Material paints TEXT and icons with (TextButton,
    // active states), so it maps to primaryDeep — the TEXT-safe tone — not to
    // c.primary, which is fill-only at 2.76:1 in light.
    primary: c.primaryDeep,
    onPrimary: isDark ? c.onPrimary : c.bg,
    primaryContainer: c.tintPrimary,
    onPrimaryContainer: c.primaryDeep,
    secondary: c.warning,
    onSecondary: isDark ? c.onPrimary : c.bg,
    secondaryContainer: c.tintWarning,
    onSecondaryContainer: c.warning,
    tertiary: c.success,
    onTertiary: isDark ? c.onPrimary : c.bg,
    tertiaryContainer: c.tintSuccess,
    onTertiaryContainer: c.success,
    error: c.danger,
    onError: isDark ? c.onPrimary : c.bg,
    errorContainer: c.tintDanger,
    onErrorContainer: c.danger,
    surface: c.surface,
    onSurface: c.ink,
    surfaceDim: c.bg,
    surfaceBright: c.surface,
    surfaceContainerLowest: c.surfaceSunken,
    surfaceContainerLow: c.bg,
    surfaceContainer: c.surfaceRaised,
    surfaceContainerHigh: c.surfaceRaised,
    surfaceContainerHighest: c.surfaceRaised,
    onSurfaceVariant: c.inkMuted,
    // outline is what TextField, Switch, Checkbox and OutlinedButton draw their
    // BOUNDARY from — it must be borderStrong (3.65:1), never the decorative
    // hairline, or every control loses its visible edge.
    outline: c.borderStrong,
    outlineVariant: c.border,
    scrim: c.overlay,
    shadow: isDark ? Primitives.plum01 : Primitives.clay42,
    inverseSurface: c.ink,
    onInverseSurface: c.surface,
    inversePrimary: c.primary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    // Bundled, license-registered faces. NEVER google_fonts: NearlyStop is offline
    // and account-free. The per-script cascade and the Persian metric adjustments
    // are daybreak-bilingual-type's; only the numeric scale lives here.
    fontFamily: 'Nunito',
    fontFamilyFallback: const ['Vazirmatn'],
    textTheme: _daybreakTextTheme(c),
    // Material's own theme cross-fade is a luminance jolt on a bedside screen.
    // themeAnimationStyle is set on MaterialApp, not here — see the App widget.
    extensions: <ThemeExtension<dynamic>>[c, daybreakShapes, e, daybreakMotion],
  );
}

// display 72 · title 34 · heading 24 · body-lg 20 · body 17 · label 15 · caption 14
// Line heights: tight 1.05 · snug 1.25 · body 1.6. Persian bumps each by +0.14 and
// steps display down to 58 — that projection is daybreak-bilingual-type's.
TextTheme _daybreakTextTheme(DaybreakColors c) => TextTheme(
      displayLarge: TextStyle(
        fontSize: 72,
        height: 1.05,
        letterSpacing: -0.045 * 72,
        fontWeight: FontWeight.w800,
        color: c.ink,
      ),
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.25,
        letterSpacing: -0.03 * 34,
        fontWeight: FontWeight.w800,
        color: c.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        height: 1.25,
        letterSpacing: -0.02 * 24,
        fontWeight: FontWeight.w800,
        color: c.ink,
      ),
      bodyLarge: TextStyle(fontSize: 20, height: 1.6, color: c.ink),
      bodyMedium: TextStyle(fontSize: 17, height: 1.6, color: c.ink),
      labelLarge: TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w700, color: c.ink),
      bodySmall: TextStyle(fontSize: 14, height: 1.6, color: c.inkMuted),
    );

// ===========================================================================
// INJECTION — once, at the composition root.
// ===========================================================================
class App extends StatelessWidget {
  const App({required this.themeMode, super.key});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildDaybreakTheme(Brightness.light),
      darkTheme: buildDaybreakTheme(Brightness.dark),
      themeMode: themeMode,
      // Material interpolates ThemeData over kThemeAnimationDuration by default;
      // for a 6am theme switch that cross-fade is a luminance jolt nobody asked for.
      themeAnimationStyle: AnimationStyle.noAnimation,
      home: const _TodayHeroDemo(),
    );
  }
}

// ===========================================================================
// A CONSUMER — the Today hero. Every aesthetic value is a slot read.
// ===========================================================================
class _TodayHeroDemo extends StatelessWidget {
  const _TodayHeroDemo();

  @override
  Widget build(BuildContext context) {
    final c = DaybreakColors.of(context);
    final s = DaybreakShapes.of(context);
    final e = DaybreakElevation.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: c.wash),
        padding: EdgeInsetsDirectional.all(s.s6),
        child: AnimatedContainer(
          duration: resolveMotion(context, DaybreakMotion.of(context).base),
          curve: DaybreakMotion.of(context).easeOut,
          padding: EdgeInsetsDirectional.all(s.s7),
          decoration: BoxDecoration(
            gradient: c.sunrise, // mirrors in Persian: AlignmentDirectional
            borderRadius: BorderRadius.circular(s.radiusXl),
            boxShadow: e.glow, // the ONE glow on this screen
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // onPrimary is the only foreground measured on the gradient:
              // 6.04:1 on the coral stop, 9.71:1 on the amber stop. White fails.
              Text('9 mg', style: text.displayLarge!.copyWith(color: c.onPrimary)),
              SizedBox(height: s.s3),
              // A number that matters goes on an OPAQUE chip, never on the
              // gradient: text over a gradient can only be verified at its worst
              // stop, and ink-on-surface is 13.6:1.
              Container(
                padding: EdgeInsetsDirectional.symmetric(horizontal: s.s4, vertical: s.s2),
                decoration: ShapeDecoration(color: c.surface, shape: s.pillShape()),
                child: Text('Step 3 of 15', style: text.labelLarge!.copyWith(color: c.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
