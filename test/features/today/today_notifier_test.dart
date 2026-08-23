// The writes, headless, against a REAL database.
//
// A `ProviderContainer` and never a pumped widget: what these assert is the
// FACT that reaches storage — the date and the planned dose written into a row
// that is permanent — rather than that a button fired.
//
// The epic proposes a bare-`implements` `FakeTaperRepository`. It cannot
// exist: EPIC-05 made `TaperRepository` a `final class` precisely so nothing
// could subtype it. Testing against a real `NativeDatabase.memory()` is what
// `testing-strategy` rule 4 asks for anyway, and it proves strictly more — a
// fake can record a call the database would have rejected.
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/today/application/today_view_provider.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

import '../../support/db_harness.dart';

void main() {
  // The seeded plan starts on 1 April 2026 at 10mg with 5mg and 1mg tablets.
  const today = LocalDate(2026, 4, 16);

  setUpAll(initializeDateFormatting);

  late AppDatabaseHolder holder;
  setUp(() => holder = AppDatabaseHolder(openTestDatabase()));

  ProviderContainer containerAt(LocalDate date) {
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(holder.database),
        todayDateProvider.overrideWithValue(date),
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime.utc(date.year, date.month, date.day, 8)),
        ),
        resolvedLocaleProvider.overrideWithValue(const Locale('en')),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Seeds the plan and waits for the first emission.
  Future<TodayNotifier> ready(ProviderContainer container) async {
    await container.read(taperRepositoryProvider).savePlan(seededDraft());
    // A LISTENER, not just a read: `container.read(provider.future)` on a
    // stream nobody is listening to never resolves — the read hands back a
    // pending future and nothing drives the subscription.
    container.listen(todayViewProvider, (_, _) {});
    await container.read(todayViewProvider.future);
    return container.read(todayViewProvider.notifier);
  }

  /// The stored log for [date], or null.
  Future<DoseLogFacts?> storedLog(
    ProviderContainer container,
    LocalDate date,
  ) async {
    final snapshot = await container
        .read(taperRepositoryProvider)
        .watchSnapshot()
        .first;
    final facts = switch (snapshot) {
      Ok<TaperSnapshot, StorageFailure>(:final value) => value,
      Err<TaperSnapshot, StorageFailure>(:final failure) => throw StateError(
        '$failure',
      ),
    };
    for (final log in facts.logs) {
      if (log.date == date) return log;
    }
    return null;
  }

  /// Today's `DayPlan` dose, read from the derivation the screen also reads.
  Milligrams plannedFor(ProviderContainer container, LocalDate date) {
    final derived = container.read(derivedScheduleProvider);
    final days = switch (derived) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('$failure'),
    };
    return days.firstWhere((day) => day.date == date).dose;
  }

  test('markTakenToday stores TODAY with today’s planned dose', () async {
    // `plannedMg` is mandatory and the repository does not run the generator,
    // so the notifier passes the `DayPlan`'s dose it already holds. A default
    // here writes the wrong number into a row that is a permanent fact.
    final container = containerAt(today);
    final notifier = await ready(container);
    final planned = plannedFor(container, today);

    await notifier.markTakenToday();

    final log = await storedLog(container, today);
    expect(log, isNotNull);
    expect(log!.taken, isTrue);
    expect(log.plannedMg, planned);
    expect(log.actualMg, planned);
  });

  test('backfill stores THAT day’s dose, not today’s', () async {
    // The bug this rules out: backfilling an earlier day with today's planned
    // dose records the wrong number against it, and the cumulative total is
    // wrong forever. The seeded plan alternates, so the two differ.
    final container = containerAt(today);
    final notifier = await ready(container);
    // FOUND, not hardcoded: DSNS alternates, so which earlier day carries the
    // other dose depends on the block pattern. Hardcoding an offset makes the
    // test pass or fail on the calendar rather than on the behaviour.
    final todaysDose = plannedFor(container, today);
    final earlier = List<int>.generate(10, (index) => index + 1)
        .map((back) => today.addDays(-back))
        .firstWhere((date) => plannedFor(container, date) != todaysDose);
    final earlierDose = plannedFor(container, earlier);

    await notifier.backfill(earlier);

    final log = await storedLog(container, earlier);
    expect(log!.plannedMg, earlierDose);
    expect(await storedLog(container, today), isNull);
  });

  test('the taken flag comes from the STREAM, not a local bool', () async {
    // The notifier holds no state of its own. The write goes out, the
    // repository re-emits, and the flag arrives with the new snapshot — which
    // is what makes every other screen agree without re-deriving anything.
    final container = containerAt(today);
    final notifier = await ready(container);
    expect(
      (container.read(todayViewProvider).requireValue as TodayDose).taken,
      isFalse,
    );

    await notifier.markTakenToday();
    await Future<void>.delayed(Duration.zero);

    expect(
      (container.read(todayViewProvider).requireValue as TodayDose).taken,
      isTrue,
    );
  });

  test('saveNote stores the note AND the planned dose', () async {
    // CONTRACTS.md §3: `DoseLogs.plannedMg` is non-null, and a note may be the
    // first thing that creates the row.
    final container = containerAt(today);
    final notifier = await ready(container);
    final planned = plannedFor(container, today);

    await notifier.saveNote('slept badly');

    final log = await storedLog(container, today);
    expect(log!.note, 'slept badly');
    expect(log.plannedMg, planned);
    expect(log.taken, isFalse, reason: 'a note is not a tick');
  });

  test('undoLast removes today’s tick', () async {
    final container = containerAt(today);
    final notifier = await ready(container);
    await notifier.markTakenToday();
    expect((await storedLog(container, today))!.taken, isTrue);

    await notifier.undoLast();

    final log = await storedLog(container, today);
    expect(log?.taken ?? false, isFalse);
  });

  test('recordHold stores a hold against the ACTIVE step', () async {
    final container = containerAt(today);
    final notifier = await ready(container);

    await notifier.recordHold(5);

    final snapshot = await container
        .read(taperRepositoryProvider)
        .watchSnapshot()
        .first;
    final facts = (snapshot as Ok<TaperSnapshot, StorageFailure>).value;
    expect(facts.holds, hasLength(1));
    expect(facts.holds.single.extraDays, 5);
    expect(facts.holds.single.fromDate, today);
  });

  test('recordHold refuses 0 and 29 BEFORE any write', () async {
    // 28 is the ceiling because a longer stall is a plan change, not a hold.
    // Rejected in the notifier so the reader gets an answer and the row never
    // exists — a database that rejected it would be a crash, not an answer.
    final container = containerAt(today);
    final notifier = await ready(container);

    await notifier.recordHold(0);
    await notifier.recordHold(29);

    final snapshot = await container
        .read(taperRepositoryProvider)
        .watchSnapshot()
        .first;
    expect(
      (snapshot as Ok<TaperSnapshot, StorageFailure>).value.holds,
      isEmpty,
    );
  });

  test('recordFlare stores a flare dated today, at the chosen dose', () async {
    final container = containerAt(today);
    final notifier = await ready(container);

    await notifier.recordFlare(mg(10));

    final snapshot = await container
        .read(taperRepositoryProvider)
        .watchSnapshot()
        .first;
    final facts = (snapshot as Ok<TaperSnapshot, StorageFailure>).value;
    expect(facts.flares, hasLength(1));
    expect(facts.flares.single.date, today);
    expect(facts.flares.single.revertToDose, mg(10));
  });

  test('a flare does not move the cumulative total', () async {
    // The number the reader watches for two years. A flare appends a fact and
    // rewrites no history (SPEC.md §5.2).
    final container = containerAt(today);
    final notifier = await ready(container);
    await notifier.markTakenToday();
    final before = (await storedLog(container, today))!.actualMg;

    await notifier.recordFlare(mg(10));

    expect((await storedLog(container, today))!.actualMg, before);
  });

  test(
    'a failed write leaves the dose UNTOUCHED and reports beside it',
    () async {
      // The epic asks for `AsyncError(...).copyWithPrevious(state)`. Riverpod 3
      // made `copyWithPrevious` `@internal`, so that is no longer public API —
      // and separating the two is the better shape anyway: a write failing is
      // not the READ stream saying something, and routing it through the same
      // channel is exactly what makes the dose vanish when a tick fails.
      //
      // So the assertion is stronger than the epic's: the view state is not
      // merely still present, it is IDENTICAL, and the failure is readable
      // beside it.
      {
        final container = containerAt(today);
        final notifier = await ready(container);
        final before = container.read(todayViewProvider).requireValue;
        expect(container.read(todayWriteFailureProvider), isNull);
        // A real failure, not a simulated one.
        await holder.database.close();

        await notifier.markTakenToday();

        final after = container.read(todayViewProvider);
        expect(after.hasValue, isTrue, reason: 'the screen blanked');
        expect(
          after.hasError,
          isFalse,
          reason: 'a write error reached the read',
        );
        expect(after.requireValue, before);
        expect(
          container.read(todayWriteFailureProvider),
          isNotNull,
          reason: 'the failure was swallowed',
        );
      }
    },
  );
  test('a REFUSED derivation is surfaced, never waited on forever', () async {
    // The same hole EPIC-09 found on Schedule, in the screen the person opens
    // every morning. The mid-load guard reads "a plan with nothing derived yet
    // is still loading", which is indistinguishable from "the generator
    // refused" — so the emission is filtered away, the skeleton stays up, and
    // nothing times out. The comment above the `Err` arm claimed `TodayNoPlan`
    // was the honest answer; the guard below it made sure that answer was
    // never reached.
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(holder.database),
        todayDateProvider.overrideWithValue(today),
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime.utc(2026, 4, 16, 8)),
        ),
        resolvedLocaleProvider.overrideWithValue(const Locale('en')),
        derivedScheduleProvider.overrideWithValue(
          const Err<List<DayPlan>, Failure>(
            PlanNotStarted(LocalDate(2026, 4, 1)),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(taperRepositoryProvider).savePlan(seededDraft());
    container.listen(todayViewProvider, (_, _) {}, onError: (_, _) {});

    await expectLater(
      container.read(todayViewProvider.future),
      throwsA(isA<PlanNotStarted>()),
    );
  });
}
