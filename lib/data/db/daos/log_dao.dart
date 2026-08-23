/// Queries over the dose log.
library;

import 'package:drift/drift.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/db/tables.dart';

part 'log_dao.g.dart';

/// The only door to SQL for [DoseLogs].
@DriftAccessor(tables: <Type>[DoseLogs])
class LogDao extends DatabaseAccessor<AppDatabase> with _$LogDaoMixin {
  /// Creates the DAO over [db].
  LogDao(super.attachedDatabase);

  /// Every log for [planId], oldest first, read once.
  Future<List<DoseLogRow>> readLogs(int planId) =>
      (select(doseLogs)
            ..where((t) => t.planId.equals(planId))
            ..orderBy(<OrderClauseGenerator<$DoseLogsTable>>[
              (t) => OrderingTerm.asc(t.date),
            ]))
          .get();

  /// The log for one date, if there is one.
  Future<DoseLogRow?> readLog(int planId, LocalDate date) =>
      (select(doseLogs)..where(
            (t) => t.planId.equals(planId) & t.date.equals(date.toIso8601()),
          ))
          .getSingleOrNull();

  /// Inserts or updates the row for `(planId, date)`.
  ///
  /// Ticking twice and backfilling three days late are both this one call,
  /// against the `UNIQUE(plan_id, date)` index — never a read-modify-write.
  ///
  /// The conflict target is spelled out. `insertOnConflictUpdate` targets the
  /// PRIMARY KEY, and the second tick of the same day carries no `id`, so it
  /// arrives as a fresh insert and hits the unique index instead of updating.
  /// The `uid` is excluded from the update so the row keeps the identity it
  /// was first written with — EPIC-13's backup joins on it.
  Future<void> upsertLog(DoseLogsCompanion log) async {
    await into(doseLogs).insert(
      log,
      onConflict: DoUpdate<$DoseLogsTable, DoseLogRow>(
        (_) => log.copyWith(uid: const Value<String>.absent()),
        target: <Column<Object>>[doseLogs.planId, doseLogs.date],
      ),
    );
  }
}
