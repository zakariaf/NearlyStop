/// Tier 2e — the type roles Material 3 has no slot for.
///
/// Three of them, and each exists because an M3 slot would either lose a font
/// feature or be reused somewhere it does not belong.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_type.dart';

/// App-specific type roles.
@immutable
class DaybreakTypography extends ThemeExtension<DaybreakTypography> {
  /// Creates the role set.
  const DaybreakTypography({
    required this.doseNumeral,
    required this.overline,
    required this.dayStateChip,
  });

  /// The Today hero dose number.
  ///
  /// The display role plus [FontFeature.tabularFigures]: 9 → 10 must not shift
  /// the number the user reads every morning for 780 days.
  final TextStyle doseNumeral;

  /// The block-header kicker and the day-state chip's label.
  ///
  /// Caption at weight 800 with **positive** tracking. **`en`/`de` only** — the
  /// string arrives already uppercased from the ARB, and Perso-Arabic has no
  /// case, so in `fa`/`ckb` this is plain caption at tracking 0 and the *word*
  /// carries the emphasis instead.
  final TextStyle overline;

  /// The four day-state chips. Tabular so a column of doses stays aligned.
  final TextStyle dayStateChip;

  /// Reads the role set out of [context]; asserts rather than falling back.
  static DaybreakTypography of(BuildContext context) {
    final ext = Theme.of(context).extension<DaybreakTypography>();
    assert(
      ext != null,
      'DaybreakTypography missing. Build via buildDaybreakTheme().',
    );
    return ext!;
  }

  @override
  DaybreakTypography copyWith({
    TextStyle? doseNumeral,
    TextStyle? overline,
    TextStyle? dayStateChip,
  }) {
    return DaybreakTypography(
      doseNumeral: doseNumeral ?? this.doseNumeral,
      overline: overline ?? this.overline,
      dayStateChip: dayStateChip ?? this.dayStateChip,
    );
  }

  @override
  DaybreakTypography lerp(covariant DaybreakTypography? other, double t) {
    if (other == null) return this;
    // Short-circuit the endpoints. Beyond saving an allocation on the two
    // most common values of t, it is what makes `lerp(a, b, 0) == a`
    // exact: LinearGradient.lerp MERGES two different stop lists, so a
    // gradient interpolated to t = 0 carries the union of both and is
    // not `a`.
    if (t <= 0) return this;
    if (t >= 1) return other;
    return DaybreakTypography(
      doseNumeral: TextStyle.lerp(doseNumeral, other.doseNumeral, t)!,
      overline: TextStyle.lerp(overline, other.overline, t)!,
      dayStateChip: TextStyle.lerp(dayStateChip, other.dayStateChip, t)!,
    );
  }

  /// Every slot, in declaration order, for value equality.
  ///
  /// `ThemeData` compares its extensions with `==`, so without this two
  /// structurally identical themes are "different" and every `Theme.of`
  /// dependent rebuilds on a theme that did not change.
  List<Object?> get _props => <Object?>[
    doseNumeral,
    overline,
    dayStateChip,
  ];

  @override
  bool operator ==(Object other) =>
      other is DaybreakTypography && listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

/// Builds the app-specific roles from the same scale as the `TextTheme`, so a
/// change to the scale reaches both.
DaybreakTypography daybreakTypography(
  DaybreakScript script, {
  required DaybreakColors colors,
  bool boldText = false,
}) {
  final text = daybreakTextTheme(script, colors: colors, boldText: boldText);
  const tabular = <FontFeature>[FontFeature.tabularFigures()];
  final isPerso = script == DaybreakScript.perso;

  return DaybreakTypography(
    doseNumeral: text.displayLarge!.copyWith(fontFeatures: tabular),
    overline: text.labelSmall!.copyWith(
      fontWeight: boldText ? FontWeight.w900 : FontWeight.w800,
      fontVariations: <FontVariation>[
        FontVariation('wght', boldText ? 900 : 800),
      ],
      // +0.06em at 14. Latin only: positive tracking snaps Perso-Arabic joins.
      letterSpacing: isPerso ? 0 : 0.06 * 14,
      color: colors.inkMuted,
    ),
    dayStateChip: text.labelMedium!.copyWith(fontFeatures: tabular),
  );
}
