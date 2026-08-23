// PlanDao against a real engine.
// `isNull` is a drift query builder AND a matcher; the matcher is the one
// this file wants.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';

import '../../../support/db_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());

  Future<int> insertPlan(String uid, int createdAt) => db.planDao.insertPlan(
    TaperPlansCompanion.insert(
      uid: uid,
      startDate: const LocalDate(2026, 4, 1),
      startingDose: mg(10),
      targetDose: Milligrams.zero,
      tabletStrengths: <Milligrams>[mg(5), mg(1)],
      allowHalves: true,
      method: TaperMethod.dsns,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
    ),
  );

  test(
    'readActivePlan answers null on an empty table, then the plan',
    () async {
      // `getSingleOrNull`, not `getSingle`: zero rows is the fresh-install and
      // post-delete state, not an error. `getSingle` throws here, and the first
      // thing a new user sees is a crash.
      expect(await db.planDao.readActivePlan(), isNull);

      await insertPlan('plan-1', 0);

      expect((await db.planDao.readActivePlan())?.uid, 'plan-1');
    },
  );

  test('with two plans 1ms apart, the later createdAt wins', () async {
    await insertPlan('older', 1776000000000);
    await insertPlan('newer', 1776000000001);

    final plan = await db.planDao.readActivePlan();

    expect(plan!.uid, 'newer');
  });

  test('countPlans counts, and deletePlan takes the row', () async {
    final id = await insertPlan('plan-1', 0);
    expect(await db.planDao.countPlans(), 1);

    await db.planDao.deletePlan(id);

    expect(await db.planDao.countPlans(), 0);
    expect(await db.planDao.readActivePlan(), isNull);
  });

  test('updatePlan writes only the fields the patch names', () async {
    final id = await insertPlan('plan-1', 0);

    await db.planDao.updatePlan(
      id,
      TaperPlansCompanion(targetDose: Value<Milligrams>(mg(2))),
    );

    final plan = await db.planDao.readActivePlan();
    expect(plan!.targetDose, mg(2));
    expect(plan.startingDose, mg(10), reason: 'untouched by the patch');
    expect(plan.uid, 'plan-1', reason: 'identity survives an edit');
  });

  test(
    'readFlares answers oldest first, whatever order they were written',
    () async {
      final planId = await insertPlan('plan-1', 0);

      for (final day in <int>[7, 3]) {
        await db.planDao.insertFlare(
          FlareEventsCompanion.insert(
            uid: 'flare-$day',
            planId: planId,
            date: LocalDate(2026, 5, day),
            revertToDose: mg(10),
          ),
        );
      }

      expect(
        (await db.planDao.readFlares(planId)).map((r) => r.date).toList(),
        <LocalDate>[const LocalDate(2026, 5, 3), const LocalDate(2026, 5, 7)],
      );
    },
  );
}
