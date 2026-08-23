// StepDao against a real engine.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/db/app_database.dart';

import '../../../support/db_harness.dart';

void main() {
  late AppDatabase db;
  late int planId;

  setUp(() async {
    db = openTestDatabase();
    planId = await seedPlan(db);
  });

  Future<int> insertStep(int index) => seedStep(db, planId, index: index);

  test('nextStepIndex is 0 on an empty table and max + 1 after', () async {
    // A guess here is a straight UNIQUE(planId, stepIndex) violation on the
    // app's most emotionally loaded action.
    expect(await db.stepDao.nextStepIndex(planId), 0);

    for (var i = 0; i < 3; i++) {
      await insertStep(i);
    }

    expect(await db.stepDao.nextStepIndex(planId), 3);
  });

  test('nextStepIndex is max + 1, not count', () async {
    // The two agree until an index is skipped, at which point `count` collides.
    await insertStep(0);
    await insertStep(4);

    expect(await db.stepDao.nextStepIndex(planId), 5);
  });

  test('readSteps answers in stepIndex order, not insertion order', () async {
    await insertStep(1);
    await insertStep(0);

    final steps = await db.stepDao.readSteps(planId);

    expect(steps.map((s) => s.stepIndex).toList(), <int>[0, 1]);
  });

  test('updateStatus writes only the status column', () async {
    final stepId = await insertStep(0);

    await db.stepDao.updateStatus(stepId, StepStatus.completed);

    final step = (await db.stepDao.readSteps(planId)).single;
    expect(step.status, StepStatus.completed);
    expect(step.uid, 'step-0');
    expect(step.fromDose, mg(10));
  });

  test(
    'readHolds joins through Steps to reach a plan-scoped hold',
    () async {
      // HoldEvents has no planId of its own — it hangs off a step — so this
      // join is the only way a plan's holds are found at all.
      final stepId = await insertStep(0);

      await db.stepDao.insertHold(
        HoldEventsCompanion.insert(
          uid: 'hold-1',
          stepId: stepId,
          fromDate: const LocalDate(2026, 4, 10),
          extraDays: 3,
        ),
      );

      final holds = await db.stepDao.readHolds(planId);

      expect(holds, hasLength(1));
      expect(holds.single.extraDays, 3);
    },
  );

  test('watchHolds excludes holds belonging to another plan', () async {
    final mineStepId = await insertStep(0);
    final otherPlanId = await seedPlan(
      db,
      uid: 'plan-2',
      createdAt: DateTime.utc(2026, 1, 2),
    );
    final otherStepId = await seedStep(db, otherPlanId, uid: 'other-step');
    for (final (uid, stepId) in <(String, int)>[
      ('mine', mineStepId),
      ('theirs', otherStepId),
    ]) {
      await db.stepDao.insertHold(
        HoldEventsCompanion.insert(
          uid: uid,
          stepId: stepId,
          fromDate: const LocalDate(2026, 4, 10),
          extraDays: 2,
        ),
      );
    }

    final holds = await db.stepDao.readHolds(planId);

    expect(holds.map((h) => h.uid).toList(), <String>['mine']);
  });

  test('readHoldsForStep narrows to one step', () async {
    // A one-shot read, not a stream: its only caller is `startNextStep`,
    // summing Sigma extraDays inside a transaction that must not observe a
    // later write.
    final first = await insertStep(0);
    final second = await insertStep(1);
    for (final (uid, stepId) in <(String, int)>[('a', first), ('b', second)]) {
      await db.stepDao.insertHold(
        HoldEventsCompanion.insert(
          uid: uid,
          stepId: stepId,
          fromDate: const LocalDate(2026, 4, 10),
          extraDays: 1,
        ),
      );
    }

    final holds = await db.stepDao.readHoldsForStep(second);

    expect(holds.map((h) => h.uid).toList(), <String>['b']);
  });
}
