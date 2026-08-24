// The payload upgrade ladder, exercised before it is needed.
//
// v1.0.0 ships schema **v1** (CONTRACTS §11), so no genuinely older payload
// exists yet and there is no real rung to test. What IS testable — and what
// matters at the first schema bump, on a phone holding 780 days of history —
// is that the machinery runs the rung, refuses when a rung is missing, and
// never silently passes old-shaped rows into a current-schema database.
//
// **This stands in for a real ladder step.** The first genuine one replaces
// the synthetic upgrader below with itself, and this file keeps only the
// missing-rung and empty-ladder cases.
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/features/backup/data/backup_writer.dart';
import 'package:nearlystop/features/backup/data/restore_service.dart';
import 'package:nearlystop/features/backup/domain/payload_upgrades.dart';
import 'package:nearlystop/features/backup/domain/restore_failure.dart';
import 'package:test/test.dart';

import '../../fixtures/hostile_plan.dart';

void main() {
  late Directory workspace;
  late File liveFile;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('nearlystop_ladder');
    liveFile = File('${workspace.path}/nearlystop.sqlite');
  });
  tearDown(() => workspace.deleteSync(recursive: true));

  AppDatabase openLive() => AppDatabase.forTesting(NativeDatabase(liveFile));

  /// A v1 backup of the hostile plan.
  Future<File> v1Backup() async {
    final live = openLive();
    await seedHostilePlan(live);
    final result = await withClock(
      Clock.fixed(DateTime.utc(2025, 4, 16, 8, 30)),
      () => writeBackup(
        database: live,
        directory: workspace,
        appVersion: '1.0.0+1',
        clock: clock,
      ),
    );
    await live.close();
    liveFile.deleteSync();
    return (result as Ok<File, BackupWriteFailure>).value;
  }

  /// A synthetic 1 → 2 rung: renames every drug to a marker.
  ///
  /// Deliberately a change you can SEE in the restored rows. A rung that
  /// returned its input would pass whether it ran or not.
  List<UpgradedRow> renameDrug(List<UpgradedRow> rows) => <UpgradedRow>[
    for (final entry in rows)
      if (entry.table == 'taper_plans')
        (
          table: entry.table,
          row: <String, Object?>{...entry.row, 'drug_name': 'upgraded by v2'},
          line: entry.line,
        )
      else
        entry,
  ];

  group('upgradePayload', () {
    test('a rung runs, and its output is what lands', () async {
      final backup = await v1Backup();

      final result = await restoreBackup(
        file: backup,
        liveDatabaseFile: liveFile,
        stagingDirectory: workspace,
        // The app claims schema 2; the file says 1. One rung to climb.
        appSchemaVersion: 2,
        upgraders: <int, PayloadUpgrader>{1: renameDrug},
      );

      expect(result, isA<Ok<void, RestoreFailure>>());
      final reopened = openLive();
      addTearDown(reopened.close);
      final plan = (await reopened.select(reopened.taperPlans).get()).single;
      expect(plan.drugName, 'upgraded by v2');
    });

    test('a missing rung refuses, and changes nothing', () async {
      // The whole reason the ladder exists. An unmigrated payload inserted
      // into a current-schema database is silent data loss — one column short
      // and a plan that reads plausibly and is wrong.
      final backup = await v1Backup();

      final result = await restoreBackup(
        file: backup,
        liveDatabaseFile: liveFile,
        stagingDirectory: workspace,
        appSchemaVersion: 3,
        upgraders: <int, PayloadUpgrader>{1: renameDrug},
      );

      expect(result, isA<Err<void, RestoreFailure>>());
      expect(liveFile.existsSync(), isFalse, reason: 'it published anyway');
    });

    test('a payload NEWER than the app is refused before any rung', () async {
      // Refused, never guessed: this is what stops somebody on an old build
      // from mangling data a new one wrote.
      final backup = await v1Backup();

      final result = await restoreBackup(
        file: backup,
        liveDatabaseFile: liveFile,
        stagingDirectory: workspace,
        appSchemaVersion: 0,
        upgraders: <int, PayloadUpgrader>{1: renameDrug},
      );

      expect(
        (result as Err<void, RestoreFailure>).failure,
        isA<NewerThanApp>(),
      );
    });

    test('a v1 file into a v1 app climbs nothing at all', () async {
      final backup = await v1Backup();

      final result = await restoreBackup(
        file: backup,
        liveDatabaseFile: liveFile,
        stagingDirectory: workspace,
        appSchemaVersion: 1,
        // Deliberately a rung that would be VISIBLE if it ran.
        upgraders: <int, PayloadUpgrader>{1: renameDrug},
      );

      expect(result, isA<Ok<void, RestoreFailure>>());
      final reopened = openLive();
      addTearDown(reopened.close);
      final plan = (await reopened.select(reopened.taperPlans).get()).single;
      expect(plan.drugName, hostileDrugName);
    });
  });

  test('the shipped ladder is empty exactly while the schema is v1', () {
    // The checklist line, as a test. The first schema bump makes this red, and
    // the only way to make it green again is to write the rung and its
    // fixture — which is the point.
    final schemaVersion = AppDatabase.forTesting(
      NativeDatabase.memory(),
    ).schemaVersion;

    expect(
      kPayloadUpgraders.keys.toList()..sort(),
      <int>[for (var from = 1; from < schemaVersion; from++) from],
      reason: 'a schema bump landed without a payload upgrader',
    );
  });
}
