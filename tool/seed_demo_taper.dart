/// Fills a NearlyStop database with a taper that is months old.
///
/// **Why this exists.** The app only lets you tick today, so a fresh install
/// shows a Progress chart with one point on it — which tells you nothing about
/// whether the staircase, the flare marks or the axis actually work. This
/// writes the history a real user would have after most of a year.
///
/// **`tool/`, never `lib/`.** `tool/check_bans.sh` bans fixture seeding under
/// `lib/` outright, because a seeder that ships writes invented doses into a
/// real patient's database. That rule is scoped to `lib/` precisely so this
/// can exist here.
///
/// Usage: `bash tool/seed_demo.sh` — it finds the booted simulator's database
/// and runs this.
///
/// **Run through `flutter test`, not `dart run`.** `AppDatabase` reaches
/// `path_provider` through `database_location.dart`, and `path_provider`
/// reaches `dart:ui`, so plain Dart cannot compile it. Wrapping the body in a
/// `test()` is the cheap way to borrow the Flutter SDK's compiler for a
/// script; the alternative is splitting a shipped library to suit a demo tool,
/// which is the tail wagging the dog.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:nearlystop/data/db/app_database.dart';

/// One 1mg DSNS step, in days. `SPEC.md` §3.1.
const int kStepDays = 52;

/// Milligrams from a decimal, for readable literals.
Milligrams mg(num value) => Milligrams.fromHundredths((value * 100).round());

/// The database to fill, passed as `--dart-define=DB=…`.
const String kDatabasePath = String.fromEnvironment('DB');

void main() {
  test(
    'seed a demo taper',
    seedDemoTaper,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> seedDemoTaper() async {
  if (kDatabasePath.isEmpty) {
    fail('pass the database with --dart-define=DB=… (see tool/seed_demo.sh)');
  }
  final file = File(kDatabasePath);
  if (!file.existsSync()) {
    fail('no database at ${file.path} — launch the app once first');
  }

  final db = AppDatabase.forTesting(NativeDatabase(file));

  // Today, from the machine. The app injects its clock, but this writes rows
  // rather than rendering, so the wall clock is the right reference.
  final now = DateTime.now();
  final today = LocalDate(now.year, now.month, now.day);

  // Deep enough into the active step to land in the HIGH blocks, where the
  // pattern is alternating and the chart has something to show. Day 41 of 52
  // sits in block 9.
  const dayInActiveStep = 41;
  const completedSteps = 4;
  final start = today.addDays(
    -((completedSteps * kStepDays) + dayInActiveStep - 1),
  );

  stdout.writeln('seeding a taper that started $start, today is $today');

  await db.transaction(() async {
    // A clean slate, so re-running is idempotent rather than additive.
    await db.delete(db.doseLogs).go();
    await db.delete(db.flareEvents).go();
    await db.delete(db.holdEvents).go();
    await db.delete(db.steps).go();
    await db.delete(db.taperPlans).go();

    final planId = await db.planDao.insertPlan(
      TaperPlansCompanion.insert(
        uid: 'demo-plan',
        drugName: const Value<String>('Prednisolone'),
        startDate: start,
        startingDose: mg(10),
        targetDose: Milligrams.zero,
        tabletStrengths: <Milligrams>[mg(5), mg(1)],
        allowHalves: true,
        method: TaperMethod.dsns,
        createdAt: DateTime.utc(now.year, now.month, now.day),
      ),
    );

    // Five steps: 10→9→8→7→6→5. Four ran their full 52 days; the fifth is
    // running now.
    final steps = <StepFacts>[];
    for (var index = 0; index <= completedSteps; index++) {
      final from = mg(10 - index);
      final to = mg(9 - index);
      final stepStart = start.addDays(index * kStepDays);
      final status = index < completedSteps
          ? StepStatus.completed
          : StepStatus.active;

      final id = await db.stepDao.insertStep(
        StepsCompanion.insert(
          uid: 'demo-step-$index',
          planId: planId,
          stepIndex: index,
          fromDose: from,
          toDose: to,
          startDate: stepStart,
          status: status,
          patternVersion: 1,
        ),
      );
      steps.add(
        StepFacts(
          id: id,
          index: index,
          fromDose: from,
          toDose: to,
          startDate: stepStart,
          status: status,
          patternVersion: 1,
        ),
      );
    }

    final plan = TaperPlanFacts(
      drugName: 'Prednisolone',
      startDate: start,
      startingDose: mg(10),
      targetDose: Milligrams.zero,
      tabletStrengths: <TabletStrength>[
        TabletStrength(mg(5)),
        TabletStrength(mg(1)),
      ],
      allowHalves: true,
      method: TaperMethod.dsns,
    );

    // A hold and a flare, so the chart's two mark types are exercised. Both
    // land inside completed steps, where a real one would.
    final holdFrom = start.addDays(kStepDays + 20);
    final flareOn = start.addDays(kStepDays * 2 + 31);
    final holds = <HoldEvent>[
      HoldEvent(stepId: steps[1].id, fromDate: holdFrom, extraDays: 5),
    ];
    final flares = <FlareEvent>[
      FlareEvent(date: flareOn, revertToDose: mg(9)),
    ];

    await db.stepDao.insertHold(
      HoldEventsCompanion.insert(
        uid: 'demo-hold-0',
        stepId: steps[1].id,
        fromDate: holdFrom,
        extraDays: 5,
      ),
    );
    await db.planDao.insertFlare(
      FlareEventsCompanion.insert(
        uid: 'demo-flare-0',
        planId: planId,
        date: flareOn,
        revertToDose: mg(9),
      ),
    );

    // **The app's OWN generator**, not a hand-rolled day loop. Logs written
    // against a schedule this app would not produce are logs on dates that do
    // not exist, and the adherence count then reads "taken 214 of 209 days".
    final derived = generateSchedule(
      plan: plan,
      steps: steps,
      flares: flares,
      holds: holds,
      until: today,
    );
    if (derived case Err<List<DayPlan>, DomainFailure>(:final failure)) {
      throw StateError('the demo plan does not derive: $failure');
    }
    final days = (derived as Ok<List<DayPlan>, DomainFailure>).value;

    var taken = 0;
    var missed = 0;
    for (final day in days) {
      if (day.date > today) continue;
      // A few genuine gaps, because a chart over a perfect record is a chart
      // nobody has. Every 23rd day and every 37th is skipped.
      final elapsed = day.date.difference(start);
      if (elapsed % 23 == 0 || elapsed % 37 == 0) {
        missed++;
        continue;
      }
      await db.logDao.upsertLog(
        DoseLogsCompanion.insert(
          uid: 'demo-log-$elapsed',
          planId: planId,
          date: day.date,
          plannedMg: day.dose,
          actualMg: day.dose,
          taken: true,
        ),
        onConflict: DoseLogsCompanion.insert(
          uid: 'demo-log-$elapsed',
          planId: planId,
          date: day.date,
          plannedMg: day.dose,
          actualMg: day.dose,
          taken: true,
        ).copyWith(uid: const Value<String>.absent()),
      );
      taken++;
    }

    // Past the disclaimer, so the app opens straight onto Today.
    await db.settingsDao.ensureRowExists('demo-settings');
    await db.settingsDao.updateSettings(
      SettingsRowsCompanion(
        disclaimerAcceptedAt: Value<DateTime?>(
          DateTime.utc(now.year, now.month, now.day),
        ),
      ),
    );

    stdout
      ..writeln('  ${steps.length} steps, 10mg down to 5mg')
      ..writeln('  ${days.length} days derived, $taken ticked, $missed missed')
      ..writeln('  1 hold (5 days) and 1 flare back to 9mg');
  });

  await db.close();
  stdout.writeln('done — relaunch the app');
}
