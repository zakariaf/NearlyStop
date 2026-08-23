/// Today's state: the stream, the projection, and the writes.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/step_size.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:nearlystop/l10n/bidi.dart';
import 'package:nearlystop/l10n/date_formats.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';

/// Today's screen state.
final StreamNotifierProvider<TodayNotifier, TodayViewState> todayViewProvider =
    StreamNotifierProvider<TodayNotifier, TodayViewState>(TodayNotifier.new);

/// Composes today's date, the derived schedule and the logs into one value.
///
/// **It re-derives nothing.** `derivedScheduleProvider` already ran
/// `generateSchedule` once in the app layer (CONTRACTS.md §4); this reads it.
/// A second call here would be a second answer, and the two would diverge on
/// the day somebody changed one.
///
/// **It owns no timer and no lifecycle hook.** EPIC-06's `DayTicker` holds the
/// only one, and invalidating `todayDateProvider` is what rebuilds this. A
/// second ticker would double-fire the resume handler.
class TodayNotifier extends StreamNotifier<TodayViewState> {
  @override
  Stream<TodayViewState> build() {
    final date = ref.watch(todayDateProvider);
    final schedule = ref.watch(derivedScheduleProvider);
    final l10n = ref.watch(appLocalizationsProvider);
    final locale = ref.watch(resolvedLocaleProvider);
    final repository = ref.watch(taperRepositoryProvider);

    final days = switch (schedule) {
      Ok<List<DayPlan>, Failure>(:final value) => value,
      // A derivation failure is not an empty schedule. The stream below still
      // has to produce something, and `TodayNoPlan` is the honest answer: we
      // cannot say what to take, so we do not say anything about a dose.
      Err<List<DayPlan>, Failure>() => const <DayPlan>[],
    };

    return repository
        .watchSnapshot()
        // A plan that EXISTS but has produced no schedule yet is mid-LOAD, not
        // "you have no plan". `derivedScheduleProvider` returns an empty list
        // before its first emission, and projecting that would flash "Your
        // plan starts here" at somebody who has been on a taper for a year.
        // Skipping the emission leaves the screen in `AsyncLoading` until the
        // derivation lands and `ref.watch` rebuilds this.
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
              date: date,
              l10n: l10n,
              locale: locale,
            ),
            // Rethrown so the `AsyncValue` carries the error arm rather than
            // a fabricated "no plan" — the screen must be able to tell "you
            // have no plan" from "we could not read your plan".
            // `StorageFailure` is a `Failure`, not an `Exception` — the typed
            // spine deliberately does not extend it. `AsyncValue` carries any
            // Object, so the arm is preserved either way, and wrapping it in an
            // exception would lose the type the screen switches on.
            // ignore: only_throw_errors
            Err<TaperSnapshot, StorageFailure>(:final failure) => throw failure,
          },
        );
  }

  // ---------------------------------------------------------------- writes
  //
  // Every one goes through `TaperRepository`. No mutation touches a DAO, and
  // none keeps a local flag: the write commits, the watched stream re-emits,
  // and every other surface — Schedule's row state, Progress's total, the
  // notification's payload — sees the same fact without re-deriving it. A
  // shortcut here becomes a divergence bug two years into a taper, by which
  // time the evidence is gone.

  /// Ticks today.
  Future<void> markTakenToday() async {
    final date = ref.read(todayDateProvider);
    await _write(
      (repository) => repository.markTaken(date, plannedMg: _planned(date)),
    );
  }

  /// Ticks an earlier day, with THAT day's planned dose.
  ///
  /// Not today's. Backfilling an earlier day with today's number records the
  /// wrong dose against it, and the cumulative total is wrong forever.
  Future<void> backfill(LocalDate date) async {
    await _write(
      (repository) => repository.markTaken(date, plannedMg: _planned(date)),
    );
  }

  /// Un-ticks today.
  Future<void> undoLast() async {
    final date = ref.read(todayDateProvider);
    await _write((repository) => repository.undoTaken(date));
  }

  /// Saves — or clears — today's note.
  ///
  /// Carries `plannedMg` because a note may be the first thing that creates
  /// the row, and `DoseLogs.plannedMg` is non-null (CONTRACTS.md §3).
  Future<void> saveNote(String? text) async {
    final date = ref.read(todayDateProvider);
    await _write(
      (repository) => repository.setNote(date, text, plannedMg: _planned(date)),
    );
  }

  /// Records a flare, reverting to a dose the reader CHOSE.
  ///
  /// Two arguments, per CONTRACTS.md §3. The next-step size the reader picked
  /// reaches storage through the plan/step path, not through here.
  Future<void> recordFlare(Milligrams revertTo) async {
    final date = ref.read(todayDateProvider);
    await _write(
      (repository) => repository.recordFlare(on: date, revertTo: revertTo),
    );
  }

  /// Holds the active step for [extraDays] more days.
  ///
  /// Out-of-range values are refused HERE, before any write. 28 is the ceiling
  /// because a longer stall is a plan change rather than a hold, and a
  /// database that rejected it would be a crash instead of an answer.
  Future<void> recordHold(int extraDays) async {
    final current = state.hasValue ? state.requireValue : null;
    final prompt = switch (current) {
      TodayDose(:final hold) => hold,
      TodayStepFinished(:final hold) => hold,
      TodayNoPlan() || TodayTaperComplete() || null => null,
    };
    if (prompt == null) return;
    if (extraDays < prompt.minExtraDays || extraDays > prompt.maxExtraDays) {
      return;
    }
    final date = ref.read(todayDateProvider);
    await _write(
      (repository) => repository.recordHold(
        stepId: prompt.stepId,
        from: date,
        extraDays: extraDays,
      ),
    );
  }

  /// Begins the next step.
  Future<void> startNextStep() async {
    await _write((repository) => repository.startNextStep());
  }

  /// Today's planned dose, from the derivation the screen already holds.
  ///
  /// The repository does not run the generator, so the caller supplies this.
  Milligrams _planned(LocalDate date) {
    final derived = ref.read(derivedScheduleProvider);
    final days = switch (derived) {
      Ok<List<DayPlan>, Failure>(:final value) => value,
      Err<List<DayPlan>, Failure>() => const <DayPlan>[],
    };
    for (final day in days) {
      if (day.date == date) return day.dose;
    }
    return Milligrams.zero;
  }

  /// Runs a write and reports a failure WITHOUT disturbing the dose.
  ///
  /// The failure goes to [todayWriteFailureProvider], not into `state`. Two
  /// reasons, and the second is the one that matters:
  ///
  /// * Riverpod 3 made `AsyncValue.copyWithPrevious` `@internal`, so the
  ///   "error arm that still carries the previous value" trick the epic
  ///   describes is no longer public API to reach for.
  /// * A write failing is not the READ stream saying something. Putting it
  ///   through the same channel is exactly what makes the dose vanish when a
  ///   tick fails — and a reader who taps Taken and loses the number they
  ///   opened the app for has lost more than the write.
  ///
  /// So the dose stays where it was, `AsyncData` and untouched, and the screen
  /// shows the failure beside it.
  Future<void> _write(
    Future<Result<void, StorageFailure>> Function(TaperRepository) action,
  ) async {
    final result = await action(ref.read(taperRepositoryProvider));
    ref.read(todayWriteFailureProvider.notifier).recordOutcome(result);
  }

  /// Facts in, one view state out.
  ///
  /// A **pure static function** so it is unit-testable with no container: the
  /// whole of this epic's branching lives here, and it takes nine cases to
  /// cover. Formatting happens here too, where the locale is known — never in
  /// a widget.
  @visibleForTesting
  static TodayViewState project({
    required TaperSnapshot snapshot,
    required List<DayPlan> schedule,
    required LocalDate date,
    required AppLocalizations l10n,
    required Locale locale,
  }) {
    final plan = snapshot.plan;
    if (plan == null || schedule.isEmpty) return const TodayNoPlan();

    final today = _dayFor(schedule, date);
    if (today == null) return const TodayNoPlan();

    final logsByDate = <LocalDate, DoseLogFacts>{
      for (final log in snapshot.logs) log.date: log,
    };
    final taken = logsByDate[date]?.taken ?? false;
    final step = _stepFor(snapshot.steps, today.stepIndex);
    final tablets = _renderTablets(today, locale);

    // Target reached: the generator keeps emitting steady-state days at the
    // target rather than stepping negative (SPEC.md §7), so "complete" is a
    // question about the DOSE, not about running out of days.
    if (today.dose <= plan.targetDose) return const TodayTaperComplete();

    final flare = _flarePrompt(snapshot, plan, today, l10n, locale);
    final hold = _holdPrompt(snapshot, today, l10n, locale);
    final stepFinished =
        today.kind == DayKind.steadyState &&
        step != null &&
        (snapshot.statusByStepId[step.id] ?? step.status) ==
            StepStatus.completed;

    if (stepFinished) {
      return TodayStepFinished(
        dateLine: formatFullDayLabel(date, locale),
        doseAmount: formatDose(today.dose, locale),
        doseUnit: l10n.milligramUnit,
        tablets: tablets.text,
        unachievableMessage: tablets.flag,
        taken: taken,
        stepIndex: _localizedInt(step.index + 1, locale),
        stepCount: _localizedInt(snapshot.steps.length, locale),
        nextStepPreview: _nextStepPreview(plan, today.dose, locale, l10n),
        canStartNextStep: true,
        flare: flare,
        hold: hold,
      );
    }

    final isSteadyState = today.kind == DayKind.steadyState;
    return TodayDose(
      dateLine: formatFullDayLabel(date, locale),
      doseAmount: formatDose(today.dose, locale),
      doseUnit: l10n.milligramUnit,
      tablets: tablets.text,
      unachievableMessage: tablets.flag,
      isNewDoseDay: today.isNewDose,
      taken: taken,
      stepIndex: _localizedInt((step?.index ?? today.stepIndex) + 1, locale),
      stepCount: _localizedInt(snapshot.steps.length, locale),
      fromDose: _dose(step?.fromDose ?? today.dose, locale, l10n),
      toDose: _dose(step?.toDose ?? today.dose, locale, l10n),
      dayInStep: isSteadyState
          ? null
          : _localizedInt(today.dayInStep ?? 0, locale),
      stepLength: isSteadyState ? null : _localizedInt(_stepLength, locale),
      isSteadyState: isSteadyState,
      holdingLabel: isSteadyState
          ? l10n.holdingAtDose(_dose(today.dose, locale, l10n))
          : null,
      backfill: _backfill(schedule, logsByDate, plan, date, l10n, locale),
      noteText: logsByDate[date]?.note,
      flare: flare,
      hold: hold,
    );
  }

  /// A DSNS step is 52 days (SPEC.md §3.1).
  static const int _stepLength = 52;

  /// Eleven blocks per step (SPEC.md §3.1's table).
  static const int _blockCount = 11;

  static DayPlan? _dayFor(List<DayPlan> schedule, LocalDate date) {
    for (final day in schedule) {
      if (day.date == date) return day;
    }
    return null;
  }

  static StepFacts? _stepFor(List<StepFacts> steps, int index) {
    for (final step in steps) {
      if (step.index == index) return step;
    }
    return steps.isEmpty ? null : steps.last;
  }

  /// The tablet breakdown, or the flag that replaces it.
  ///
  /// Exactly one of the two is non-null. An unachievable dose is FLAGGED with
  /// its exact value and never rounded — CLAUDE.md rule 5, the one unforgivable
  /// bug.
  static ({String? text, String? flag}) _renderTablets(
    DayPlan day,
    Locale locale,
  ) => switch (day.composition) {
    Ok<TabletComposition, DomainFailure>(:final value) => (
      text: _composition(value, locale),
      flag: null,
    ),
    Err<TabletComposition, DomainFailure>() => (
      text: null,
      flag: lookupAppLocalizations(
        locale,
      ).doseNotAchievable(formatDose(day.dose, locale)),
    ),
  };

  /// "1 × 5mg · 4 × 1mg", isolated for a Perso-Arabic sentence.
  ///
  /// The whole run is LTR — a count, a multiplication sign and a Latin unit —
  /// so without an isolate it reorders inside a Persian line and reports the
  /// wrong count against the wrong strength.
  static String _composition(TabletComposition composition, Locale locale) {
    final parts = <String>[
      for (final count in composition.counts)
        _tabletPart(count.count, count.strength, locale),
      if (composition.half case final half?)
        '½ × ${formatDose(half.strength, locale)}mg',
    ];
    return isolateLtr(parts.join(' · '));
  }

  /// "4 × 1mg" — a count, a multiplication sign, a strength.
  static String _tabletPart(int count, Milligrams strength, Locale locale) {
    final counted = _localizedInt(count, locale);
    return '$counted × ${formatDose(strength, locale)}mg';
  }

  static String _dose(Milligrams dose, Locale locale, AppLocalizations l10n) =>
      '${formatDose(dose, locale)}${l10n.milligramUnit}';

  static String _localizedInt(int value, Locale locale) =>
      numberFormatFor(locale).format(value);

  /// "9mg → 8.5mg" — what starting the next step would do.
  static String _nextStepPreview(
    TaperPlanFacts plan,
    Milligrams current,
    Locale locale,
    AppLocalizations l10n,
  ) {
    final suggestion = suggestStep(
      currentDose: current,
      targetDose: plan.targetDose,
      strengths: plan.tabletStrengths,
      allowHalves: plan.allowHalves,
    );
    final next = switch (suggestion) {
      Ok<StepSuggestion, DomainFailure>(:final value) =>
        current - value.suggested,
      Err<StepSuggestion, DomainFailure>() => current,
    };
    return isolateLtr(
      '${_dose(current, locale, l10n)} → ${_dose(next, locale, l10n)}',
    );
  }

  /// The trailing run of un-ticked past days.
  ///
  /// **The run, not the lifetime total.** A day that WAS ticked terminates it:
  /// prompting every morning about a day missed three months ago, for the rest
  /// of a two-year taper, is not a prompt.
  static BackfillPrompt? _backfill(
    List<DayPlan> schedule,
    Map<LocalDate, DoseLogFacts> logs,
    TaperPlanFacts plan,
    LocalDate date,
    AppLocalizations l10n,
    Locale locale,
  ) {
    final planned = <LocalDate>{for (final day in schedule) day.date};
    var count = 0;
    var oldest = date;
    for (var cursor = date.addDays(-1); ; cursor = cursor.addDays(-1)) {
      // Days before the plan started were never the reader's to tick.
      if (cursor < plan.startDate) break;
      if (!planned.contains(cursor)) break;
      if (logs[cursor]?.taken ?? false) break;
      count++;
      oldest = cursor;
    }
    if (count == 0) return null;
    return BackfillPrompt(
      oldest: oldest,
      count: count,
      label: l10n.nDaysNotTicked(count),
    );
  }

  /// The doses this person has actually been on, newest first.
  static FlarePrompt _flarePrompt(
    TaperSnapshot snapshot,
    TaperPlanFacts plan,
    DayPlan today,
    AppLocalizations l10n,
    Locale locale,
  ) {
    final completed =
        <StepFacts>[
            for (final step in snapshot.steps)
              if ((snapshot.statusByStepId[step.id] ?? step.status) ==
                  StepStatus.completed)
                step,
          ]
          // Newest first: the most recent dose that worked is the one they are
          // most likely to want.
          ..sort((a, b) => b.index.compareTo(a.index));

    // Sorted by index so "the step after this one" is findable, which is what
    // says when a step actually ENDED. A step that was held ran longer than 52
    // days, and a label built from the nominal length tells the reader they
    // were on that dose over dates they were not — while they are choosing a
    // dose to go back to from exactly these labels.
    final byIndex = <StepFacts>[...snapshot.steps]
      ..sort((a, b) => a.index.compareTo(b.index));
    LocalDate endOf(StepFacts step) {
      for (final other in byIndex) {
        if (other.index == step.index + 1) return other.startDate;
      }
      return step.startDate.addDays(_stepLength);
    }

    final candidates = <FlareCandidate>[
      for (final step in completed)
        FlareCandidate(
          dose: step.fromDose,
          label: l10n.flareDateRange(
            _dose(step.fromDose, locale, l10n),
            formatDayLabel(step.startDate, locale),
            formatDayLabel(endOf(step), locale),
          ),
        ),
    ];

    final defaultRevertTo = candidates.isEmpty
        ? today.dose
        : candidates.first.dose;
    final suggestion = suggestStep(
      currentDose: defaultRevertTo,
      targetDose: plan.targetDose,
      strengths: plan.tabletStrengths,
      allowHalves: plan.allowHalves,
    );
    return FlarePrompt(
      candidates: candidates,
      defaultRevertTo: defaultRevertTo,
      suggestedStep: switch (suggestion) {
        Ok<StepSuggestion, DomainFailure>(:final value) => value.suggested,
        Err<StepSuggestion, DomainFailure>() => Milligrams.zero,
      },
      stepDiffersFromCommunity: switch (suggestion) {
        Ok<StepSuggestion, DomainFailure>(:final value) =>
          value.communityPracticeDiffers,
        Err<StepSuggestion, DomainFailure>() => false,
      },
    );
  }

  /// What the hold sheet calls the thing being held.
  ///
  /// On a steady-state day `blockIndex` is null, and `?? 1` printed "Block 1
  /// of 11" — the FIRST block, on a day that is past the last one. The reader
  /// opening that sheet was told they were somewhere they were not, on the
  /// screen asking them to decide about it. With no block, the STEP is the
  /// honest unit.
  static String _blockLabel(
    DayPlan day,
    StepFacts step,
    AppLocalizations l10n,
  ) {
    final block = day.blockIndex;
    if (block == null) return l10n.stepOfTotal(step.index + 1, step.index + 1);
    return l10n.blockOfTotal(block, _blockCount);
  }

  /// Null when no step is running — there is nothing to hold.
  static HoldPrompt? _holdPrompt(
    TaperSnapshot snapshot,
    DayPlan today,
    AppLocalizations l10n,
    Locale locale,
  ) {
    for (final step in snapshot.steps) {
      final status = snapshot.statusByStepId[step.id] ?? step.status;
      if (status != StepStatus.active) continue;
      return HoldPrompt(
        stepId: step.id,
        // `blockOfTotal` takes ints and does its own locale-aware number
        // formatting, so the digits are right without being formatted twice.
        blockLabel: _blockLabel(today, step, l10n),
        defaultExtraDays: 7,
        minExtraDays: 1,
        maxExtraDays: 28,
      );
    }
    return null;
  }
}

/// The last write failure, or null.
///
/// **Separate from [todayViewProvider] on purpose.** A failed tick must not
/// take the dose off the screen, and the read stream is not the place to say
/// that a write went wrong.
final NotifierProvider<TodayWriteFailure, StorageFailure?>
todayWriteFailureProvider =
    NotifierProvider<TodayWriteFailure, StorageFailure?>(
      TodayWriteFailure.new,
    );

/// Holds the last write failure, so the screen can show it beside the dose.
class TodayWriteFailure extends Notifier<StorageFailure?> {
  @override
  StorageFailure? build() => null;

  /// Records the outcome of a write.
  ///
  /// Takes the `Result` rather than a nullable failure, so the "success clears
  /// the last error" rule lives here once instead of at every call site — and
  /// so a caller cannot report a failure and forget to clear it.
  void recordOutcome(Result<void, StorageFailure> result) {
    state = switch (result) {
      Ok<void, StorageFailure>() => null,
      Err<void, StorageFailure>(:final failure) => failure,
    };
  }
}
