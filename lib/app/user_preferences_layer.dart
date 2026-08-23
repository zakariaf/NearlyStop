/// The user's accessibility preferences, applied below `MaterialApp`.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';

/// The app's own text-scale multiplier, bounded below.
///
/// 0.9–1.5 because this one is OUR control, not the user's OS setting. The
/// product of the two is deliberately left unbounded — screens have to survive
/// it, which is what the 200% goldens are for — and the OS value is never
/// clamped DOWN, which `tool/check_bans.sh` enforces by banning
/// `withClampedTextScaling` outright.
const double kMinUserTextScale = 0.9;

/// The upper bound on the app's own multiplier.
///
/// `SPEC.md` §5.4 asks for a control ON TOP of the OS setting, for people
/// whose phone is already at its maximum and it is still not enough.
const double kMaxUserTextScale = 2;

/// The ceiling on the PRODUCT of the two scalers.
///
/// iOS AX5 is about 3.1×, and 3.1 × 2.0 is 6.2× — a size no golden renders and
/// no 320pt device survives. This bounds the product only: with the app slider
/// at 1.0 the layer does not wrap at all, so the OS value passes through
/// untouched at any setting and SPEC §10's "usable at the largest OS text
/// size" is honoured in full. EPIC-14's overflow matrix is built on this
/// number.
const double kMaxComposedTextScale = 4;

/// Applies the in-app preferences that only exist below `MaterialApp`.
///
/// It has to happen **here**, below `MaterialApp`, because that is the first
/// place a `MediaQuery` exists: `theme:` and `darkTheme:` are evaluated above
/// it, so no call site up there can read `boldTextOf`. Flutter does not apply
/// `boldText` on its own — it exposes the flag and leaves honouring it to the
/// app, and `accessibility-as-code` says honouring it is correctness.
///
/// It is a widget rather than a helper on `_NearlyStopAppState` so that
/// `test/support/harness.dart` can mount the SAME layer. A harness that
/// rebuilt an approximation of this would let a screen pass under a text
/// scale the app never actually produces.
class UserPreferencesLayer extends StatelessWidget {
  /// Wraps [child] in the user's text-scale and bold-text preferences.
  const UserPreferencesLayer({
    required this.script,
    required this.highContrast,
    required this.userTextScale,
    required this.child,
    super.key,
  });

  /// The script the themes above were built from.
  ///
  /// Passed in rather than re-derived: rebuilding in Latin here would silently
  /// drop the Persian transform for exactly the users who turned bold text on.
  final DaybreakScript script;

  /// The user's in-app high-contrast setting, ORed with the OS switch below.
  final bool highContrast;

  /// The user's in-app text-scale multiplier, before bounding.
  final double userTextScale;

  /// The subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var content = child;

    // The app's multiplier, ON TOP of the OS scaler rather than replacing it.
    // Replacing it would discard the choice the user made in their phone's own
    // accessibility settings, which for this audience is the one they are most
    // likely to have already found.
    final bounded = userTextScale.clamp(kMinUserTextScale, kMaxUserTextScale);
    if (bounded != 1) {
      final media = MediaQuery.of(context);
      content = MediaQuery(
        data: media.copyWith(
          textScaler: ComposedTextScaler(media.textScaler, bounded),
        ),
        child: content,
      );
    }

    if (!MediaQuery.boldTextOf(context)) return content;
    return Theme(
      data: buildDaybreakTheme(
        Theme.of(context).brightness,
        script,
        // The user's SETTING or the OS switch. Reading only the OS one here
        // would drop the in-app choice for the same users.
        highContrast: highContrast || MediaQuery.highContrastOf(context),
        boldText: true,
      ),
      child: content,
    );
  }
}

/// The OS scaler MULTIPLIED by the app's own factor, product-capped.
///
/// Not `TextScaler.clamp`: clamping to a minimum of 1.5 leaves an OS setting
/// of 2.0 at 2.0, when the user asked for both. Composition means OS 2.0 × app
/// 1.5 is 3.0.
///
/// The PRODUCT is capped at [kMaxComposedTextScale], and only the product: the
/// layer above does not wrap at all when the factor is 1.0, so the OS value
/// passes through untouched at any setting. This app never shrinks a choice
/// the user made in their phone's own accessibility settings.
@immutable
@visibleForTesting
class ComposedTextScaler extends TextScaler {
  /// Composes [_platform] with [_factor].
  const ComposedTextScaler(this._platform, this._factor);

  final TextScaler _platform;
  final double _factor;

  @override
  double scale(double fontSize) {
    final composed = _platform.scale(fontSize) * _factor;
    final ceiling = fontSize * kMaxComposedTextScale;
    return composed < ceiling ? composed : ceiling;
  }

  @override
  // Deprecated upstream in favour of non-linear scaling, but still abstract on
  // `TextScaler`, so it has to be implemented. Composed the same way as
  // `scale`, so a caller reading either gets a consistent answer.
  // ignore: deprecated_member_use
  double get textScaleFactor => _platform.textScaleFactor * _factor;

  @override
  bool operator ==(Object other) =>
      other is ComposedTextScaler &&
      other._platform == _platform &&
      other._factor == _factor;

  @override
  int get hashCode => Object.hash(_platform, _factor);
}
