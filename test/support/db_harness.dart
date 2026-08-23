/// The shared data-layer test harness.
///
/// A **real** `NativeDatabase.memory()` engine, never a mocked DAO:
/// constraints, cascades, pragmas and upserts are exactly what a mock cannot
/// have (`testing-strategy` rule 4).
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
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

/// Reopens a file-backed database over bytes an earlier one left behind.
///
/// The other half of [openTempFileDatabase]: a persistence claim needs the
/// first database CLOSED and a second one opened over the same file, because
/// that is the only shape in which "it survived" means anything.
AppDatabase reopenFileDatabase(File file) {
  final db = AppDatabase.forTesting(NativeDatabase(file));
  addTearDown(db.close);
  return db;
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

/// Inserts a plan through the DAO and returns its row id.
///
/// Shared because four test files were each declaring their own copy, and a
/// column added to `TaperPlans` would have had to be added to all four.
Future<int> seedPlan(
  AppDatabase db, {
  String uid = 'plan-1',
  DateTime? createdAt,
  LocalDate startDate = const LocalDate(2026, 4, 1),
  Milligrams? startingDose,
  Milligrams targetDose = Milligrams.zero,
  List<Milligrams>? strengths,
  bool allowHalves = true,
  TaperMethod method = TaperMethod.dsns,
}) => db.planDao.insertPlan(
  TaperPlansCompanion.insert(
    uid: uid,
    startDate: startDate,
    startingDose: startingDose ?? mg(10),
    targetDose: targetDose,
    tabletStrengths: strengths ?? <Milligrams>[mg(5), mg(1)],
    allowHalves: allowHalves,
    method: method,
    createdAt: createdAt ?? DateTime.utc(2026),
  ),
);

/// Inserts a step through the DAO and returns its row id.
Future<int> seedStep(
  AppDatabase db,
  int planId, {
  int index = 0,
  String? uid,
  Milligrams? fromDose,
  Milligrams? toDose,
  LocalDate startDate = const LocalDate(2026, 4, 1),
  StepStatus status = StepStatus.active,
}) => db.stepDao.insertStep(
  StepsCompanion.insert(
    uid: uid ?? 'step-$index',
    planId: planId,
    stepIndex: index,
    fromDose: fromDose ?? mg(10),
    toDose: toDose ?? mg(9),
    startDate: startDate,
    status: status,
    patternVersion: 1,
  ),
);

/// Writes a dose log through the DAO, replacing the row if the date repeats.
///
/// Seeding wants "make this row look like this"; the repository's own writes
/// deliberately narrow the conflict set, and those paths are tested through
/// the repository rather than here.
Future<void> seedLog(
  AppDatabase db,
  int planId,
  LocalDate date, {
  String? uid,
  Milligrams? plannedMg,
  Milligrams? actualMg,
  bool taken = true,
  DateTime? takenAt,
  String? note,
}) {
  final row = DoseLogsCompanion.insert(
    uid: uid ?? 'log-${date.toIso8601()}',
    planId: planId,
    date: date,
    plannedMg: plannedMg ?? mg(10),
    actualMg: actualMg ?? plannedMg ?? mg(10),
    taken: taken,
    takenAt: Value<DateTime?>(takenAt),
    note: Value<String?>(note),
  );
  return db.logDao.upsertLog(
    row,
    onConflict: row.copyWith(uid: const Value<String>.absent()),
  );
}

/// Rebuilds a [TaperPlanDraft] with a different non-DSNS hold period.
extension TaperPlanDraftHoldPeriod on TaperPlanDraft {
  /// Returns this draft with [days] as its hold period.
  TaperPlanDraft withHoldPeriod(int days) => TaperPlanDraft(
    drugName: drugName,
    startDate: startDate,
    currentDose: currentDose,
    targetDose: targetDose,
    strengths: strengths,
    allowHalves: allowHalves,
    method: method,
    stepSize: stepSize,
    percentage: percentage,
    fixedStep: fixedStep,
    holdPeriodDays: days,
  );
}

/// Runs `PRAGMA [pragma]` and returns its single integer result.
Future<int> pragmaValue(AppDatabase db, String pragma) async {
  final rows = await db.customSelect('PRAGMA $pragma').get();
  return rows.single.data.values.first! as int;
}

/// A handle to a test database that other suites can pass around.
///
/// A named holder rather than a bare `AppDatabase` so a test reads as "the
/// database this container was given" at every call site.
final class AppDatabaseHolder {
  /// Wraps [database].
  AppDatabaseHolder(this.database);

  /// The open database.
  final AppDatabase database;
}
