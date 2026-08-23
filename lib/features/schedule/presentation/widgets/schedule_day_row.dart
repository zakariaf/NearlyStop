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
      isNewDose: day.isNewDose,
      newDoseLabel: day.isNewDose ? l10n.stateNewDoseDay : null,
      isHoldDay: day.isHoldDay,
      holdLabel: day.holdLabel,
      stateLabel: stateWord(l10n, day.state),
      semanticsLabel: _sentence(l10n),
    );

    // ONE semantics node, built here rather than by the component: the row is
    // read as one sentence, and six fragments per day is 312 rotor stops over
    // a 52-day step. The `InkWell`'s own node is excluded and its tap is
    // re-declared on the container.
    return Semantics(
      container: true,
      button: tickable,
      label: _sentence(l10n),
      hint: tickable ? null : l10n.pastStepReadOnly,
      onTap: tickable ? () => onToggle!(day) : null,
      child: ExcludeSemantics(
        child: tickable
            ? Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => onToggle!(day),
                  borderRadius: BorderRadius.all(
                    Radius.circular(shapes.radiusMd),
                  ),
                  child: row,
                ),
              )
            : row,
      ),
    );
  }

  /// The row as one sentence, framed by the ARB and never concatenated here.
  ///
  /// Each clause is its own localized fragment with its own punctuation, so
  /// Persian and Kurdish get their own comma and their own word order rather
  /// than English's joined with a separator.
  String _sentence(AppLocalizations l10n) {
    // TWO frames, not a prefix pasted on: "Today" leads the sentence, and
    // which end of a sentence leads is the locale's decision, not this file's.
    final frame = day.state == DayState.today
        ? l10n.scheduleTodaySemantics
        : l10n.scheduleDaySemantics;
    return frame(
      day.dayLabel,
      day.spokenDose,
      day.tabletsLabel,
      <String>[
        if (day.isNewDose) l10n.scheduleNoteNewDose,
        if (day.isHoldDay) _heldNote(l10n),
        if (day.unachievable) l10n.scheduleNoteUnachievable,
        l10n.scheduleNoteState(stateWord(l10n, day.state)),
      ].join(),
    );
  }

  /// The hold clause, with the block number when there is one.
  String _heldNote(AppLocalizations l10n) {
    final block = day.holdBlockNumber;
    return block == null
        ? l10n.scheduleNoteHeldNoBlock
        : l10n.scheduleNoteHeld(block);
  }
}
