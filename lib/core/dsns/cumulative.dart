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
Milligrams plannedCumulativeMg(List<DayPlan> days) {
  var hundredths = 0;
  for (final day in days) {
    hundredths += day.dose.hundredths;
  }
  // Conservation tripwire: parts sum to the whole. Free in release, and it
  // catches the bug the moment it happens rather than in a printed report.
  assert(
    hundredths == days.fold<int>(0, (sum, d) => sum + d.dose.hundredths),
    'plannedCumulativeMg lost a day',
  );
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
Adherence adherence(
  List<DoseLogFacts> logs,
  List<DayPlan> days,
  LocalDate today,
) {
  var taken = 0;
  for (final entry in logs) {
    if (entry.taken && entry.date <= today) taken++;
  }
  var planned = 0;
  for (final day in days) {
    if (day.date <= today) planned++;
  }
  return Adherence(takenCount: taken, plannedCount: planned);
}
