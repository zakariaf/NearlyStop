/// The chart, as sentences.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// Every tread, flare and hold as a row, in date order.
///
/// **Real UI, not a hidden `Semantics` string.** A screen-reader user needs it,
/// and so does a low-vision sighted reader at 200% — and only one of those two
/// can hear a label nobody draws. Above 1.5× text scale this replaces the
/// chart outright, because a 176px canvas cannot carry legible axis labels at
/// that size and shrinking them is the defect `accessibility-as-code` bans.
class DoseHistoryList extends StatelessWidget {
  /// Creates the list.
  const DoseHistoryList({required this.title, required this.rows, super.key});

  /// "Dose history as a list", already localized.
  final String title;

  /// The rows, already localized and already in date order.
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            title,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.ink,
            ),
          ),
        ),
        SizedBox(height: shapes.s3),
        for (final row in rows)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: shapes.s2),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: shapes.s4,
                vertical: shapes.s3,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.all(
                  Radius.circular(shapes.radiusMd),
                ),
                border: Border.all(
                  color: colors.border,
                  width: shapes.hairlineWidth,
                ),
              ),
              child: Text(
                row,
                style: text.bodyMedium?.copyWith(color: colors.ink),
              ),
            ),
          ),
      ],
    );
  }
}
