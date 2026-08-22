/// Tier 2b — radii, the spacing ramp, and the silhouette factories.
///
/// A component asks for a **shape**, not a number: `s.cardShape()`, not
/// `BorderRadius.circular(24)`. Re-shaping the system is then one edit here
/// rather than a grep across every screen.
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The geometry slots widgets read.
@immutable
class DaybreakShapes extends ThemeExtension<DaybreakShapes> {
  /// Creates the geometry set.
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

  /// 8 — chips and small marks.
  final double radiusXs;

  /// 12 — inputs and compact tiles.
  final double radiusSm;

  /// 16 — the default tile.
  final double radiusMd;

  /// 24 — cards, day rows, taper-step blocks.
  final double radiusLg;

  /// 32 — the dose hero and the disclaimer sheet's top corners.
  final double radiusXl;

  /// 999 — a stadium. Large enough that any realistic height reads as a pill.
  final double radiusPill;

  /// The decorative row divider's stroke width.
  final double hairlineWidth;

  /// The focus ring's stroke width. Drawn in `primaryDeep`, never `primary`.
  final double focusRingWidth;

  /// 4 logical pixels.
  double get s1 => 4;

  /// 8 logical pixels.
  double get s2 => 8;

  /// 12 logical pixels.
  double get s3 => 12;

  /// 16 logical pixels.
  double get s4 => 16;

  /// 20 logical pixels.
  double get s5 => 20;

  /// 24 logical pixels.
  double get s6 => 24;

  /// 32 logical pixels.
  double get s7 => 32;

  /// 40 logical pixels.
  double get s8 => 40;

  /// 48 logical pixels.
  double get s9 => 48;

  /// Reads the geometry out of [context]; asserts rather than falling back.
  static DaybreakShapes of(BuildContext context) {
    final ext = Theme.of(context).extension<DaybreakShapes>();
    assert(
      ext != null,
      'DaybreakShapes missing. Build via buildDaybreakTheme().',
    );
    return ext!;
  }

  /// Cards, day rows and taper-step blocks — [radiusLg].
  RoundedRectangleBorder cardShape({BorderSide side = BorderSide.none}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: side,
      );

  /// The dose hero — [radiusXl].
  RoundedRectangleBorder heroShape() => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radiusXl),
  );

  /// A bottom sheet: [radiusXl] on the top corners only.
  RoundedRectangleBorder sheetShape() => RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
  );

  /// Chips, the active tab pill and the "new dose day" badge.
  StadiumBorder pillShape({BorderSide side = BorderSide.none}) =>
      StadiumBorder(side: side);

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
    // Short-circuit the endpoints. Beyond saving an allocation on the two
    // most common values of t, it is what makes `lerp(a, b, 0) == a`
    // exact: LinearGradient.lerp MERGES two different stop lists, so a
    // gradient interpolated to t = 0 carries the union of both and is
    // not `a`.
    if (t <= 0) return this;
    if (t >= 1) return other;
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

  /// Every slot, in declaration order, for value equality.
  ///
  /// `ThemeData` compares its extensions with `==`, so without this two
  /// structurally identical themes are "different" and every `Theme.of`
  /// dependent rebuilds on a theme that did not change.
  List<Object?> get _props => <Object?>[
    radiusXs,
    radiusSm,
    radiusMd,
    radiusLg,
    radiusXl,
    radiusPill,
    hairlineWidth,
    focusRingWidth,
  ];

  @override
  bool operator ==(Object other) =>
      other is DaybreakShapes && listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

/// Geometry is theme-independent, so the same instance is attached to every
/// `ThemeData` the builder can return.
const DaybreakShapes daybreakShapes = DaybreakShapes(
  radiusXs: 8,
  radiusSm: 12,
  radiusMd: 16,
  radiusLg: 24,
  radiusXl: 32,
  radiusPill: 999,
  hairlineWidth: 1,
  focusRingWidth: 3,
);
