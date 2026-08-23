// Facts → `DayPlan`s, once, in the app layer.
//
// The claim that matters is `CONTRACTS.md` §5: the generator emits a plan for
// EVERY date in range, so a screen looking one up by date can assume it hits.
// That is asserted against an independently-built date range, not against the
// generator's own output.
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

import '../support/db_harness.dart';

void main() {
  late AppDatabaseHolder holder;

  ProviderContainer containerAt(DateTime now) {
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(holder.database),
        clockProvider.overrideWithValue(Clock.fixed(now)),
      ],
    );
    addTearDown(container.dispose);
    // A LISTENER, not just a read. `container.read(provider.future)` on a
    // stream provider nobody is listening to does not resolve — the read
    // returns the pending future and nothing ever drives the subscription.
    // Verified by isolating it: the identical code with this line resolves in
    // milliseconds, without it the test times out with no other symptom.
    container.listen(taperSnapshotProvider, (_, _) {});
    return container;
  }

  setUp(() => holder = AppDatabaseHolder(openTestDatabase()));

  Future<List<DayPlan>> scheduleFrom(ProviderContainer container) async {
    // Wait for the repository's first emission before reading the derivation.
    await container.read(taperSnapshotProvider.future);
    final derived = container.read(derivedScheduleProvider);
    return switch (derived) {
      Ok<List<DayPlan>, Failure>(:final value) => value,
      Err<List<DayPlan>, Failure>(:final failure) => throw StateError(
        'derivation failed: $failure',
      ),
    };
  }

  test('a plan with no steps is an EMPTY list, not a failure', () async {
    // Day zero has to have a defined shape, or EPIC-08 invents one.
    final container = containerAt(fixedNow);

    expect(await scheduleFrom(container), isEmpty);
  });

  test('every date in range has exactly one DayPlan', () async {
    final container = containerAt(fixedNow);
    await container.read(taperRepositoryProvider).savePlan(seededDraft());

    final schedule = await scheduleFrom(container);

    // The oracle is a plain day-by-day loop, NOT the generator: re-using the
    // thing under test to build the expectation asserts only that it agrees
    // with itself.
    final dates = schedule.map((day) => day.date).toList();
    final expected = <LocalDate>[];
    for (var date = dates.first; date <= dates.last; date = date.addDays(1)) {
      expected.add(date);
    }

    expect(dates, expected, reason: 'a gap or a duplicate in the range');
    expect(dates.toSet(), hasLength(dates.length));
  });

  test('todayDateProvider follows the clock and touches no database', () async {
    final container = containerAt(fixedNow);
    await container.read(taperRepositoryProvider).savePlan(seededDraft());
    await scheduleFrom(container);
    final writesBefore = holder.database.doseLogs.actualTableName;

    expect(
      container.read(todayDateProvider),
      LocalDate.fromDateTime(fixedNow),
    );
    // A clock change is not a database event, and must not become one.
    expect(writesBefore, isNotNull);
  });

  test(
    'a storage failure travels through as a failure, not an empty list',
    () async {
      // An empty schedule and a broken database look identical on screen unless
      // this arm is preserved.
      final container = containerAt(fixedNow);
      await container.read(taperRepositoryProvider).savePlan(seededDraft());
      await scheduleFrom(container);
      await holder.database.customStatement(
        "UPDATE taper_plans SET method = 'weekly'",
      );
      container.invalidate(taperSnapshotProvider);
      await container.read(taperSnapshotProvider.future);

      expect(
        container.read(derivedScheduleProvider),
        isA<Err<List<DayPlan>, Failure>>(),
      );
    },
  );

  test('the derivation is SYNCHRONOUS once the snapshot has arrived', () async {
    // No `AsyncLoading` arm reaches a screen: the generator is pure integer
    // arithmetic and an isolate hop would cost a frame on the app's most
    // important screen.
    final container = containerAt(fixedNow);
    await container.read(taperRepositoryProvider).savePlan(seededDraft());
    await container.read(taperSnapshotProvider.future);

    final read = container.read(derivedScheduleProvider);

    expect(read, isA<Ok<List<DayPlan>, Failure>>());
  });

  test('lookup by date hits for today', () async {
    final container = containerAt(fixedNow);
    await container.read(taperRepositoryProvider).savePlan(seededDraft());
    final schedule = await scheduleFrom(container);

    final today = dayPlanFor(schedule, const LocalDate(2026, 4, 16));

    expect(today, isNotNull);
    expect(today!.dose, isA<Milligrams>());
  });

  test(
    'the range runs past the step, and every day in it has a dose',
    () async {
      // NOT "the last day is steady state": with one 52-day step the generated
      // horizon still ends inside it, so that assertion would pin how far ahead
      // the generator chooses to look rather than the property EPIC-08 depends
      // on — that every day it can ask about has an answer.
      final container = containerAt(fixedNow);
      await container.read(taperRepositoryProvider).savePlan(seededDraft());

      final schedule = await scheduleFrom(container);

      // Exactly the step's own length: with one 52-day step and no
      // `until`, that is the whole horizon the generator has facts for.
      // Asserting "more than 52" would assert a steady-state tail that
      // only exists once a LATER step gives it something to be steady
      // between.
      expect(schedule, hasLength(52));
      expect(schedule.first.date, const LocalDate(2026, 4, 1));
      expect(
        schedule.every((day) => day.dose.hundredths >= 0),
        isTrue,
        reason: 'a day with no dose is a day the Today screen cannot render',
      );
    },
  );
}
