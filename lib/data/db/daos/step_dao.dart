/// Queries over the step aggregate.
library;

import 'package:drift/drift.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/db/tables.dart';

part 'step_dao.g.dart';

/// The only door to SQL for [Steps] and [HoldEvents].
@DriftAccessor(tables: <Type>[Steps, HoldEvents])
class StepDao extends DatabaseAccessor<AppDatabase> with _$StepDaoMixin {
  /// Creates the DAO over [db].
  StepDao(super.attachedDatabase);

  /// Every step of [planId], read once.
  Future<List<StepRow>> readSteps(int planId) =>
      (select(steps)
            ..where((t) => t.planId.equals(planId))
            ..orderBy(<OrderClauseGenerator<$StepsTable>>[
              (t) => OrderingTerm.asc(t.stepIndex),
            ]))
          .get();

  /// The next free `stepIndex` for [planId] — `max(stepIndex) + 1`, or 0.
  ///
  /// Called from **inside** the caller's transaction. Both `recordFlare` and
  /// `startNextStep` need it, and a guess is a straight `UNIQUE(planId,
  /// stepIndex)` violation on the most emotionally loaded action in the app.
  /// A SQL `MAX`, not a fold over decoded rows: this runs inside the caller's
  /// write transaction, and decoding every step through every converter to
  /// read one integer means an unreadable column can abort a write that only
  /// needed a number.
  Future<int> nextStepIndex(int planId) async {
    final highest = steps.stepIndex.max();
    final row =
        await (selectOnly(steps)
              ..addColumns(<Expression<Object>>[highest])
              ..where(steps.planId.equals(planId)))
            .getSingle();
    // NULL on an empty table — `max()` over no rows, not a missing column.
    return (row.read(highest) ?? -1) + 1;
  }

  /// Inserts a step and returns its row id.
  Future<int> insertStep(StepsCompanion step) => into(steps).insert(step);

  /// Writes a step's stored status.
  ///
  /// **Exactly two callers**: `recordFlare` marks the truncated step
  /// `abandoned`, and `startNextStep` marks the finished one `completed`. Every
  /// other read of "is this step done" goes through EPIC-04's pure
  /// `stepStatusFor` — the column is a record of events, not a derived cache
  /// something has to keep fresh.
  Future<void> updateStatus(int stepId, StepStatus status) async {
    await (update(steps)..where((t) => t.id.equals(stepId))).write(
      StepsCompanion(status: Value<StepStatus>(status)),
    );
  }

  /// Re-anchors a step's start date.
  ///
  /// **One caller**: `updatePlanFacts`, when the plan's own start date moves
  /// and the first step has to move with it or the generator's
  /// `steps.first.startDate == plan.startDate` precondition fails forever.
  Future<void> updateStartDate(int stepId, LocalDate startDate) async {
    await (update(steps)..where((t) => t.id.equals(stepId))).write(
      StepsCompanion(startDate: Value<LocalDate>(startDate)),
    );
  }

  /// Every hold belonging to any step of [planId], read once.
  Future<List<HoldEventRow>> readHolds(int planId) async {
    final query = select(holdEvents).join(<Join<HasResultSet, dynamic>>[
      innerJoin(steps, steps.id.equalsExp(holdEvents.stepId)),
    ])..where(steps.planId.equals(planId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(holdEvents)).toList();
  }

  /// Every hold on one step.
  Future<List<HoldEventRow>> readHoldsForStep(int stepId) => (select(
    holdEvents,
  )..where((t) => t.stepId.equals(stepId))).get();

  /// Appends a hold.
  Future<void> insertHold(HoldEventsCompanion hold) async {
    await into(holdEvents).insert(hold);
  }
}
