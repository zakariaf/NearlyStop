/// The Progress screen as a staircase, three numbers and a sentence.
library;

import 'package:flutter/foundation.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// One horizontal tread of the staircase.
///
/// **Two treads per step, never one and never fifty-two.** A DSNS step has no
/// single nominal dose — it is 26 days at `fromDose` and 26 at `toDose`
/// (`SPEC.md` §3.1) — so the reduction emits the old dose for the first half of
/// the step and the new dose for the second, with the boundary at the day-27
/// crossover. The alternating days are NOT drawn as one-day treads: the
/// day-level alternation is Schedule's subject, and Progress shows the trend a
/// doctor asks about at the six-month appointment.
///
/// Adjacent segments at the same dose — a step's `toDose` beside the next
/// step's `fromDose` — are deliberately **not merged**. The boundary is a fact
/// about the plan, and the painter draws them as one continuous tread anyway
/// because their y is identical.
@immutable
final class DoseSegment {
  /// Creates one tread.
  const DoseSegment({
    required this.startDayIndex,
    required this.endDayIndex,
    required this.dose,
  }) : assert(
         endDayIndex >= startDayIndex,
         'a tread runs forwards; an inverted span means the reduction lost a '
         'boundary and the staircase will not tile the plan',
       );

  /// Days since the plan started, inclusive.
  final int startDayIndex;

  /// The last day of the tread, inclusive.
  final int endDayIndex;

  /// The dose held across it. `Milligrams`, never a `double` (CONTRACTS §1).
  final Milligrams dose;

  /// How many days the tread covers.
  int get length => endDayIndex - startDayIndex + 1;

  @override
  bool operator ==(Object other) =>
      other is DoseSegment &&
      other.startDayIndex == startDayIndex &&
      other.endDayIndex == endDayIndex &&
      other.dose == dose;

  @override
  int get hashCode => Object.hash(startDayIndex, endDayIndex, dose);

  @override
  String toString() =>
      'DoseSegment($startDayIndex..$endDayIndex @ ${dose.hundredths})';
}

/// A flare, marked on the timeline.
@immutable
final class FlareMark {
  /// Creates the mark.
  const FlareMark({
    required this.dayIndex,
    required this.dose,
    required this.label,
  });

  /// Days since the plan started.
  final int dayIndex;

  /// The dose the taper went back to.
  final Milligrams dose;

  /// "Flare on 3 March 2025, back to 10 milligrams", already localized.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is FlareMark &&
      other.dayIndex == dayIndex &&
      other.dose == dose &&
      other.label == label;

  @override
  int get hashCode => Object.hash(dayIndex, dose, label);
}

/// A hold, marked on the timeline.
///
/// Marked because `SPEC.md` §4.3 says "flares **and** holds": a rheumatologist
/// looking at a stalled staircase needs to see why it stalled.
@immutable
final class HoldMark {
  /// Creates the mark.
  const HoldMark({
    required this.dayIndex,
    required this.days,
    required this.dose,
    required this.label,
  });

  /// The hold's first day, in days since the plan started.
  final int dayIndex;

  /// How many extra days it added.
  final int days;

  /// The dose held.
  final Milligrams dose;

  /// "Held at 9 milligrams for 5 days from 12 June 2025", already localized.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is HoldMark &&
      other.dayIndex == dayIndex &&
      other.days == days &&
      other.dose == dose &&
      other.label == label;

  @override
  int get hashCode => Object.hash(dayIndex, days, dose, label);
}

/// Reduces a day-by-day plan to the staircase's treads.
///
/// Pure, and deliberately top-level rather than buried in the projection: it
/// takes no locale and no clock, so it is testable at the cheapest tier there
/// is.
///
/// The treads **tile** the input exactly — contiguous, non-overlapping, and
/// covering every day the generator emitted. That is asserted here as well as
/// in the suite, because a gap in the staircase is a gap in the evidence the
/// screen exists to show.
List<DoseSegment> reduceToSegments(List<DayPlan> days) {
  if (days.isEmpty) return const <DoseSegment>[];

  final segments = <DoseSegment>[];
  var stepStart = 0;
  for (var index = 1; index <= days.length; index++) {
    final endOfStep =
        index == days.length ||
        days[index].stepIndex != days[stepStart].stepIndex;
    if (!endOfStep) continue;
    _emitStep(segments, days, stepStart, index - 1);
    stepStart = index;
  }

  assert(
    segments.first.startDayIndex == 0 &&
        segments.last.endDayIndex == days.length - 1,
    'the staircase must cover every day the generator emitted',
  );
  return segments;
}

/// Emits one step's two treads into [into].
///
/// The crossover is found by `dayInStep`, not by counting positions: a hold
/// day REPEATS its host's `dayInStep` (`SPEC.md` §5.2), so the 27th row of a
/// held step is not its 27th day. Counting positions would move the crossover
/// by however many days the hold added, which is exactly the case a
/// rheumatologist is looking at the chart to understand.
void _emitStep(
  List<DoseSegment> into,
  List<DayPlan> days,
  int first,
  int last,
) {
  const crossover = 27;
  var split = last + 1;
  for (var index = first; index <= last; index++) {
    final dayInStep = days[index].dayInStep;
    // Steady-state days have no `dayInStep`, and they need no case of their
    // own: they always TRAIL a step's numbered days, so the split has already
    // been found by the time they appear and they fall into the second tread
    // — which is where they belong, at the new dose.
    if (dayInStep != null && dayInStep >= crossover) {
      split = index;
      break;
    }
  }

  if (split > last) {
    // A step truncated before its crossover — the current step, most of the
    // time. One tread, at the dose it is actually being taken at.
    into.add(
      DoseSegment(
        startDayIndex: first,
        endDayIndex: last,
        dose: _treadDose(days, first, last, DoseKind.oldDose),
      ),
    );
    return;
  }

  into
    ..add(
      DoseSegment(
        startDayIndex: first,
        endDayIndex: split - 1,
        dose: _treadDose(days, first, split - 1, DoseKind.oldDose),
      ),
    )
    ..add(
      DoseSegment(
        startDayIndex: split,
        endDayIndex: last,
        dose: _treadDose(days, split, last, DoseKind.newDose),
      ),
    );
}

/// The dose a tread is drawn at: the [kind] the half is named for.
///
/// Read off a day of that kind rather than from `StepFacts`, so the reduction
/// needs only what the generator emitted — and so a flare that rewrote the
/// days is reflected without the step table having to agree.
Milligrams _treadDose(List<DayPlan> days, int first, int last, DoseKind kind) {
  for (var index = first; index <= last; index++) {
    if (days[index].doseKind == kind) return days[index].dose;
  }
  return days[first].dose;
}

/// The three numbers, already localized.
@immutable
final class ProgressStats {
  /// Creates the stats.
  const ProgressStats({
    required this.daysOnDrug,
    required this.cumulativeMg,
    required this.adherence,
    required this.adherenceCaption,
  });

  /// "581", in the locale's numerals.
  final String daysOnDrug;

  /// "6,842", grouped by the locale's own formatter.
  final String cumulativeMg;

  /// "574 of 581". **Never a percentage and never a streak** (`SPEC.md` §4.3).
  final String adherence;

  /// "days ticked so far — a few gaps change nothing".
  final String adherenceCaption;

  @override
  bool operator ==(Object other) =>
      other is ProgressStats &&
      other.daysOnDrug == daysOnDrug &&
      other.cumulativeMg == cumulativeMg &&
      other.adherence == adherence &&
      other.adherenceCaption == adherenceCaption;

  @override
  int get hashCode =>
      Object.hash(daysOnDrug, cumulativeMg, adherence, adherenceCaption);
}

/// The chart's y-axis and its end labels.
@immutable
final class ProgressAxis {
  /// Creates the axis.
  const ProgressAxis({
    required this.minDose,
    required this.maxDose,
    required this.firstLabel,
    required this.lastLabel,
  });

  /// The lowest dose in the series.
  final Milligrams minDose;

  /// The highest dose in the series.
  final Milligrams maxDose;

  /// The earliest date, already formatted.
  final String firstLabel;

  /// The latest date, already formatted.
  final String lastLabel;

  @override
  bool operator ==(Object other) =>
      other is ProgressAxis &&
      other.minDose == minDose &&
      other.maxDose == maxDose &&
      other.firstLabel == firstLabel &&
      other.lastLabel == lastLabel;

  @override
  int get hashCode => Object.hash(minDose, maxDose, firstLabel, lastLabel);
}

/// What the Progress screen is showing.
@immutable
sealed class ProgressViewState {
  const ProgressViewState();
}

/// No plan yet.
final class ProgressNoPlan extends ProgressViewState {
  /// Creates the empty state.
  const ProgressNoPlan();

  @override
  bool operator ==(Object other) => other is ProgressNoPlan;

  @override
  int get hashCode => (ProgressNoPlan).hashCode;
}

/// The staircase and everything under it.
final class ProgressLoaded extends ProgressViewState {
  /// Creates the loaded state.
  const ProgressLoaded({
    required this.segments,
    required this.flares,
    required this.holds,
    required this.todayDayIndex,
    required this.todayDose,
    required this.axis,
    required this.stats,
    required this.startLine,
    required this.encouragement,
    required this.eventCountLabel,
    required this.chartSummary,
    required this.historyRows,
  });

  /// The treads, in order.
  final List<DoseSegment> segments;

  /// Flares, in date order.
  final List<FlareMark> flares;

  /// Holds, in date order.
  final List<HoldMark> holds;

  /// Where today sits on the x axis.
  final int todayDayIndex;

  /// Today's dose, for the marker's y.
  final Milligrams todayDose;

  /// The y axis and the two date labels.
  final ProgressAxis axis;

  /// The three numbers, formatted.
  final ProgressStats stats;

  /// "Started 12 September 2024 at 15mg".
  final String startLine;

  /// "6mg lower than when you started", or the warm neutral line.
  final String encouragement;

  /// "2 flares and 1 hold recorded" — clauses drop when a count is zero.
  final String eventCountLabel;

  /// The chart as one sentence, for a screen reader.
  final String chartSummary;

  /// The same information as rows, in date order.
  final List<String> historyRows;

  @override
  bool operator ==(Object other) =>
      other is ProgressLoaded &&
      other.todayDayIndex == todayDayIndex &&
      other.todayDose == todayDose &&
      other.axis == axis &&
      other.stats == stats &&
      other.startLine == startLine &&
      other.encouragement == encouragement &&
      other.eventCountLabel == eventCountLabel &&
      other.chartSummary == chartSummary &&
      listEquals(other.segments, segments) &&
      listEquals(other.flares, flares) &&
      listEquals(other.holds, holds) &&
      listEquals(other.historyRows, historyRows);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(segments),
    Object.hashAll(flares),
    Object.hashAll(holds),
    todayDayIndex,
    todayDose,
    axis,
    stats,
    startLine,
    encouragement,
    eventCountLabel,
    chartSummary,
    Object.hashAll(historyRows),
  );
}
