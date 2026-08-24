// Writing a backup: over a real engine, to a real temp directory.
//
// Never a mocked DAO. What this asserts is what reaches the FILE, and a fake
// can happily record a row the database would have rejected — or return rows
// in an order SQLite never would.
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/backup/backup_writer.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/features/backup/domain/backup_envelope.dart';
import 'package:test/test.dart';

import '../../support/db_harness.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('nearlystop_backup');
  });
  tearDown(() => workspace.deleteSync(recursive: true));

  /// Writes a backup of [db] into the workspace at a pinned instant.
  Future<Result<File, BackupWriteFailure>> write(
    AppDatabase db, {
    Directory? into,
  }) => withClock(
    Clock.fixed(DateTime.utc(2025, 4, 16, 8, 30)),
    () => writeBackup(
      database: db,
      directory: into ?? workspace,
      appVersion: '1.0.0+1',
      clock: clock,
    ),
  );

  /// A plan, two steps and three logs — inserted in either order.
  Future<void> seed(AppDatabase db, {bool shuffled = false}) async {
    final planId = await seedPlan(db);
    final steps = <int>[0, 1];
    final logs = <int>[0, 1, 2];
    for (final index in shuffled ? steps.reversed : steps) {
      await seedStep(db, planId, index: index, uid: 'step-$index');
    }
    for (final index in shuffled ? logs.reversed : logs) {
      await seedLog(
        db,
        planId,
        LocalDate(2026, 4, 1 + index),
        uid: 'log-$index',
      );
    }
  }

  test('the file is named for the day it was written', () async {
    final db = openTestDatabase();
    await seed(db);

    final result = await write(db);

    expect(result, isA<Ok<File, BackupWriteFailure>>());
    final file = (result as Ok<File, BackupWriteFailure>).value;
    expect(
      file.path.split(Platform.pathSeparator).last,
      'nearlystop-backup-2025-04-16.ndjson',
    );
  });

  test('line one is a header that parses on its own', () async {
    final db = openTestDatabase();
    await seed(db);

    final file = (await write(db) as Ok<File, BackupWriteFailure>).value;
    final lines = const LineSplitter().convert(await file.readAsString());

    final header = BackupHeader.parse(lines.first);
    expect(header, isA<Ok<BackupHeader, EnvelopeFailure>>());
    final parsed = (header as Ok<BackupHeader, EnvelopeFailure>).value;
    expect(parsed.formatVersion, kBackupFormatVersion);
    expect(parsed.appVersion, '1.0.0+1');
    expect(parsed.exportedAtUtc, DateTime.utc(2025, 4, 16, 8, 30));
  });

  test('the digest in the header is the digest of the payload', () async {
    // The one check that makes a truncated or edited file refusable. Computed
    // here from the bytes on disk, not from anything the writer remembered.
    final db = openTestDatabase();
    await seed(db);

    final file = (await write(db) as Ok<File, BackupWriteFailure>).value;
    final text = await file.readAsString();
    final firstBreak = text.indexOf('\n');
    final header =
        (BackupHeader.parse(text.substring(0, firstBreak))
                as Ok<BackupHeader, EnvelopeFailure>)
            .value;
    final payload = utf8.encode(text.substring(firstBreak + 1));

    expect(header.payloadSha256, sha256.convert(payload).toString());
  });

  test('shuffled insertion order produces BYTE-IDENTICAL payloads', () async {
    // What `ORDER BY uid` buys. Drift's `select()` without one returns
    // whatever order SQLite chooses, which after a restore is not the source
    // order — so a round-trip comparison would fail for a reason that has
    // nothing to do with the data.
    final first = openTestDatabase();
    await seed(first);
    final second = openTestDatabase();
    await seed(second, shuffled: true);

    final a = (await write(first) as Ok<File, BackupWriteFailure>).value;
    final bDirectory = Directory('${workspace.path}/second')..createSync();
    final b =
        (await write(second, into: bDirectory) as Ok<File, BackupWriteFailure>)
            .value;

    expect(await b.readAsString(), await a.readAsString());
  });

  test('every payload line names a known table, in dependency order', () async {
    final db = openTestDatabase();
    await seed(db);

    final file = (await write(db) as Ok<File, BackupWriteFailure>).value;
    final lines = const LineSplitter().convert(await file.readAsString());
    final tables = <String>[
      for (final line in lines.skip(1))
        (PayloadLine.parse(line) as Ok<PayloadLine, EnvelopeFailure>)
            .value
            .table,
    ];

    expect(tables, isNotEmpty);
    // Never going backwards through `kBackupTables`: the groups appear in the
    // declared order, so restore inserts in dependency order and a foreign key
    // cannot be dangling half way through.
    var seenIndex = -1;
    for (final table in tables) {
      final index = kBackupTables.indexOf(table);
      expect(index, greaterThanOrEqualTo(seenIndex), reason: table);
      seenIndex = index;
    }
  });

  test('doses are written as hundredths, and no dose is a double', () async {
    final db = openTestDatabase();
    await seed(db);

    final file = (await write(db) as Ok<File, BackupWriteFailure>).value;
    final lines = const LineSplitter().convert(await file.readAsString());
    var checked = 0;
    for (final line in lines.skip(1)) {
      final row = (PayloadLine.parse(line) as Ok<PayloadLine, EnvelopeFailure>)
          .value
          .row;
      for (final MapEntry(key: field, :value) in row.entries) {
        if (!field.endsWith('_hundredths_mg')) continue;
        if (value == null) continue;
        // A list of strengths is a list of hundredths; every element still has
        // to be an int, and a double here is a rounding error waiting for the
        // first 2.5mg tablet.
        for (final each in value is List ? value : <Object?>[value]) {
          expect(each, isA<int>(), reason: '$field is not an int');
          checked++;
        }
      }
    }
    expect(checked, greaterThan(0), reason: 'no dose fields were written');
  });

  test('the temp directory is empty afterwards', () async {
    // Two temp files are written and renamed away. One left behind is a
    // backup-sized file the reader never sees and the OS never reclaims.
    final db = openTestDatabase();
    await seed(db);

    await write(db);

    final leftovers = workspace
        .listSync()
        .whereType<File>()
        .where((f) => !f.path.endsWith('.ndjson'))
        .toList();
    expect(leftovers, isEmpty);
  });

  test('a directory it cannot write to is a typed refusal', () async {
    final db = openTestDatabase();
    await seed(db);

    final result = await write(
      db,
      into: Directory('${workspace.path}/does/not/exist'),
    );

    expect(result, isA<Err<File, BackupWriteFailure>>());
  });
}
