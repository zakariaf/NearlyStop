/// Tier 2a — the colour slots widgets read.
///
/// A widget reads `DaybreakColors.of(context).ink`, never `Primitives.clay19`:
/// a primitive is a value with no theme, and a widget holding one hardcodes
/// light mode and renders brown-on-brown the first time someone switches to
/// dark at 6am.
///
/// Four palettes ship: light, dark, and a high-contrast pair selected by
/// `buildDaybreakTheme(..., highContrast: true)`. The high-contrast pair is
/// authored as an **override over the base**, so the two cannot drift apart
/// structurally — a slot added to one is added to both by construction.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nearlystop/theme/gradients.dart';
import 'package:nearlystop/theme/primitives.dart';

/// Every colour the app is allowed to render, as named slots.
@immutable
class DaybreakColors extends ThemeExtension<DaybreakColors> {
  /// Creates a palette. Every slot is required: a nullable slot is a slot that
  /// renders as `null` on the one screen nobody checked.
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

  /// The page ground behind every surface.
  final Color bg;

  /// The default card and sheet ground.
  final Color surface;

  /// A surface lifted above [surface] — headers, raised rows.
  final Color surfaceRaised;

  /// A surface recessed below [surface] — wells, inactive tracks.
  final Color surfaceSunken;

  /// Body and heading text. 13.60:1 on [surface].
  final Color ink;

  /// Secondary text that a user still has to read. 6.23:1 on [surface].
  final Color inkMuted;

  /// Disabled glyphs and placeholders **only** — never body copy, never a
  /// caption a user must read, never a label attached to a control they
  /// operate.
  final Color inkFaint;

  /// The signature coral.
  ///
  /// **FILL ONLY in the light theme — 2.76:1 on [surface].** Never text, never
  /// a meaningful icon, never a control boundary or a focus ring. Accent text,
  /// links, the active tab label and the focus ring use [primaryDeep]. In dark
  /// the distinction collapses (both are `coral70` at 7.30:1), which is exactly
  /// why the light theme's discipline is enforced by the contrast test rather
  /// than by "it looked fine when I checked".
  final Color primary;

  /// The text-safe accent tone. 5.56:1 on [bg]. This is what
  /// `ColorScheme.primary` maps to.
  final Color primaryDeep;

  /// The warm secondary accent.
  final Color secondary;

  /// The **only** foreground allowed on [primary] and on the [sunrise] gradient
  /// — 6.04:1 at the gradient's worst stop, where white measures 2.76:1 and
  /// fails.
  ///
  /// Deliberately different from `ColorScheme.onPrimary`, which sits on
  /// `ColorScheme.primary` (= [primaryDeep]) instead. Two roles, two grounds,
  /// two colours.
  final Color onPrimary;

  /// Success text.
  final Color success;

  /// A success fill or mark.
  final Color successFill;

  /// Warning text.
  final Color warning;

  /// A warning fill or mark.
  final Color warningFill;

  /// Danger text. Reserved for something actually going wrong — a missed dose
  /// is not one (see [stateMissed]).
  final Color danger;

  /// A danger fill or mark.
  final Color dangerFill;

  /// An opaque wash behind [primaryDeep] text.
  final Color tintPrimary;

  /// An opaque wash behind [success] text.
  final Color tintSuccess;

  /// An opaque wash behind [warning] text.
  final Color tintWarning;

  /// An opaque wash behind [danger] text.
  final Color tintDanger;

  /// The decorative hairline between rows of the same weight (~1.35:1). Never
  /// the sole boundary of a control, never an input outline, never a focus ring
  /// — that is [borderStrong]. Maps to `ColorScheme.outlineVariant`.
  final Color border;

  /// A visible control boundary, 3.65:1 on [surface]. Maps to
  /// `ColorScheme.outline`, which is what Material draws every `TextField`,
  /// `Switch`, `Checkbox` and `OutlinedButton` edge from.
  final Color borderStrong;

  /// The scrim behind a modal sheet. Translucent, so nothing is ever measured
  /// against it — text over the disclaimer scrim sits on the sheet's opaque
  /// [surface].
  final Color overlay;

  /// A day whose dose was ticked.
  final Color stateTaken;

  /// A day that was never ticked.
  ///
  /// Warm taupe, deliberately **not** [danger]. This app is opened every
  /// morning for ~780 days by someone already frightened; red punishes a person
  /// for a bad morning. Argued once, in EPIC-02; a change back to red is a
  /// product decision, not a palette tidy-up, and the theme test says so.
  final Color stateMissed;

  /// Today's row.
  final Color stateToday;

  /// A day on which the new dose is taken. Selected by a separate `isNewDose`
  /// bool, never by a fifth `DayState` member — a day is routinely both `today`
  /// and a new-dose day.
  final Color stateNewDose;

  /// The signature sunrise. At most one per screen; only [onPrimary] on it.
  final LinearGradient sunrise;

  /// The page wash behind a scrolling surface.
  final LinearGradient wash;

  /// Reads the palette out of [context].
  ///
  /// **Asserts** rather than falling back: a fallback ships a palette no
  /// contrast row ever measured, and loud-in-debug beats
  /// unreadable-on-a-bedside-table.
  static DaybreakColors of(BuildContext context) {
    final ext = Theme.of(context).extension<DaybreakColors>();
    assert(
      ext != null,
      'DaybreakColors missing. Build via buildDaybreakTheme().',
    );
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

  /// Interpolates **every** field.
  ///
  /// A field added above and forgotten here is the classic design-system rot:
  /// it would snap while its neighbours cross-faded.
  /// `theme_extension_test.dart` walks the fields so the omission is a red
  /// test, not a visual artefact.
  @override
  DaybreakColors lerp(covariant DaybreakColors? other, double t) {
    if (other == null) return this;
    // Short-circuit the endpoints. Beyond saving an allocation on the two
    // most common values of t, it is what makes `lerp(a, b, 0) == a`
    // exact: LinearGradient.lerp MERGES two different stop lists, so a
    // gradient interpolated to t = 0 carries the union of both and is
    // not `a`.
    if (t <= 0) return this;
    if (t >= 1) return other;
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
      // LinearGradient.lerp interpolates stop by stop and returns a
      // LinearGradient whenever both inputs are LinearGradients.
      sunrise: LinearGradient.lerp(sunrise, other.sunrise, t)!,
      wash: LinearGradient.lerp(wash, other.wash, t)!,
    );
  }

  /// Every slot, in declaration order, for value equality.
  ///
  /// `ThemeData` compares its extensions with `==`, so without this two
  /// structurally identical themes are "different" and every `Theme.of`
  /// dependent rebuilds on a theme that did not change.
  List<Object?> get _props => <Object?>[
    bg,
    surface,
    surfaceRaised,
    surfaceSunken,
    ink,
    inkMuted,
    inkFaint,
    primary,
    primaryDeep,
    secondary,
    onPrimary,
    success,
    successFill,
    warning,
    warningFill,
    danger,
    dangerFill,
    tintPrimary,
    tintSuccess,
    tintWarning,
    tintDanger,
    border,
    borderStrong,
    overlay,
    stateTaken,
    stateMissed,
    stateToday,
    stateNewDose,
    sunrise,
    wash,
  ];

  @override
  bool operator ==(Object other) =>
      other is DaybreakColors && listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

/// The light palette.
const DaybreakColors lightDaybreakColors = DaybreakColors(
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
  overlay: Color(0x8C3B2A25), // clay19 at 55%
  stateTaken: Primitives.moss52,
  stateMissed: Primitives.clay56,
  stateToday: Primitives.coral55,
  stateNewDose: Primitives.amber42,
  sunrise: DaybreakGradients.sunriseLight,
  wash: DaybreakGradients.washLight,
);

/// The dark palette.
///
/// **Authored, not flipped.** Every accent is raised in luminance to clear AA
/// on a dark ground, and the ground itself stays warm — `plum11`, never
/// `#000000`. This is a 6am bedside screen; an OLED-true-black void is the cold
/// clinical register the brief rules out.
const DaybreakColors darkDaybreakColors = DaybreakColors(
  bg: Primitives.plum11,
  surface: Primitives.plum15,
  surfaceRaised: Primitives.plum19,
  surfaceSunken: Primitives.plum08,
  ink: Primitives.clay94,
  inkMuted: Primitives.clay73,
  inkFaint: Primitives.taupe56,
  primary: Primitives.coral70,
  primaryDeep:
      Primitives.coral70, // in dark the fill and the text tone converge
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
  overlay: Color(0xA810090D), // plum03 at 66%
  stateTaken: Primitives.moss70,
  stateMissed: Primitives.plum54,
  stateToday: Primitives.coral70,
  stateNewDose: Primitives.amber83,
  sunrise: DaybreakGradients.sunriseDark,
  wash: DaybreakGradients.washDark,
);

/// The light high-contrast palette.
///
/// A **derivation with a measured result**, not a second design — authored as a
/// `copyWith` over [lightDaybreakColors] so the two cannot drift apart
/// structurally. Text rows clear **7:1**; boundary and state-mark rows clear
/// **4.5:1**.
///
/// Four structural moves:
///
/// * `border` becomes `borderStrong` — the decorative hairline disappears as a
///   concept.
/// * `inkMuted` becomes `ink`, and `inkFaint` steps down to a tone that clears
///   7:1. For this population a caption they cannot read is a caption that is
///   not there.
/// * `stateMissed` stays warm taupe, darkened until it clears the floor. It
/// does
///   **not** become `danger`: high contrast changes the luminance, never the
///   emotional register.
/// * `primary` stays exactly as decorative as in the base palette. Raising the
///   coral to clear 7:1 would destroy the signature and is not what the toggle
///   promises; the high-contrast path reaches text through `primaryDeep`.
///
/// Honest limit: high contrast is a **palette** swap. It does not change type
/// size, spacing or hit targets — those are the text-scale and 48dp floors,
/// which are always on.
final DaybreakColors lightHighContrastDaybreakColors = lightDaybreakColors
    .copyWith(
      inkMuted: lightDaybreakColors.ink,
      inkFaint: Primitives.clay37,
      primaryDeep: Primitives.coral33,
      onPrimary: Primitives.clay04,
      success: Primitives.moss34,
      warning: Primitives.amber34,
      danger: Primitives.rose32,
      border: Primitives.clay50,
      borderStrong: Primitives.clay50,
      stateTaken: Primitives.moss50,
      stateMissed: Primitives.clay50,
      stateToday: Primitives.coral50,
    );

/// The dark high-contrast palette — the same derivation on a dark ground, where
/// the lift comes from raising the foregrounds rather than pushing `bg` to
/// `#000000`.
final DaybreakColors darkHighContrastDaybreakColors = darkDaybreakColors
    .copyWith(
      inkMuted: darkDaybreakColors.ink,
      inkFaint: Primitives.clay73,
      // The dark sunrise's worst stop is `coral66`, one step darker than the
      // light one, so the base `clay11` measures 6.49:1 there and misses the
      // 7:1 floor. Reuses the light high-contrast tone rather than minting a
      // sixteenth primitive: 7.53:1 on that stop, 8.38:1 on the coral fill.
      onPrimary: Primitives.clay04,
      primaryDeep: Primitives.coral76,
      success: Primitives.moss79,
      danger: Primitives.rose75,
      border: Primitives.plum58,
      borderStrong: Primitives.plum58,
      stateMissed: Primitives.plum58,
    );

/// Selects one of the four palettes.
DaybreakColors daybreakColorsFor(
  Brightness brightness, {
  required bool highContrast,
}) => switch ((brightness, highContrast)) {
  (Brightness.light, false) => lightDaybreakColors,
  (Brightness.light, true) => lightHighContrastDaybreakColors,
  (Brightness.dark, false) => darkDaybreakColors,
  (Brightness.dark, true) => darkHighContrastDaybreakColors,
};
