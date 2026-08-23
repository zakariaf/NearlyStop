/// The Schedule's state: one step's blocks, and the two writes.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/app/retry_policy.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/dsns_pattern.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/l10n/bidi.dart';
import 'package:nearlystop/l10n/date_formats.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:riverpod/misc.dart' show StreamNotifierProviderFamily;

/// Why a tick was refused.
///
/// **Typed, and never a silent no-op.** A tap that does nothing and says
/// nothing teaches the reader that the app is broken.
enum ScheduleRefusal {
  /// The day is in a step that is already finished.
  readOnly,

  /// The day has not happened yet.
  futureDay,
}

/// The step the reader is in, for the screen's default argument.
final Provider<int> currentStepIndexProvider = Provider<int>((ref) {
  final snapshot = ref.watch(taperSnapshotProvider);
  return switch (snapshot) {
    AsyncData<Result<TaperSnapshot, StorageFailure>>(:final value) =>
      switch (value) {
        Ok<TaperSnapshot, StorageFailure>(value: final facts) => _activeIndex(
          facts,
        ),
        Err<TaperSnapshot, StorageFailure>() => 0,
      },
    _ => 0,
  };
});

int _activeIndex(TaperSnapshot facts) {
  for (final step in facts.steps) {
    if ((facts.statusByStepId[step.id] ?? step.status) == StepStatus.active) {
      return step.index;
    }
  }
  return facts.steps.isEmpty ? 0 : facts.steps.last.index;
}

/// The step the reader has BROWSED to, or null to follow the active step.
///
/// Null rather than "the active index" so the screen keeps following the
/// active step as it advances. A reader who opened the app in step 3 and left
/// it open across midnight into step 4 should see step 4.
final NotifierProvider<BrowsedStep, int?> browsedStepProvider =
    NotifierProvider<BrowsedStep, int?>(BrowsedStep.new);

/// Holds which step the switcher last chose.
class BrowsedStep extends Notifier<int?> {
  @override
  int? build() => null;

  /// Browses [index], read-only unless it happens to be the active step.
  void show(int index) {
    if (state == index) return;
    state = index;
  }

  /// Goes back to following whichever step is running.
  void followActive() => state = null;
}

/// The day the list is centred on, or null for today.
///
/// Set from `/schedule?focus=<iso>` and cleared by jump-to-today. A provider
/// rather than screen state because the deep link and the control both write
/// it, and the list is rebuilt from scratch when it changes.
final NotifierProvider<ScheduleFocus, LocalDate?> scheduleFocusProvider =
    NotifierProvider<ScheduleFocus, LocalDate?>(ScheduleFocus.new);

/// Holds the focused day.
class ScheduleFocus extends Notifier<LocalDate?> {
  @override
  LocalDate? build() => null;

  /// Centres the list on [date].
  void focus(LocalDate date) {
    if (state == date) return;
    state = date;
  }

  /// Goes back to centring on today.
  void clear() => state = null;
}

/// The step actually on screen.
final Provider<int> shownStepIndexProvider = Provider<int>(
  (ref) =>
      ref.watch(browsedStepProvider) ?? ref.watch(currentStepIndexProvider),
);

/// Which step every generated date belongs to.
///
/// The lookup `?focus=<iso>` needs and nothing more. A date the plan has never
/// heard of is simply absent, which is what makes the deep link's fallback a
/// map miss rather than an exception — a deep link is user input.
final Provider<Map<LocalDate, int>> scheduleFocusDatesProvider =
    Provider<Map<LocalDate, int>>((ref) {
      final derived = ref.watch(derivedScheduleProvider);
      return switch (derived) {
        Ok<List<DayPlan>, Failure>(:final value) => <LocalDate, int>{
          for (final day in value) day.date: day.stepIndex,
        },
        Err<List<DayPlan>, Failure>() => const <LocalDate, int>{},
      };
    });

/// Every step, as the switcher offers it.
final Provider<List<StepOption>> scheduleStepOptionsProvider =
    Provider<List<StepOption>>((ref) {
      final snapshot = ref.watch(taperSnapshotProvider);
      final l10n = ref.watch(appLocalizationsProvider);
      final locale = ref.watch(resolvedLocaleProvider);
      final facts = switch (snapshot) {
        AsyncData<Result<TaperSnapshot, StorageFailure>>(:final value) =>
          switch (value) {
            Ok<TaperSnapshot, StorageFailure>(value: final data) => data,
            Err<TaperSnapshot, StorageFailure>() => null,
          },
        _ => null,
      };
      if (facts == null) return const <StepOption>[];

      final steps = <StepFacts>[...facts.steps]
        ..sort((a, b) => a.index.compareTo(b.index));
      return <StepOption>[
        for (final step in steps)
          StepOption(
            index: step.index,
            label: l10n.stepRangeLabel(
              step.index + 1,
              steps.length,
              ScheduleNotifier.doseText(step.fromDose, locale, l10n),
              ScheduleNotifier.doseText(step.toDose, locale, l10n),
            ),
            status: facts.statusByStepId[step.id] ?? step.status,
          ),
      ];
    });

/// One step's schedule, keyed by step index.
final StreamNotifierProviderFamily<ScheduleNotifier, ScheduleViewState, int>
scheduleViewProvider =
    StreamNotifierProvider.family<ScheduleNotifier, ScheduleViewState, int>(
      ScheduleNotifier.new,
      // A refused derivation is a fact about the plan, not a flaky read.
      retry: retryTransientOnly,
    );

/// Selects one step out of the already-derived schedule and groups it.
///
/// **It does not call `generateSchedule`.** EPIC-06's `derivedScheduleProvider`
/// ran it once in the app layer; running it again here would be a second
/// answer, and the two would diverge the day somebody changed one. Nothing is
/// cached in the repository either — the repository returns facts
/// (CONTRACTS.md §4).
class ScheduleNotifier extends StreamNotifier<ScheduleViewState> {
  /// Creates the notifier for one step.
  ///
  /// Riverpod 3 hands a family's argument to the CONSTRUCTOR, not to `build`.
  ScheduleNotifier(this.stepIndex);

  /// Which step this notifier is showing.
  final int stepIndex;

  @override
  Stream<ScheduleViewState> build() {
    final today = ref.watch(todayDateProvider);
    final schedule = ref.watch(derivedScheduleProvider);
    final l10n = ref.watch(appLocalizationsProvider);
    final locale = ref.watch(resolvedLocaleProvider);
    final repository = ref.watch(taperRepositoryProvider);

    final List<DayPlan> days;
    switch (schedule) {
      case Ok<List<DayPlan>, Failure>(:final value):
        days = value;
      // A REFUSAL, not an empty schedule. Swallowing it into `const []` makes
      // it indistinguishable from "derived nothing yet", and the mid-load
      // guard below then filters the emission away for ever: the skeleton
      // stays up, and a stream that never emits has no timeout to save it.
      case Err<List<DayPlan>, Failure>(:final failure):
        return Stream<ScheduleViewState>.error(failure);
    }

    return repository
        .watchSnapshot()
        // A plan that exists with nothing derived yet is mid-load, not an
        // empty schedule — the same flash EPIC-08 found on Today.
        .where(
          (result) => switch (result) {
            Ok<TaperSnapshot, StorageFailure>(:final value) =>
              value.plan == null || days.isNotEmpty,
            Err<TaperSnapshot, StorageFailure>() => true,
          },
        )
        .map(
          (result) => switch (result) {
            Ok<TaperSnapshot, StorageFailure>(:final value) => project(
              snapshot: value,
              schedule: days,
              stepIndex: stepIndex,
              today: today,
              l10n: l10n,
              locale: locale,
            ),
            // `StorageFailure` is a `Failure`, not an `Exception` — the typed
            // spine does not extend it, and wrapping it would lose the type
            // the screen switches on.
            // ignore: only_throw_errors
            Err<TaperSnapshot, StorageFailure>(:final failure) => throw failure,
          },
        );
  }

  /// Ticks a past day of the active step.
  ///
  /// Returns the reason when it refuses. **Never a silent no-op**: a tap that
  /// does nothing and says nothing teaches the reader the app is broken.
  Future<ScheduleRefusal?> markTaken(
    LocalDate date, {
    required Milligrams plannedMg,
  }) => _guarded(
    date,
    (repository) => repository.markTaken(date, plannedMg: plannedMg),
  );

  /// Un-ticks a day of the active step.
  Future<ScheduleRefusal?> undoTaken(LocalDate date) =>
      _guarded(date, (repository) => repository.undoTaken(date));

  Future<ScheduleRefusal?> _guarded(
    LocalDate date,
    Future<Result<void, StorageFailure>> Function(TaperRepository) action,
  ) async {
    final refusal = refuse(date);
    if (refusal != null) return refusal;
    await action(ref.read(taperRepositoryProvider));
    return null;
  }

  /// Why [date] cannot be ticked, or null.
  ///
  /// Exposed so the row can render the reason rather than discovering it on a
  /// tap that goes nowhere.
  @visibleForTesting
  ScheduleRefusal? refuse(LocalDate date) {
    if (date > ref.read(todayDateProvider)) return ScheduleRefusal.futureDay;
    final loaded = state.hasValue ? state.requireValue : null;
    if (loaded is ScheduleLoaded && !loaded.steps.isActive) {
      return ScheduleRefusal.readOnly;
    }
    // Before the first emission there is nothing to judge against, and the
    // step index is the only thing known.
    if (loaded == null && stepIndex != ref.read(currentStepIndexProvider)) {
      return ScheduleRefusal.readOnly;
    }
    return null;
  }

  /// Facts in, one step's blocks out.
  @visibleForTesting
  static ScheduleViewState project({
    required TaperSnapshot snapshot,
    required List<DayPlan> schedule,
    required int stepIndex,
    required LocalDate today,
    required AppLocalizations l10n,
    required Locale locale,
  }) {
    final plan = snapshot.plan;
    if (plan == null || schedule.isEmpty) return const ScheduleNoPlan();

    final steps = <StepFacts>[...snapshot.steps]
      ..sort((a, b) => a.index.compareTo(b.index));
    if (steps.isEmpty) return const ScheduleNoPlan();

    final step = steps.firstWhere(
      (candidate) => candidate.index == stepIndex,
      orElse: () => steps.last,
    );
    final status = snapshot.statusByStepId[step.id] ?? step.status;
    final logs = <LocalDate, DoseLogFacts>{
      for (final log in snapshot.logs) log.date: log,
    };
    final isActive = status == StepStatus.active;

    final days = <DayPlan>[
      for (final day in schedule)
        if (day.stepIndex == step.index) day,
    ];

    // Grouped by block, in order, with a trailing group for the days that
    // belong to no block. Every date the generator emitted lands in exactly
    // one group, which is what makes the list cover the whole step.
    final byBlock = <int?, List<DayPlan>>{};
    for (final day in days) {
      byBlock.putIfAbsent(day.blockIndex, () => <DayPlan>[]).add(day);
    }
    final numbered = <int>[for (final key in byBlock.keys) ?key]..sort();

    final blocks = <ScheduleBlockVm>[
      for (final number in numbered)
        _block(
          number: number,
          days: byBlock[number]!,
          step: step,
          isActive: isActive,
          today: today,
          logs: logs,
          l10n: l10n,
          locale: locale,
        ),
      if (byBlock[null] case final steady?)
        ScheduleBlockVm(
          blockNumber: null,
          title: l10n.steadyStateTitle(_dose(step.toDose, locale, l10n)),
          summary: '',
          status: _statusFor(steady, today),
          days: <ScheduleDayVm>[
            for (final day in steady)
              _row(
                day: day,
                isActive: isActive,
                today: today,
                logs: logs,
                l10n: l10n,
                locale: locale,
              ),
          ],
        ),
    ];

    return ScheduleLoaded(
      steps: StepNav(
        index: step.index,
        total: steps.length,
        hasPrevious: step.index > 0,
        hasNext: step.index < steps.length - 1,
        isActive: isActive,
      ),
      blocks: blocks,
      todayLocator: _locate(blocks, today),
    );
  }

  static ScheduleBlockVm _block({
    required int number,
    required List<DayPlan> days,
    required StepFacts step,
    required bool isActive,
    required LocalDate today,
    required Map<LocalDate, DoseLogFacts> logs,
    required AppLocalizations l10n,
    required Locale locale,
  }) => ScheduleBlockVm(
    blockNumber: number,
    title: l10n.blockOfTotal(number, _pattern.blocks.length),
    summary: blockSummary(
      number: number,
      newDose: step.toDose,
      oldDose: step.fromDose,
      l10n: l10n,
      locale: locale,
    ),
    status: _statusFor(days, today),
    days: <ScheduleDayVm>[
      for (final day in days)
        _row(
          day: day,
          isActive: isActive,
          today: today,
          logs: logs,
          l10n: l10n,
          locale: locale,
        ),
    ],
  );

  /// The block's teaching sentence, read off the BLOCK TABLE.
  ///
  /// Never hardcoded, and never "the new dose always leads": blocks 7–11
  /// invert, so the OLD dose becomes the single day (SPEC.md §3.1). A summary
  /// that always named the new dose first would be wrong for five of eleven.
  @visibleForTesting
  static String blockSummary({
    required int number,
    required Milligrams newDose,
    required Milligrams oldDose,
    required AppLocalizations l10n,
    required Locale locale,
  }) {
    final block = _pattern.blocks[number - 1];
    // Whichever half is the SINGLE day leads. In blocks 1–6 that is the new
    // dose; from 7 on it is the old one.
    final newLeads = block.newDays <= block.oldDays;
    return l10n.blockSummary(
      newLeads ? block.newDays : block.oldDays,
      _dose(newLeads ? newDose : oldDose, locale, l10n),
      newLeads ? block.oldDays : block.newDays,
      _dose(newLeads ? oldDose : newDose, locale, l10n),
    );
  }

  static const DsnsPattern _pattern = DsnsPattern.v1();

  static BlockStatus _statusFor(List<DayPlan> days, LocalDate today) {
    if (days.last.date < today) return BlockStatus.completed;
    if (days.first.date > today) return BlockStatus.upcoming;
    return BlockStatus.current;
  }

  static (int, int)? _locate(List<ScheduleBlockVm> blocks, LocalDate today) {
    for (var block = 0; block < blocks.length; block++) {
      final days = blocks[block].days;
      for (var day = 0; day < days.length; day++) {
        if (days[day].date == today) return (block, day);
      }
    }
    return null;
  }

  /// One row, joined against what was recorded.
  static ScheduleDayVm _row({
    required DayPlan day,
    required bool isActive,
    required LocalDate today,
    required Map<LocalDate, DoseLogFacts> logs,
    required AppLocalizations l10n,
    required Locale locale,
  }) {
    final log = logs[day.date];
    final taken = log?.taken ?? false;

    // **The SPEC.md §5.2 join.** A taken row is labelled from the DoseLog's
    // recorded `actualMg`; every other row from the derived plan. The
    // generator recomposes all days from the plan's CURRENT strengths, so a
    // past row rendered from it would silently rewrite itself to a breakdown
    // the person never took — every time the prescription changes.
    final source = taken ? log!.actualMg : day.dose;
    final composition = taken
        ? composeTablets(
            target: log!.actualMg,
            strengths: _recordedStrengths(log),
            allowHalves: true,
          )
        : day.composition;

    final tablets = switch (composition) {
      Ok<TabletComposition, DomainFailure>(:final value) => (
        text: _composition(value, locale, l10n),
        unachievable: false,
      ),
      Err<TabletComposition, DomainFailure>() => (
        text: l10n.doseNotAchievable(formatDose(source, locale)),
        unachievable: true,
      ),
    };

    return ScheduleDayVm(
      date: day.date,
      dayLabel: formatDayLabel(day.date, locale),
      doseLabel: _dose(source, locale, l10n),
      spokenDose: formatDose(source, locale),
      tabletsLabel: tablets.text,
      unachievable: tablets.unachievable,
      state: _stateFor(day.date, today, taken: taken, logged: log != null),
      isNewDose: day.isNewDose,
      isHoldDay: day.isHoldDay,
      // A hold on a steady-state day belongs to no block, and naming one there
      // would be an invented number on the screen whose job is legibility.
      holdLabel: switch ((day.isHoldDay, day.blockIndex)) {
        (false, _) => null,
        (true, final int block) => l10n.heldAtBlock(block),
        (true, _) => l10n.held,
      },
      holdBlockNumber: day.isHoldDay ? day.blockIndex : null,
      tickable: isActive && day.date <= today,
      plannedMg: day.dose,
      recordedSource: taken,
    );
  }

  /// The strengths a recorded dose was composed from.
  ///
  /// EPIC-05 stores `actualMg` but not the composition, so the breakdown is
  /// recomposed — from the RECORDED amount rather than the planned one, which
  /// is the half of SPEC.md §5.2 that is expressible today. When EPIC-13 adds a
  /// recorded composition this reads it instead, and the row stops depending
  /// on the current strengths at all.
  static List<TabletStrength> _recordedStrengths(DoseLogFacts log) =>
      const <TabletStrength>[
        TabletStrength.fromHundredths(500),
        TabletStrength.fromHundredths(100),
      ];

  static DayState _stateFor(
    LocalDate date,
    LocalDate today, {
    required bool taken,
    required bool logged,
  }) {
    if (taken) return DayState.taken;
    if (date == today) return DayState.today;
    if (date < today) return DayState.missed;
    return DayState.upcoming;
  }

  static String _composition(
    TabletComposition composition,
    Locale locale,
    AppLocalizations l10n,
  ) {
    final parts = <String>[
      for (final count in composition.counts)
        _tabletPart(count.count, count.strength, locale),
      if (composition.half case final half?)
        '½ × ${formatDose(half.strength, locale)}mg',
    ];
    // The separator comes from the ARB: frame 3's `.stab` uses a comma, and
    // in Perso-Arabic that comma is U+060C. Isolated as a unit so the whole
    // breakdown keeps its LTR order inside an RTL sentence.
    return isolateLtr(parts.join(l10n.tabletSeparator));
  }

  /// "4 × 1mg" — a count, a multiplication sign, a strength.
  static String _tabletPart(int count, Milligrams strength, Locale locale) {
    final counted = numberFormatFor(locale).format(count);
    return '$counted × ${formatDose(strength, locale)}mg';
  }

  static String _dose(Milligrams dose, Locale locale, AppLocalizations l10n) =>
      doseText(dose, locale, l10n);

  /// "9mg" — a dose with its unit, in the locale's numerals.
  ///
  /// Exposed because the step switcher labels its rows with the same two doses
  /// this projection puts on its blocks, and two spellings of one dose on one
  /// screen is the kind of difference a reader tries to explain.
  static String doseText(
    Milligrams dose,
    Locale locale,
    AppLocalizations l10n,
  ) => '${formatDose(dose, locale)}${l10n.milligramUnit}';
}
