// LogDao against a real engine.
import 'package:flutter_test/flutter_test.dart';
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

  Future<void> log(LocalDate date, {bool taken = true, String? note}) =>
      seedLog(db, planId, date, taken: taken, note: note);

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
}
