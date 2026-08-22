/// One day of a taper, derived — never stored.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// Whether a day belongs to a step's pattern or to the steady state after it.
enum DayKind {
  /// Inside a step: the alternating DSNS calendar, or a non-DSNS hold period.
  step,

  /// After a step's realised length and before the next step begins — or, after
  /// the final step, indefinitely. `SPEC.md` §3.1: *"then the new dose every
  /// day, and that dose becomes the old dose of the next step."*
  steadyState,
}

/// Which of a step's two doses a day carries.
///
/// A different axis from `DayState`, which is the *row log* state. A day is
/// routinely both `today` and a new-dose day, so the two can never be one enum.
enum DoseKind {
  /// The dose the step is stepping down **to**.
  newDose,

  /// The dose the step is stepping down **from**.
  oldDose,
}

/// What the patient takes on one calendar day.
///
/// **Never stored as truth** (`SPEC.md` §6). Produced by `generateSchedule`
/// from the plan, its steps, its flares and its holds, and rebuildable from
/// them forever — which is what makes a flare incapable of corrupting history.
@immutable
final class DayPlan {
  /// Creates a day.
  const DayPlan({
    required this.date,
    required this.stepIndex,
    required this.kind,
    required this.blockIndex,
    required this.dayInBlock,
    required this.dayInStep,
    required this.dose,
    required this.doseKind,
    required this.composition,
    required this.isHoldDay,
  });

  /// The calendar day.
  final LocalDate date;

  /// 0-based index of the step this day belongs to — or, for a steady-state
  /// day, the step it follows.
  final int stepIndex;

  /// Whether this is a step day or a steady-state day.
  final DayKind kind;

  /// 1–11 on a DSNS step day. `null` on a steady-state day and on a
  /// percentage/fixedMg day, which have no blocks.
  final int? blockIndex;

  /// 1-based position within the block, on a DSNS step day; `null` otherwise.
  final int? dayInBlock;

  /// 1..52 on a step day, **excluding hold days** — a hold day repeats the host
  /// day's value. `null` on a steady-state day.
  final int? dayInStep;

  /// What to take today.
  final Milligrams dose;

  /// Whether [dose] is the step's new or old dose.
  final DoseKind doseKind;

  /// How [dose] breaks down into tablets, or why it cannot be made.
  ///
  /// Computed from the plan's **current** strengths, so changing strengths
  /// mid-taper recomposes every day in this derived view — past included. Past
  /// `DoseLog.actualMg` rows are facts and are never touched, so the Schedule's
  /// past rows render from the log; presentation must join, not overwrite
  /// (`SPEC.md` §5.2).
  final Result<TabletComposition, DomainFailure> composition;

  /// Whether this day was inserted by a `HoldEvent`.
  final bool isHoldDay;

  /// Whether today is a new-dose day.
  ///
  /// A flag, never a `DayState` member (CONTRACTS.md §1): a day is routinely
  /// both `today` and a new-dose day. Presentation reads this for the
  /// `stateNewDose` slot.
  bool get isNewDose => doseKind == DoseKind.newDose;

  @override
  bool operator ==(Object other) =>
      other is DayPlan &&
      other.date == date &&
      other.stepIndex == stepIndex &&
      other.kind == kind &&
      other.blockIndex == blockIndex &&
      other.dayInBlock == dayInBlock &&
      other.dayInStep == dayInStep &&
      other.dose == dose &&
      other.doseKind == doseKind &&
      other.isHoldDay == isHoldDay &&
      _sameComposition(composition, other.composition);

  @override
  int get hashCode => Object.hash(
    date,
    stepIndex,
    kind,
    blockIndex,
    dayInBlock,
    dayInStep,
    dose,
    doseKind,
    isHoldDay,
  );

  /// Compares two composition outcomes structurally.
  ///
  /// A `Failure` carries no value equality on purpose — you switch on it, you
  /// never compare instances — so two unreachable doses are equal when they
  /// failed the same way.
  static bool _sameComposition(
    Result<TabletComposition, DomainFailure> a,
    Result<TabletComposition, DomainFailure> b,
  ) => switch ((a, b)) {
    (
      Ok<TabletComposition, DomainFailure>(:final value),
      Ok<TabletComposition, DomainFailure>(value: final other),
    ) =>
      value == other,
    (
      Err<TabletComposition, DomainFailure>(:final failure),
      Err<TabletComposition, DomainFailure>(failure: final other),
    ) =>
      failure.code == other.code,
    _ => false,
  };

  @override
  String toString() =>
      'DayPlan(${date.toIso8601()}, $dose, ${doseKind.name}, '
      '${kind.name}, block $blockIndex/day $dayInBlock, step day $dayInStep'
      '${isHoldDay ? ', hold' : ''})';
}
