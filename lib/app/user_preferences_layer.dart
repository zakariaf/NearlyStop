/// The user's accessibility preferences, applied below `MaterialApp`.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/composed_text_scaler.dart';
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
