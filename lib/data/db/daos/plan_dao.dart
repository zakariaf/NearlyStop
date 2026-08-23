/// Queries over the plan aggregate.
library;

import 'package:drift/drift.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/db/tables.dart';

part 'plan_dao.g.dart';

/// The only door to SQL for [TaperPlans] and [FlareEvents].
///
/// Drift's stream invalidation is **table-based**: a `.watch()` re-emits when
/// any table its query reads is written. That is not magic and it is what the
/// repository's combined snapshot relies on, so nothing here ever polls.
@DriftAccessor(tables: <Type>[TaperPlans, FlareEvents])
class PlanDao extends DatabaseAccessor<AppDatabase> with _$PlanDaoMixin {
  /// Creates the DAO over [db].
  PlanDao(super.attachedDatabase);

  /// The single active plan, read once.
  Future<TaperPlanRow?> readActivePlan() =>
      (select(taperPlans)
            ..orderBy(<OrderClauseGenerator<$TaperPlansTable>>[
              (t) => OrderingTerm.desc(t.createdAt),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// How many plans exist. v1 permits at most one.
  Future<int> countPlans() async => (await select(taperPlans).get()).length;

  /// Inserts a plan and returns its row id.
  Future<int> insertPlan(TaperPlansCompanion plan) =>
      into(taperPlans).insert(plan);

  /// Updates the plan row in place.
  Future<void> updatePlan(int id, TaperPlansCompanion plan) async {
    await (update(
      taperPlans,
    )..where((t) => t.id.equals(id))).write(plan);
  }

  /// Deletes the plan; the cascades take its steps, logs, flares and holds.
  Future<void> deletePlan(int id) async {
    await (delete(
      taperPlans,
    )..where((t) => t.id.equals(id))).go();
  }

  /// Every flare on [planId], oldest first, read once.
  Future<List<FlareEventRow>> readFlares(int planId) =>
      (select(flareEvents)
            ..where((t) => t.planId.equals(planId))
            ..orderBy(<OrderClauseGenerator<$FlareEventsTable>>[
              (t) => OrderingTerm.asc(t.date),
            ]))
          .get();

  /// Appends a flare.
  Future<void> insertFlare(FlareEventsCompanion flare) async {
    await into(flareEvents).insert(flare);
  }
}
