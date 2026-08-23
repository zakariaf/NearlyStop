// "Kill the app mid-taper, reopen, and nothing is lost" — `SPEC.md` §10, as a
// test.
//
// A **file-backed** database, because that is the whole claim: bytes survive
// the process. `NativeDatabase.memory()` cannot prove it, and neither can
// `integration_test` — it restarts the widget tree, which says nothing about
// the file on disk. EPIC-08's, EPIC-11's and EPIC-12's "kill and relaunch"
// criteria point here.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/cumulative.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/golden_vector_codec.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';

import '../support/db_harness.dart';

/// What the app renders, reduced to the three things a reopen must reproduce.
typedef Rendered = (
  List<DayPlan> schedule,
  Milligrams total,
  Map<int, StepStatus> status,
);

void main() {
  test('a 120-day taper survives close-and-reopen, byte for byte', () async {
    final directory = Directory.systemTemp.createTempSync('nearlystop_trip');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/nearlystop.sqlite');

    Future<TaperSnapshot> snapshotOf(TaperRepository repository) async {
      final result = await repository.watchSnapshot().first;
      return switch (result) {
        Ok<TaperSnapshot, StorageFailure>(:final value) => value,
        Err<TaperSnapshot, StorageFailure>(:final failure) => throw StateError(
          'snapshot failed: $failure',
        ),
      };
    }

    Rendered render(TaperSnapshot snapshot) {
      final generated = generateSchedule(
        plan: snapshot.plan!,
        steps: snapshot.steps,
        flares: snapshot.flares,
        holds: snapshot.holds,
      );
      return (
        switch (generated) {
          Ok<List<DayPlan>, DomainFailure>(:final value) => value,
          Err<List<DayPlan>, DomainFailure>(:final failure) => throw StateError(
            'generation failed: $failure',
          ),
        },
        cumulativeTakenMg(snapshot.logs),
        snapshot.statusByStepId,
      );
    }

    // 1. Build the fixture through the PUBLIC repository API only.
    final first = AppDatabase.forTesting(NativeDatabase(file));
    final writer = TaperRepository(first, fixedClock);
    expect(
      await writer.savePlan(seededDraft()),
      isA<Ok<void, StorageFailure>>(),
    );
    const start = LocalDate(2026, 4, 1);
    var skipped = 0;
    for (var day = 0; day < 120; day++) {
      // A handful missed, so `adherence` has something to say later.
      if (day % 17 == 0) {
        skipped++;
        continue;
      }
      expect(
        await writer.markTaken(start.addDays(day), plannedMg: mg(10)),
        isA<Ok<void, StorageFailure>>(),
      );
    }
    expect(
      await writer.recordHold(
        stepId: 1,
        from: start.addDays(20),
        extraDays: 3,
      ),
      isA<Ok<void, StorageFailure>>(),
    );
    expect(
      await writer.recordFlare(on: start.addDays(45), revertTo: mg(10)),
      isA<Ok<void, StorageFailure>>(),
    );
    final before = render(await snapshotOf(writer));

    // 2. Kill it.
    await first.close();

    // 3. Reopen from the same file, at the same instant.
    final second = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(second.close);
    final after = render(await snapshotOf(TaperRepository(second, fixedClock)));

    // 4. The regenerated schedule is identical element for element. Compared
    // through EPIC-04's serialised form so a failure names the first differing
    // date rather than saying "lists differ".
    expect(after.$1, hasLength(before.$1.length));
    expect(before.$1, isNotEmpty);
    for (var i = 0; i < before.$1.length; i++) {
      expect(
        encodeGoldenRow(after.$1[i]),
        encodeGoldenRow(before.$1[i]),
        reason: 'day ${before.$1[i].date}',
      );
    }
    expect(encodeGoldenVector(after.$1), encodeGoldenVector(before.$1));

    // 5. The total is unchanged, in hundredths.
    expect(after.$2.hundredths, before.$2.hundredths);
    expect(after.$2.hundredths, (120 - skipped) * 1000);

    // 6. And the derived statuses agree at the same fixed clock.
    expect(after.$3, before.$3);
    expect(after.$3, isNotEmpty);
  });
}
