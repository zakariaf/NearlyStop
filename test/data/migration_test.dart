// The upgrade ceremony, exercised before an upgrade is needed.
//
// A person 400 days into a 780-day taper has no account, no server and no
// cloud backup: the file on their phone is the only copy that exists. The
// assertion that matters here is not "the columns exist after migrating" —
// that passes happily while the data is gone — it is that **every row
// survived with identical values**.
@Tags(<String>['migration'])
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../support/db_harness.dart';
import 'generated_migrations/schema.dart';
import 'migration_fixture/v2_database.dart' as v2;

void main() {
  test('the LIVE schema still matches the committed v1 dump', () async {
    // The assertion that catches a table edited in `tables.dart` after the
    // dump was taken — the failure mode this whole ceremony exists to prevent.
    //
    // The database handed in must be **empty**, so that `onCreate` runs
    // `createAll()` from the live table definitions and the collected schema
    // is the live one. Handing in `verifier.schemaAt(1).newConnection()`
    // instead — the shape the drift docs use for a v1-to-v2 *upgrade* test —
    // makes this compare the committed dump against itself and pass no matter
    // what `tables.dart` says.
    final verifier = SchemaVerifier(GeneratedHelper());
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 1);
  });

  test('the live schema is internally self-consistent', () async {
    // `validateDatabaseSchema` compares what is in `sqlite_master` against
    // what drift would create. It catches a hand-written `customConstraints`
    // string that parses but lands differently from what the Dart side thinks.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await SchemaVerifier(GeneratedHelper()).migrateAndValidate(db, 1);

    await expectLater(db.validateDatabaseSchema(), completes);
  });

  group('the ladder, against the synthetic v2 fixture', () {
    late Directory directory;
    late File file;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('nearlystop_migration');
      file = File('${directory.path}/nearlystop.sqlite');
      addTearDown(() => directory.deleteSync(recursive: true));
    });

    /// Writes a plan, 60 mixed logs (two with notes), a flare and a hold at v1.
    Future<List<DoseLogRow>> seedAtV1() async {
      final db = AppDatabase.forTesting(NativeDatabase(file));
      final planId = await db.planDao.insertPlan(
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
      final stepId = await db.stepDao.insertStep(
        StepsCompanion.insert(
          uid: 'step-0',
          planId: planId,
          stepIndex: 0,
          fromDose: mg(10),
          toDose: mg(9),
          startDate: const LocalDate(2026, 4, 1),
          status: StepStatus.active,
          patternVersion: 1,
        ),
      );
      for (var i = 0; i < 60; i++) {
        await seedLog(
          db,
          planId,
          const LocalDate(2026, 4, 1).addDays(i),
          uid: 'log-$i',
          plannedMg: i.isEven ? mg(10) : mg(9),
          taken: i % 7 != 0,
          takenAt: i % 7 == 0 ? null : fixedNow.add(Duration(days: i)),
          note: switch (i) {
            3 => 'dizzy',
            41 => 'much better',
            _ => null,
          },
        );
      }
      await db.planDao.insertFlare(
        FlareEventsCompanion.insert(
          uid: 'flare-1',
          planId: planId,
          date: const LocalDate(2026, 5, 1),
          revertToDose: mg(10),
          note: const Value<String?>('flared at the wedding'),
        ),
      );
      await db.stepDao.insertHold(
        HoldEventsCompanion.insert(
          uid: 'hold-1',
          stepId: stepId,
          fromDate: const LocalDate(2026, 4, 20),
          extraDays: 3,
        ),
      );
      final logs = await db.logDao.readLogs(planId);
      await db.close();
      return logs;
    }

    test('every row survives the migration with identical values', () async {
      final before = await seedAtV1();

      final upgraded = v2.AppDatabaseV2(NativeDatabase(file));
      addTearDown(upgraded.close);
      final after =
          await (upgraded.select(
                upgraded.doseLogsV2,
              )..orderBy(<OrderClauseGenerator<v2.$DoseLogsV2Table>>[
                (t) => OrderingTerm.asc(t.date),
              ]))
              .get();

      expect(after, hasLength(60));
      expect(before, hasLength(60));
      for (var i = 0; i < 60; i++) {
        final was = before[i];
        final now = after[i];
        expect(now.uid, was.uid, reason: 'row $i uid');
        expect(now.date, was.date, reason: 'row $i date');
        expect(now.plannedMg, was.plannedMg, reason: 'row $i plannedMg');
        expect(now.actualMg, was.actualMg, reason: 'row $i actualMg');
        expect(now.taken, was.taken, reason: 'row $i taken');
        expect(now.takenAt, was.takenAt, reason: 'row $i takenAt');
        expect(now.note, was.note, reason: 'row $i note');
      }
      // And the rows nothing in the ALTER touched.
      expect(await upgraded.select(upgraded.taperPlans).get(), hasLength(1));
      expect(await upgraded.select(upgraded.steps).get(), hasLength(1));
      expect(
        (await upgraded.select(upgraded.flareEvents).get()).single.note,
        'flared at the wedding',
      );
      expect(
        (await upgraded.select(upgraded.holdEvents).get()).single.extraDays,
        3,
      );
    });

    test(
      'the added column is null on every migrated row, and writable',
      () async {
        await seedAtV1();

        final upgraded = v2.AppDatabaseV2(NativeDatabase(file));
        addTearDown(upgraded.close);
        final migrated = await upgraded.select(upgraded.doseLogsV2).get();
        expect(
          migrated.map((r) => r.recordedSource),
          everyElement(isNull),
        );

        await (upgraded.update(
          upgraded.doseLogsV2,
        )..where((t) => t.uid.equals('log-3'))).write(
          const v2.DoseLogsV2Companion(
            recordedSource: Value<String?>('notification'),
          ),
        );

        final row = await (upgraded.select(
          upgraded.doseLogsV2,
        )..where((t) => t.uid.equals('log-3'))).getSingle();
        expect(row.recordedSource, 'notification');
        expect(row.note, 'dizzy', reason: 'the v1 value is still there');
      },
    );

    test('opening a v1 binary against a v2 file fails loudly', () async {
      // The downgrade direction. Silently dropping the unknown column would
      // destroy data the newer build wrote.
      await seedAtV1();
      final upgraded = v2.AppDatabaseV2(NativeDatabase(file));
      await upgraded.select(upgraded.doseLogsV2).get();
      await upgraded.close();

      final downgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(downgraded.close);

      // Drift refuses rather than dropping the column it does not know about,
      // and the refusal comes from the GENERATED ladder — which is also the
      // proof that `stepByStep()` is wired and not merely written down.
      await expectLater(
        downgraded.select(downgraded.doseLogs).get(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('downgrade'), contains('2'), contains('1')),
          ),
        ),
      );
      // And the newer build's data is still on disk, untouched by the refusal.
      final raw = sqlite3.open(file.path);
      addTearDown(raw.dispose);
      expect(raw.select('PRAGMA user_version').single.values.first, 2);
    });
  });
}
