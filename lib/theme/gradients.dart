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

  /// The light theme's sunrise. Only `DaybreakColors.onPrimary` may sit on it,
  /// and only as decoration: 5.47:1 at stop 0 — the darkest, and therefore the
  /// worst — rising to 10.62:1 at the amber end. White measures 2.35:1 there
  /// and fails. **7:1 is unreachable on this ground with any foreground**
  /// (pure black reaches 6.88:1), which is why the number a patient reads sits
  /// on an opaque `surface` chip at 13.6:1 rather than on the gradient.
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

  /// The chart's stroke (light).
  ///
  /// Flat `primaryDeep` rather than a coral ramp: this stroke is the only mark
  /// carrying the Progress screen's information and it has no text of its own,
  /// so WCAG 2.1 SC 1.4.11 asks it for 3:1 against the card at EVERY point.
  /// `primary` measures 2.76:1 on the light wash and is decorative-only.
  static const LinearGradient chartLineLight = LinearGradient(
    colors: <Color>[Primitives.coral43, Primitives.coral43],
  );

  /// The chart's stroke (dark).
  static const LinearGradient chartLineDark = LinearGradient(
    colors: <Color>[Primitives.coral70, Primitives.coral70],
  );

  /// The area under the chart's stroke (light).
  ///
  /// Decoration: it carries no information, so `primary` at 30% is legitimate
  /// here even though it is not legitimate as the stroke.
  static const LinearGradient chartFillLight = LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: <Color>[Color(0x4DF97350), Color(0x0AFFC470)],
  );

  /// The area under the chart's stroke (dark).
  static const LinearGradient chartFillDark = LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: <Color>[Color(0x4DFF8A6B), Color(0x0AFFC470)],
  );

  /// The stop of [gradient] that gives [foreground] its **lowest** contrast.
  ///
  /// A ratio against a gradient is only meaningful at its worst stop, and the
  /// worst stop is a property of the pair, not a named index. Naming one was
  /// the bug: the previous version returned stop 1 while stop 0 is darker in
  /// both sunrises, so the contrast budget measured an easier ground than the
  /// one that ships.
  ///
  /// Uses WCAG 2.1 relative luminance — the same formula
  /// `Color.computeLuminance` implements — so this agrees with the contrast
  /// oracle in the tests by construction.
  static Color worstStopFor(Color foreground, LinearGradient gradient) {
    final foregroundLuminance = foreground.computeLuminance();
    var worst = gradient.colors.first;
    var lowest = double.infinity;
    for (final stop in gradient.colors) {
      final stopLuminance = stop.computeLuminance();
      final hi = foregroundLuminance > stopLuminance
          ? foregroundLuminance
          : stopLuminance;
      final lo = foregroundLuminance > stopLuminance
          ? stopLuminance
          : foregroundLuminance;
      final ratio = (hi + 0.05) / (lo + 0.05);
      if (ratio < lowest) {
        lowest = ratio;
        worst = stop;
      }
    }
    return worst;
  }
}
