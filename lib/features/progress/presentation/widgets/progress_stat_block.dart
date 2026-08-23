/// One statistic, with the unit said in words.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// A number, what it is a number of, and what it counts.
///
/// **The unit is always in words.** "341" alone is not information to someone
/// two years into a taper; "taken 341 of 350 days" is. The screen reader gets
/// the overline and the unit as one sentence for the same reason — three
/// fragments read as three unrelated announcements.
class ProgressStatBlock extends StatelessWidget {
  /// Creates one stat block.
  const ProgressStatBlock({
    required this.overline,
    required this.value,
    required this.unit,
    super.key,
  });

  /// The category, already localized and in its natural case.
  ///
  /// Never `toUpperCase()`d: it no-ops in Persian and shouts in English, and
  /// the tracking in the overline style is what makes it read as an overline.
  final String overline;

  /// The number, already formatted for the locale.
  final String value;

  /// The number's meaning, in words. Already localized.
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      // One sentence. Three nodes would be read as three announcements, and
      // the middle one would be a bare number.
      label: '$overline: $unit',
      child: ExcludeSemantics(
        child: Container(
          margin: EdgeInsetsDirectional.only(bottom: shapes.s3),
          padding: EdgeInsetsDirectional.all(shapes.s4),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
            boxShadow: elevationOf(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                overline,
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.inkMuted,
                ),
              ),
              SizedBox(height: shapes.s1),
              Text(
                value,
                style: text.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.ink,
                  // Tabular, so a column of figures does not jitter sideways
                  // as the digits change — on the one screen whose whole job
                  // is showing a number getting smaller.
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

  /// The block's shadow stack.
  List<BoxShadow> elevationOf(BuildContext context) =>
      DaybreakElevation.of(context).level1;
}
