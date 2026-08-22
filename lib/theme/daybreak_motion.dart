/// Tier 2d — motion, and the one place a widget asks "should I animate?".
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The duration and curve slots widgets read.
@immutable
class DaybreakMotion extends ThemeExtension<DaybreakMotion> {
  /// Creates the motion set.
  const DaybreakMotion({
    required this.fast,
    required this.base,
    required this.slow,
    required this.easeOut,
    required this.easeInOut,
  });

  /// 120ms — a tap's own feedback.
  final Duration fast;

  /// 220ms — a state change the user caused: ticking a dose, opening a block.
  final Duration base;

  /// 420ms — the one celebratory moment, a taper step completing.
  final Duration slow;

  /// The default entry curve.
  final Curve easeOut;

  /// The default transition curve.
  final Curve easeInOut;

  /// Reads the motion set out of [context]; asserts rather than falling back.
  static DaybreakMotion of(BuildContext context) {
    final ext = Theme.of(context).extension<DaybreakMotion>();
    assert(
      ext != null,
      'DaybreakMotion missing. Build via buildDaybreakTheme().',
    );
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

  /// Durations interpolate; `Curve`s are not interpolable, so they **snap** at
  /// the midpoint. That is deliberate, not unfinished: a half-way curve has no
  /// meaning, and every palette shares these two curves anyway.
  @override
  DaybreakMotion lerp(covariant DaybreakMotion? other, double t) {
    if (other == null) return this;
    // Short-circuit the endpoints. lerpDuration is already exact at t = 0 and
    // 1, so this only skips an allocation — the curves snap either way.
    if (t <= 0) return this;
    if (t >= 1) return other;
    return DaybreakMotion(
      fast: lerpDuration(fast, other.fast, t),
      base: lerpDuration(base, other.base, t),
      slow: lerpDuration(slow, other.slow, t),
      easeOut: t < 0.5 ? easeOut : other.easeOut,
      easeInOut: t < 0.5 ? easeInOut : other.easeInOut,
    );
  }

  /// Every slot, in declaration order, for value equality.
  ///
  /// `ThemeData` compares its extensions with `==`, so without this two
  /// structurally identical themes are "different" and every `Theme.of`
  /// dependent rebuilds on a theme that did not change.
  List<Object?> get _props => <Object?>[
    fast,
    base,
    slow,
    easeOut,
    easeInOut,
  ];

  @override
  bool operator ==(Object other) =>
      other is DaybreakMotion && listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

/// The motion set. Theme-independent, so one instance serves every `ThemeData`.
const DaybreakMotion daybreakMotion = DaybreakMotion(
  fast: Duration(milliseconds: 120),
  base: Duration(milliseconds: 220),
  slow: Duration(milliseconds: 420),
  easeOut: Cubic(0.22, 0.85, 0.34, 1),
  easeInOut: Cubic(0.65, 0, 0.35, 1),
);

/// Resolves [full] against the OS reduced-motion setting.
///
/// Returns [Duration.zero] when the user has asked the OS to stop animations —
/// **not a shorter duration, not a softer curve**. Someone who turned
/// animations off asked for stop. Read from `MediaQuery`, so it tracks the OS
/// live rather than a value copied into app state at startup.
Duration resolveMotion(BuildContext context, Duration full) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : full;
