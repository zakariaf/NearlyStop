/// One statistic, with the unit said in words.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// A number, what it is a number of, and what it counts.
///
/// **The unit is always in words.** "341" alone is not information to someone
/// two years into a taper; "taken 341 of 350 days" is. The screen reader gets
/// the overline and the unit as one sentence for the same reason — three
/// fragments read as three unrelated announcements.
class ProgressStatBlock extends StatelessWidget {
  /// Creates one stat block.
  const ProgressStatBlock({
    required this.value,
    required this.unit,
    this.valueUnit,
    super.key,
  });

  /// The number, already formatted for the locale.
  final String value;

  /// The number's meaning, in words. Already localized.
  final String unit;

  /// The unit that belongs to the figure itself — frame 4's `.u` span.
  ///
  /// "6,842 **mg**": smaller and inline, so the number stays the thing the eye
  /// lands on while never appearing without its unit.
  final String? valueUnit;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      // One sentence, and the NUMBER is in it. The first version read
      // "Progress: days on prednisolone" — the category and the unit, with
      // the figure left out, on the screen whose whole subject is a number
      // getting smaller.
      label: '$value${valueUnit ?? ''} $unit',
      child: ExcludeSemantics(
        child: Container(
          margin: EdgeInsetsDirectional.only(bottom: shapes.s3),
          padding: EdgeInsetsDirectional.all(shapes.s4),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
            boxShadow: DaybreakElevation.of(context).level1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // No overline. Frame 4's `.stat` is a value and a label; a third
              // line is a third thing to read on a card that exists to be
              // glanced at.
              Text.rich(
                TextSpan(
                  text: value,
                  children: <InlineSpan>[
                    if (valueUnit case final unit?)
                      TextSpan(
                        text: unit,
                        style: text.bodyMedium
                            ?.atWeight(FontWeight.w800)
                            .copyWith(color: colors.inkMuted),
                      ),
                  ],
                ),
                style: text.headlineLarge
                    ?.atWeight(FontWeight.w800)
                    .copyWith(
                      color: colors.ink,
                      // Tabular, so a column of figures does not jitter
                      // sideways as the digits change — on the one screen
                      // whose whole job is showing a number getting smaller.
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
              ),
              SizedBox(height: shapes.s1),
              Text(
                unit,
                style: text.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
