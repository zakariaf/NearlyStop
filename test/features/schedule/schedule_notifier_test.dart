// The Schedule's notifier: what it emits, and the two writes.
//
// `ProviderContainer` and a REAL `NativeDatabase.memory()`, never a pumped
// widget and never a mocked DAO. The epic proposes a bare-`implements`
// `FakeTaperRepository`; it cannot exist, because EPIC-05 made
// `TaperRepository` a `final class` precisely so nothing could subtype it —
// and a real engine proves strictly more, since a fake can happily record a
// write the database would have rejected.
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

import '../../support/db_harness.dart';

void main() {
  // The seeded plan starts on 1 April 2026 at 10mg with 5mg and 1mg tablets,
  // so 16 April is day 16 of a 52-day step.
  const today = LocalDate(2026, 4, 16);
  // Day 55: step 0's 52 days are behind, so `startNextStep` is legal and step
  // 0 becomes the completed step every read-only assertion needs.
  const afterStepOne = LocalDate(2026, 5, 25);

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

  /// Saves the seeded plan and waits for [step]'s first emission.
  ///
  /// A LISTENER, not just a read: `read(provider.future)` on a stream nobody
  /// listens to never resolves.
  Future<ScheduleLoaded> ready(
    ProviderContainer container, {
    int step = 0,
    LocalDate startDate = const LocalDate(2026, 4, 1),
  }) async {
    await container
        .read(taperRepositoryProvider)
        .savePlan(seededDraft(startDate: startDate));
    container.listen(scheduleViewProvider(step), (_, _) {});
    return await container.read(scheduleViewProvider(step).future)
        as ScheduleLoaded;
  }

  /// The state after the stream has caught up with a write.
  ///
  /// `read(provider.future)` on an already-loaded provider resolves to the
  /// value it ALREADY has, so a test that writes and re-reads asserts against
  /// the state from before its own mutation. Draining the queue lets the live
  /// listener take the next emission.
  Future<ScheduleLoaded> settled(ProviderContainer container, int step) async {
    await pumpEventQueue();
    return container.read(scheduleViewProvider(step)).requireValue
        as ScheduleLoaded;
  }

  /// The days the app-wide derivation produced for [step].
  List<DayPlan> derivedStep(ProviderContainer container, int step) {
    final derived = container.read(derivedScheduleProvider);
    final days = switch (derived) {
      Ok<List<DayPlan>, Failure>(:final value) => value,
      Err<List<DayPlan>, Failure>(:final failure) => throw StateError(
        '$failure',
      ),
    };
    return <DayPlan>[
      for (final day in days)
        if (day.stepIndex == step) day,
    ];
  }

  /// Every stored dose log, newest read straight from the repository.
  Future<List<DoseLogFacts>> storedLogs(ProviderContainer container) async {
    final snapshot = await container
        .read(taperRepositoryProvider)
        .watchSnapshot()
        .first;
    return switch (snapshot) {
      Ok<TaperSnapshot, StorageFailure>(:final value) => value.logs,
      Err<TaperSnapshot, StorageFailure>(:final failure) => throw StateError(
        '$failure',
      ),
    };
  }

  group('what it emits', () {
    test(
      'the active step is eleven blocks with today located in one',
      () async {
        final container = containerAt(today);
        final loaded = await ready(container);

        expect(
          loaded.blocks.where((block) => block.blockNumber != null),
          hasLength(11),
        );
        expect(loaded.steps.isActive, isTrue);
        expect(loaded.steps.index, 0);

        // The oracle is the app-wide derivation, not a hardcoded coordinate: if
        // the block table ever changes, this test moves with it instead of
        // becoming a lie.
        final expected = derivedStep(
          container,
          0,
        ).firstWhere((day) => day.date == today).blockIndex;
        final locator = loaded.todayLocator;
        expect(locator, isNotNull);
        expect(loaded.blocks[locator!.$1].blockNumber, expected);
        expect(loaded.blocks[locator.$1].days[locator.$2].date, today);
      },
    );

    test('a completed step is browsable and every row is read-only', () async {
      final container = containerAt(afterStepOne);
      await ready(container);
      await container.read(taperRepositoryProvider).startNextStep();
      final loaded = await settled(container, 0);
      expect(loaded.steps.isActive, isFalse);
      expect(loaded.steps.total, 2);
      expect(loaded.steps.hasNext, isTrue);
      expect(loaded.days, isNotEmpty);
      expect(loaded.days.every((day) => !day.tickable), isTrue);
      expect(loaded.todayLocator, isNull);
    });

    test(
      'a HoldEvent adds five marked rows that do not advance the day count',
      () async {
        // Without the marker the list grows five rows all reading "day 14 of
        // 52" — a bug, on the one screen whose job is making structure legible.
        final container = containerAt(today);
        await ready(container);
        final steps = derivedStep(container, 0);
        final host = steps.firstWhere((day) => day.dayInStep == 14).date;
        await container
            .read(taperRepositoryProvider)
            .recordHold(
              stepId: 1,
              from: host,
              extraDays: 5,
            );
        final loaded = await settled(container, 0);
        expect(loaded.days.where((day) => day.isHoldDay), hasLength(5));

        final held = <DayPlan>[
          for (final day in derivedStep(container, 0))
            if (day.isHoldDay) day,
        ];
        expect(held.map((day) => day.dayInStep).toSet(), <int>{14});
        final resumed = derivedStep(
          container,
          0,
        ).firstWhere((day) => day.date == held.last.date.addDays(1));
        expect(resumed.dayInStep, 15);
        expect(resumed.isHoldDay, isFalse);
      },
    );
  });

  group('the writes', () {
    test('marking a past day stores THAT day’s planned dose', () async {
      // The bug this rules out: forwarding today's planned dose to an earlier
      // day writes the wrong number into a permanent record. The step
      // alternates, so on the seeded plan the two genuinely differ.
      final container = containerAt(today);
      final loaded = await ready(container);
      final row = loaded.days.lastWhere(
        (day) => day.date < today && day.tickable,
      );
      final notifier = container.read(scheduleViewProvider(0).notifier);

      final refusal = await notifier.markTaken(
        row.date,
        plannedMg: row.plannedMg,
      );

      expect(refusal, isNull);
      final logs = await storedLogs(container);
      expect(logs, hasLength(1));
      expect(logs.single.date, row.date);
      expect(logs.single.plannedMg, row.plannedMg);
      expect(logs.single.taken, isTrue);
    });

    test('undo removes the tick it made', () async {
      final container = containerAt(today);
      final loaded = await ready(container);
      final row = loaded.days.lastWhere(
        (day) => day.date < today && day.tickable,
      );
      final notifier = container.read(scheduleViewProvider(0).notifier);

      await notifier.markTaken(row.date, plannedMg: row.plannedMg);
      final refusal = await notifier.undoTaken(row.date);

      expect(refusal, isNull);
      final logs = await storedLogs(container);
      expect(
        logs.where((log) => log.date == row.date && log.taken),
        isEmpty,
      );
    });

    test('a future day is refused, and writes NOTHING', () async {
      // A silent no-op fails this test: the refusal is typed so the row can
      // say why rather than looking broken.
      final container = containerAt(today);
      final loaded = await ready(container);
      final row = loaded.days.firstWhere((day) => day.date > today);
      final notifier = container.read(scheduleViewProvider(0).notifier);

      expect(
        await notifier.markTaken(row.date, plannedMg: row.plannedMg),
        ScheduleRefusal.futureDay,
      );
      expect(
        await notifier.undoTaken(row.date),
        ScheduleRefusal.futureDay,
      );
      expect(await storedLogs(container), isEmpty);
    });

    test('a day in a completed step is refused, and writes NOTHING', () async {
      final container = containerAt(afterStepOne);
      await ready(container);
      await container.read(taperRepositoryProvider).startNextStep();
      final loaded = await settled(container, 0);
      final row = loaded.days.first;
      final notifier = container.read(scheduleViewProvider(0).notifier);

      expect(
        await notifier.markTaken(row.date, plannedMg: row.plannedMg),
        ScheduleRefusal.readOnly,
      );
      expect(await notifier.undoTaken(row.date), ScheduleRefusal.readOnly);
      expect(await storedLogs(container), isEmpty);
    });
  });

  group('the plumbing', () {
    test(
      'leaving a step disposes it, so step 12 costs what step 1 did',
      () async {
        // A leaked per-step subscription is how a screen with a switcher gets
        // slow at step 12 and nobody can say why.
        final disposed = <Object>{};
        final container = ProviderContainer(
          overrides: <Override>[
            databaseProvider.overrideWithValue(holder.database),
            todayDateProvider.overrideWithValue(afterStepOne),
            clockProvider.overrideWithValue(
              Clock.fixed(DateTime.utc(2026, 5, 25, 8)),
            ),
            resolvedLocaleProvider.overrideWithValue(const Locale('en')),
          ],
          observers: <ProviderObserver>[_DisposeRecorder(disposed)],
        );
        addTearDown(container.dispose);
        await container.read(taperRepositoryProvider).savePlan(seededDraft());
        await container.read(taperRepositoryProvider).startNextStep();

        final first = container.listen(scheduleViewProvider(0), (_, _) {});
        await container.read(scheduleViewProvider(0).future);
        first.close();
        // Auto-dispose is deferred to the next microtask drain.
        await Future<void>.delayed(Duration.zero);

        expect(disposed, contains(scheduleViewProvider(0)));
      },
    );

    test('the feature never runs the generator itself', () {
      // CONTRACTS §4: `generateSchedule` runs ONCE, in the app layer. A second
      // call here would be a second answer, and the two would diverge the day
      // somebody changed one. The IMPORT is the check, not the word — the
      // provider's own doc comment names the function it deliberately avoids.
      final sources = Directory('lib/features/schedule')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      expect(sources, isNotEmpty);
      for (final file in sources) {
        expect(
          file.readAsStringSync(),
          isNot(contains('dsns/schedule_generator.dart')),
          reason: '${file.path} derives its own schedule',
        );
      }
    });

    test(
      'a derivation that FAILS is surfaced, never waited on forever',
      () async {
        // The hang this rules out: the mid-load guard reads "a plan with
        // nothing derived yet is still loading", which is indistinguishable
        // from "the generator refused". Filtering that emission away leaves
        // the skeleton on screen for ever, and a stream that never emits has
        // no timeout to save it.
        final container = containerAt(today);
        await container.read(taperRepositoryProvider).savePlan(seededDraft());
        final broken = ProviderContainer(
          overrides: <Override>[
            databaseProvider.overrideWithValue(holder.database),
            todayDateProvider.overrideWithValue(today),
            clockProvider.overrideWithValue(_eightAm),
            resolvedLocaleProvider.overrideWithValue(const Locale('en')),
            derivedScheduleProvider.overrideWithValue(_refused),
          ],
        );
        addTearDown(broken.dispose);
        broken.listen(scheduleViewProvider(0), (_, _) {}, onError: (_, _) {});

        await expectLater(
          broken.read(scheduleViewProvider(0).future),
          throwsA(isA<PlanNotStarted>()),
        );
      },
    );

    test(
      'a derivation that fails LATER keeps the blocks already on screen',
      () async {
        // The other half: the reader is looking at block 3 when the derivation
        // starts refusing. Blanking the list to "no plan" would tell them their
        // taper had been deleted.
        final failing = _SwitchableDerivation();
        final container = ProviderContainer(
          overrides: <Override>[
            databaseProvider.overrideWithValue(holder.database),
            todayDateProvider.overrideWithValue(today),
            clockProvider.overrideWithValue(_eightAm),
            resolvedLocaleProvider.overrideWithValue(const Locale('en')),
            derivedScheduleProvider.overrideWith(failing.build),
          ],
        );
        addTearDown(container.dispose);
        await container.read(taperRepositoryProvider).savePlan(seededDraft());
        container.listen(
          scheduleViewProvider(0),
          (_, _) {},
          onError: (_, _) {},
        );
        final loaded = await container.read(scheduleViewProvider(0).future);

        failing.fail();
        container.invalidate(derivedScheduleProvider);
        await pumpEventQueue();

        final state = container.read(scheduleViewProvider(0));
        expect(state, isA<AsyncError<ScheduleViewState>>());
        expect(state.error, isA<PlanNotStarted>());
        expect(
          state.value,
          loaded,
          reason: 'the blocks the reader was looking at were thrown away',
        );
      },
    );
  });
}

/// Eight in the morning on the pinned day.
final Clock _eightAm = Clock.fixed(DateTime.utc(2026, 4, 16, 8));

/// The derivation refusing, as `derivedScheduleProvider` would return it.
const Result<List<DayPlan>, Failure> _refused = Err<List<DayPlan>, Failure>(
  PlanNotStarted(LocalDate(2026, 4, 1)),
);

/// A derivation that can be told to start refusing.
///
/// A class rather than a captured local so the override reads as one object
/// with a state, and `fail()` names what the test is doing to it.
final class _SwitchableDerivation {
  bool _failing = false;

  /// Makes every later build refuse.
  void fail() => _failing = true;

  /// The provider body handed to `overrideWith`.
  Result<List<DayPlan>, Failure> build(Ref ref) {
    if (_failing) {
      return _refused;
    }
    return _real(ref);
  }

  Result<List<DayPlan>, Failure> _real(Ref ref) {
    final snapshot = ref.watch(taperSnapshotProvider);
    return switch (snapshot) {
      AsyncData<Result<TaperSnapshot, StorageFailure>>(:final value) =>
        switch (value) {
          Ok<TaperSnapshot, StorageFailure>(value: final facts) =>
            facts.plan == null
                ? const Ok<List<DayPlan>, Failure>(<DayPlan>[])
                : generateSchedule(
                    plan: facts.plan!,
                    steps: facts.steps,
                    flares: facts.flares,
                    holds: facts.holds,
                  ),
          Err<TaperSnapshot, StorageFailure>(:final failure) => Err(failure),
        },
      _ => const Ok<List<DayPlan>, Failure>(<DayPlan>[]),
    };
  }
}

/// Records which providers the container disposed.
final class _DisposeRecorder extends ProviderObserver {
  _DisposeRecorder(this.disposed);

  final Set<Object> disposed;

  @override
  void didDisposeProvider(ProviderObserverContext context) =>
      disposed.add(context.provider);
}
