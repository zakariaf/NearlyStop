/// The shared data-layer test harness.
///
/// A **real** `NativeDatabase.memory()` engine, never a mocked DAO:
/// constraints, cascades, pragmas and upserts are exactly what a mock cannot
/// have (`testing-strategy` rule 4).
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/db/database_location.dart';
import 'package:nearlystop/data/taper_repository.dart';

/// The instant every data-layer test reads as "now".
final DateTime fixedNow = DateTime.utc(2026, 4, 16, 8);

/// A clock pinned to [fixedNow].
Clock get fixedClock => Clock.fixed(fixedNow);

/// Milligrams from a decimal count, for readable test literals.
Milligrams mg(num milligrams) =>
    Milligrams.fromHundredths((milligrams * 100).round());

/// Opens an in-memory database and closes it in teardown.
AppDatabase openTestDatabase() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// Opens a **file-backed** database in a temp directory, deleted in teardown.
///
/// `NativeDatabase.memory()` cannot prove the close-and-reopen claim: the whole
/// point is that bytes survive the process.
({AppDatabase db, File file}) openTempFileDatabase() {
  final directory = Directory.systemTemp.createTempSync('nearlystop_test');
  addTearDown(() => directory.deleteSync(recursive: true));
  final file = File('${directory.path}/nearlystop.sqlite');
  final db = AppDatabase.forTesting(NativeDatabase(file));
  addTearDown(db.close);
  return (db: db, file: file);
}

/// A [DatabaseLocation] that answers with a directory the test controls, and
/// counts how many times it was asked.
///
/// A class rather than a bare closure so the call count is observable — the
/// point of several tests is that the database is opened exactly once.
final class FakeDatabaseLocation {
  /// Answers with `<[directory]>/nearlystop.sqlite`.
  FakeDatabaseLocation(this.directory);

  /// Where the file is claimed to live.
  final Directory directory;

  /// How many times the location was asked.
  int calls = 0;

  /// The [DatabaseLocation] to hand to [AppDatabase].
  Future<File> call() async {
    calls++;
    return File('${directory.path}/$databaseFileName');
  }
}

/// The repo-wide seeded plan: Prednisolone, 10mg to 0, 5mg + 1mg, halves on,
/// DSNS, first step 10 -> 9 from 2026-04-01.
TaperPlanDraft seededDraft({
  LocalDate startDate = const LocalDate(2026, 4, 1),
  TaperMethod method = TaperMethod.dsns,
  List<Milligrams>? strengths,
  int? percentage,
  Milligrams? fixedStep,
}) => TaperPlanDraft(
  drugName: 'Prednisolone',
  startDate: startDate,
  currentDose: mg(10),
  targetDose: Milligrams.zero,
  strengths: strengths ?? <Milligrams>[mg(5), mg(1)],
  allowHalves: true,
  method: method,
  stepSize: mg(1),
  percentage: percentage,
  fixedStep: fixedStep,
);

/// Runs `PRAGMA [pragma]` and returns its single integer result.
Future<int> pragmaValue(AppDatabase db, String pragma) async {
  final rows = await db.customSelect('PRAGMA $pragma').get();
  return rows.single.data.values.first! as int;
}
