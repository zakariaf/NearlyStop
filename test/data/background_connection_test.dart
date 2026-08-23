// The SHIPPING connection, not the in-process one every other test uses.
//
// `AppDatabase(location)` runs the engine on a background isolate through
// `NativeDatabase.createInBackground`, and errors cross that boundary wrapped
// in `DriftRemoteException` — a different class from the
// `DriftWrappedException` an in-process engine throws. A classifier that knows
// only the second one types every constraint violation on a real phone as a
// generic storage error while the whole suite says otherwise.
@Tags(<String>['migration'])
library;

import 'dart:io';

// `isNotNull` is a drift query builder AND a matcher; the matcher is the one
// this file wants.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';

import '../support/db_harness.dart';

void main() {
  late Directory directory;
  late AppDatabase db;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('nearlystop_background');
    final location = FakeDatabaseLocation(directory);
    db = AppDatabase(location.call);
    addTearDown(() => directory.deleteSync(recursive: true));
    addTearDown(db.close);
  });

  test('the background isolate really is in play', () async {
    // If this ever runs in-process the test below stops proving anything, so
    // the premise is asserted rather than assumed: an error raised by the
    // engine arrives as a remote wrap, whose toString carries the cause.
    await seedPlan(db);

    expect(File('${directory.path}/nearlystop.sqlite').existsSync(), isTrue);
  });

  test('a constraint violation across the isolate is typed, not Io', () async {
    final planId = await seedPlan(db);
    await seedLog(db, planId, const LocalDate(2026, 4, 2), uid: 'first');

    Object? raised;
    try {
      await db
          .into(db.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              uid: 'second',
              planId: planId,
              date: const LocalDate(2026, 4, 2),
              plannedMg: mg(10),
              actualMg: mg(10),
              taken: true,
            ),
          );
    } on Object catch (error) {
      raised = error;
    }

    expect(raised, isNotNull);
    expect(
      storageFailureFrom(raised!),
      isA<ConstraintViolation>(),
      reason:
          'across the isolate the wrap is DriftRemoteException, and an '
          'Io here is the bug this whole file exists to catch',
    );
  });

  test('the same failure through a repository over this connection', () async {
    await TaperRepository(db, fixedClock).savePlan(seededDraft());

    // A hold on a step this plan does not own is refused in Dart; a hold with
    // extraDays past the step is refused too. What reaches the engine here is
    // the CHECK on a directly-inserted row — the same 19-family code, arriving
    // through the isolate.
    Object? raised;
    try {
      await db
          .into(db.holdEvents)
          .insert(
            HoldEventsCompanion.insert(
              uid: 'bad-hold',
              stepId: 1,
              fromDate: const LocalDate(2026, 4, 10),
              extraDays: 0,
            ),
          );
    } on Object catch (error) {
      raised = error;
    }

    expect(storageFailureFrom(raised!), isA<ConstraintViolation>());
  });
}
