/// The pill that takes the reader back to today.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// A small pill that appears only while today is off screen.
///
/// **Both transitions matter.** A control that appears once and then stays is
/// a control the reader learns to ignore, and this screen is opened every
/// morning for something like 780 days.
class JumpToTodayButton extends StatelessWidget {
  /// Creates the pill.
  const JumpToTodayButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// The glyph, pointing back up the list.
  static const IconData glyph = Icons.today_outlined;

  /// "Jump to today", already localized. Never a glyph on its own.
  final String label;

  /// Returns the list to today.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final elevation = DaybreakElevation.of(context);

    return Material(
      color: colors.surfaceRaised,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
          boxShadow: elevation.level2,
          border: Border.all(
            color: colors.border,
            width: shapes.hairlineWidth,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
          child: Padding(
            // 44pt is the floor, so the vertical padding is generous rather
            // than tight: this pill is tapped by a 78-year-old thumb.
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: shapes.s4,
              vertical: shapes.s3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(glyph, size: 20, color: colors.primaryDeep),
                SizedBox(width: shapes.s2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.atWeight(FontWeight.w800)
                      .copyWith(color: colors.primaryDeep),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
