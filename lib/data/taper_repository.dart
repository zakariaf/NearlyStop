/// The one object the rest of the app talks to about a taper.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/dsns_pattern.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/dsns/step_size.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:nearlystop/data/db/app_database.dart' as db;
import 'package:nearlystop/data/mappers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:sqlite3/common.dart' show SqliteException;
import 'package:ulid/ulid.dart';

/// Everything `generateSchedule` needs, plus each step's derived status.
///
/// Exactly the generator's input set — proven by a test that feeds one straight
/// in — so the app layer never has to assemble it from pieces.
@immutable
final class TaperSnapshot {
  /// Creates a snapshot.
  const TaperSnapshot({
    required this.plan,
    required this.steps,
    required this.logs,
    required this.flares,
    required this.holds,
    required this.statusByStepId,
  });

  /// The active plan, or `null` on a fresh install and after `deletePlan`.
  final TaperPlanFacts? plan;

  /// Every step, in index order.
  final List<StepFacts> steps;

  /// Every dose log, oldest first.
  final List<DoseLogFacts> logs;

  /// Every flare, oldest first.
  final List<FlareEvent> flares;

  /// Every hold across every step.
  final List<HoldEvent> holds;

  /// EPIC-04's pure `stepStatusFor` applied per step at the injected clock's
  /// today.
  ///
  /// **Derived, not stored.** It is here so EPIC-11's *Start next step* has one
  /// definition of "completed" to gate on, and so advancing the clock flips a
  /// status with no write to `Steps.status`.
  final Map<int, StepStatus> statusByStepId;
}

/// The user-entered facts of a plan, plus the first step's size.
///
/// Defined **here** — EPIC-11's form builds one and must not declare its own.
@immutable
final class TaperPlanDraft {
  /// Creates a draft.
  const TaperPlanDraft({
    required this.drugName,
    required this.startDate,
    required this.currentDose,
    required this.targetDose,
    required this.strengths,
    required this.allowHalves,
    required this.method,
    required this.stepSize,
    this.percentage,
    this.fixedStep,
  });

  /// Free text, defaulting to Prednisolone.
  final String drugName;

  /// The first day of the plan, and of its first step.
  final LocalDate startDate;

  /// The dose the patient is on now.
  final Milligrams currentDose;

  /// The dose they are heading for.
  final Milligrams targetDose;

  /// The strengths they hold.
  final List<Milligrams> strengths;

  /// Whether they can split a tablet.
  final bool allowHalves;

  /// Which arithmetic the plan uses.
  final TaperMethod method;

  /// The suggested-or-overridden first step size.
  final Milligrams stepSize;

  /// Percent per step, for [TaperMethod.percentage].
  final int? percentage;

  /// A fixed step, for [TaperMethod.fixedMg].
  final Milligrams? fixedStep;
}

/// Reads and writes the taper. **The single write path.**
///
/// Returns **facts**. `generateSchedule` runs once in the app layer's
/// `derivedScheduleProvider`, and the per-screen projections are providers
/// there — nothing is cached here (CONTRACTS.md §3, §4).
///
/// Every mutation is one transaction, every query inside it awaited, and the
/// `Future` resolves only after the durable commit; the watched stream then
/// re-emits on its own. No optimistic pre-commit update, and no manual
/// republish.
final class TaperRepository {
  /// Creates the repository over [_db], reading "now" from [_clock].
  TaperRepository(this._db, this._clock);

  final db.AppDatabase _db;
  final Clock _clock;

  /// Everything the generator needs, re-emitted after every write.
  ///
  /// **One trigger, one transactional read.** Drift's stream invalidation is
  /// table-based, so a query declaring `readsFrom` every table the snapshot
  /// touches re-emits when any of them is written — and the read that follows
  /// runs inside a transaction, so the five lists are always from the same
  /// instant.
  ///
  /// The obvious alternative — subscribe to the four DAO streams and combine
  /// their latest values — is worse in two ways that matter here. It emits
  /// TORN snapshots (steps from after a flare beside logs from before it,
  /// because the four streams fire independently), and its cleanup depends on
  /// a hand-written `onCancel` propagating through `asyncExpand`, which is one
  /// leaked drift query per screen the user walks away from if it does not.
  Stream<Result<TaperSnapshot, StorageFailure>> watchSnapshot() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
          _db.taperPlans,
          _db.steps,
          _db.doseLogs,
          _db.flareEvents,
          _db.holdEvents,
        },
      )
      .watch()
      .asyncMap((_) => _readSnapshot());

  /// One consistent read of every fact the generator needs.
  Future<Result<TaperSnapshot, StorageFailure>> _readSnapshot() async {
    try {
      return await _db.transaction(() async {
        final plan = await _db.planDao.readActivePlan();
        if (plan == null) {
          // A fresh install and the state after `deletePlan`. Both are a
          // well-defined empty snapshot, never an error.
          return const Ok(
            TaperSnapshot(
              plan: null,
              steps: <StepFacts>[],
              logs: <DoseLogFacts>[],
              flares: <FlareEvent>[],
              holds: <HoldEvent>[],
              statusByStepId: <int, StepStatus>{},
            ),
          );
        }
        return Ok(
          _assemble(
            plan,
            await _db.stepDao.readSteps(plan.id),
            await _db.logDao.readLogs(plan.id),
            await _db.planDao.readFlares(plan.id),
            await _db.stepDao.readHolds(plan.id),
          ),
        );
      });
    } on Object catch (error) {
      // A corrupt row is one unreadable value, not a reason to crash a phone
      // holding the only copy of a 400-day taper.
      return Err(_mapError(error));
    }
  }

  /// Projects four row lists onto one snapshot.
  ///
  /// No error arm: every conversion that can fail — a `method` column holding
  /// `'weekly'`, a malformed date — throws while drift builds the ROW, which
  /// is upstream of here and caught by [_readSnapshot].
  TaperSnapshot _assemble(
    db.TaperPlanRow plan,
    List<db.StepRow> steps,
    List<db.DoseLogRow> logs,
    List<db.FlareEventRow> flares,
    List<db.HoldEventRow> holds,
  ) {
    final planFacts = planFactsFrom(plan);
    final stepFacts = steps.map(stepFactsFrom).toList();
    final holdFacts = holds.map(holdEventFrom).toList();
    final today = LocalDate.fromDateTime(_clock.now());
    final nominal = nominalStepLength(planFacts);
    return TaperSnapshot(
      plan: planFacts,
      steps: stepFacts,
      logs: logs.map(doseLogFactsFrom).toList(),
      flares: flares.map(flareEventFrom).toList(),
      holds: holdFacts,
      statusByStepId: <int, StepStatus>{
        for (final step in stepFacts)
          step.id: stepStatusFor(
            step,
            holdFacts,
            today,
            nominalLength: nominal,
          ),
      },
    );
  }

  /// Records that the planned dose was taken on [date].
  ///
  /// [plannedMg] is required because `DoseLogs.plannedMg` is NOT NULL and this
  /// is an upsert that may have to CREATE the row. The caller has it on the
  /// `DayPlan` it is already rendering, which is what keeps the generator out
  /// of the data layer.
  ///
  /// The **date is passed in and the instant comes from the clock**, so
  /// backfilling three days late works by construction and no path here can
  /// derive a date from `now()`. `actualMg` is set to [plannedMg] and then
  /// frozen — that is what lets Progress sum it and Schedule render a past row
  /// honestly after the strengths change.
  ///
  /// `note` is not in the conflict set, so ticking a day never erases what the
  /// patient wrote on it.
  Future<Result<void, StorageFailure>> markTaken(
    LocalDate date, {
    required Milligrams plannedMg,
  }) => _write('markTaken', (plan) async {
    final takenAt = Value<DateTime>(_clock.now());
    await _db.logDao.upsertLog(
      _freshLog(
        plan.id,
        date,
        plannedMg: plannedMg,
        taken: true,
        takenAt: takenAt,
      ),
      onConflict: db.DoseLogsCompanion(
        plannedMg: Value<Milligrams>(plannedMg),
        actualMg: Value<Milligrams>(plannedMg),
        taken: const Value<bool>(true),
        takenAt: takenAt,
      ),
    );
  });

  /// Un-ticks [date], **preserving the row and its note**.
  ///
  /// Not a delete: deleting would silently destroy a note the patient wrote on
  /// the same day.
  Future<Result<void, StorageFailure>> undoTaken(LocalDate date) =>
      _write('undoTaken', (plan) => _db.logDao.clearTaken(plan.id, date));

  /// Writes (or clears) the note on [date].
  ///
  /// Takes [plannedMg] for the same NOT NULL reason [markTaken] does: the very
  /// first note on an un-ticked day has to be able to create the row. On a day
  /// that already has one, only the note is written — the recorded dose and
  /// the tick are facts a note must not disturb.
  Future<Result<void, StorageFailure>> setNote(
    LocalDate date,
    String? note, {
    required Milligrams plannedMg,
  }) => _write('setNote', (plan) async {
    await _db.logDao.upsertLog(
      _freshLog(
        plan.id,
        date,
        plannedMg: plannedMg,
        note: Value<String?>(note),
      ),
      onConflict: db.DoseLogsCompanion(note: Value<String?>(note)),
    );
  });

  /// The row a day gets when it does not have one yet.
  ///
  /// One place, so a column added to `DoseLogs` is supplied by every path that
  /// can create a row rather than by whichever two of the three remembered.
  db.DoseLogsCompanion _freshLog(
    int planId,
    LocalDate date, {
    required Milligrams plannedMg,
    bool taken = false,
    Value<DateTime?> takenAt = const Value<DateTime?>.absent(),
    Value<String?> note = const Value<String?>.absent(),
  }) => db.DoseLogsCompanion.insert(
    uid: Ulid().toString(),
    planId: planId,
    date: date,
    plannedMg: plannedMg,
    actualMg: plannedMg,
    taken: taken,
    takenAt: takenAt,
    note: note,
  );

  /// Records a flare: go back to [revertTo], starting [on].
  ///
  /// One transaction — the flare row, the running step marked `abandoned`, and
  /// a new step whose `startDate` **is the flare date**, which is what triggers
  /// the generator's truncation rule. `stepIndex` is `max(existing) + 1`, never
  /// a guess: an unspecified index here is a straight UNIQUE violation on the
  /// most emotionally loaded action in the app.
  ///
  /// **Nothing is deleted**, so the cumulative total is preserved by
  /// construction.
  Future<Result<void, StorageFailure>> recordFlare({
    required LocalDate on,
    required Milligrams revertTo,
  }) => _write('recordFlare', (plan) async {
    if (revertTo < plan.targetDose) {
      // Below the target, `nextDose` clamps UP and the step would record a
      // dose increase — which the generator rejects, leaving the plan unable
      // to produce a schedule at all. Refuse the write instead of storing a
      // fact that cannot be read back.
      throw const _Refused('a flare cannot revert below the plan target');
    }
    final steps = await _db.stepDao.readSteps(plan.id);
    await _db.planDao.insertFlare(
      db.FlareEventsCompanion.insert(
        uid: Ulid().toString(),
        planId: plan.id,
        date: on,
        revertToDose: revertTo,
      ),
    );
    for (final step in steps.where(
      (s) => s.status == StepStatus.active,
    )) {
      await _db.stepDao.updateStatus(step.id, StepStatus.abandoned);
    }
    await _db.stepDao.insertStep(
      db.StepsCompanion.insert(
        uid: Ulid().toString(),
        planId: plan.id,
        stepIndex: await _db.stepDao.nextStepIndex(plan.id),
        fromDose: revertTo,
        toDose: _toDoseFrom(revertTo, plan),
        startDate: on,
        status: StepStatus.active,
        patternVersion: const DsnsPattern.v1().version,
      ),
    );
  });

  /// Holds the current block for [extraDays] more days from [from].
  ///
  /// The step is **not** abandoned (`SPEC.md` §5.2); the generator extends it
  /// and shifts the remainder forward.
  Future<Result<void, StorageFailure>> recordHold({
    required int stepId,
    required LocalDate from,
    required int extraDays,
  }) => _write('recordHold', (plan) async {
    if (extraDays <= 0) throw const _Refused('a hold is at least one day');
    final steps = await _db.stepDao.readSteps(plan.id);
    if (!steps.any((step) => step.id == stepId)) {
      // The FOREIGN KEY only says the step EXISTS. A hold on another plan's
      // step would be written happily and then never read back, because the
      // snapshot's join is scoped by plan — a silent no-op on the one action
      // whose whole purpose is to move dates.
      throw const _Refused('that step does not belong to this plan');
    }
    await _db.stepDao.insertHold(
      db.HoldEventsCompanion.insert(
        uid: Ulid().toString(),
        stepId: stepId,
        fromDate: from,
        extraDays: extraDays,
      ),
    );
  });

  /// Creates the plan **and its first step**, in one transaction.
  ///
  /// Without the step no plan ever produces a schedule: `startNextStep` needs a
  /// last step and `generateSchedule` over zero steps returns nothing, so a
  /// brand-new user's Today, Schedule and Progress would render empty forever
  /// (CONTRACTS.md §7).
  ///
  /// v1 holds at most one plan; a second `savePlan` is [Invariant] and appends
  /// nothing. EPIC-11's recreate flow deletes first.
  Future<Result<void, StorageFailure>> savePlan(TaperPlanDraft draft) async {
    final refusal = _refuse(draft);
    if (refusal != null) return Err(refusal);
    try {
      await _db.transaction(() async {
        if (await _db.planDao.countPlans() > 0) {
          throw const _Refused('v1 holds one plan; delete it first');
        }
        final planId = await _db.planDao.insertPlan(
          db.TaperPlansCompanion.insert(
            uid: Ulid().toString(),
            drugName: Value<String>(draft.drugName),
            startDate: draft.startDate,
            startingDose: draft.currentDose,
            targetDose: draft.targetDose,
            tabletStrengths: draft.strengths,
            allowHalves: draft.allowHalves,
            method: draft.method,
            percentage: Value<double?>(draft.percentage?.toDouble()),
            fixedStep: Value<Milligrams?>(draft.fixedStep),
            createdAt: _clock.now(),
          ),
        );
        await _db.stepDao.insertStep(
          db.StepsCompanion.insert(
            uid: Ulid().toString(),
            planId: planId,
            stepIndex: 0,
            fromDose: draft.currentDose,
            toDose: nextDose(
              draft.currentDose,
              draft.stepSize,
              draft.targetDose,
            ),
            startDate: draft.startDate,
            status: StepStatus.active,
            patternVersion: const DsnsPattern.v1().version,
          ),
        );
      });
      return const Ok(null);
    } on Object catch (error) {
      return Err(_mapError(error));
    }
  }

  /// `SPEC.md` §5.2's *edit the plan mid-step*.
  ///
  /// Updates the plan row and **appends no step and touches no `DoseLog`**.
  /// Future days recompose on the next emission because the generator is pure.
  Future<Result<void, StorageFailure>> updatePlanFacts(TaperPlanDraft draft) =>
      _write('updatePlanFacts', (plan) async {
        final refusal = _refuse(draft);
        if (refusal != null) throw _Refused(refusal.detail);
        await _db.planDao.updatePlan(
          plan.id,
          db.TaperPlansCompanion(
            drugName: Value<String>(draft.drugName),
            startDate: Value<LocalDate>(draft.startDate),
            startingDose: Value<Milligrams>(draft.currentDose),
            targetDose: Value<Milligrams>(draft.targetDose),
            tabletStrengths: Value<List<Milligrams>>(draft.strengths),
            allowHalves: Value<bool>(draft.allowHalves),
            method: Value<TaperMethod>(draft.method),
            percentage: Value<double?>(draft.percentage?.toDouble()),
            fixedStep: Value<Milligrams?>(draft.fixedStep),
          ),
        );
      });

  /// Replaces the held strengths.
  ///
  /// **Past `DoseLog` rows are untouched** (`SPEC.md` §5.2: future days
  /// recompose, past logs stay as recorded).
  Future<Result<void, StorageFailure>> updateStrengths(
    List<Milligrams> strengths,
  ) => _write('updateStrengths', (plan) async {
    if (strengths.isEmpty) {
      throw const _Refused('a plan needs at least one tablet strength');
    }
    await _db.planDao.updatePlan(
      plan.id,
      db.TaperPlansCompanion(
        tabletStrengths: Value<List<Milligrams>>(strengths),
      ),
    );
  });

  /// Marks the finished step `completed` and appends the next one.
  ///
  /// **The start date is the day the previous step actually ends, not the day
  /// the user tapped.** Taking `today` opens a gap when they tap three days
  /// late; hard-coding `lastStart + 52` eats a hold's extra days when they tap
  /// early, which would make Hold do nothing — the exact thing `SPEC.md` §5.2
  /// forbids. A computed start in the past is correct: its early days are
  /// immediately backfillable through the `(planId, date)` upsert.
  Future<Result<void, StorageFailure>> startNextStep() =>
      _write('startNextStep', (plan) async {
        final steps = await _db.stepDao.readSteps(plan.id);
        if (steps.isEmpty) throw const _Refused('no step to follow');
        final last = steps.last;
        if (last.toDose <= plan.targetDose) {
          throw const _Refused('the target is already reached');
        }
        final planFacts = planFactsFrom(plan);
        final holds = await _db.stepDao.readHoldsForStep(last.id);
        final nominal = nominalStepLength(planFacts);
        final status = stepStatusFor(
          stepFactsFrom(last),
          holds.map(holdEventFrom).toList(),
          LocalDate.fromDateTime(_clock.now()),
          nominalLength: nominal,
        );
        if (status != StepStatus.completed) {
          throw const _Refused('the current step is not complete');
        }
        final extra = holds.fold(
          0,
          (sum, h) => sum + h.extraDays,
        );
        await _db.stepDao.updateStatus(last.id, StepStatus.completed);
        await _db.stepDao.insertStep(
          db.StepsCompanion.insert(
            uid: Ulid().toString(),
            planId: plan.id,
            stepIndex: last.stepIndex + 1,
            fromDose: last.toDose,
            toDose: _toDoseFrom(last.toDose, plan),
            startDate: last.startDate.addDays(nominal + extra),
            status: StepStatus.active,
            patternVersion: const DsnsPattern.v1().version,
          ),
        );
      });

  /// Deletes the plan and everything that cascades from it.
  ///
  /// The repository does not prompt: EPIC-11's UI owns the confirmation and the
  /// export-first flow (`SPEC.md` §5.3).
  Future<Result<void, StorageFailure>> deletePlan(int id) async {
    try {
      await _db.transaction(() async {
        await _db.planDao.deletePlan(id);
      });
      return const Ok(null);
    } on Object catch (error) {
      return Err(_mapError(error));
    }
  }

  /// Why [draft] cannot be stored, or `null` if it can.
  ///
  /// These are the facts `generateSchedule` refuses. Writing one anyway leaves
  /// a plan that renders nothing on every screen, in the only copy of the
  /// patient's data — and the data layer is where the fact is created, so it is
  /// where the refusal belongs.
  Invariant? _refuse(TaperPlanDraft draft) {
    if (draft.strengths.isEmpty) {
      return const Invariant('a plan needs at least one tablet strength');
    }
    if (draft.targetDose > draft.currentDose) {
      return const Invariant('the target is above the current dose');
    }
    return switch (draft.method) {
      TaperMethod.dsns => null,
      TaperMethod.percentage =>
        draft.percentage == null
            ? const Invariant('a percentage plan needs a percentage')
            : null,
      TaperMethod.fixedMg =>
        draft.fixedStep == null
            ? const Invariant('a fixed-step plan needs a step size')
            : null,
    };
  }

  /// The next dose after stepping down from [from], using the plan's own rule.
  Milligrams _toDoseFrom(Milligrams from, db.TaperPlanRow plan) {
    final strengths = <TabletStrength>[
      for (final mg in plan.tabletStrengths) TabletStrength(mg),
    ];
    final suggestion = suggestStep(
      currentDose: from,
      targetDose: plan.targetDose,
      strengths: strengths,
      allowHalves: plan.allowHalves,
    );
    final size = switch (suggestion) {
      Ok<StepSuggestion, DomainFailure>(:final value) => value.suggested,
      Err<StepSuggestion, DomainFailure>() => Milligrams.zero,
    };
    return nextDose(from, size, plan.targetDose);
  }

  /// One transaction, one plan lookup, one typed arm.
  ///
  /// The lookup is **inside** the transaction and its row is handed to [body],
  /// so no mutation reads the plan twice and none can act on a plan that was
  /// deleted between the check and the write.
  Future<Result<void, StorageFailure>> _write(
    String what,
    Future<void> Function(db.TaperPlanRow plan) body,
  ) async {
    try {
      return await _db.transaction(() async {
        final plan = await _db.planDao.readActivePlan();
        if (plan == null) return Err<void, StorageFailure>(NotFound(what));
        await body(plan);
        return const Ok<void, StorageFailure>(null);
      });
    } on Object catch (error) {
      return Err(_mapError(error));
    }
  }
}

/// An app-rule refusal raised inside a transaction so it rolls back.
///
/// Private on purpose: it never escapes this file. [_mapError] turns it into an
/// [Invariant], which is what the caller switches on.
@immutable
final class _Refused implements Exception {
  const _Refused(this.detail);
  final String detail;
}

/// Converts an engine or rule error into a typed failure.
///
/// The **only** place a drift or sqlite exception is named. Everything above
/// this line sees a [StorageFailure].
///
/// Visible for testing because an error mapper is exactly the code that never
/// runs until the day it matters: the `DriftWrappedException` arm is not
/// reachable from any public call this engine version makes, and an untested
/// mapper turns a single unreadable row into a blanket "storage error".
@visibleForTesting
StorageFailure mapStorageFailure(Object error) => _mapError(error);

StorageFailure _mapError(Object error) {
  // Drift wraps whatever the engine or a converter threw. Unwrap before
  // classifying, or every converter FormatException reads as an Io failure.
  var cause = error;
  while (cause is DriftWrappedException) {
    final inner = cause.cause;
    if (inner == null) break;
    cause = inner;
  }
  if (cause is _Refused) return Invariant(cause.detail);
  if (cause is FormatException) return Corrupt(cause.message);
  if (cause is SqliteException) {
    // The low byte of an extended result code is the primary code, and 19 is
    // SQLITE_CONSTRAINT — covering UNIQUE (2067), CHECK (275), FOREIGN KEY
    // (787), NOT NULL (1299) and PRIMARY KEY (1555) in one test. Matching the
    // message text instead breaks the day SQLite rewords it.
    if (cause.extendedResultCode & 0xFF == 19) {
      return ConstraintViolation(cause.message);
    }
  }
  return Io(cause);
}
