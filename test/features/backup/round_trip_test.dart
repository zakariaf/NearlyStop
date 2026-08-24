// Export, wipe, import — and end up with what you started with.
//
// This is the test the whole feature exists to pass. Every other test in the
// epic checks one rung; this one checks that the rungs are a ladder, over a
// hostile fixture rather than a tidy one, because the rows people actually
// have are the ones with commas and quotes and empty notes in them.
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/features/backup/data/backup_writer.dart';
import 'package:nearlystop/features/backup/data/restore_service.dart';
import 'package:nearlystop/features/backup/domain/restore_failure.dart';
import 'package:test/test.dart';

import '../../support/db_harness.dart';

void main() {
  late Directory workspace;
  late File liveFile;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('nearlystop_roundtrip');
    liveFile = File('${workspace.path}/nearlystop.sqlite');
  });
  tearDown(() => workspace.deleteSync(recursive: true));

  AppDatabase openLive() => AppDatabase.forTesting(NativeDatabase(liveFile));

  /// A plan with the awkward values, not the tidy ones.
  Future<void> seedHostile(AppDatabase db) async {
    final planId = await seedPlan(
      db,
      drugName: 'Prednisolon "Actavis", 5mg',
      // A quarter-milligram target, which only survives if doses are stored
      // and encoded as hundredths.
      startingDose: const Milligrams.fromHundredths(1025),
      strengths: const <Milligrams>[
        Milligrams.fromHundredths(500),
        Milligrams.fromHundredths(250),
        Milligrams.fromHundredths(100),
      ],
    );
    await seedStep(db, planId);
    await seedStep(db, planId, index: 1, uid: 'step-1');
    await seedLog(
      db,
      planId,
      const LocalDate(2026, 4, 1),
      uid: 'log-a',
      note: 'felt fine, "no aches"\nslept well',
    );
    await seedLog(db, planId, const LocalDate(2026, 4, 2), uid: 'log-b');
    // A leap day, and a note that is empty rather than absent.
    await seedLog(
      db,
      planId,
      const LocalDate(2024, 2, 29),
      uid: 'log-leap',
      note: '',
    );
  }

  /// Everything the app stores, as comparable values.
  Future<Map<String, Object?>> snapshotOf(AppDatabase db) async => {
    'plans': <Object?>[
      for (final plan in await db.select(db.taperPlans).get())
        <String, Object?>{
          'uid': plan.uid,
          'drug': plan.drugName,
          'start': plan.startDate.toString(),
          'from': plan.startingDose.hundredths,
          'target': plan.targetDose.hundredths,
          'strengths': plan.tabletStrengths.map((s) => s.hundredths).toList(),
          'halves': plan.allowHalves,
          'method': plan.method.name,
          'hold': plan.holdPeriodDays,
          'created': plan.createdAt.toUtc().toIso8601String(),
        },
    ],
    'steps':
        <Object?>[
          for (final step in await db.select(db.steps).get())
            <String, Object?>{
              'uid': step.uid,
              'index': step.stepIndex,
              'from': step.fromDose.hundredths,
              'to': step.toDose.hundredths,
              'start': step.startDate.toString(),
              'status': step.status.name,
            },
        ]..sort(
          (a, b) => '${(a! as Map)['uid']}'.compareTo('${(b! as Map)['uid']}'),
        ),
    'logs':
        <Object?>[
          for (final log in await db.select(db.doseLogs).get())
            <String, Object?>{
              'uid': log.uid,
              'date': log.date.toString(),
              'planned': log.plannedMg.hundredths,
              'actual': log.actualMg.hundredths,
              'taken': log.taken,
              'note': log.note,
            },
        ]..sort(
          (a, b) => '${(a! as Map)['uid']}'.compareTo('${(b! as Map)['uid']}'),
        ),
  };

  Future<File> exportFrom(AppDatabase db) async {
    final result = await withClock(
      Clock.fixed(DateTime.utc(2025, 4, 16, 8, 30)),
      () => writeBackup(
        database: db,
        directory: workspace,
        appVersion: '1.0.0+1',
        clock: clock,
      ),
    );
    return (result as Ok<File, BackupWriteFailure>).value;
  }

  Future<Result<void, RestoreFailure>> importInto(File backup) => restoreBackup(
    file: backup,
    liveDatabaseFile: liveFile,
    stagingDirectory: workspace,
    appSchemaVersion: AppDatabase.forTesting(
      NativeDatabase.memory(),
    ).schemaVersion,
  );

  test('export, wipe, import — and it is the same taper', () async {
    final live = openLive();
    await seedHostile(live);
    final before = await snapshotOf(live);
    final backup = await exportFrom(live);
    await live.close();

    // WIPED, not merged into: the file is deleted outright, which is the
    // "new phone" case this feature is for.
    liveFile.deleteSync();

    final result = await importInto(backup);

    expect(result, isA<Ok<void, RestoreFailure>>());
    final reopened = openLive();
    addTearDown(reopened.close);
    expect(await snapshotOf(reopened), before);
  });

  test('importing the same file twice lands on the same place', () async {
    // Idempotent by construction — restore replaces rather than merges — and
    // worth asserting, because a reader who taps Import twice must not end up
    // with two plans and a schedule that cannot be generated.
    final live = openLive();
    await seedHostile(live);
    final before = await snapshotOf(live);
    final backup = await exportFrom(live);
    await live.close();

    await importInto(backup);
    await importInto(backup);

    final reopened = openLive();
    addTearDown(reopened.close);
    expect(await snapshotOf(reopened), before);
  });

  test('a note with a quote and a newline comes back exactly', () async {
    // NDJSON is line-delimited, so a newline inside a value is the obvious way
    // to split one row into two. JSON escapes it; this is the test that says
    // so rather than assuming it.
    final live = openLive();
    await seedHostile(live);
    final backup = await exportFrom(live);
    await live.close();
    liveFile.deleteSync();

    await importInto(backup);

    final reopened = openLive();
    addTearDown(reopened.close);
    final logs = await reopened.select(reopened.doseLogs).get();
    final restored = logs.firstWhere((l) => l.uid == 'log-a');
    expect(restored.note, 'felt fine, "no aches"\nslept well');
    // Every payload line is still one line.
    final lines = const LineSplitter().convert(backup.readAsStringSync());
    expect(lines.where((l) => l.trim().isNotEmpty).length, lines.length);
  });

  test('a quarter-milligram dose survives, to the hundredth', () async {
    // CONTRACTS §11's regression, end to end: 10.25mg is 1025 hundredths, and
    // any unit confusion in the codec shows up here as 102.5mg or 1.025mg.
    final live = openLive();
    await seedHostile(live);
    final backup = await exportFrom(live);
    await live.close();
    liveFile.deleteSync();

    await importInto(backup);

    final reopened = openLive();
    addTearDown(reopened.close);
    final plan = (await reopened.select(reopened.taperPlans).get()).single;
    expect(plan.startingDose, const Milligrams.fromHundredths(1025));
    expect(
      plan.tabletStrengths.map((s) => s.hundredths).toList()..sort(),
      <int>[100, 250, 500],
    );
  });

  test('a leap day and an empty note both survive', () async {
    final live = openLive();
    await seedHostile(live);
    final backup = await exportFrom(live);
    await live.close();
    liveFile.deleteSync();

    await importInto(backup);

    final reopened = openLive();
    addTearDown(reopened.close);
    final logs = await reopened.select(reopened.doseLogs).get();
    final leap = logs.firstWhere((l) => l.uid == 'log-leap');
    expect(leap.date, const LocalDate(2024, 2, 29));
    expect(
      leap.note,
      '',
      reason: 'an empty note came back as null — a different fact',
    );
  });
}
