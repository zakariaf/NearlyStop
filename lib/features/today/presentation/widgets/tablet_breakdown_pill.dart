/// The tablet breakdown, as physical counts.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// "1 × 5mg · 4 × 1mg" — what to actually count out of the box.
///
/// The dose is the number; this is the instruction. A reader who knows they
/// need 9mg still has to work out that it is one 5 and four 1s, and doing that
/// arithmetic half-awake at 6am is where the mistakes are.
///
/// The text arrives already bidi-isolated: a run of Latin counts and units
/// inside a Perso-Arabic sentence reorders without it, and reports the wrong
/// count against the wrong strength.
class TabletBreakdownPill extends StatelessWidget {
  /// Creates the pill.
  const TabletBreakdownPill({required this.text, super.key});

  /// The pill glyph.
  static const IconData glyph = Icons.medication_outlined;

  /// The breakdown, pre-formatted and pre-isolated.
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: shapes.s3,
        vertical: shapes.s2,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(glyph, size: 18, color: colors.primaryDeep),
          SizedBox(width: shapes.s2),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
