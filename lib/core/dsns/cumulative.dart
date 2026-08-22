/// The arithmetic behind the Progress screen.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// How many days were ticked, out of how many have happened.
///
/// Two integers and nothing else. The domain returns **no streak, no
/// percentage-as-judgement and no "days missed" headline** (`SPEC.md` §4.3):
/// the copy is *"taken 341 of 350 days"*, said gently, to someone who is
/// already frightened and has 780 mornings of this ahead of them.
@immutable
final class Adherence {
  /// Records [takenCount] ticked days out of [plannedCount] elapsed ones.
  const Adherence({required this.takenCount, required this.plannedCount});

  /// Days the patient ticked, on or before the day being reported.
  final int takenCount;

  /// Days the schedule planned **that have already happened**.
  final int plannedCount;

  @override
  bool operator ==(Object other) =>
      other is Adherence &&
      other.takenCount == takenCount &&
      other.plannedCount == plannedCount;

  @override
  int get hashCode => Object.hash(takenCount, plannedCount);

  @override
  String toString() => 'Adherence($takenCount of $plannedCount)';
}

/// Total milligrams actually swallowed, over every ticked log.
///
/// A flare preserves this total by construction: recording one appends a
/// `FlareEvent` and a new `Step` and never edits a `DoseLog`, so the input to
/// this function does not change.
Milligrams cumulativeTakenMg(List<DoseLogFacts> logs) {
  var hundredths = 0;
  for (final entry in logs) {
    if (entry.taken) hundredths += entry.actualMg.hundredths;
  }
  return Milligrams.fromHundredths(hundredths);
}

/// Total milligrams the schedule plans across [days].
///
/// The conservation invariant this function has to satisfy — parts sum to the
/// whole — is asserted by `cumulative_test.dart` against an **independent**
/// oracle (26 x fromDose + 26 x toDose for a DSNS step). It is deliberately not
/// an in-function `assert`: the only cheap thing such an assert could compare
/// against is the same reduction over the same list, which holds for any
/// implementation including one that skipped a day.
Milligrams plannedCumulativeMg(List<DayPlan> days) {
  var hundredths = 0;
  for (final day in days) {
    hundredths += day.dose.hundredths;
  }
  return Milligrams.fromHundredths(hundredths);
}

/// Calendar days from [start] to [today], **inclusive** — day one is one day.
int daysOnSteroids(LocalDate start, LocalDate today) =>
    today.difference(start) + 1;

/// Adherence as of [today].
///
/// [Adherence.plannedCount] counts only days with `date <= today`. An
/// unqualified count includes the future and reads "taken 341 of 780 days" on
/// day 350 of a two-year taper, which is not a true sentence about anything.
///
/// [Adherence.takenCount] counts **distinct dates that the schedule actually
/// plans**. Two logs for one date — a double write across a restore — or a log
/// for a date a flare truncated out of the schedule would otherwise produce
/// "taken 351 of 350 days", rendered verbatim to a frightened patient every
/// morning.
Adherence adherence(
  List<DoseLogFacts> logs,
  List<DayPlan> days,
  LocalDate today,
) {
  final plannedDates = <LocalDate>{
    for (final day in days)
      if (day.date <= today) day.date,
  };
  final takenDates = <LocalDate>{
    for (final entry in logs)
      if (entry.taken && plannedDates.contains(entry.date)) entry.date,
  };
  return Adherence(
    takenCount: takenDates.length,
    plannedCount: plannedDates.length,
  );
}
