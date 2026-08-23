/// The pure function at the centre of the app.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/dsns_pattern.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// Derives the days a patient will live from the facts that were stored.
///
/// Pure and synchronous: dates in, days out. No I/O, no clock, no database, no
/// Flutter. That is what makes a flare incapable of corrupting history — a
/// flare appends a fact and the schedule is re-derived — and what makes the
/// whole engine testable without a single mock (`SPEC.md` §6).
///
/// **Emits exactly one [DayPlan] for every date in range, with no holes**
/// (CONTRACTS.md §5):
///
/// * **Step days** — [DayKind.step], `blockIndex` 1..11 on DSNS, `dayInStep`
///   1..52 counting non-hold days.
/// * **Steady-state days** — after a step's realised length and before the next
///   step's `startDate`: [DayKind.steadyState] at that step's `toDose`. Steps
///   are user-initiated, so a patient who finishes day 52 on a Friday and taps
///   *Start next step* on Monday has three days that must still render.
/// * **After the final step** — steady-state at that step's `toDose`,
///   indefinitely, which is what makes `SPEC.md` §7's "target reached" a
///   renderable state instead of an empty list.
///
/// [until] is the **right bound of generation**. `null` means *the end of the
/// last step*, which is what the golden vector pins; every caller that renders
/// Today passes an explicit bound instead.
///
/// A step's realised length is `min(nominal + Σ holdExtraDays, days until the
/// next step's startDate)`. That one rule is what makes flare rollback
/// non-destructive: a flare inserts a step starting on the flare date, which
/// truncates the running step there. Nothing is deleted, nothing is rewritten,
/// and days before the flare regenerate byte for byte because their inputs did
/// not change.
///
/// **`StepFacts.status` is ignored.** Truncation comes from `startDate`
/// ordering alone, so an `abandoned` step still contributes every day it
/// actually spanned — those days *were lived*, and the Schedule's past rows and
/// the Progress staircase are built from them. `status` exists for the UI and
/// for `startNextStep`.
///
/// [flares] is accepted for signature stability with `SPEC.md` §6 and is
/// deliberately **not read**: a flare is already expressed in [steps] as a step
/// beginning on the flare date, and reading it again here would be a second
/// source of truth for the same event. EPIC-10 marks flares on the Progress
/// timeline from the facts directly.
///
/// The caller's contract is that `steps.first.startDate == plan.startDate`
/// (CONTRACTS.md §7 — `savePlan` inserts Step 0 in the same transaction).
///
/// Total: returns for every input. [TargetAboveStart], [PlanNotStarted],
/// [MissingMethodParameter] and [UnknownPatternVersion] are values, never
/// throws.
Result<List<DayPlan>, DomainFailure> generateSchedule({
  required TaperPlanFacts plan,
  required List<StepFacts> steps,
  required List<FlareEvent> flares,
  required List<HoldEvent> holds,
  LocalDate? until,
}) {
  final guard = _validate(plan, until);
  if (guard != null) return Err(guard);
  if (steps.isEmpty) return const Ok(<DayPlan>[]);

  final ordered = [...steps]
    ..sort((a, b) {
      final byDate = a.startDate.compareTo(b.startDate);
      return byDate != 0 ? byDate : a.index.compareTo(b.index);
    });

  // CONTRACTS.md §5 promises exactly one DayPlan for every date in range, and
  // that promise rests entirely on the first step opening on the plan's first
  // day. An earlier first step emits days before the plan exists; a later one
  // leaves a hole the Schedule screen renders as a gap. Both are refusals, not
  // best-effort renders.
  if (ordered.first.startDate != plan.startDate) {
    return Err(PlanNotStarted(plan.startDate));
  }

  final composer = _CompositionCache(plan);
  final days = <DayPlan>[];

  for (var i = 0; i < ordered.length; i++) {
    final step = ordered[i];
    // The step's exclusive end: the EARLIER of the next step's start and one
    // day past `until`. Taking only `nextStart` here let generation run months
    // past the requested right bound AND replaced the truncated step's
    // remaining alternating pattern with flat steady-state days at the lower
    // dose — a caller bounding at a past date was told to take the new dose
    // every day for weeks it should have alternated.
    final nextStart = i + 1 < ordered.length ? ordered[i + 1].startDate : null;
    final stop = _earliest(nextStart, until?.addDays(1));

    final shape = _shapeFor(plan, step);
    switch (shape) {
      case Err<List<_ShapeDay>, DomainFailure>(:final failure):
        return Err(failure);
      case Ok<List<_ShapeDay>, DomainFailure>(value: final pattern):
        final after = _emitStepDays(
          into: days,
          step: step,
          pattern: pattern,
          extraByDate: _extraDaysByDate(holds, step.id),
          composer: composer,
          stop: stop,
        );
        // A null `stop` means "the end of the last step, and no further",
        // which is the contract the golden vector pins.
        _emitSteadyState(
          into: days,
          step: step,
          composer: composer,
          from: after,
          boundary: stop,
        );
    }
  }

  return Ok(days);
}

/// The three refusals that are about the plan rather than a step.
DomainFailure? _validate(TaperPlanFacts plan, LocalDate? until) {
  if (plan.targetDose > plan.startingDose) {
    return TargetAboveStart(plan.startingDose, plan.targetDose);
  }
  if (until != null && until < plan.startDate) {
    return PlanNotStarted(plan.startDate);
  }
  return switch (plan.method) {
    TaperMethod.dsns => null,
    TaperMethod.percentage =>
      plan.percentage == null
          ? const MissingMethodParameter(TaperMethod.percentage)
          : null,
    TaperMethod.fixedMg =>
      plan.fixedStep == null
          ? const MissingMethodParameter(TaperMethod.fixedMg)
          : null,
  };
}

/// One position the step's date walk lands on.
typedef _WalkedDay = ({LocalDate date, int patternIndex, bool isHoldDay});

/// Walks a step's dates, inserting hold days, up to (exclusive) [stop].
///
/// **The single definition of a step's realised shape.** The generator maps it
/// to `DayPlan`s and `stepStatusFor` counts it, so the schedule and the "Start
/// next step" button can never disagree about when a step ends.
///
/// Holds are consumed **at every date the walk emits, including a date that is
/// itself a hold day** — a second hold anchored to an inserted day used to be
/// silently dropped, so the patient lived fewer days than their status said. A
/// hold with a non-positive `extraDays`, or one anchored to a date this step
/// never reaches, contributes nothing to either side.
List<_WalkedDay> _walkStep({
  required LocalDate startDate,
  required int patternLength,
  required Map<LocalDate, int> extraByDate,
  LocalDate? stop,
}) {
  final walked = <_WalkedDay>[];
  var date = startDate;
  for (var index = 0; index < patternLength; index++) {
    if (stop != null && date >= stop) return walked;
    walked.add((date: date, patternIndex: index, isHoldDay: false));
    var pending = extraByDate[date] ?? 0;
    date = date.addDays(1);
    while (pending > 0) {
      if (stop != null && date >= stop) return walked;
      walked.add((date: date, patternIndex: index, isHoldDay: true));
      pending = pending - 1 + (extraByDate[date] ?? 0);
      date = date.addDays(1);
    }
  }
  return walked;
}

/// Appends one step's days and returns the first date it did not use.
LocalDate _emitStepDays({
  required List<DayPlan> into,
  required StepFacts step,
  required List<_ShapeDay> pattern,
  required Map<LocalDate, int> extraByDate,
  required _CompositionCache composer,
  required LocalDate? stop,
}) {
  final walked = _walkStep(
    startDate: step.startDate,
    patternLength: pattern.length,
    extraByDate: extraByDate,
    stop: stop,
  );
  for (final position in walked) {
    final day = pattern[position.patternIndex];
    into.add(
      DayPlan(
        date: position.date,
        stepIndex: step.index,
        kind: DayKind.step,
        blockIndex: day.blockIndex,
        dayInBlock: day.dayInBlock,
        // A hold day repeats the host day's position: it is the same day of
        // the step, lived twice.
        dayInStep: position.patternIndex + 1,
        dose: day.dose,
        doseKind: day.doseKind,
        composition: composer.of(day.dose),
        isHoldDay: position.isHoldDay,
      ),
    );
  }
  return walked.isEmpty ? step.startDate : walked.last.date.addDays(1);
}

/// Fills `[from, boundary)` with steady-state days at the step's new dose.
void _emitSteadyState({
  required List<DayPlan> into,
  required StepFacts step,
  required _CompositionCache composer,
  required LocalDate from,
  required LocalDate? boundary,
}) {
  if (boundary == null) return;
  for (var date = from; date < boundary; date = date.addDays(1)) {
    into.add(
      DayPlan(
        date: date,
        stepIndex: step.index,
        kind: DayKind.steadyState,
        blockIndex: null,
        dayInBlock: null,
        dayInStep: null,
        dose: step.toDose,
        doseKind: DoseKind.newDose,
        composition: composer.of(step.toDose),
        isHoldDay: false,
      ),
    );
  }
}

/// Where [step] stands on [today].
///
/// The **single** definition of step completion in the codebase: EPIC-05
/// exposes it through the snapshot and EPIC-11 gates *Start next step* on it,
/// so the button can ever be enabled and can never be enabled by a second rule.
///
/// A step is [StepStatus.completed] when `today >= startDate + nominalLength +
/// Σ extraDays`, [StepStatus.active] from its start date until then, and
/// [StepStatus.pending] before it. A step whose stored status is already
/// [StepStatus.abandoned] reports that unchanged — abandonment is an event, not
/// a date computation.
///
/// [nominalLength] is 52 for DSNS and the plan's hold period for the other two
/// methods.
StepStatus stepStatusFor(
  StepFacts step,
  List<HoldEvent> holds,
  LocalDate today, {
  required int nominalLength,
}) {
  if (step.status == StepStatus.abandoned) return StepStatus.abandoned;
  if (today < step.startDate) return StepStatus.pending;
  final realised = realisedStepLength(
    step,
    holds,
    nominalLength: nominalLength,
  );
  return today >= step.startDate.addDays(realised)
      ? StepStatus.completed
      : StepStatus.active;
}

/// How many days [step] actually runs for, once its holds are applied.
///
/// **The single definition of a step's length**, walked exactly the way
/// [generateSchedule] walks it. A caller that instead folds
/// `sum(hold.extraDays)` gets a different answer whenever a hold is anchored to
/// a date the step never reaches — and then "when does this step end" means one
/// thing to [stepStatusFor] and another to whoever appends the next step,
/// leaving orphan days at the old dose in the gap between them.
int realisedStepLength(
  StepFacts step,
  List<HoldEvent> holds, {
  required int nominalLength,
}) => _walkStep(
  startDate: step.startDate,
  patternLength: nominalLength,
  extraByDate: _extraDaysByDate(holds, step.id),
).length;

/// The nominal length of one step under [plan]: 52 for DSNS, the plan's hold
/// period otherwise.
///
/// Exists so a caller cannot default [stepStatusFor]'s `nominalLength` to 52 on
/// a `percentage` plan that runs 14 days — which would leave "Start next step"
/// disabled for 38 days after the schedule had already reached steady state.
int nominalStepLength(TaperPlanFacts plan) => switch (plan.method) {
  TaperMethod.dsns => dsnsStepDays,
  TaperMethod.percentage || TaperMethod.fixedMg => plan.holdPeriodDays,
};

/// The earlier of two optional bounds, or whichever one is present.
LocalDate? _earliest(LocalDate? a, LocalDate? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a < b ? a : b;
}

Map<LocalDate, int> _extraDaysByDate(List<HoldEvent> holds, int stepId) {
  final byDate = <LocalDate, int>{};
  for (final hold in holds) {
    if (hold.stepId != stepId || hold.extraDays <= 0) continue;
    byDate[hold.fromDate] = (byDate[hold.fromDate] ?? 0) + hold.extraDays;
  }
  return byDate;
}

/// One position in a step's shape, before dates are attached.
@immutable
final class _ShapeDay {
  const _ShapeDay({
    required this.dose,
    required this.doseKind,
    required this.blockIndex,
    required this.dayInBlock,
  });

  final Milligrams dose;
  final DoseKind doseKind;
  final int? blockIndex;
  final int? dayInBlock;
}

/// The dose sequence one step lays down, by method.
///
/// `percentage` and `fixedMg` differ only in how the step *size* was computed —
/// which happened when the step was created, and is already recorded in
/// `step.toDose`. Both produce the same "new dose every day" shape here, so
/// they share one code path.
Result<List<_ShapeDay>, DomainFailure> _shapeFor(
  TaperPlanFacts plan,
  StepFacts step,
) {
  switch (plan.method) {
    case TaperMethod.dsns:
      final pattern = DsnsPattern.forVersion(step.patternVersion);
      switch (pattern) {
        case Err<DsnsPattern, DomainFailure>(:final failure):
          return Err(failure);
        case Ok<DsnsPattern, DomainFailure>(value: final table):
          final shape = <_ShapeDay>[];
          for (final block in table.blocks) {
            // The single day always LEADS its block (SPEC.md §3.1). Blocks 1-6
            // lead with the new dose; from block 7 they lead with the old one,
            // which is why the crossover has two consecutive old days.
            final leadKind = block.leadsWithNew
                ? DoseKind.newDose
                : DoseKind.oldDose;
            final restKind = block.leadsWithNew
                ? DoseKind.oldDose
                : DoseKind.newDose;
            for (var position = 1; position <= block.length; position++) {
              final kind = position == 1 ? leadKind : restKind;
              shape.add(
                _ShapeDay(
                  dose: kind == DoseKind.newDose ? step.toDose : step.fromDose,
                  doseKind: kind,
                  blockIndex: block.index,
                  dayInBlock: position,
                ),
              );
            }
          }
          return Ok(shape);
      }
    case TaperMethod.percentage:
    case TaperMethod.fixedMg:
      return Ok(<_ShapeDay>[
        for (var day = 0; day < plan.holdPeriodDays; day++)
          _ShapeDay(
            dose: step.toDose,
            doseKind: DoseKind.newDose,
            blockIndex: null,
            dayInBlock: null,
          ),
      ]);
  }
}

/// Memoises composition per distinct dose within one call.
///
/// A DSNS step has at most two distinct doses, so this is a two-entry map that
/// turns 52 solver runs into two.
final class _CompositionCache {
  _CompositionCache(this._plan);

  final TaperPlanFacts _plan;
  final Map<int, Result<TabletComposition, DomainFailure>> _byHundredths = {};

  Result<TabletComposition, DomainFailure> of(Milligrams dose) =>
      _byHundredths.putIfAbsent(
        dose.hundredths,
        () => composeTablets(
          target: dose,
          strengths: _plan.tabletStrengths,
          allowHalves: _plan.allowHalves,
        ),
      );
}
