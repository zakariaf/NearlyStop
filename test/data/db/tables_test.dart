// Against a REAL in-memory engine. Constraints, cascades and pragmas are
// exactly what a mocked DAO cannot have, and every one of them below is a rule
// the app relies on being unbreakable rather than merely policed in Dart.
// `isNull` is a drift query builder AND a matcher; the matcher is the one this
// file wants.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../../support/db_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());

  Future<int> insertPlan({String uid = 'plan-1', int createdAt = 0}) =>
      seedPlan(
        db,
        uid: uid,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
      );

  Future<int> insertStep(int planId, {int index = 0, String uid = 'step-1'}) =>
      seedStep(db, planId, index: index, uid: uid);

  test('foreign_keys is ON — every cascade below is decorative without it', () {
    // SQLite defaults it to 0 PER CONNECTION and silently no-ops FK actions.
    expect(pragmaValue(db, 'foreign_keys'), completion(1));
  });

  test('deleting a plan takes its steps, logs, flares and — through Steps — '
      'its holds', () async {
    final planId = await insertPlan();
    final stepId = await insertStep(planId);
    await insertStep(planId, index: 1, uid: 'step-2');
    for (var i = 0; i < 3; i++) {
      await seedLog(db, planId, LocalDate(2026, 4, i + 1), uid: 'log-$i');
    }
    await db.planDao.insertFlare(
      FlareEventsCompanion.insert(
        uid: 'flare-1',
        planId: planId,
        date: const LocalDate(2026, 4, 5),
        revertToDose: mg(10),
      ),
    );
    await db.stepDao.insertHold(
      HoldEventsCompanion.insert(
        uid: 'hold-1',
        stepId: stepId,
        fromDate: const LocalDate(2026, 4, 3),
        extraDays: 3,
      ),
    );

    await db.planDao.deletePlan(planId);

    expect(await db.select(db.taperPlans).get(), isEmpty);
    expect(await db.select(db.steps).get(), isEmpty);
    expect(await db.select(db.doseLogs).get(), isEmpty);
    expect(await db.select(db.flareEvents).get(), isEmpty);
    // The second hop: HoldEvents cascades through Steps, which a single-level
    // cascade silently misses.
    expect(await db.select(db.holdEvents).get(), isEmpty);
  });

  test('every table refuses a duplicate uid', () async {
    final planId = await insertPlan();
    final stepId = await insertStep(planId);

    Future<void> expectDuplicate(String label, Future<void> Function() write) =>
        expectLater(write(), throwsA(isA<SqliteException>()), reason: label);

    await expectDuplicate('TaperPlans', () => insertPlan(createdAt: 1));
    await expectDuplicate('Steps', () => insertStep(planId, index: 9));
    await seedLog(db, planId, const LocalDate(2026, 4, 1), uid: 'log-1');
    await expectDuplicate(
      'DoseLogs',
      () => db
          .into(db.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              uid: 'log-1',
              planId: planId,
              date: const LocalDate(2026, 4, 2),
              plannedMg: mg(10),
              actualMg: mg(10),
              taken: true,
            ),
          ),
    );
    await db.planDao.insertFlare(
      FlareEventsCompanion.insert(
        uid: 'flare-1',
        planId: planId,
        date: const LocalDate(2026, 4, 5),
        revertToDose: mg(10),
      ),
    );
    await expectDuplicate(
      'FlareEvents',
      () => db.planDao.insertFlare(
        FlareEventsCompanion.insert(
          uid: 'flare-1',
          planId: planId,
          date: const LocalDate(2026, 4, 6),
          revertToDose: mg(10),
        ),
      ),
    );
    await db.stepDao.insertHold(
      HoldEventsCompanion.insert(
        uid: 'hold-1',
        stepId: stepId,
        fromDate: const LocalDate(2026, 4, 3),
        extraDays: 1,
      ),
    );
    await expectDuplicate(
      'HoldEvents',
      () => db.stepDao.insertHold(
        HoldEventsCompanion.insert(
          uid: 'hold-1',
          stepId: stepId,
          fromDate: const LocalDate(2026, 4, 4),
          extraDays: 1,
        ),
      ),
    );
    await db.settingsDao.ensureRowExists('settings-1');
    await expectDuplicate(
      'SettingsRows',
      () => db
          .into(db.settingsRows)
          .insert(
            SettingsRowsCompanion.insert(
              id: const Value<int>(1),
              uid: 'settings-1',
            ),
          ),
    );
  });

  test('no table accepts a row without a uid', () async {
    // Raw SQL, because the Dart companions make `uid` required and so cannot
    // express the omission. EPIC-13's backup format joins on these ids: a
    // nullable one would be a row that cannot survive an export/import round
    // trip, and NOT NULL in the DDL is the only thing that rules it out.
    final planId = await insertPlan();
    final stepId = await insertStep(planId);
    final inserts = <String, String>{
      'taper_plans':
          'INSERT INTO taper_plans (start_date, starting_dose, target_dose, '
          'tablet_strengths, allow_halves, method, created_at) '
          "VALUES ('2026-04-01', 1000, 0, '500,100', 1, 'dsns', 0)",
      'steps':
          'INSERT INTO steps (plan_id, step_index, from_dose, to_dose, '
          'start_date, status, pattern_version) '
          "VALUES ($planId, 7, 1000, 900, '2026-04-01', 'active', 1)",
      'dose_logs':
          'INSERT INTO dose_logs (plan_id, date, planned_mg, actual_mg, taken) '
          "VALUES ($planId, '2026-07-01', 1000, 1000, 1)",
      'flare_events':
          'INSERT INTO flare_events (plan_id, date, revert_to_dose) '
          "VALUES ($planId, '2026-07-01', 1000)",
      'hold_events':
          'INSERT INTO hold_events (step_id, from_date, extra_days) '
          "VALUES ($stepId, '2026-07-01', 2)",
      'settings_rows': 'INSERT INTO settings_rows (id) VALUES (0)',
    };

    for (final entry in inserts.entries) {
      await expectLater(
        db.customStatement(entry.value),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('NOT NULL'),
          ),
        ),
        reason:
            '${entry.key} — a syntax error would also throw, so the '
            'message has to name the constraint',
      );
    }
  });

  test('UNIQUE(planId, date) makes ticking idempotent', () async {
    final planId = await insertPlan();
    for (var i = 0; i < 2; i++) {
      await seedLog(
        db,
        planId,
        const LocalDate(2026, 4, 1),
        uid: 'log-1',
        taken: i == 1,
      );
    }
    final rows = await db.select(db.doseLogs).get();
    expect(rows, hasLength(1));
    expect(rows.single.taken, isTrue);
  });

  test('UNIQUE(planId, stepIndex) parses AND refuses a duplicate', () async {
    // If the hand-written constraint were `UNIQUE(plan_id, index)` — `index` is
    // a reserved keyword — createAll() would have thrown before any assertion
    // in this file ran.
    final planId = await insertPlan();
    await insertStep(planId);
    await expectLater(
      db.stepDao.insertStep(
        StepsCompanion.insert(
          uid: 'step-2',
          planId: planId,
          stepIndex: 0,
          fromDose: mg(10),
          toDose: mg(9),
          startDate: const LocalDate(2026, 4, 1),
          status: StepStatus.active,
          patternVersion: 1,
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('CHECK(extraDays > 0) refuses a zero- or negative-day hold', () async {
    final planId = await insertPlan();
    final stepId = await insertStep(planId);
    for (final days in <int>[0, -1]) {
      await expectLater(
        db.stepDao.insertHold(
          HoldEventsCompanion.insert(
            uid: 'hold-$days',
            stepId: stepId,
            fromDate: const LocalDate(2026, 4, 3),
            extraDays: days,
          ),
        ),
        throwsA(isA<SqliteException>()),
        reason: 'extraDays=$days',
      );
    }
    await db.stepDao.insertHold(
      HoldEventsCompanion.insert(
        uid: 'hold-ok',
        stepId: stepId,
        fromDate: const LocalDate(2026, 4, 3),
        extraDays: 1,
      ),
    );
    expect(await db.select(db.holdEvents).get(), hasLength(1));
  });

  test('CHECK(id = 0) stops the settings table growing a second row', () async {
    await db.settingsDao.ensureRowExists('settings-0');
    await expectLater(
      db
          .into(db.settingsRows)
          .insert(
            SettingsRowsCompanion.insert(id: const Value<int>(1), uid: 'other'),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('the column shapes are what the storage rules claim', () async {
    final planId = await insertPlan(createdAt: 1776000000000);
    final raw = await db
        .customSelect(
          'SELECT starting_dose, start_date, created_at, percentage '
          'FROM taper_plans WHERE id = ?',
          variables: <Variable<Object>>[Variable<int>(planId)],
        )
        .getSingle();
    // A dose is an INTEGER of hundredths, never a REAL.
    expect(raw.data['starting_dose'], 1000);
    expect(raw.data['starting_dose'], isA<int>());
    // A calendar date is TEXT, never a timestamp.
    expect(raw.data['start_date'], '2026-04-01');
    // An instant is UTC epoch ms.
    expect(raw.data['created_at'], 1776000000000);
    // percentage is the one genuine REAL in the schema, and it is not a dose.
    expect(raw.data['percentage'], isNull);
  });
}
