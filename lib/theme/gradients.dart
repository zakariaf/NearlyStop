/// The two Daybreak gradients, expressed so they mirror in Persian.
///
/// **`begin`/`end` are [AlignmentDirectional], never `Alignment`.** `Alignment`
/// does not mirror, so in `fa` and `ckb` the light would fall from the wrong
/// corner while every other element mirrored — a physical-side bug that no LTR
/// golden can catch.
///
/// **The 138° derivation.** CSS measures a `linear-gradient` angle clockwise
/// from "to top". Flutter's alignment box is `-1..1` with **+y downward**, so
/// the direction vector for a CSS angle θ is `(sin θ, −cos θ)`; at 138° that is
/// `(0.669, 0.743)`, and `begin` is its componentwise negative.
///
/// Honest limit: `Alignment` components are independent axis fractions, so the
/// rendered angle is exactly 138° only on a square box and flattens on a wide
/// hero card. The geometric alternative is `topCenter`→`bottomCenter` with
/// `transform: GradientRotation((138 - 180) * pi / 180)`, **negating the
/// radians under `TextDirection.rtl`** because `GradientRotation` has no
/// direction resolution — which is precisely why the `AlignmentDirectional`
/// form is the shipped default.
///
/// One sunrise per screen, maximum. Two retires the signature.
library;

import 'package:flutter/painting.dart';
import 'package:nearlystop/theme/primitives.dart';

/// The Daybreak gradients.
///
/// Stops that appear **only** inside a gradient stay inline here and get no
/// entry in [Primitives]: a named stop invites a widget to use it as a flat
/// fill, and no row of the contrast budget ever measured it as one.
abstract final class DaybreakGradients {
  /// 138° from "to top", resolved to the **leading** top corner in both
  /// scripts.
  static const AlignmentDirectional sunriseBegin = AlignmentDirectional(
    -0.669,
    -0.743,
  );

  /// The opposite corner — the componentwise negative of [sunriseBegin].
  static const AlignmentDirectional sunriseEnd = AlignmentDirectional(
    0.669,
    0.743,
  );

  /// The light theme's sunrise. Only `DaybreakColors.onPrimary` may sit on it:
  /// 6.04:1 at the coral stop (the worst), 9.71:1 at the amber end. White
  /// measures 2.76:1 and fails.
  static const LinearGradient sunriseLight = LinearGradient(
    begin: sunriseBegin,
    end: sunriseEnd,
    colors: <Color>[
      Color(0xFFF9633F),
      Primitives.coral64,
      Color(0xFFFF9A4D),
      Color(0xFFFFC46A),
    ],
    stops: <double>[0, 0.32, 0.68, 1],
  );

  /// The dark theme's sunrise — the same shape, raised in luminance.
  static const LinearGradient sunriseDark = LinearGradient(
    begin: sunriseBegin,
    end: sunriseEnd,
    colors: <Color>[
      Color(0xFFE8613F),
      Primitives.coral66,
      Color(0xFFFF9E52),
      Primitives.amber83,
    ],
    stops: <double>[0, 0.34, 0.70, 1],
  );

  /// The page wash (light). Vertical in both scripts, so there is no
  /// directional component to mirror; both endpoints sit within 0.6 of the
  /// `ink`-on-`surface` ratio, so text over the wash is covered by the flat
  /// `ink` rows.
  static const LinearGradient washLight = LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: <Color>[Color(0xFFFFF7EE), Primitives.clay100],
  );

  /// The page wash (dark).
  static const LinearGradient washDark = LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: <Color>[Color(0xFF3B2B31), Primitives.plum15],
  );

  /// The sunrise's **worst stop** for a foreground contrast measurement.
  ///
  /// A ratio against a gradient is only meaningful at its worst stop; for both
  /// sunrises that is the coral end. Exposed so the contrast budget measures
  /// the same colour the design measured, rather than a stop chosen by eye.
  static Color worstSunriseStop({required bool isDark}) =>
      isDark ? Primitives.coral66 : Primitives.coral64;
}
