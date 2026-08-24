/// "Step 3 of 15 · 10mg → 9mg · Day 14 of 52".
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// Where the reader is inside a 52-day pattern they did not design.
///
/// **A `Wrap`, not a `Row`.** Three segments plus separators overflow a 390pt
/// phone the moment the text grows, and this line is the orientation device —
/// clipping it leaves the reader inside a block structure they cannot see.
///
/// **One semantics node.** The reader hears "Step 3 of 15, reducing from 10
/// milligrams to 9 milligrams, day 14 of 52" as a sentence, not six fragments.
class DoseContextLine extends StatelessWidget {
  /// Creates the line.
  const DoseContextLine({
    required this.stepLabel,
    required this.fromDose,
    required this.toDose,
    required this.dayLabel,
    required this.holdingLabel,
    required this.semanticsLabel,
    super.key,
  }) : assert(
         (dayLabel == null) == (holdingLabel != null),
         'a day either has a position in its step or is holding — never both, '
         'and never neither: there would be nothing to print',
       );

  /// "Step 3 of 15", already localized and already worded.
  ///
  /// **The words, not a fraction.** "3 / 15" was what shipped, and it is two
  /// unlabelled numbers on the one line whose entire job is to orient
  /// somebody inside a 52-day pattern they did not design. Composed by the
  /// notifier from `stepOfTotal`, like every other string this widget takes.
  final String stepLabel;

  /// "10mg".
  final String fromDose;

  /// "9mg".
  final String toDose;

  /// "Day 14 of 52", or null on a steady-state day.
  ///
  /// Worded for the same reason [stepLabel] is.
  final String? dayLabel;

  /// "Holding at 9mg" — what replaces the third segment on a steady-state day.
  final String? holdingLabel;

  /// The whole line as one sentence.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final style = Theme.of(context).textTheme.bodyMedium
        ?.atWeight(FontWeight.w600)
        .copyWith(color: colors.inkMuted);

    Widget separator() => Text(
      '·',
      style: style?.copyWith(color: colors.inkFaint),
    );

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: shapes.s2,
          runSpacing: shapes.s1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(stepLabel, style: style),
            separator(),
            // A `Wrap`, not a `Row`: "10mg → 9mg" is three items, and at the
            // composed ceiling three items are wider than the line the outer
            // Wrap gave them. Nested so the arrow stays with the doses rather
            // than drifting between the other chips.
            Wrap(
              spacing: shapes.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(fromDose, style: style),
                // `Icons.adaptive.arrow_forward` mirrors itself under RTL. The
                // ban gate forbids `Icons.arrow_forward` precisely so this is
                // the one that gets used: the logical reading is "from 10mg to
                // 9mg", so the glyph points toward the end of the reading
                // direction in both.
                Icon(
                  Icons.adaptive.arrow_forward,
                  size: 16,
                  color: colors.inkFaint,
                ),
                Text(toDose, style: style),
              ],
            ),
            separator(),
            if (holdingLabel case final holding?)
              Text(holding, style: style)
            else
              Text(dayLabel!, style: style),
          ],
        ),
      ),
    );
  }
}
