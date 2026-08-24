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
import 'package:nearlystop/data/backup/backup_writer.dart';
import 'package:nearlystop/data/backup/restore_service.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/features/backup/domain/backup_envelope.dart';
import 'package:nearlystop/features/backup/domain/restore_failure.dart';
import 'package:test/test.dart';

import '../../fixtures/hostile_plan.dart';

void main() {
  late Directory workspace;
  late File liveFile;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('nearlystop_roundtrip');
    liveFile = File('${workspace.path}/nearlystop.sqlite');
  });
  tearDown(() => workspace.deleteSync(recursive: true));

  AppDatabase openLive() => AppDatabase.forTesting(NativeDatabase(liveFile));

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
    await seedHostilePlan(live);
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
    await seedHostilePlan(live);
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
    await seedHostilePlan(live);
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
    await seedHostilePlan(live);
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
    await seedHostilePlan(live);
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

  test('export, import, export — and the BYTES are identical', () async {
    // The strongest statement the feature can make. With `exportedAtUtc`
    // frozen by the fixed clock, any difference between the two files is a
    // real one: a reordered row, a dropped field, a re-encoded dose.
    final live = openLive();
    await seedHostilePlan(live);
    final first = await exportFrom(live);
    final firstBytes = first.readAsBytesSync();
    await live.close();
    liveFile.deleteSync();

    await importInto(first);
    final reopened = openLive();
    final second = await exportFrom(reopened);
    await reopened.close();

    expect(second.readAsBytesSync(), firstBytes);
  });

  test('a shuffled insertion order produces the same bytes', () async {
    // What `ORDER BY uid` in the writer buys. Without it the file records the
    // order rows happened to be written in, and two phones holding the same
    // taper export two different files.
    final forward = openLive();
    await seedHostilePlan(forward);
    final firstBytes = (await exportFrom(forward)).readAsBytesSync();
    await forward.close();
    liveFile.deleteSync();

    // The same rows, arriving through a restore — which inserts in payload
    // order, not in the order they were originally typed.
    final backup = File('${workspace.path}/replay.ndjson')
      ..writeAsBytesSync(firstBytes);
    await importInto(backup);
    final replayed = openLive();
    final secondBytes = (await exportFrom(replayed)).readAsBytesSync();
    await replayed.close();

    expect(secondBytes, firstBytes);
  });

  test('a double import leaves no duplicate uid in any of the six', () async {
    // The uid is what makes a restore idempotent. A table where COUNT(*) has
    // drifted past COUNT(DISTINCT uid) is a plan the generator will refuse to
    // derive, on a phone whose owner just wanted their history back.
    final live = openLive();
    await seedHostilePlan(live);
    final backup = await exportFrom(live);
    await live.close();

    await importInto(backup);
    await importInto(backup);

    final reopened = openLive();
    addTearDown(reopened.close);
    // Enumerated from drift's own metadata rather than from `kBackupTables`:
    // those are PAYLOAD names (`settings`, not `settings_rows`) and, more to
    // the point, a seventh table added to the schema and forgotten by the
    // backup would still be checked here.
    final tables = <String>[
      for (final table in reopened.allTables)
        if (table.$columns.any((c) => c.name == 'uid')) table.actualTableName,
    ];
    expect(tables, hasLength(kBackupTables.length));

    for (final table in tables) {
      final row = await reopened
          .customSelect(
            'SELECT COUNT(*) AS total, COUNT(DISTINCT uid) AS distinct_uids '
            'FROM $table;',
          )
          .getSingle();
      expect(
        row.data['total'],
        row.data['distinct_uids'],
        reason: '$table has duplicate uids after two imports',
      );
      expect(
        row.data['total'],
        greaterThan(0),
        reason: '$table is empty, so this assertion proves nothing',
      );
    }
  });

  test('the cumulative total and the taken count survive exactly', () async {
    // SPEC §5.2's conservation invariant, end to end. `==` on integer
    // hundredths and never `closeTo`: a total that is off by a hundredth of a
    // milligram is a codec bug, and rounding it away is how it ships.
    final live = openLive();
    await seedHostilePlan(live);
    final before = await _conserved(live);
    final backup = await exportFrom(live);
    await live.close();
    liveFile.deleteSync();

    await importInto(backup);

    final reopened = openLive();
    addTearDown(reopened.close);
    expect(await _conserved(reopened), before);
    // And the fixture actually distinguishes the two numbers — one log is
    // recorded but not taken, so a count that mistook "logged" for "taken"
    // would differ.
    expect(before.takenDays, lessThan(before.loggedDays));
  });
}

/// The two numbers SPEC §5.2 says a restore must not move.
///
/// Read straight out of SQL rather than through the domain, so the assertion
/// is about what is ON DISK rather than about a projection agreeing with
/// itself.
Future<({int cumulativeHundredths, int takenDays, int loggedDays})> _conserved(
  AppDatabase db,
) async {
  final row = await db
      .customSelect(
        'SELECT COALESCE(SUM(CASE WHEN taken THEN actual_mg END), 0) AS total, '
        'COUNT(CASE WHEN taken THEN 1 END) AS taken_days, '
        'COUNT(*) AS logged_days FROM dose_logs;',
      )
      .getSingle();
  return (
    cumulativeHundredths: row.data['total']! as int,
    takenDays: row.data['taken_days']! as int,
    loggedDays: row.data['logged_days']! as int,
  );
}
