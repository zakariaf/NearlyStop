/// Tier 2c — warm, multi-layer elevation.
///
/// Flutter has no multi-layer shadow token, so each level is a
/// `List<BoxShadow>`. Never `Material(elevation:)` and never `Colors.black`: a
/// neutral shadow on a `#FFF9F2` ground reads as grey dirt and drains the
/// warmth the whole emotional brief rests on.
///
/// **CSS blur is not Flutter `blurRadius`.** CSS blur `b` means σ = `b/2`;
/// Flutter's `blurRadius` r means σ = `0.57735·r + 0.5`. Solving, **r ≈
/// 0.866·(b − 1)**. Writing the CSS number straight in makes every shadow about
/// 15% too tight — a hard edge where the system wants a warm lift — and nothing
/// else in the suite notices. Each layer below carries its CSS source.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nearlystop/theme/primitives.dart';

/// The elevation slots widgets read.
@immutable
class DaybreakElevation extends ThemeExtension<DaybreakElevation> {
  /// Creates the elevation set.
  const DaybreakElevation({
    required this.level0,
    required this.level1,
    required this.level2,
    required this.level3,
    required this.glow,
  });

  /// Flat on the ground — the empty list.
  final List<BoxShadow> level0;

  /// A row or chip lifted just off the surface.
  final List<BoxShadow> level1;

  /// The default card lift.
  final List<BoxShadow> level2;

  /// A sheet or a dialog.
  final List<BoxShadow> level3;

  /// The coral halo, reserved for the **one** element per screen carrying the
  /// sunrise gradient — the dose hero, or the primary action.
  final List<BoxShadow> glow;

  /// Reads the elevation set out of [context]; asserts rather than falling
  /// back.
  static DaybreakElevation of(BuildContext context) {
    final ext = Theme.of(context).extension<DaybreakElevation>();
    assert(
      ext != null,
      'DaybreakElevation missing. Build via buildDaybreakTheme().',
    );
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
    // Short-circuit the endpoints, which is what makes `lerp(a, b, 0) == a`
    // exact here: BoxShadow.lerpList always returns FRESH inner lists, and this
    // type's equality compares those lists element by element.
    if (t <= 0) return this;
    if (t >= 1) return other;
    return DaybreakElevation(
      level0: BoxShadow.lerpList(level0, other.level0, t)!,
      level1: BoxShadow.lerpList(level1, other.level1, t)!,
      level2: BoxShadow.lerpList(level2, other.level2, t)!,
      level3: BoxShadow.lerpList(level3, other.level3, t)!,
      glow: BoxShadow.lerpList(glow, other.glow, t)!,
    );
  }

  /// Value equality, layer by layer.
  ///
  /// `listEquals` per field rather than one list of lists: comparing
  /// `List<List<BoxShadow>>` compares the inner lists by IDENTITY, and `lerp`
  /// always returns fresh ones — so `lerp(a, b, 0) == a` would be false and
  /// `ThemeData` would see a changed theme on every rebuild.
  @override
  bool operator ==(Object other) =>
      other is DaybreakElevation &&
      listEquals(other.level0, level0) &&
      listEquals(other.level1, level1) &&
      listEquals(other.level2, level2) &&
      listEquals(other.level3, level3) &&
      listEquals(other.glow, glow);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(level0),
    Object.hashAll(level1),
    Object.hashAll(level2),
    Object.hashAll(level3),
    Object.hashAll(glow),
  );
}

/// One layer of a warm shadow, converting its CSS blur on the way in.
///
/// [cssBlur] is the number from the design source; the stored `blurRadius` is
/// `0.866 * (cssBlur - 1)`. [dy] is the vertical offset — every Daybreak shadow
/// is vertical-only, so no elevation level ever acquires a physical side that
/// would fail to mirror in Persian.
BoxShadow _layer(Color ink, double dy, double cssBlur, double alpha) =>
    BoxShadow(
      color: ink.withValues(alpha: alpha),
      offset: Offset(0, dy),
      blurRadius: 0.866 * (cssBlur - 1),
    );

List<BoxShadow> _stack(
  Color ink,
  List<(double dy, double cssBlur, double alpha)> layers,
) => <BoxShadow>[
  for (final (dy, cssBlur, alpha) in layers) _layer(ink, dy, cssBlur, alpha),
];

/// Light elevation — warm brown (`clay42`), never black.
///
/// CSS sources:
/// * shadow-1: `0 1px 2px rgba(140,84,56,.07), 0 2px 8px rgba(140,84,56,.06)`
/// * shadow-2: `0 2px 4px rgba(140,84,56,.07), 0 10px 24px rgba(140,84,56,.10)`
/// * shadow-3: `0 6px 12px rgba(140,84,56,.09), 0 22px 48px
/// rgba(140,84,56,.14)`
final DaybreakElevation lightDaybreakElevation = DaybreakElevation(
  level0: const <BoxShadow>[],
  level1: _stack(Primitives.clay42, const [(1, 2, 0.07), (2, 8, 0.06)]),
  level2: _stack(Primitives.clay42, const [(2, 4, 0.07), (10, 24, 0.10)]),
  level3: _stack(Primitives.clay42, const [(6, 12, 0.09), (22, 48, 0.14)]),
  glow: _stack(Primitives.coral64, const [(8, 18, 0.22), (20, 44, 0.20)]),
);

/// Dark elevation — plum-black (`plum01`), never neutral black.
///
/// CSS sources, from `design/daybreak-system.html`'s dark override block:
/// * shadow-1: `0 1px 2px rgba(8,4,6,.45), 0 2px 8px rgba(8,4,6,.35)`
/// * shadow-2: `0 2px 4px rgba(8,4,6,.45), 0 10px 24px rgba(8,4,6,.45)`
/// * shadow-3: `0 6px 12px rgba(8,4,6,.5), 0 22px 48px rgba(8,4,6,.55)`
final DaybreakElevation darkDaybreakElevation = DaybreakElevation(
  level0: const <BoxShadow>[],
  level1: _stack(Primitives.plum01, const [(1, 2, 0.45), (2, 8, 0.35)]),
  level2: _stack(Primitives.plum01, const [(2, 4, 0.45), (10, 24, 0.45)]),
  level3: _stack(Primitives.plum01, const [(6, 12, 0.50), (22, 48, 0.55)]),
  glow: _stack(Primitives.coral66, const [(8, 18, 0.24), (20, 44, 0.18)]),
);

/// Selects the elevation set for [brightness].
///
/// High contrast does not change elevation: a shadow never carries contrast,
/// and a shadow doing the work of a boundary is a missing `borderStrong`.
DaybreakElevation daybreakElevationFor(Brightness brightness) =>
    brightness == Brightness.dark
    ? darkDaybreakElevation
    : lightDaybreakElevation;
