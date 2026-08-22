/// The persisted facts the schedule is derived from.
///
/// `SPEC.md` §6: **persist facts only.** These records mirror the stored tables
/// field for field; EPIC-05 maps drift rows onto them, and the domain never
/// sees a drift class. `DayPlan` is not here, because `DayPlan` is never
/// stored.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';

/// How a taper computes its next dose.
///
/// All three arms generate a real schedule — the Plan screen offers all three
/// and `TaperMethod` is a stored column, so a segment that silently produced a
/// DSNS schedule would be a plan the patient did not choose (CONTRACTS.md §8).
/// Declared here in `lib/core/`, never in a data-layer converter.
enum TaperMethod {
  /// The eleven-block, 52-day alternating calendar.
  dsns,

  /// Step by a percentage of the current dose, then that dose every day.
  percentage,

  /// Step by a fixed number of milligrams, then that dose every day.
  fixedMg,
}

/// Where a step stands.
///
/// Read from the fact only for [abandoned] — abandonment is an event, not a
/// date computation. The other three are derived by `stepStatusFor`.
enum StepStatus {
  /// The step has not started yet.
  pending,

  /// The step is running.
  active,

  /// The step ran its full length.
  completed,

  /// A flare truncated the step.
  abandoned,
}

/// The plan the patient and their doctor agreed.
@immutable
final class TaperPlanFacts {
  /// Creates the plan record.
  const TaperPlanFacts({
    required this.drugName,
    required this.startDate,
    required this.startingDose,
    required this.targetDose,
    required this.tabletStrengths,
    required this.allowHalves,
    required this.method,
    this.percentage,
    this.fixedStep,
    this.holdPeriodDays = dsnsHoldPeriodDays,
  });

  /// The default hold period for the non-DSNS methods.
  ///
  /// 52 so the "day N of 52" context line and the step-completion rule are
  /// uniform across all three methods.
  static const int dsnsHoldPeriodDays = 52;

  /// Free text, defaulting to "Prednisolone". Never looked up in a database.
  final String drugName;

  /// The first day of the plan.
  final LocalDate startDate;

  /// The dose the plan starts from.
  final Milligrams startingDose;

  /// The dose the plan aims at, usually zero.
  final Milligrams targetDose;

  /// The tablet strengths the patient actually holds.
  final List<TabletStrength> tabletStrengths;

  /// Whether the patient said they can split a tablet.
  final bool allowHalves;

  /// Which arithmetic the plan uses.
  final TaperMethod method;

  /// Percent of the current dose per step. Required when [method] is
  /// [TaperMethod.percentage]; `null` otherwise.
  final int? percentage;

  /// A fixed step size. Required when [method] is [TaperMethod.fixedMg]; `null`
  /// otherwise.
  final Milligrams? fixedStep;

  /// Days a non-DSNS step holds the new dose before the next step may begin.
  final int holdPeriodDays;
}

/// One reduction: from a dose, to a dose, starting on a date.
@immutable
final class StepFacts {
  /// Creates the step record.
  const StepFacts({
    required this.id,
    required this.index,
    required this.fromDose,
    required this.toDose,
    required this.startDate,
    required this.status,
    required this.patternVersion,
  });

  /// Stable identity, used to attach holds to this step.
  final int id;

  /// 0-based position in the plan's steps.
  final int index;

  /// The dose this step steps down **from** — the "old" dose.
  final Milligrams fromDose;

  /// The dose this step steps down **to** — the "new" dose.
  final Milligrams toDose;

  /// The first day of the step.
  final LocalDate startDate;

  /// The stored status.
  ///
  /// **The generator ignores this except to report it back.** Truncation is
  /// derived from `startDate` ordering alone, so an `abandoned` step still
  /// contributes every day it actually spanned — those days *were lived*, and
  /// the Schedule's past rows and the Progress staircase are built from them.
  final StepStatus status;

  /// The `DsnsPattern` version frozen at the moment this step was created.
  final int patternVersion;
}

/// A flare: the patient went back to the last dose that worked.
///
/// Appending one never edits history. The repository writes this row **and** a
/// new step starting on the same date in one transaction; the generator's only
/// job is to truncate the running step at that date.
@immutable
final class FlareEvent {
  /// Creates the flare record.
  const FlareEvent({required this.date, required this.revertToDose, this.note});

  /// The day the flare was recorded.
  final LocalDate date;

  /// The dose the patient went back to.
  final Milligrams revertToDose;

  /// The patient's own words, if they wrote any.
  final String? note;
}

/// A hold: stay at the current block and dose for [extraDays] more days.
///
/// `SPEC.md` §5.2 — a hold does **not** abandon the step, and v1 does not
/// repeat blocks (that is v2 item 4). The extra days repeat the host day
/// exactly and shift the rest of the step forward.
@immutable
final class HoldEvent {
  /// Creates the hold record.
  const HoldEvent({
    required this.stepId,
    required this.fromDate,
    required this.extraDays,
    this.note,
  });

  /// The step this hold belongs to.
  final int stepId;

  /// The last day taken as normal; the extra days follow it.
  final LocalDate fromDate;

  /// How many extra days to insert.
  final int extraDays;

  /// The patient's own words, if they wrote any.
  final String? note;
}

/// One logged day.
@immutable
final class DoseLogFacts {
  /// Creates the log record.
  const DoseLogFacts({
    required this.date,
    required this.plannedMg,
    required this.actualMg,
    required this.taken,
    this.note,
  });

  /// The day this log is about.
  final LocalDate date;

  /// What the schedule said, recorded at the moment it was logged.
  final Milligrams plannedMg;

  /// What the patient actually took.
  final Milligrams actualMg;

  /// Whether the patient ticked the day.
  final bool taken;

  /// The patient's own words, if they wrote any.
  final String? note;
}
