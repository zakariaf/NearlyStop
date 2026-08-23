/// One schedule row, wired to its data and its tap.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_row.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// A [ScheduleDayVm] rendered as EPIC-07’s [DayStateRow], with its tap.
///
/// **A non-tickable row is not an [InkWell] at all.** A dead tap target that
/// ripples and does nothing is worse than no target: it teaches the reader
/// that the app is broken. Read-only rows carry the reason in their semantics
/// instead.
class ScheduleDayRow extends StatelessWidget {
  /// Creates a row for [day].
  const ScheduleDayRow({required this.day, this.onToggle, super.key});

  /// The row's data, already formatted and localized.
  final ScheduleDayVm day;

  /// Called with the row's date when a tickable row is tapped.
  final ValueChanged<ScheduleDayVm>? onToggle;

  /// The localized word for a day's state.
  static String stateWord(AppLocalizations l10n, DayState state) =>
      switch (state) {
        DayState.taken => l10n.stateTaken,
        DayState.missed => l10n.stateNotTicked,
        DayState.today => l10n.stateToday,
        DayState.upcoming => l10n.stateUpcoming,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shapes = DaybreakShapes.of(context);
    final tickable = day.tickable && onToggle != null;

    final row = DayStateRow(
      state: day.state,
      dayLabel: day.dayLabel,
      doseText: day.doseLabel,
      tabletsText: day.unachievable ? null : day.tabletsLabel,
      unachievableText: day.unachievable ? day.tabletsLabel : null,
      stateLabel: stateWord(l10n, day.state),
      semanticsLabel: _sentence(l10n),
    );

    if (!tickable) {
      return Semantics(
        hint: l10n.pastStepReadOnly,
        child: row,
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => onToggle!(day),
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
        child: row,
      ),
    );
  }

  String _sentence(AppLocalizations l10n) => <String>[
    day.dayLabel,
    day.doseLabel,
    day.tabletsLabel,
    stateWord(l10n, day.state),
  ].join(', ');
}
