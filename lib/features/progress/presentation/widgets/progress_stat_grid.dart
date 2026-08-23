/// The three numbers, laid out without a grid.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/features/progress/presentation/widgets/progress_stat_block.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// One stat, so the layout can find and measure it.
///
/// A named wrapper rather than a bare `Expanded`: the reflow test has to say
/// "the first two share a row", and it needs something to ask.
class ProgressStatBlockSlot extends StatelessWidget {
  /// Wraps [child].
  const ProgressStatBlockSlot({required this.child, super.key});

  /// The stat block.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Days on the drug, milligrams taken, days ticked.
///
/// **Never a `GridView`.** SPEC.md §4.2's ban is about the Schedule, but the
/// reason travels: a grid of three cards is three cards a reader scans
/// horizontally, and at 200% they are three columns two characters wide. A
/// `Row` that becomes a `Column` is what a reflow actually is.
class ProgressStatGrid extends StatelessWidget {
  /// Creates the grid.
  const ProgressStatGrid({
    required this.stats,
    required this.medicine,
    super.key,
  });

  /// Above this text scale every block is full width.
  ///
  /// The same rung the Today hero and the day row use, so the screens change
  /// shape together rather than one at a time.
  static const double stackAboveTextScale = 1.3;

  /// The three numbers, already formatted.
  final ProgressStats stats;

  /// The drug's name, for the first block's label.
  final String medicine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shapes = DaybreakShapes.of(context);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > stackAboveTextScale;

    final days = ProgressStatBlockSlot(
      child: ProgressStatBlock(
        value: stats.daysOnDrug,
        unit: l10n.daysOnDrugLabel(medicine),
      ),
    );
    final total = ProgressStatBlockSlot(
      child: ProgressStatBlock(
        value: stats.cumulativeMg,
        valueUnit: ' ${l10n.milligramUnit}',
        unit: l10n.totalTaken,
      ),
    );
    final ticked = ProgressStatBlockSlot(
      child: ProgressStatBlock(
        value: stats.adherence,
        unit: stats.adherenceCaption,
      ),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[days, total, ticked],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: days),
              SizedBox(width: shapes.s3),
              Expanded(child: total),
            ],
          ),
        ),
        ticked,
      ],
    );
  }
}
