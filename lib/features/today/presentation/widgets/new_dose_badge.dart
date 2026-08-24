/// The "New dose day" badge.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// Says, in three channels, that today takes the step's new dose.
///
/// **Shape, glyph AND word — never the colour alone.** A dose change is
/// exactly where this population makes mistakes, and the difference between
/// 9mg and 10mg is invisible unless the screen says so in more than a tint.
///
/// Rendered only on a new-dose day. On an old-dose day the slot is EMPTY, not
/// a second badge saying the opposite: a badge that is always there is
/// furniture, and furniture is not read.
class NewDoseBadge extends StatelessWidget {
  /// Creates the badge.
  const NewDoseBadge({required this.label, super.key});

  /// The sunrise glyph.
  static const IconData glyph = Icons.wb_twilight;

  /// The badge's floor, so it stays a tap-sized landmark at any text size.
  static const double minHeight = 34;

  /// "New dose day", already localized.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: minHeight),
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: shapes.s3,
        vertical: shapes.s1,
      ),
      decoration: BoxDecoration(
        // A light pill ON the sunrise card, so it reads as a label pinned to
        // the gradient rather than a second gradient surface.
        color: colors.surface,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(glyph, size: 16, color: colors.primaryDeep),
          SizedBox(width: shapes.s1),
          Flexible(
            child: Text(
              label,
              // `.badge { font-size: var(--fs-caption) }` — caption 14, not 20.
              style: Theme.of(context).textTheme.labelSmall
                  ?.atWeight(FontWeight.w800)
                  .copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
