/// The "we could not read your plan" panel.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// A read failure, with the one action that can help.
///
/// Shared because Today and Schedule both watch the same snapshot and both
/// fail the same way, and a second copy is a second chance to word it
/// differently on the screen a frightened reader happens to be on.
class ErrorPanel extends StatelessWidget {
  /// Creates the panel.
  const ErrorPanel({
    required this.title,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  /// What went wrong, already localized.
  final String title;

  /// The retry action's label, already localized.
  final String retryLabel;

  /// Retries the read.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.all(shapes.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.cloud_off_outlined, size: 44, color: colors.inkFaint),
          SizedBox(height: shapes.s4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.atWeight(FontWeight.w800)
                .copyWith(color: colors.ink),
          ),
          SizedBox(height: shapes.s5),
          SecondaryButton(label: retryLabel, expand: true, onPressed: onRetry),
        ],
      ),
    );
  }
}
