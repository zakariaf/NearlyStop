// The repository, against a real engine and an injected clock.
//
// Never a mocked DAO: every claim below — the upsert, the cascade, the
// transaction rollback, the constraint mapping — is a property of the engine,
// and a mock would agree with whatever the implementation happened to do.
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/cumulative.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:sqlite3/common.dart' show SqliteException;

import '../support/db_harness.dart';

void main() {
  late AppDatabase db;
  late TaperRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = TaperRepository(db, fixedClock);
  });

  // A second AppDatabase over the same process makes drift warn about
  // multiple instances; every test here shares the one from setUp and varies
  // only the clock.
  TaperRepository repoAt(DateTime now) => TaperRepository(db, Clock.fixed(now));

  Future<TaperSnapshot> snapshot() async {
    final result = await repository.watchSnapshot().first;
    return switch (result) {
      Ok<TaperSnapshot, StorageFailure>(:final value) => value,
      Err<TaperSnapshot, StorageFailure>(:final failure) => throw StateError(
        'snapshot failed: $failure',
      ),
    };
  }

  Future<void> expectOk(Future<Result<void, StorageFailure>> write) async {
    expect(await write, isA<Ok<void, StorageFailure>>());
  }

  F expectErr<F extends StorageFailure>(Result<void, StorageFailure> r) {
    expect(r, isA<Err<void, StorageFailure>>());
    return (r as Err<void, StorageFailure>).failure as F;
  }

  group('markTaken', () {
    test('creates the row, freezes actualMg, and is idempotent', () async {
      await expectOk(repository.savePlan(seededDraft()));

      await expectOk(
        repository.markTaken(const LocalDate(2026, 4, 16), plannedMg: mg(9)),
      );
      await expectOk(
        repository.markTaken(const LocalDate(2026, 4, 16), plannedMg: mg(9)),
      );

      final logs = (await snapshot()).logs;
      expect(logs, hasLength(1));
      expect(logs.single.taken, isTrue);
      expect(logs.single.plannedMg, mg(9));
      expect(logs.single.actualMg, mg(9));
      final rows = await db.select(db.doseLogs).get();
      expect(rows.single.takenAt, fixedNow);
    });

    test('backfills three days late: date from the argument, instant from the '
        'clock', () async {
      await expectOk(repository.savePlan(seededDraft()));

      await expectOk(
        repository.markTaken(const LocalDate(2026, 4, 13), plannedMg: mg(10)),
      );

      final row = (await db.select(db.doseLogs).get()).single;
      expect(row.date, const LocalDate(2026, 4, 13));
      // No path derives a date from now(); if one did, this would be 04-16.
      expect(row.takenAt, fixedNow);
    });

    test('is NotFound with no plan, rather than a crash', () async {
      final failure = expectErr<NotFound>(
        await repository.markTaken(
          const LocalDate(2026, 4, 16),
          plannedMg: mg(9),
        ),
      );
      // The ENTITY, not the method: a screen routes on `NotFound('plan')`.
      expect(failure.what, 'plan');
    });
  });

  test(
    'a note survives markTaken and undoTaken; undo is not a delete',
    () async {
      await expectOk(repository.savePlan(seededDraft()));
      const future = LocalDate(2026, 5, 20);

      await expectOk(repository.setNote(future, 'dizzy', plannedMg: mg(9)));
      await expectOk(repository.markTaken(future, plannedMg: mg(9)));
      await expectOk(repository.undoTaken(future));

      final logs = (await snapshot()).logs;
      expect(logs, hasLength(1), reason: 'undoTaken is not a delete');
      expect(logs.single.note, 'dizzy');
      expect(logs.single.taken, isFalse);
      expect((await db.select(db.doseLogs).get()).single.takenAt, isNull);
    },
  );

  test('undoTaken on a date with no row is a no-op, not a failure', () async {
    await expectOk(repository.savePlan(seededDraft()));

    await expectOk(repository.undoTaken(const LocalDate(2026, 4, 16)));

    expect(await db.select(db.doseLogs).get(), isEmpty);
  });

  group('savePlan', () {
    test('inserts the plan and exactly one step at index 0', () async {
      await expectOk(repository.savePlan(seededDraft()));

      final snap = await snapshot();
      expect(snap.plan, isNotNull);
      expect(snap.steps, hasLength(1));
      final step = snap.steps.single;
      expect(step.index, 0);
      expect(step.fromDose, mg(10));
      expect(step.toDose, mg(9));
      expect(step.startDate, const LocalDate(2026, 4, 1));
      expect(step.status, StepStatus.active);
      expect(step.patternVersion, 1);
    });

    test('a second savePlan is Invariant and appends nothing', () async {
      await expectOk(repository.savePlan(seededDraft()));

      expectErr<Invariant>(await repository.savePlan(seededDraft()));

      expect(await db.select(db.taperPlans).get(), hasLength(1));
      expect(await db.select(db.steps).get(), hasLength(1));
    });
  });

  test("a hold on a step that is not this plan's is refused", () async {
    // The FOREIGN KEY only says the step exists. Without the ownership check
    // the row is written and then never read back, because the snapshot's
    // join is plan-scoped — Hold would appear to do nothing.
    await expectOk(repository.savePlan(seededDraft()));
    final orphanPlan = await seedPlan(db, uid: 'plan-2', createdAt: fixedNow);
    final orphanStep = await seedStep(db, orphanPlan, uid: 'orphan-step');

    expectErr<Invariant>(
      await repository.recordHold(
        stepId: orphanStep,
        from: const LocalDate(2026, 4, 10),
        extraDays: 3,
      ),
    );

    expect(await db.select(db.holdEvents).get(), isEmpty);
  });

  group('a draft the generator would refuse is refused at the write', () {
    // Written here rather than left to the UI: this is the only copy of the
    // patient's data, and a plan `generateSchedule` rejects renders nothing on
    // every screen with nothing in the row to say why.
    final refused = <String, TaperPlanDraft>{
      'no strengths': seededDraft(strengths: <Milligrams>[]),
      'percentage method with no percentage': seededDraft(
        method: TaperMethod.percentage,
      ),
      'fixedMg method with no step': seededDraft(method: TaperMethod.fixedMg),
    };

    for (final entry in refused.entries) {
      test('savePlan refuses ${entry.key}', () async {
        expectErr<Invariant>(await repository.savePlan(entry.value));

        expect(await db.select(db.taperPlans).get(), isEmpty);
        expect(await db.select(db.steps).get(), isEmpty);
      });

      test('updatePlanFacts refuses ${entry.key}', () async {
        await expectOk(repository.savePlan(seededDraft()));

        expectErr<Invariant>(await repository.updatePlanFacts(entry.value));

        // Rolled back: the plan the patient already had is untouched.
        final plan = (await snapshot()).plan!;
        expect(plan.method, TaperMethod.dsns);
        expect(plan.tabletStrengths, hasLength(2));
      });
    }

    test('savePlan refuses a first step of zero', () async {
      // Not caught by anything downstream: the row reads as valid and the
      // generator emits 52 days at the same dose, forever.
      expectErr<Invariant>(
        await repository.savePlan(
          TaperPlanDraft(
            drugName: 'Prednisolone',
            startDate: const LocalDate(2026, 4, 1),
            currentDose: mg(10),
            targetDose: Milligrams.zero,
            strengths: <Milligrams>[mg(5), mg(1)],
            allowHalves: true,
            method: TaperMethod.dsns,
            stepSize: Milligrams.zero,
          ),
        ),
      );

      expect(await db.select(db.taperPlans).get(), isEmpty);
    });

    test('a plan already AT its target is accepted with a zero step', () async {
      // The other arm: nothing left to reduce is a finished plan, not an
      // invalid one.
      await expectOk(
        repository.savePlan(
          TaperPlanDraft(
            drugName: 'Prednisolone',
            startDate: const LocalDate(2026, 4, 1),
            currentDose: mg(1),
            targetDose: mg(1),
            strengths: <Milligrams>[mg(1)],
            allowHalves: true,
            method: TaperMethod.dsns,
            stepSize: Milligrams.zero,
          ),
        ),
      );

      expect((await snapshot()).steps, hasLength(1));
    });

    test('savePlan refuses a target above the current dose', () async {
      expectErr<Invariant>(
        await repository.savePlan(
          TaperPlanDraft(
            drugName: 'Prednisolone',
            startDate: const LocalDate(2026, 4, 1),
            currentDose: mg(5),
            targetDose: mg(10),
            strengths: <Milligrams>[mg(5)],
            allowHalves: true,
            method: TaperMethod.dsns,
            stepSize: mg(1),
          ),
        ),
      );

      expect(await db.select(db.taperPlans).get(), isEmpty);
    });

    test(
      'a percentage plan WITH its percentage is accepted and generates',
      () async {
        // The other arm: the guard must not refuse a legal non-DSNS plan.
        await expectOk(
          repository.savePlan(
            seededDraft(method: TaperMethod.percentage, percentage: 10),
          ),
        );

        final snap = await snapshot();
        expect(snap.plan!.percentage, 10);
        expect(
          generateSchedule(
            plan: snap.plan!,
            steps: snap.steps,
            flares: snap.flares,
            holds: snap.holds,
          ),
          isA<Ok<List<DayPlan>, DomainFailure>>(),
        );
      },
    );
  });

  group('recordFlare', () {
    test('abandons the running step, appends a flare and a new step', () async {
      await expectOk(repository.savePlan(seededDraft()));

      await expectOk(
        repository.recordFlare(
          on: const LocalDate(2026, 5, 1),
          revertTo: mg(10),
        ),
      );

      final snap = await snapshot();
      expect(snap.steps.first.status, StepStatus.abandoned);
      expect(snap.flares, hasLength(1));
      expect(snap.flares.single.date, const LocalDate(2026, 5, 1));
      final fresh = snap.steps.last;
      expect(fresh.index, 1);
      expect(fresh.fromDose, mg(10));
      // The flare date IS the new step's start; that is what triggers the
      // generator's truncation rule.
      expect(fresh.startDate, const LocalDate(2026, 5, 1));
      expect(fresh.status, StepStatus.active);
    });

    test(
      'twice in a row: stepIndex increases and the total is unchanged',
      () async {
        await expectOk(repository.savePlan(seededDraft()));
        for (var day = 1; day <= 20; day++) {
          await expectOk(
            repository.markTaken(LocalDate(2026, 4, day), plannedMg: mg(10)),
          );
        }
        final before = cumulativeTakenMg((await snapshot()).logs);

        await expectOk(
          repository.recordFlare(
            on: const LocalDate(2026, 5, 1),
            revertTo: mg(10),
          ),
        );
        await expectOk(
          repository.recordFlare(
            on: const LocalDate(2026, 5, 8),
            revertTo: mg(10),
          ),
        );

        final snap = await snapshot();
        expect(snap.steps.map((s) => s.index).toList(), <int>[0, 1, 2]);
        // Nothing was deleted, so history cannot have moved.
        expect(cumulativeTakenMg(snap.logs), before);
        expect(before.hundredths, 20 * 1000);
      },
    );
  });

  group('startNextStep', () {
    // The step runs 2026-04-01 + 52 days, so it completes on 2026-05-23.
    // Both tests below must land there, from opposite sides.
    for (final (label, now) in <(String, DateTime)>[
      ('tapped three days LATE', DateTime.utc(2026, 5, 26, 8)),
      ('tapped the day it completes', DateTime.utc(2026, 5, 23, 8)),
    ]) {
      test(
        '$label: the next step starts on the day the last one ended',
        () async {
          final repo = repoAt(now);
          await expectOk(repo.savePlan(seededDraft()));

          await expectOk(repo.startNextStep());

          final steps = await db.stepDao.readSteps(1);
          // Taking `today` here would open a three-day gap in the late case.
          expect(steps.last.startDate, const LocalDate(2026, 5, 23));
          expect(steps.last.stepIndex, 1);
          expect(steps.last.fromDose, mg(9));
          expect(steps.first.status, StepStatus.completed);
        },
      );
    }

    test('a 3-day hold pushes the next start to +55, not +52', () async {
      final repo = repoAt(DateTime.utc(2026, 6));
      await expectOk(repo.savePlan(seededDraft()));
      await expectOk(
        repo.recordHold(
          stepId: 1,
          from: const LocalDate(2026, 4, 20),
          extraDays: 3,
        ),
      );

      await expectOk(repo.startNextStep());

      final steps = await db.stepDao.readSteps(1);
      // Hard-coding +52 here would swallow the hold, which SPEC 5.2 forbids.
      expect(steps.last.startDate, const LocalDate(2026, 5, 26));
    });

    test('refuses while the step is still running', () async {
      final repo = repoAt(DateTime.utc(2026, 4, 20));
      await expectOk(repo.savePlan(seededDraft()));

      expectErr<Invariant>(await repo.startNextStep());

      expect(await db.select(db.steps).get(), hasLength(1));
    });

    test('refuses once the target is reached', () async {
      final repo = repoAt(DateTime.utc(2027, 4));
      await expectOk(
        repo.savePlan(
          TaperPlanDraft(
            drugName: 'Prednisolone',
            startDate: const LocalDate(2026, 4, 1),
            currentDose: mg(1),
            targetDose: mg(1),
            strengths: <Milligrams>[mg(1)],
            allowHalves: true,
            method: TaperMethod.dsns,
            stepSize: mg(1),
          ),
        ),
      );

      expectErr<Invariant>(await repo.startNextStep());
    });
  });

  test(
    'updatePlanFacts edits the plan, appends no step, touches no log',
    () async {
      await expectOk(repository.savePlan(seededDraft()));
      await expectOk(
        repository.markTaken(const LocalDate(2026, 4, 2), plannedMg: mg(10)),
      );
      final logsBefore = await db.select(db.doseLogs).get();

      await expectOk(
        repository.updatePlanFacts(
          seededDraft(startDate: const LocalDate(2026, 4, 5)),
        ),
      );

      expect(await db.select(db.steps).get(), hasLength(1));
      expect(await db.select(db.doseLogs).get(), logsBefore);
      expect((await snapshot()).plan!.startDate, const LocalDate(2026, 4, 5));
    },
  );

  group('updateStrengths', () {
    test('rejects an empty list', () async {
      await expectOk(repository.savePlan(seededDraft()));

      expectErr<Invariant>(await repository.updateStrengths(<Milligrams>[]));

      expect((await snapshot()).plan!.tabletStrengths, hasLength(2));
    });

    test('changes the plan and leaves past actualMg alone', () async {
      await expectOk(repository.savePlan(seededDraft()));
      await expectOk(
        repository.markTaken(const LocalDate(2026, 4, 2), plannedMg: mg(10)),
      );

      await expectOk(
        repository.updateStrengths(<Milligrams>[mg(5), mg(2.5), mg(1)]),
      );

      final snap = await snapshot();
      expect(snap.plan!.tabletStrengths.map((t) => t.mg), <Milligrams>[
        mg(5),
        mg(2.5),
        mg(1),
      ]);
      expect(snap.logs.single.actualMg, mg(10));
    });
  });

  test(
    'deletePlan takes everything with it and the snapshot goes empty',
    () async {
      await expectOk(repository.savePlan(seededDraft()));
      await expectOk(
        repository.markTaken(const LocalDate(2026, 4, 2), plannedMg: mg(10)),
      );

      await expectOk(repository.deletePlan());

      final snap = await snapshot();
      expect(snap.plan, isNull);
      expect(snap.steps, isEmpty);
      expect(snap.logs, isEmpty);
    },
  );

  group('failure mapping, driven by the real engine', () {
    test(
      "the engine's own UNIQUE violation is typed, not thrown",
      () async {
        // Caught from a REAL write, not a constructed exception. No public
        // repository method reaches this any more — every write that could
        // violate a constraint is refused in Dart first — so the honest shape
        // is: force the engine to raise, then assert the mapper types what it
        // actually raised. `map_storage_failure_test` covers the other codes.
        await expectOk(repository.savePlan(seededDraft()));
        await seedLog(db, 1, const LocalDate(2026, 4, 2), uid: 'first');

        Object? raised;
        try {
          await db
              .into(db.doseLogs)
              .insert(
                DoseLogsCompanion.insert(
                  uid: 'second',
                  planId: 1,
                  date: const LocalDate(2026, 4, 2),
                  plannedMg: mg(10),
                  actualMg: mg(10),
                  taken: true,
                ),
              );
        } on Object catch (error) {
          raised = error;
        }

        expect(raised, isA<SqliteException>());
        expect((raised! as SqliteException).extendedResultCode, 2067);
        expect(storageFailureFrom(raised), isA<ConstraintViolation>());
      },
    );

    test('an unknown method written by raw SQL surfaces as Corrupt', () async {
      await expectOk(repository.savePlan(seededDraft()));

      await db.customStatement("UPDATE taper_plans SET method = 'weekly'");

      final result = await repository.watchSnapshot().first;
      expect(result, isA<Err<TaperSnapshot, StorageFailure>>());
      expect(
        (result as Err<TaperSnapshot, StorageFailure>).failure,
        isA<Corrupt>(),
      );
    });

    test(
      'a corrupt STEP row surfaces through the step stream, not a crash',
      () async {
        // Different arrival path from the corrupt plan above: the plan reads
        // fine, so the failure comes up the joined step stream and has to be
        // caught there rather than escaping as an unhandled stream error.
        await expectOk(repository.savePlan(seededDraft()));
        await db.customStatement("UPDATE steps SET status = 'paused'");

        final result = await repository.watchSnapshot().first;

        expect(result, isA<Err<TaperSnapshot, StorageFailure>>());
        expect(
          (result as Err<TaperSnapshot, StorageFailure>).failure,
          isA<Corrupt>(),
        );
      },
    );

    test(
      'a converter failure inside a WRITE is Corrupt, unwrapped from drift',
      () async {
        // Drift wraps whatever a converter threw. Without the unwrap this reads
        // as an Io failure and the screen shows "storage error" for what is
        // actually a single unreadable row.
        await expectOk(repository.savePlan(seededDraft()));
        await db.customStatement("UPDATE taper_plans SET method = 'weekly'");

        final result = await repository.markTaken(
          const LocalDate(2026, 4, 16),
          plannedMg: mg(9),
        );

        expect(
          (result as Err<void, StorageFailure>).failure,
          isA<Corrupt>(),
        );
      },
    );

    test('a closed database is Io, not an escaping StateError', () async {
      await expectOk(repository.savePlan(seededDraft()));
      await db.close();

      final result = await repository.deletePlan();

      expect(
        (result as Err<void, StorageFailure>).failure,
        isA<Io>(),
      );
    });
  });

  test(
    'a flare cannot revert BELOW the plan target',
    () async {
      // `nextDose` clamps up to the target, so a revert below it would record
      // a step whose toDose is HIGHER than its fromDose — a dose increase the
      // generator refuses, leaving the plan unable to produce a schedule.
      await expectOk(
        repository.savePlan(
          TaperPlanDraft(
            drugName: 'Prednisolone',
            startDate: const LocalDate(2026, 4, 1),
            currentDose: mg(10),
            targetDose: mg(5),
            strengths: <Milligrams>[mg(5), mg(1)],
            allowHalves: true,
            method: TaperMethod.dsns,
            stepSize: mg(1),
          ),
        ),
      );

      expectErr<Invariant>(
        await repository.recordFlare(
          on: const LocalDate(2026, 5, 1),
          revertTo: mg(2),
        ),
      );

      // Rolled back whole: no flare row and no extra step.
      final snap = await snapshot();
      expect(snap.flares, isEmpty);
      expect(snap.steps, hasLength(1));
    },
  );

  test(
    'cancelling the snapshot stream cancels its four DAO subscriptions',
    () async {
      // A live drift stream left behind is a "Timer still pending" in the next
      // test and a leak on a screen the user walked away from.
      await expectOk(repository.savePlan(seededDraft()));
      var emissions = 0;
      final sub = repository.watchSnapshot().listen((_) => emissions++);
      await pumpEventQueue();
      final seenWhileListening = emissions;

      await sub.cancel();
      await expectOk(
        repository.markTaken(const LocalDate(2026, 4, 2), plannedMg: mg(10)),
      );
      await pumpEventQueue();

      expect(seenWhileListening, greaterThan(0));
      expect(emissions, seenWhileListening, reason: 'no emission after cancel');
    },
  );

  group('the facts a write must not be able to make unreadable', () {
    // Every case here writes a row `generateSchedule` refuses, in the only
    // copy of the patient's data, and the plan then renders nothing on every
    // screen with no way back but deleting it.
    Future<void> expectGenerates() async {
      final snap = await snapshot();
      expect(
        generateSchedule(
          plan: snap.plan!,
          steps: snap.steps,
          flares: snap.flares,
          holds: snap.holds,
        ),
        isA<Ok<List<DayPlan>, DomainFailure>>(),
      );
    }

    test('moving the plan start moves step 0 with it', () async {
      await expectOk(repository.savePlan(seededDraft()));

      await expectOk(
        repository.updatePlanFacts(
          seededDraft(startDate: const LocalDate(2026, 4, 5)),
        ),
      );

      final snap = await snapshot();
      expect(snap.plan!.startDate, const LocalDate(2026, 4, 5));
      expect(
        snap.steps.first.startDate,
        const LocalDate(2026, 4, 5),
        reason: 'a step left behind fails the generator forever',
      );
      await expectGenerates();
    });

    test('moving the start past the next step is refused', () async {
      await expectOk(repository.savePlan(seededDraft()));
      await expectOk(
        repository.recordFlare(
          on: const LocalDate(2026, 5, 1),
          revertTo: mg(10),
        ),
      );

      expectErr<Invariant>(
        await repository.updatePlanFacts(
          seededDraft(startDate: const LocalDate(2026, 6, 1)),
        ),
      );

      final snap = await snapshot();
      expect(snap.plan!.startDate, const LocalDate(2026, 4, 1));
      expect(snap.steps.first.startDate, const LocalDate(2026, 4, 1));
      await expectGenerates();
    });

    test('a flare on or before the plan start is refused', () async {
      await expectOk(repository.savePlan(seededDraft()));

      for (final on in <LocalDate>[
        const LocalDate(2026, 3, 20),
        const LocalDate(2026, 4, 1),
      ]) {
        expectErr<Invariant>(
          await repository.recordFlare(on: on, revertTo: mg(10)),
        );
      }

      expect((await snapshot()).steps, hasLength(1));
      await expectGenerates();
    });

    test('a hold anchored outside its step is refused', () async {
      // Accepted, it is invisible to the walk that derives the step's length,
      // so `stepStatusFor` and `startNextStep` would disagree about when the
      // step ends and orphan days at the old dose appear in the gap.
      await expectOk(repository.savePlan(seededDraft()));

      for (final from in <LocalDate>[
        const LocalDate(2026, 3, 31), // before it starts
        const LocalDate(2026, 9, 1), // long past its end
      ]) {
        expectErr<Invariant>(
          await repository.recordHold(stepId: 1, from: from, extraDays: 10),
        );
      }

      expect(await db.select(db.holdEvents).get(), isEmpty);
    });
  });

  group("the plan's own arithmetic, not always DSNS's", () {
    test(
      'a fixedMg plan appends its FIXED step, not a suggested one',
      () async {
        // suggestStep is the DSNS rule — largest achievable at or under 10%.
        // Applying it here appends 17.5 -> 16.0 instead of the 2.5mg the
        // clinician wrote down. The app arranges; it does not decide.
        final repo = repoAt(DateTime.utc(2026, 6));
        await expectOk(
          repo.savePlan(
            TaperPlanDraft(
              drugName: 'Prednisolone',
              startDate: const LocalDate(2026, 4, 1),
              currentDose: mg(20),
              targetDose: Milligrams.zero,
              strengths: <Milligrams>[mg(5), mg(1)],
              allowHalves: true,
              method: TaperMethod.fixedMg,
              stepSize: mg(2.5),
              fixedStep: mg(2.5),
            ),
          ),
        );

        await expectOk(repo.startNextStep());

        final steps = await db.stepDao.readSteps(1);
        expect(steps.first.toDose, mg(17.5));
        expect(steps.last.fromDose, mg(17.5));
        expect(steps.last.toDose, mg(15));
      },
    );

    test('a percentage plan appends its PERCENTAGE step', () async {
      final repo = repoAt(DateTime.utc(2026, 6));
      await expectOk(
        repo.savePlan(
          seededDraft(method: TaperMethod.percentage, percentage: 10),
        ),
      );

      await expectOk(repo.startNextStep());

      final steps = await db.stepDao.readSteps(1);
      // 10% of 9mg is 0.9mg; the largest achievable at or under that with
      // 5mg + 1mg and halves is 0.5mg.
      expect(steps.last.fromDose, mg(9));
      expect(steps.last.toDose, mg(8.5));
    });

    test('holdPeriodDays survives a round trip', () async {
      // Without a column it resets to the DSNS 52 on every read, and
      // `nominalStepLength` — whose whole purpose is the non-DSNS arms — reads
      // exactly that field.
      await expectOk(
        repository.savePlan(
          seededDraft(
            method: TaperMethod.percentage,
            percentage: 10,
          ).withHoldPeriod(14),
        ),
      );

      expect((await snapshot()).plan!.holdPeriodDays, 14);
    });
  });

  test(
    'a re-tick after a plan edit does not rewrite what was swallowed',
    () async {
      // `actualMg` is frozen at tick time. Progress sums it and Schedule
      // renders past rows from it, so a later edit must not move a number the
      // patient already acted on.
      await expectOk(repository.savePlan(seededDraft()));
      const day = LocalDate(2026, 4, 2);
      await expectOk(repository.markTaken(day, plannedMg: mg(9)));

      await expectOk(repository.markTaken(day, plannedMg: mg(8.5)));

      final logs = (await snapshot()).logs;
      expect(logs, hasLength(1));
      expect(logs.single.actualMg, mg(9), reason: 'frozen at tick time');
      expect(logs.single.plannedMg, mg(9));
    },
  );

  test('an UN-ticked day does take the new dose when it is ticked', () async {
    // The other arm: freezing must not stop a day being recorded correctly the
    // FIRST time, including after an undo.
    await expectOk(repository.savePlan(seededDraft()));
    const day = LocalDate(2026, 4, 2);
    await expectOk(repository.markTaken(day, plannedMg: mg(9)));
    await expectOk(repository.undoTaken(day));

    await expectOk(repository.markTaken(day, plannedMg: mg(8.5)));

    final logs = (await snapshot()).logs;
    expect(logs.single.actualMg, mg(8.5));
    expect(logs.single.taken, isTrue);
  });

  group('watchSnapshot', () {
    test('emits on subscription and after every mutation', () async {
      final emissions = <TaperSnapshot>[];
      final sub = repository.watchSnapshot().listen((r) {
        if (r case Ok<TaperSnapshot, StorageFailure>(:final value)) {
          emissions.add(value);
        }
      });
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await expectOk(repository.savePlan(seededDraft()));
      await pumpEventQueue();
      await expectOk(
        repository.markTaken(const LocalDate(2026, 4, 2), plannedMg: mg(10)),
      );
      await pumpEventQueue();
      await expectOk(
        repository.recordHold(
          stepId: 1,
          from: const LocalDate(2026, 4, 10),
          extraDays: 2,
        ),
      );
      await pumpEventQueue();

      expect(
        emissions.first.plan,
        isNull,
        reason: 'the fresh-install emission',
      );
      expect(emissions.last.plan, isNotNull);
      expect(emissions.last.logs, hasLength(1));
      expect(emissions.last.holds, hasLength(1));
      expect(
        emissions.map((e) => e.holds.length).toList(),
        containsAllInOrder(<int>[0, 1]),
        reason: 'a hold write re-emits through the join on Steps',
      );
    });

    test(
      'the emitted snapshot IS generateSchedule input, fed straight in',
      () async {
        await expectOk(repository.savePlan(seededDraft()));

        final snap = await snapshot();
        final schedule = generateSchedule(
          plan: snap.plan!,
          steps: snap.steps,
          flares: snap.flares,
          holds: snap.holds,
        );

        expect(schedule, isA<Ok<List<DayPlan>, DomainFailure>>());
        expect(
          (schedule as Ok<List<DayPlan>, DomainFailure>).value,
          isNotEmpty,
        );
      },
    );

    test(
      'statusByStepId is derived: the clock flips it with no write',
      () async {
        await expectOk(repository.savePlan(seededDraft()));
        expect((await snapshot()).statusByStepId[1], StepStatus.active);
        final storedBefore = (await db.select(db.steps).get()).single.status;

        final result = await repoAt(
          DateTime.utc(2026, 6),
        ).watchSnapshot().first;
        final snap = (result as Ok<TaperSnapshot, StorageFailure>).value;

        expect(snap.statusByStepId[1], StepStatus.completed);
        expect(
          (await db.select(db.steps).get()).single.status,
          storedBefore,
          reason: 'the stored column was not touched',
        );
      },
    );
  });
}
