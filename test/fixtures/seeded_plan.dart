/// The one seeded plan every UI epic renders — screens, goldens, parity.
///
/// *Prednisolone, current 10mg, target 0mg, strengths 5mg + 1mg, halves on,
/// DSNS, active step **10mg → 9mg**, day 14 of 52.*
///
/// **A separate file from `taper_fixture.dart`, and not a second definition.**
/// The domain fixture imports `package:test`, whose `expect`/`group`/`test`
/// collide with `flutter_test`'s the moment a widget test imports both — so
/// the values are imported from there and re-exposed here, never retyped. A
/// second copy is a fixture that drifts, and the whole point of pinning one is
/// that a golden and a parity sheet show the same plan.
///
/// The clock is pinned to **2026-04-14**, which is day 14 of a step that
/// starts 2026-04-01. The epics quote 2025-04-16 from an earlier draft of the
/// plan's start date; the invariant that matters — and the one the tests
/// assert — is `dayInStep == 14`, so the clock follows the fixture rather than
/// the prose.
library;

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/progress/application/progress_view_provider.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/today/application/today_view_provider.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';
import 'taper_fixture.dart' as domain;

/// The plan under test.
final TaperPlanFacts seededPlan = domain.fixturePlan;

/// Its one active step, 10mg → 9mg.
const StepFacts seededStep = domain.fixtureStep;

/// The day the pinned clock reports — day 14 of the step.
const LocalDate seededToday = LocalDate(2026, 4, 14);

/// The pinned instant, at eight in the morning.
final DateTime seededNow = DateTime.utc(
  seededToday.year,
  seededToday.month,
  seededToday.day,
  8,
);

/// Days elapsed in the active step at [seededToday], counting the first day.
int get seededDayInStep => seededToday.difference(seededStep.startDate) + 1;

/// The whole snapshot, ready to override `taperSnapshotProvider` with.
TaperSnapshot seededSnapshot({
  List<DoseLogFacts> logs = const <DoseLogFacts>[],
  List<FlareEvent> flares = const <FlareEvent>[],
  List<HoldEvent> holds = const <HoldEvent>[],
}) => TaperSnapshot(
  plan: seededPlan,
  steps: const <StepFacts>[seededStep],
  logs: logs,
  flares: flares,
  holds: holds,
  statusByStepId: <int, StepStatus>{seededStep.id: StepStatus.active},
);

/// The overrides a screen needs to render [seededSnapshot] deterministically.
///
/// The snapshot, not a database: a golden or a sweep must not depend on
/// drift's stream timing, and three suites spelling the same four overrides
/// out is three chances to pin a different clock than the fixture's.
List<Override> seededPlanOverrides({Locale locale = const Locale('en')}) =>
    <Override>[
      taperSnapshotProvider.overrideWith(
        (ref) => Stream<Result<TaperSnapshot, StorageFailure>>.value(
          Ok<TaperSnapshot, StorageFailure>(seededSnapshot()),
        ),
      ),
      todayDateProvider.overrideWithValue(seededToday),
      clockProvider.overrideWithValue(Clock.fixed(seededNow)),
      resolvedLocaleProvider.overrideWithValue(locale),
    ];

/// Writes [seededPlan] into whatever database [container] is wired to.
///
/// Named apart from `db_harness.dart`'s `seedPlan`, which inserts a row: this
/// one goes through the repository so `Step 0` exists.
///
/// The repository, not the DAO: the same transaction the app uses, so the
/// `Step 0` CONTRACTS §7 requires exists here too. A test that inserted rows
/// directly would produce a plan with no step and a schedule of nothing.
Future<void> seedTaperInto(ProviderContainer container) async {
  final result = await container
      .read(taperRepositoryProvider)
      .savePlan(
        TaperPlanDraft(
          drugName: seededPlan.drugName,
          startDate: seededPlan.startDate,
          currentDose: seededPlan.startingDose,
          targetDose: seededPlan.targetDose,
          strengths: <Milligrams>[
            for (final strength in seededPlan.tabletStrengths)
              Milligrams.fromHundredths(strength.hundredths),
          ],
          allowHalves: seededPlan.allowHalves,
          method: seededPlan.method,
          stepSize: seededStep.fromDose - seededStep.toDose,
          holdPeriodDays: seededPlan.holdPeriodDays,
        ),
      );
  if (result is Err<void, StorageFailure>) {
    throw StateError('seedTaperInto failed: ${result.failure}');
  }
}

/// The seeded snapshot with every day up to [seededToday] ticked.
///
/// A screen rendered from a plan with no history shows its empty states, which
/// is a different screen from the one the sweeps are about.
TaperSnapshot seededHistory() => seededSnapshot(
  logs: <DoseLogFacts>[
    for (final day in seededSchedule())
      if (day.date < seededToday)
        DoseLogFacts(
          date: day.date,
          plannedMg: day.dose,
          actualMg: day.dose,
          taken: true,
        ),
  ],
);

/// The derived schedule for [seededPlan], through the one app-wide derivation.
List<DayPlan> seededSchedule() {
  final result = scheduleFromSnapshot(
    Ok<TaperSnapshot, StorageFailure>(seededSnapshot()),
  );
  if (result case Err<List<DayPlan>, Failure>(:final failure)) {
    throw StateError('the seeded plan does not derive: ${failure.code}');
  }
  return (result as Ok<List<DayPlan>, Failure>).value;
}

/// Overrides that put the SEEDED plan on Today, Schedule and Progress.
///
/// Those three read the repository directly rather than
/// `taperSnapshotProvider`, so [seededPlanOverrides] alone leaves them
/// rendering their error panel — which is a different screen from the one a
/// sweep is about, and a matrix that swept it would be green about the wrong
/// thing.
///
/// The view states come from each notifier's own **pure projection**, off the
/// one seeded snapshot. Not a hand-built state: a hand-built one is a second
/// fixture, and it drifts the first time a projection changes.
List<Override> seededScreenOverrides({
  required AppLocalizations l10n,
  Locale locale = const Locale('en'),
}) {
  final snapshot = seededHistory();
  final schedule = seededSchedule();
  return <Override>[
    ...seededPlanOverrides(locale: locale),
    todayViewProvider.overrideWith(
      () => _FixedToday(
        TodayNotifier.project(
          snapshot: snapshot,
          schedule: schedule,
          date: seededToday,
          l10n: l10n,
          locale: locale,
        ),
      ),
    ),
    scheduleViewProvider(seededStep.index).overrideWith(
      () => _FixedSchedule(
        ScheduleNotifier.project(
          snapshot: snapshot,
          schedule: schedule,
          stepIndex: seededStep.index,
          today: seededToday,
          l10n: l10n,
          locale: locale,
        ),
      ),
    ),
    progressViewProvider.overrideWith(
      () => _FixedProgress(
        ProgressNotifier.project(
          snapshot: snapshot,
          schedule: schedule,
          today: seededToday,
          l10n: l10n,
          locale: locale,
        ),
      ),
    ),
  ];
}

class _FixedToday extends StreamNotifier<TodayViewState>
    implements TodayNotifier {
  _FixedToday(this._state);

  final TodayViewState _state;

  @override
  Stream<TodayViewState> build() => Stream<TodayViewState>.value(_state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixedSchedule extends ScheduleNotifier {
  _FixedSchedule(this._state) : super(0);

  final ScheduleViewState _state;

  @override
  Stream<ScheduleViewState> build() => Stream<ScheduleViewState>.value(_state);
}

class _FixedProgress extends StreamNotifier<ProgressViewState>
    implements ProgressNotifier {
  _FixedProgress(this._state);

  final ProgressViewState _state;

  @override
  Stream<ProgressViewState> build() => Stream<ProgressViewState>.value(_state);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
