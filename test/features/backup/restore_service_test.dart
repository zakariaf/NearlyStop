// Restore: an all-or-nothing import that cannot damage the live database.
//
// Against REAL database files in a temp directory, never a mocked DAO — a fake
// proves nothing about WAL, sidecars or transactions, and those are exactly
// where this goes wrong. Every refusal case ends by asserting the live file's
// SHA-256 is what it was before: "it refused" and "it refused without touching
// anything" are different claims, and only the second one matters to somebody
// 400 days into a taper.
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/features/backup/data/backup_writer.dart';
import 'package:nearlystop/features/backup/data/restore_service.dart';
import 'package:nearlystop/features/backup/domain/backup_envelope.dart';
import 'package:nearlystop/features/backup/domain/restore_failure.dart';
import 'package:test/test.dart';

import '../../support/db_harness.dart';

void main() {
  late Directory workspace;
  late File liveFile;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('nearlystop_restore');
    liveFile = File('${workspace.path}/nearlystop.sqlite');
  });
  tearDown(() => workspace.deleteSync(recursive: true));

  /// The live database, opened over a real file.
  AppDatabase openLive() => AppDatabase.forTesting(NativeDatabase(liveFile));

  /// Seeds a plan and a couple of logs into [db].
  Future<void> seed(AppDatabase db, {String drugName = 'Prednisolone'}) async {
    final planId = await seedPlan(db, drugName: drugName);
    await seedStep(db, planId);
    await seedLog(db, planId, const LocalDate(2026, 4, 1), uid: 'log-a');
    await seedLog(db, planId, const LocalDate(2026, 4, 2), uid: 'log-b');
  }

  /// A valid backup file written from a throwaway database.
  Future<File> makeBackup({String drugName = 'Restored'}) async {
    final source = AppDatabase.forTesting(
      NativeDatabase(File('${workspace.path}/source.sqlite')),
    );
    await seed(source, drugName: drugName);
    final result = await withClock(
      Clock.fixed(DateTime.utc(2025, 4, 16, 8, 30)),
      () => writeBackup(
        database: source,
        directory: workspace,
        appVersion: '1.0.0+1',
        clock: clock,
      ),
    );
    await source.close();
    return (result as Ok<File, BackupWriteFailure>).value;
  }

  /// The live file's digest, for "byte-unchanged" assertions.
  String liveDigest() => sha256.convert(liveFile.readAsBytesSync()).toString();

  /// Runs a restore of [file] over the live database.
  Future<Result<void, RestoreFailure>> restore(
    File file, {
    Future<void> Function(AppDatabase)? verifyPublished,
  }) => restoreBackup(
    file: file,
    liveDatabaseFile: liveFile,
    stagingDirectory: workspace,
    appSchemaVersion: AppDatabase.forTesting(
      NativeDatabase.memory(),
    ).schemaVersion,
    verifyPublished: verifyPublished,
  );

  /// Sets up a live database with contents, closed and checkpointed.
  Future<void> prepareLive() async {
    final live = openLive();
    await seed(live, drugName: 'Original');
    await live.close();
  }

  group('it refuses without touching the live database', () {
    test('a file whose first line is not JSON', () async {
      await prepareLive();
      final before = liveDigest();
      final file = File('${workspace.path}/notes.txt')
        ..writeAsStringSync('this is my shopping list\nmilk\n');

      final result = await restore(file);

      expect(
        (result as Err<void, RestoreFailure>).failure,
        isA<NotABackupFile>(),
      );
      expect(liveDigest(), before);
    });

    test('a CSV and a PDF, fed straight to restore', () async {
      // Restore refusing the doctor exports is a rule, so it is a test: the
      // two are produced by this same app, land in the same folder, and are
      // exactly what somebody will pick by mistake.
      await prepareLive();
      final before = liveDigest();
      final csv = File('${workspace.path}/nearlystop-doses.csv')
        ..writeAsStringSync('date,dose_mg,taken\n2026-04-01,10,true\n');
      final pdf = File('${workspace.path}/nearlystop-summary.pdf')
        ..writeAsBytesSync(<int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]);

      for (final file in <File>[csv, pdf]) {
        final result = await restore(file);
        expect(
          (result as Err<void, RestoreFailure>).failure,
          isA<NotABackupFile>(),
          reason: file.path,
        );
      }
      expect(liveDigest(), before);
    });

    test('an envelope from a newer FORMAT', () async {
      await prepareLive();
      final before = liveDigest();
      final file = await _rewriteHeader(
        await makeBackup(),
        (header) => BackupHeader(
          formatVersion: header.formatVersion + 1,
          schemaVersion: header.schemaVersion,
          appVersion: header.appVersion,
          exportedAtUtc: header.exportedAtUtc,
          payloadSha256: header.payloadSha256,
        ),
      );

      final result = await restore(file);

      expect(
        (result as Err<void, RestoreFailure>).failure,
        isA<UnsupportedFormat>(),
      );
      expect(liveDigest(), before);
    });

    test('a payload from a newer SCHEMA — refused, never guessed', () async {
      // The rule that stops somebody on an old build from silently mangling
      // data a new one wrote. No staging file is created either: refusing
      // before staging is an ordering claim and gets its own assertion.
      await prepareLive();
      final before = liveDigest();
      final file = await _rewriteHeader(
        await makeBackup(),
        (header) => BackupHeader(
          formatVersion: header.formatVersion,
          schemaVersion: header.schemaVersion + 1,
          appVersion: header.appVersion,
          exportedAtUtc: header.exportedAtUtc,
          payloadSha256: header.payloadSha256,
        ),
      );

      final result = await restore(file);

      expect(
        (result as Err<void, RestoreFailure>).failure,
        isA<NewerThanApp>(),
      );
      expect(liveDigest(), before);
      expect(_stagingFiles(workspace), isEmpty);
    });

    test('one flipped payload byte', () async {
      await prepareLive();
      final before = liveDigest();
      final backup = await makeBackup();
      final lines = const LineSplitter().convert(backup.readAsStringSync());
      // A note nobody would notice by eye, and the digest catches anyway.
      lines[1] = lines[1].replaceFirst('Restored', 'Restorod');
      backup.writeAsStringSync('${lines.join('\n')}\n');

      final result = await restore(backup);

      expect(
        (result as Err<void, RestoreFailure>).failure,
        isA<CorruptedBackup>(),
      );
      expect(liveDigest(), before);
      expect(
        _stagingFiles(workspace),
        isEmpty,
        reason: 'the digest is verified BEFORE anything is staged',
      );
    });

    test('a row missing a required column, named by table and line', () async {
      await prepareLive();
      final before = liveDigest();
      final backup = await makeBackup();
      final lines = const LineSplitter().convert(backup.readAsStringSync());
      final logIndex = lines.indexWhere((l) => l.contains('"dose_logs"'));
      expect(logIndex, greaterThan(0), reason: 'no dose_logs line to break');
      lines[logIndex] = payloadLine('dose_logs', <String, Object?>{
        'uid': 'log-a',
        // `date` is gone. A row this app cannot read is a refusal that names
        // where, because "the backup is malformed" is not actionable.
        'planned_hundredths_mg': 1000,
      });
      await _rewriteWithDigest(backup, lines);

      final result = await restore(backup);

      final failure = (result as Err<void, RestoreFailure>).failure;
      expect(failure, isA<MalformedPayload>());
      expect((failure as MalformedPayload).table, 'dose_logs');
      expect(failure.line, logIndex + 1);
      expect(liveDigest(), before);
    });
  });

  group('it publishes', () {
    test(
      'replace-all: the live rows are gone, the file’s rows are there',
      () async {
        await prepareLive();
        final backup = await makeBackup();

        final result = await restore(backup);

        expect(result, isA<Ok<void, RestoreFailure>>());
        final live = openLive();
        addTearDown(live.close);
        final plans = await live.select(live.taperPlans).get();
        expect(plans, hasLength(1));
        expect(
          plans.single.drugName,
          'Restored',
          reason: 'the live plan survived — this is a merge, not a replace',
        );
      },
    );

    test('WAL-safely: no stale sidecar, and integrity_check says ok', () async {
      // The live database runs in WAL mode, so it is up to three files.
      // Renaming only the main one leaves the PREVIOUS database's `-wal` beside
      // the new file, and on reopen SQLite either replays foreign frames —
      // resurrecting pre-restore rows — or refuses to open. A happy-path test
      // passes either way; this one does not.
      final live = openLive();
      await seed(live, drugName: 'Original');
      // Leave a non-empty WAL behind: a write with no checkpoint.
      await seedLog(live, 1, const LocalDate(2026, 4, 3), uid: 'log-c');
      await live.close();
      final wal = File('${liveFile.path}-wal');
      final backup = await makeBackup();

      final result = await restore(backup);

      expect(result, isA<Ok<void, RestoreFailure>>());
      expect(
        wal.existsSync() && wal.lengthSync() > 0,
        isFalse,
        reason: 'a stale -wal survived beside the published file',
      );
      final reopened = openLive();
      addTearDown(reopened.close);
      final check = await reopened
          .customSelect('PRAGMA integrity_check;')
          .getSingle();
      expect(check.data.values.first, 'ok');
      final plans = await reopened.select(reopened.taperPlans).get();
      expect(plans.single.drugName, 'Restored');
    });

    test('a failure AFTER the rename puts all three files back', () async {
      // The one branch whose whole job is "put two years back". Without the
      // sidecars in the rollback set, the previous database's `-wal` is gone
      // and the restored main file is missing every frame it held — a plan
      // that opens and is quietly out of date.
      final live = openLive();
      await seed(live, drugName: 'Original');
      await seedLog(live, 1, const LocalDate(2026, 4, 3), uid: 'log-c');
      await live.close();
      final before = liveDigest();
      final backup = await makeBackup();

      final result = await restore(
        backup,
        verifyPublished: (_) async => throw StateError('injected'),
      );

      expect(
        (result as Err<void, RestoreFailure>).failure,
        isA<PublishFailed>(),
      );
      final reopened = openLive();
      addTearDown(reopened.close);
      final plans = await reopened.select(reopened.taperPlans).get();
      expect(plans.single.drugName, 'Original');
      final logs = await reopened.select(reopened.doseLogs).get();
      expect(
        logs.map((l) => l.uid),
        contains('log-c'),
        reason: 'the row that only lived in the -wal is gone',
      );
      await reopened.close();
      expect(
        _stagingFiles(workspace),
        isEmpty,
        reason: 'a rollback file survived a completed rollback',
      );
      expect(
        liveDigest(),
        before,
        reason: 'a rolled-back publish must leave the file byte-unchanged',
      );
    });

    test('a -wal left by a crash does not survive the publish', () async {
      // A closed database has no `-wal`: `close()` checkpoints and removes it.
      // A database whose process was KILLED does, and that is the state this
      // path has to survive. Renaming only the main file leaves that `-wal`
      // beside the new one, and SQLite then either replays its frames —
      // resurrecting pre-restore rows into a plan that no longer has them —
      // or refuses to open at all.
      await prepareLive();
      final wal = File('${liveFile.path}-wal')
        ..writeAsBytesSync(List<int>.filled(4096, 0x7F));
      final shm = File('${liveFile.path}-shm')
        ..writeAsBytesSync(List<int>.filled(1024, 0x01));
      final backup = await makeBackup();

      final result = await restore(backup);

      expect(result, isA<Ok<void, RestoreFailure>>());
      expect(wal.existsSync(), isFalse, reason: 'a foreign -wal survived');
      expect(shm.existsSync(), isFalse, reason: 'a foreign -shm survived');
      final reopened = openLive();
      addTearDown(reopened.close);
      final plans = await reopened.select(reopened.taperPlans).get();
      expect(plans.single.drugName, 'Restored');
    });

    test('nothing is left behind in the staging directory', () async {
      await prepareLive();
      final backup = await makeBackup();

      await restore(backup);

      expect(_stagingFiles(workspace), isEmpty);
    });
  });
}

/// Every staging or rollback artefact in [directory].
List<String> _stagingFiles(Directory directory) => directory
    .listSync()
    .whereType<File>()
    .map((f) => f.path.split(Platform.pathSeparator).last)
    .where((name) => name.contains('staging') || name.contains('rollback'))
    .toList();

/// Rewrites [file]'s header through [change], leaving the payload alone.
Future<File> _rewriteHeader(
  File file,
  BackupHeader Function(BackupHeader) change,
) async {
  final text = file.readAsStringSync();
  final firstBreak = text.indexOf('\n');
  final header =
      (BackupHeader.parse(text.substring(0, firstBreak))
              as Ok<BackupHeader, EnvelopeFailure>)
          .value;
  file.writeAsStringSync(
    '${change(header).toJsonLine()}\n${text.substring(firstBreak + 1)}',
  );
  return file;
}

/// Rewrites [file] with [payloadLines] and a matching digest.
///
/// So a malformed-ROW test is not accidentally a corrupted-FILE test: without
/// recomputing the digest, every payload edit fails at the checksum rung and
/// the row-level path is never reached.
Future<void> _rewriteWithDigest(File file, List<String> payloadLines) async {
  final text = file.readAsStringSync();
  final firstBreak = text.indexOf('\n');
  final header =
      (BackupHeader.parse(text.substring(0, firstBreak))
              as Ok<BackupHeader, EnvelopeFailure>)
          .value;
  final payload = '${payloadLines.skip(1).join('\n')}\n';
  final updated = BackupHeader(
    formatVersion: header.formatVersion,
    schemaVersion: header.schemaVersion,
    appVersion: header.appVersion,
    exportedAtUtc: header.exportedAtUtc,
    payloadSha256: sha256.convert(utf8.encode(payload)).toString(),
  );
  file.writeAsStringSync('${updated.toJsonLine()}\n$payload');
}
