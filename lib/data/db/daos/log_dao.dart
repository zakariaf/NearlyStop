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

  /// Inserts the `(planId, date)` row, or updates **only** the columns
  /// [onConflict] names.
  ///
  /// Ticking twice and backfilling three days late are both this one call
  /// against the `UNIQUE(plan_id, date)` index — never a read-modify-write.
  ///
  /// The conflict target is spelled out because `insertOnConflictUpdate`
  /// targets the PRIMARY KEY, and the second tick of the same day carries no
  /// `id`: it arrives as a fresh insert and hits the unique index instead of
  /// updating.
  ///
  /// Splitting the two companions is what keeps the caller from having to read
  /// the row first and echo every field back. A column absent from
  /// [onConflict] is left exactly as it was — which is how a tick preserves the
  /// note, a note preserves the dose, and both preserve the `uid` that
  /// EPIC-13's backup joins on.
  Future<void> upsertLog(
    DoseLogsCompanion fresh, {
    required DoseLogsCompanion onConflict,
  }) async {
    await into(doseLogs).insert(
      fresh,
      onConflict: DoUpdate<$DoseLogsTable, DoseLogRow>(
        (_) => onConflict,
        target: <Column<Object>>[doseLogs.planId, doseLogs.date],
      ),
    );
  }

  /// Un-ticks `(planId, date)`, preserving the row and everything else on it.
  ///
  /// A plain UPDATE, not a delete and not an upsert: a date with no row has
  /// nothing to undo, and deleting would silently destroy a note the patient
  /// wrote on the same day.
  Future<void> clearTaken(int planId, LocalDate date) async {
    await (update(doseLogs)..where(
          (t) => t.planId.equals(planId) & t.date.equals(date.toIso8601()),
        ))
        .write(
          const DoseLogsCompanion(
            taken: Value<bool>(false),
            takenAt: Value<DateTime?>(null),
          ),
        );
  }
}
