/// The Schedule's chrome: the strips and the placeholder around the list.
///
/// Ref-free presentation widgets, so they live under `widgets/` where the
/// layering gate can see them. The screen holds the two that need a `ref`.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_row.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// Says, once and at the top, that this step cannot be changed.
class ReadOnlyStrip extends StatelessWidget {
  /// Creates the strip.
  const ReadOnlyStrip({required this.message, super.key});

  /// Why the rows below are inert, already localized.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: shapes.s5,
        vertical: shapes.s3,
      ),
      color: colors.surfaceSunken,
      child: Row(
        children: <Widget>[
          Icon(Icons.lock_outline, size: 18, color: colors.inkMuted),
          SizedBox(width: shapes.s2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why the last tap was refused, said out loud.
class RefusalNotice extends StatelessWidget {
  /// Creates the notice for [refusal].
  const RefusalNotice({required this.refusal, super.key});

  /// What was refused.
  final ScheduleRefusal refusal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final message = switch (refusal) {
      ScheduleRefusal.readOnly => l10n.pastStepReadOnly,
      ScheduleRefusal.futureDay => l10n.futureDayNotYet,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: EdgeInsetsDirectional.fromSTEB(
          shapes.s5,
          shapes.s2,
          shapes.s5,
          0,
        ),
        padding: EdgeInsetsDirectional.all(shapes.s3),
        decoration: BoxDecoration(
          color: colors.tintWarning,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
          border: Border.all(
            color: colors.warning,
            width: shapes.hairlineWidth,
          ),
        ),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.ink),
        ),
      ),
    );
  }
}

/// A block-shaped placeholder while the first emission lands.
///
/// A skeleton rather than a spinner: a spinner that becomes a list moves
/// everything under it, and a reader who is unsure whether they tapped reads
/// that movement as their tap having done something.
class ScheduleSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const ScheduleSkeleton({super.key});

  /// One header plus four rows, the shape the first frame settles into.
  static const int rows = 4;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    // A `ListView`, not a `Column`: this stands in for a scroll view, and a
    // fixed column of placeholders overflows a landscape phone before any
    // data has arrived — which is the one moment nobody is looking for a bug.
    return ListView(
      padding: EdgeInsetsDirectional.all(shapes.s5),
      children: <Widget>[
        Container(
          height: 84,
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
          ),
        ),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: EdgeInsetsDirectional.only(top: shapes.s2),
            child: Container(
              height: DayStateRow.minHeight,
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.all(
                  Radius.circular(shapes.radiusMd),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
