// The database class, its wiring, and the seam that keeps tests off
// `path_provider`.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/db/database_location.dart';

import '../../support/db_harness.dart';

void main() {
  test('schemaVersion is pinned at 1', () {
    // A literal, not a reference. An accidental bump strands the committed
    // v1 dump and turns a fresh install into a migration.
    expect(openTestDatabase().schemaVersion, 1);
  });

  test('onCreate produces all six tables on an empty database', () async {
    final db = openTestDatabase();
    // "No such table" is what a missing @DriftDatabase entry looks like, and
    // it is indistinguishable from an empty result until you ask.
    expect(await db.select(db.taperPlans).get(), isEmpty);
    expect(await db.select(db.steps).get(), isEmpty);
    expect(await db.select(db.doseLogs).get(), isEmpty);
    expect(await db.select(db.flareEvents).get(), isEmpty);
    expect(await db.select(db.holdEvents).get(), isEmpty);
    expect(await db.select(db.settingsRows).get(), isEmpty);
  });

  test('the location seam composes the file without a plugin binary', () async {
    // No `path_provider` platform channel is registered in this test, which is
    // the entire point of the seam.
    final fake = FakeDatabaseLocation(
      Directory.systemTemp.createTempSync('nearlystop_loc'),
    );
    addTearDown(() => fake.directory.deleteSync(recursive: true));

    final file = await fake();

    expect(file.path, '${fake.directory.path}/nearlystop.sqlite');
    expect(databaseFileName, 'nearlystop.sqlite');
    expect(fake.calls, 1);
  });

  test('the shipping constructor opens the file the location names', () async {
    // The production `AppDatabase(location)` path — `LazyDatabase` plus
    // `createInBackground` — exercised with the fake, so no plugin binary is
    // needed and the wiring is still real. The location must be asked exactly
    // once: `LazyDatabase` resolves lazily and then caches, and re-resolving
    // per query would hit `path_provider` on every read.
    final temp = Directory.systemTemp.createTempSync('nearlystop_shipping');
    addTearDown(() => temp.deleteSync(recursive: true));
    final location = FakeDatabaseLocation(temp);

    final db = AppDatabase(location.call);
    addTearDown(db.close);
    await db.settingsDao.ensureRowExists('settings-1');
    await db.settingsDao.readSettingsOnce();

    expect(location.calls, 1);
    expect(File('${temp.path}/nearlystop.sqlite').existsSync(), isTrue);
  });

  test('bytes survive a close and reopen of the same file', () async {
    // The cheapest possible version of the epic's headline claim: if the
    // `LazyDatabase`/file wiring is wrong, this fails before any repository
    // exists to blame.
    final temp = Directory.systemTemp.createTempSync('nearlystop_reopen');
    addTearDown(() => temp.deleteSync(recursive: true));
    final file = File('${temp.path}/nearlystop.sqlite');

    final first = AppDatabase.forTesting(NativeDatabase(file));
    await first.planDao.insertPlan(
      TaperPlansCompanion.insert(
        uid: 'plan-1',
        startDate: const LocalDate(2026, 4, 1),
        startingDose: mg(10),
        targetDose: Milligrams.zero,
        tabletStrengths: <Milligrams>[mg(5), mg(1)],
        allowHalves: true,
        method: TaperMethod.dsns,
        createdAt: fixedNow,
      ),
    );
    await first.close();

    final second = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(second.close);
    final plan = await second.planDao.readActivePlan();

    expect(plan, isNotNull);
    expect(plan!.uid, 'plan-1');
    expect(plan.startingDose, mg(10));
    expect(plan.startDate, const LocalDate(2026, 4, 1));
  });
}
