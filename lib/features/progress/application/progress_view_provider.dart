/// The Progress screen's state: a staircase and three numbers, formatted.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/app/retry_policy.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/l10n/date_formats.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';

/// Everything the Progress screen shows.
final StreamNotifierProvider<ProgressNotifier, ProgressViewState>
progressViewProvider =
    StreamNotifierProvider<ProgressNotifier, ProgressViewState>(
      ProgressNotifier.new,
      // A refused derivation is a fact about the plan, not a flaky read.
      retry: retryTransientOnly,
    );

/// Projects stored facts into the staircase, the numbers and the sentences.
///
/// **This notifier formats; it does not compute.** `daysOnSteroids`,
/// `cumulativeTakenMg` and `adherence` are pure, tested and shipped in
/// `lib/core/dsns/cumulative.dart` (EPIC-04), and EPIC-13's export calls the
/// same functions. Re-deriving any of them here would put the arithmetic
/// outside that purity gate and let the screen and the export disagree about
/// how many milligrams somebody has taken.
class ProgressNotifier extends StreamNotifier<ProgressViewState> {
  @override
  Stream<ProgressViewState> build() {
    final today = ref.watch(todayDateProvider);
    final schedule = ref.watch(derivedScheduleProvider);
    final l10n = ref.watch(appLocalizationsProvider);
    final locale = ref.watch(resolvedLocaleProvider);
    final repository = ref.watch(taperRepositoryProvider);

    final List<DayPlan> days;
    switch (schedule) {
      case Ok<List<DayPlan>, Failure>(:final value):
        days = value;
      // A REFUSAL, not an empty plan. Swallowing it leaves the screen in a
      // skeleton with no timeout behind it — the defect EPIC-09 found on
      // Today and Schedule, and the same shape here.
      case Err<List<DayPlan>, Failure>(:final failure):
        return Stream<ProgressViewState>.error(failure);
    }

    return repository
        .watchSnapshot()
        // A plan that exists with nothing derived yet is mid-load, not a
        // plan with no history.
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

  /// Facts in, one screen out.
  @visibleForTesting
  static ProgressViewState project({
    required TaperSnapshot snapshot,
    required List<DayPlan> schedule,
    required LocalDate today,
    required AppLocalizations l10n,
    required Locale locale,
  }) {
    final plan = snapshot.plan;
    if (plan == null || schedule.isEmpty) return const ProgressNoPlan();

    final elapsed = <DayPlan>[
      for (final day in schedule)
        if (day.date <= today) day,
    ];
    final days = elapsed.isEmpty ? <DayPlan>[schedule.first] : elapsed;
    final segments = reduceToSegments(days);
    final numbers = numberFormatFor(locale);

    final flares = <FlareMark>[
      for (final flare in _sortedFlares(snapshot.flares))
        FlareMark(
          dayIndex: flare.date.difference(plan.startDate),
          dose: flare.revertToDose,
          label: l10n.historyFlareRow(
            formatFullDayLabel(flare.date, locale),
            formatDose(flare.revertToDose, locale),
          ),
        ),
    ];
    final holds = <HoldMark>[
      for (final hold in _sortedHolds(snapshot.holds))
        HoldMark(
          dayIndex: hold.fromDate.difference(plan.startDate),
          days: hold.extraDays,
          dose: _doseOn(days, hold.fromDate) ?? plan.startingDose,
          label: l10n.historyHoldRow(
            formatDose(
              _doseOn(days, hold.fromDate) ?? plan.startingDose,
              locale,
            ),
            hold.extraDays,
            formatFullDayLabel(hold.fromDate, locale),
          ),
        ),
    ];

    final currentDose = days.last.dose;
    final delta = Milligrams.fromHundredths(
      plan.startingDose.hundredths - currentDose.hundredths,
    );

    return ProgressLoaded(
      segments: segments,
      flares: flares,
      holds: holds,
      todayDayIndex: days.length - 1,
      todayDose: currentDose,
      axis: ProgressAxis(
        minDose: _extreme(segments, lowest: true),
        maxDose: _extreme(segments, lowest: false),
        firstLabel: formatMonthLabel(days.first.date, locale),
        lastLabel: formatMonthLabel(days.last.date, locale),
      ),
      stats: ProgressStats.from(
        plan: plan,
        logs: snapshot.logs,
        days: days,
        today: today,
        l10n: l10n,
        numbers: numbers,
      ),
      startLine: l10n.startedAt(
        formatFullDayLabel(plan.startDate, locale),
        '${formatDose(plan.startingDose, locale)}${l10n.milligramUnit}',
      ),
      encouragement: delta.hundredths <= 0
          // Never "0mg lower": a person holding steady through a flare is not
          // failing, and a zero stated as a shortfall reads as one.
          ? l10n.sameAsStart
          : l10n.lowerThanStart(
              '${formatDose(delta, locale)}${l10n.milligramUnit}',
            ),
      eventCountLabel: _eventLabel(flares.length, holds.length, l10n),
      chartSummary: _summary(
        segments: segments,
        days: days,
        flares: flares.length,
        holds: holds.length,
        l10n: l10n,
        locale: locale,
      ),
      historyRows: _historyRows(
        segments: segments,
        flares: flares,
        holds: holds,
        start: plan.startDate,
        l10n: l10n,
        locale: locale,
      ),
    );
  }

  static List<FlareEvent> _sortedFlares(List<FlareEvent> flares) =>
      <FlareEvent>[...flares]..sort((a, b) => a.date.compareTo(b.date));

  static List<HoldEvent> _sortedHolds(List<HoldEvent> holds) =>
      <HoldEvent>[...holds]..sort((a, b) => a.fromDate.compareTo(b.fromDate));

  static Milligrams? _doseOn(List<DayPlan> days, LocalDate date) {
    for (final day in days) {
      if (day.date == date) return day.dose;
    }
    return null;
  }

  static Milligrams _extreme(
    List<DoseSegment> segments, {
    required bool lowest,
  }) {
    var best = segments.first.dose;
    for (final segment in segments) {
      final swap = lowest
          ? segment.dose.hundredths < best.hundredths
          : segment.dose.hundredths > best.hundredths;
      if (swap) best = segment.dose;
    }
    return best;
  }

  /// "2 flares and 1 hold recorded" — and never "0 holds".
  static String _eventLabel(int flares, int holds, AppLocalizations l10n) {
    if (flares == 0 && holds == 0) return l10n.noEventsRecorded;
    if (holds == 0) return l10n.flaresRecorded(flares);
    if (flares == 0) return l10n.holdsRecorded(holds);
    return l10n.flaresAndHoldsRecorded(flares, holds);
  }

  static String _summary({
    required List<DoseSegment> segments,
    required List<DayPlan> days,
    required int flares,
    required int holds,
    required AppLocalizations l10n,
    required Locale locale,
  }) {
    final events = flares == 0 && holds == 0
        ? ''
        : l10n.chartSummaryEvents(_eventLabel(flares, holds, l10n));
    return l10n.chartSummary(
      formatDose(segments.first.dose, locale),
      formatMonthLabel(days.first.date, locale),
      formatDose(segments.last.dose, locale),
      formatMonthLabel(days.last.date, locale),
      events,
    );
  }

  /// Every tread, flare and hold as a sentence, **in date order**.
  ///
  /// Interleaved rather than appended, because a list that puts the events
  /// after the treads tells a screen-reader user the flare happened at the end.
  static List<String> _historyRows({
    required List<DoseSegment> segments,
    required List<FlareMark> flares,
    required List<HoldMark> holds,
    required LocalDate start,
    required AppLocalizations l10n,
    required Locale locale,
  }) {
    final rows =
        <({int dayIndex, int rank, String text})>[
          for (final segment in segments)
            (
              dayIndex: segment.startDayIndex,
              rank: 0,
              text: l10n.historySegmentRow(
                formatDose(segment.dose, locale),
                formatFullDayLabel(
                  start.addDays(segment.startDayIndex),
                  locale,
                ),
                segment.length,
              ),
            ),
          for (final flare in flares)
            (dayIndex: flare.dayIndex, rank: 1, text: flare.label),
          for (final hold in holds)
            (dayIndex: hold.dayIndex, rank: 1, text: hold.label),
        ]..sort((a, b) {
          final byDay = a.dayIndex.compareTo(b.dayIndex);
          // An event on a tread's first day is reported AFTER the tread, so
          // the reader hears the dose before the thing that changed it.
          return byDay != 0 ? byDay : a.rank.compareTo(b.rank);
        });
    return <String>[for (final row in rows) row.text];
  }
}
