/// Stored facts → `DayPlan`s. **One derivation, app-wide.**
library;

import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:riverpod/riverpod.dart';

/// The repository's watched snapshot, as a Riverpod stream.
final StreamProvider<Result<TaperSnapshot, StorageFailure>>
taperSnapshotProvider = StreamProvider<Result<TaperSnapshot, StorageFailure>>(
  (ref) => ref.watch(taperRepositoryProvider).watchSnapshot(),
);

/// Today, as a calendar date.
///
/// A plain value provider, **not a stream**: the shell's `DayTicker` owns the
/// one timer and invalidates this at local midnight. A screen that built its
/// own timer would fire a second time on resume, and one of the two rollover
/// suites would then be testing nothing.
final Provider<LocalDate> todayDateProvider = Provider<LocalDate>(
  (ref) => LocalDate.fromDateTime(ref.watch(clockProvider).now()),
);

/// The whole schedule, derived.
///
/// **Synchronous.** The generator is pure integer arithmetic over 52–780 days;
/// wrapping it in a `compute()` isolate would add a frame of latency to the
/// app's most important screen for no measurable gain. If EPIC-14's profiling
/// says otherwise, that is where it changes — not here, on a guess.
///
/// Per `CONTRACTS.md` §5 the generator emits a `DayPlan` for **every** date in
/// range — step days, steady-state days between a step's realised end and the
/// next step's start, and steady state at the target dose after the last step.
/// Consumers may therefore assume a lookup by date always hits.
///
/// **Nothing is cached to disk** (`SPEC.md` §6), and no screen re-derives: the
/// per-screen view states are projections *over* this, owned by EPIC-08/09/10.
final Provider<Result<List<DayPlan>, Failure>> derivedScheduleProvider =
    Provider<Result<List<DayPlan>, Failure>>((ref) {
      final snapshot = ref.watch(taperSnapshotProvider);

      return switch (snapshot) {
        AsyncData<Result<TaperSnapshot, StorageFailure>>(:final value) =>
          scheduleFromSnapshot(value),
        AsyncError<Result<TaperSnapshot, StorageFailure>>(:final error) => Err(
          Io(error),
        ),
        // Before the first emission there is nothing to derive. An empty list
        // rather than a failure: a fresh install has no plan, and that is not
        // an error state anyone should be shown.
        _ => const Ok<List<DayPlan>, Failure>(<DayPlan>[]),
      };
    });

/// The ONE derivation, as a function rather than only as a provider.
///
/// [derivedScheduleProvider] is what a screen watches. A caller holding a
/// snapshot it read itself — EPIC-13's export — comes through here, so there
/// is still exactly one place that turns stored facts into `DayPlan`s.
Result<List<DayPlan>, Failure> scheduleFromSnapshot(
  Result<TaperSnapshot, StorageFailure> snapshot,
) => switch (snapshot) {
  Err<TaperSnapshot, StorageFailure>(:final failure) => Err(failure),
  Ok<TaperSnapshot, StorageFailure>(:final value) => switch (value.plan) {
    // No plan at all — a fresh install, or the state after `deletePlan`.
    null => const Ok<List<DayPlan>, Failure>(<DayPlan>[]),
    final plan => generateSchedule(
      plan: plan,
      steps: value.steps,
      flares: value.flares,
      holds: value.holds,
    ),
  },
};

/// The `DayPlan` for [date], or `null` if it is outside the generated range.
///
/// A lookup helper rather than a provider family: the screens want a handful of
/// dates out of one already-derived list, and a family would rebuild the whole
/// derivation per key.
DayPlan? dayPlanFor(List<DayPlan> schedule, LocalDate date) {
  for (final day in schedule) {
    if (day.date == date) return day;
  }
  return null;
}
