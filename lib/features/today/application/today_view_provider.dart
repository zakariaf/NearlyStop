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

    return repository.watchSnapshot().map(
      (result) => switch (result) {
        Ok<TaperSnapshot, StorageFailure>(:final value) => project(
          snapshot: value,
          schedule: days,
          date: date,
          l10n: l10n,
          locale: locale,
        ),
        // Rethrown so the `AsyncValue` carries the error arm rather than a
        // fabricated "no plan" — the screen must be able to tell "you have no
        // plan" from "we could not read your plan".
        // `StorageFailure` is a `Failure`, not an `Exception` — the typed
        // spine deliberately does not extend it. `AsyncValue` carries any
        // Object, so the arm is preserved either way, and wrapping it in an
        // exception would lose the type the screen switches on.
        // ignore: only_throw_errors
        Err<TaperSnapshot, StorageFailure>(:final failure) => throw failure,
      },
    );
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

    final candidates = <FlareCandidate>[
      for (final step in completed)
        FlareCandidate(
          dose: step.fromDose,
          label: l10n.flareDateRange(
            _dose(step.fromDose, locale, l10n),
            formatDayLabel(step.startDate, locale),
            formatDayLabel(step.startDate.addDays(_stepLength), locale),
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
        blockLabel: l10n.blockOfTotal(today.blockIndex ?? 1, _blockCount),
        defaultExtraDays: 7,
        minExtraDays: 1,
        maxExtraDays: 28,
      );
    }
    return null;
  }
}
