// LogDao against a real engine.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';

import '../../../support/db_harness.dart';

void main() {
  late AppDatabase db;
  late int planId;

  setUp(() async {
    db = openTestDatabase();
    planId = await db.planDao.insertPlan(
      TaperPlansCompanion.insert(
        uid: 'plan-1',
        startDate: const LocalDate(2026, 4, 1),
        startingDose: mg(10),
        targetDose: Milligrams.zero,
        tabletStrengths: <Milligrams>[mg(5), mg(1)],
        allowHalves: true,
        method: TaperMethod.dsns,
        createdAt: DateTime.utc(2026),
      ),
    );
  });

  Future<void> log(LocalDate date, {bool taken = true, String? note}) =>
      db.logDao.upsertLog(
        DoseLogsCompanion.insert(
          uid: 'log-${date.toIso8601()}',
          planId: planId,
          date: date,
          plannedMg: mg(10),
          actualMg: mg(10),
          taken: taken,
          note: Value<String?>(note),
        ),
      );

  test('readLogs answers oldest first', () async {
    for (final day in <int>[16, 9, 21]) {
      await log(LocalDate(2026, 4, day));
    }

    final rows = await db.logDao.readLogs(planId);

    expect(rows.map((r) => r.date.day).toList(), <int>[9, 16, 21]);
  });

  test('readLogs is scoped to its plan', () async {
    await log(const LocalDate(2026, 4, 16));

    expect(await db.logDao.readLogs(planId + 1), isEmpty);
  });

  test(
    'upserting the same date twice leaves one row with the second write',
    () async {
      const date = LocalDate(2026, 4, 16);
      await log(date, note: 'first');
      await log(date, note: 'second', taken: false);

      final rows = await db.logDao.readLogs(planId);

      expect(rows, hasLength(1));
      expect(rows.single.note, 'second');
      expect(rows.single.taken, isFalse);
    },
  );

  test('readLog answers for one date and null for another', () async {
    await log(const LocalDate(2026, 4, 16));

    expect(
      await db.logDao.readLog(planId, const LocalDate(2026, 4, 16)),
      isA<DoseLogRow>(),
    );
    expect(
      await db.logDao.readLog(planId, const LocalDate(2026, 4, 17)),
      isNull,
    );
  });
}
