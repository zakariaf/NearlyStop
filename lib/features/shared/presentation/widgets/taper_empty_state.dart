/// Day zero, given a defined shape.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// What a screen shows before there is a plan.
///
/// **Warm, never "No data".** The person reading this has just been told they
/// will be on steroids for two years; the first thing the app says to them
/// should not be an error message. "Your plan starts here."
///
/// **Exactly one primary action.** Two is two decisions asked of someone who
/// has not made the first one yet.
class TaperEmptyState extends StatelessWidget {
  /// Creates the empty state.
  const TaperEmptyState({
    required this.heading,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  /// Finds the decorative illustration.
  static const Key illustrationKey = Key('taper-empty-state-illustration');

  /// The heading, already localized.
  final String heading;

  /// One sentence, already localized.
  final String message;

  /// The single action's label.
  final String actionLabel;

  /// Runs the single action.
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    // Scrollable, because at 200% the heading, the sentence and the button do
    // not fit a phone — and there is nothing else on this screen to scroll to
    // reach the rest of the message.
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: shapes.s5,
        vertical: shapes.s7,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Decorative, and SILENT: a screen reader announcing "sunrise
          // illustration" before the sentence delays the only thing on screen
          // that carries information.
          ExcludeSemantics(
            child: Center(
              child: Container(
                key: illustrationKey,
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: colors.sunrise,
                  borderRadius: BorderRadius.all(
                    Radius.circular(shapes.radiusPill),
                  ),
                ),
                child: Icon(
                  Icons.wb_twilight,
                  size: 44,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ),
          SizedBox(height: shapes.s5),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: text.titleLarge
                ?.atWeight(FontWeight.w800)
                .copyWith(color: colors.ink),
          ),
          SizedBox(height: shapes.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: colors.inkMuted),
          ),
          SizedBox(height: shapes.s6),
          PrimaryPillButton(
            label: actionLabel,
            expand: true,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
