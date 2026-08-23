/// The warm line under the numbers.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// How much lower the dose is than at the start — or, when it is not, a warm
/// neutral line.
///
/// **The widget shows what it is handed.** There is no `if (delta == 0)` here:
/// that decision is the projection's, and two places deciding the same thing
/// is one place too many. The wording is never comparative to other patients.
class EncouragementCard extends StatelessWidget {
  /// Creates the card.
  const EncouragementCard({required this.message, super.key});

  /// The sun, because this is the good news on the screen.
  static const IconData glyph = Icons.wb_sunny_outlined;

  /// The sentence, already localized.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Container(
      padding: EdgeInsetsDirectional.all(shapes.s4),
      decoration: BoxDecoration(
        color: colors.tintSuccess,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
        border: Border.all(color: colors.success, width: shapes.hairlineWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(child: Icon(glyph, size: 28, color: colors.success)),
          SizedBox(width: shapes.s3),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
