/// "Started 12 September 2024 at 15mg".
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// Where the taper began, as one sentence.
class TaperStartLine extends StatelessWidget {
  /// Creates the line.
  const TaperStartLine({required this.text, super.key});

  /// The sunrise, because this is where the morning started.
  static const IconData glyph = Icons.wb_twilight;

  /// The whole sentence, already localized.
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0, shapes.s4, 0, shapes.s1),
      child: Row(
        children: <Widget>[
          // Decoration. A reader that announces it has been told about a
          // sunrise rather than about a start date.
          ExcludeSemantics(
            child: Icon(glyph, size: 18, color: colors.primaryDeep),
          ),
          SizedBox(width: shapes.s2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.atWeight(FontWeight.w700)
                  .copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
