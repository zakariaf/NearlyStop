/// The in-progress edit of a taper plan, held apart from the persisted one.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/step_size.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/plan/domain/default_strengths.dart';
import 'package:nearlystop/features/plan/presentation/next_step_view_state.dart';

/// The editable facts, plus the step override.
///
/// A draft is **never** the persisted row. Mutating it writes nothing; `save`
/// is the only path to storage, and discarding is a matter of throwing the
/// draft away — which is what makes "I changed my mind" cost nothing on the
/// screen where a wrong keystroke costs two years of history.
@immutable
final class PlanDraft {
  /// Creates a draft.
  const PlanDraft({
    required this.drugName,
    required this.startDate,
    required this.currentDose,
    required this.targetDose,
    required this.strengths,
    required this.allowHalves,
    required this.method,
    this.percentage,
    this.fixedStep,
    this.holdPeriodDays = TaperPlanFacts.dsnsHoldPeriodDays,
    this.stepOverride,
  });

  /// Free text. Defaults to the region's own name for the drug.
  final String drugName;

  /// The plan's first day, and its first step's.
  final LocalDate startDate;

  /// The dose they are on now.
  final Milligrams currentDose;

  /// The dose they are heading for.
  final Milligrams targetDose;

  /// What they actually hold, **sorted and deduplicated**.
  final List<Milligrams> strengths;

  /// Whether they can split a tablet.
  final bool allowHalves;

  /// Which arithmetic.
  final TaperMethod method;

  /// Percent per step, for [TaperMethod.percentage].
  final int? percentage;

  /// A fixed step, for [TaperMethod.fixedMg].
  final Milligrams? fixedStep;

  /// Days a non-DSNS step holds the new dose.
  final int holdPeriodDays;

  /// The step the user chose instead of the suggestion. **Wins** (SPEC §3.2).
  final Milligrams? stepOverride;

  /// This draft with the named fields replaced.
  PlanDraft copyWith({
    String? drugName,
    LocalDate? startDate,
    Milligrams? currentDose,
    Milligrams? targetDose,
    List<Milligrams>? strengths,
    bool? allowHalves,
    TaperMethod? method,
    int? percentage,
    Milligrams? fixedStep,
    int? holdPeriodDays,
    Milligrams? stepOverride,
    bool clearOverride = false,
  }) => PlanDraft(
    drugName: drugName ?? this.drugName,
    startDate: startDate ?? this.startDate,
    currentDose: currentDose ?? this.currentDose,
    targetDose: targetDose ?? this.targetDose,
    strengths: strengths == null ? this.strengths : sortedStrengths(strengths),
    allowHalves: allowHalves ?? this.allowHalves,
    method: method ?? this.method,
    percentage: percentage ?? this.percentage,
    fixedStep: fixedStep ?? this.fixedStep,
    holdPeriodDays: holdPeriodDays ?? this.holdPeriodDays,
    stepOverride: clearOverride ? null : (stepOverride ?? this.stepOverride),
  );

  @override
  bool operator ==(Object other) =>
      other is PlanDraft &&
      other.drugName == drugName &&
      other.startDate == startDate &&
      other.currentDose == currentDose &&
      other.targetDose == targetDose &&
      other.allowHalves == allowHalves &&
      other.method == method &&
      other.percentage == percentage &&
      other.fixedStep == fixedStep &&
      other.holdPeriodDays == holdPeriodDays &&
      other.stepOverride == stepOverride &&
      listEquals(other.strengths, strengths);

  @override
  int get hashCode => Object.hash(
    drugName,
    startDate,
    currentDose,
    targetDose,
    Object.hashAll(strengths),
    allowHalves,
    method,
    percentage,
    fixedStep,
    holdPeriodDays,
    stepOverride,
  );
}

/// Sorted ascending and deduplicated — what the column stores.
///
/// `[5, 1, 5]mg` is `[1, 5]mg`. A duplicate strength changes nothing about
/// what can be composed and everything about how the chip row reads.
List<Milligrams> sortedStrengths(Iterable<Milligrams> raw) {
  final unique = <int>{for (final value in raw) value.hundredths}.toList()
    ..sort();
  return <Milligrams>[
    for (final value in unique) Milligrams.fromHundredths(value),
  ];
}

/// The draft being edited.
final NotifierProvider<PlanEditorNotifier, PlanDraft> planEditorProvider =
    NotifierProvider<PlanEditorNotifier, PlanDraft>(PlanEditorNotifier.new);

/// Holds the draft, and is the only thing that writes it.
class PlanEditorNotifier extends Notifier<PlanDraft> {
  /// Whether the user has touched the draft.
  ///
  /// Once they have, a later snapshot — from a tick, a note, anything — must
  /// not overwrite what they were typing. Before they have, the draft follows
  /// the stored plan so opening the screen shows reality.
  bool _touched = false;

  /// Whether anything has been edited since the draft was seeded.
  bool get isDirty => _touched;

  @override
  PlanDraft build() {
    final snapshot = ref.watch(taperSnapshotProvider);
    final locale = ref.watch(resolvedLocaleProvider);
    final today = ref.watch(todayDateProvider);

    if (_touched && stateOrNull != null) return state;

    final plan = switch (snapshot) {
      AsyncData<Result<TaperSnapshot, StorageFailure>>(:final value) =>
        switch (value) {
          Ok<TaperSnapshot, StorageFailure>(value: final facts) => facts.plan,
          Err<TaperSnapshot, StorageFailure>() => null,
        },
      _ => null,
    };

    if (plan == null) {
      final defaults = defaultsFor(locale.languageCode, locale.countryCode);
      return PlanDraft(
        drugName: defaults.drugName,
        startDate: today,
        currentDose: const Milligrams.fromHundredths(1000),
        targetDose: Milligrams.zero,
        strengths: defaults.strengths,
        allowHalves: true,
        method: TaperMethod.dsns,
      );
    }

    return PlanDraft(
      drugName: plan.drugName,
      startDate: plan.startDate,
      currentDose: plan.startingDose,
      targetDose: plan.targetDose,
      strengths: sortedStrengths(
        plan.tabletStrengths.map(
          (strength) => Milligrams.fromHundredths(strength.hundredths),
        ),
      ),
      allowHalves: plan.allowHalves,
      method: plan.method,
      percentage: plan.percentage,
      fixedStep: plan.fixedStep,
      holdPeriodDays: plan.holdPeriodDays,
    );
  }

  /// Replaces the draft, marking it touched.
  void edit(PlanDraft Function(PlanDraft) change) {
    final next = change(state);
    _touched = true;
    if (next == state) return;
    state = next;
  }

  /// Throws the edit away and follows the stored plan again.
  void discard() {
    _touched = false;
    ref.invalidateSelf();
  }

  /// The engine's suggestion for this draft, or null when it refuses.
  ///
  /// Pure, and read straight from EPIC-04: nothing here recomputes a step
  /// size, because a second answer is the one that ends up on the card.
  NextStepViewState? preview() {
    final suggestion = suggestStep(
      currentDose: state.currentDose,
      targetDose: state.targetDose,
      strengths: <TabletStrength>[
        for (final strength in state.strengths) TabletStrength(strength),
      ],
      allowHalves: state.allowHalves,
    );
    return switch (suggestion) {
      Ok<StepSuggestion, DomainFailure>(:final value) => NextStepViewState.from(
        value,
        current: state.currentDose,
        target: state.targetDose,
        override: state.stepOverride,
      ),
      Err<StepSuggestion, DomainFailure>() => null,
    };
  }

  /// Writes the draft. **The only path to storage.**
  ///
  /// EPIC-05's `savePlan` inserts `Step 0` in the same transaction when the
  /// plan has no steps (CONTRACTS §7) — without it nothing anywhere creates a
  /// first step, `generateSchedule` gets an empty list, and Today, Schedule
  /// and Progress all render empty for ever. What this method owns is passing
  /// the suggested-or-overridden step size into the draft it hands over.
  Future<Result<void, StorageFailure>> save() async {
    final step = state.stepOverride ?? preview()?.suggested;
    if (step == null || step.hundredths <= 0) {
      return const Err(Io('no achievable step for these strengths'));
    }
    final repository = ref.read(taperRepositoryProvider);
    // Read from the snapshot this notifier ALREADY watches, not from a fresh
    // `watchSnapshot().first`. A second subscription is a second drift query
    // whose first emission is not guaranteed to have seen the write that came
    // before it — and getting this wrong routes an EDIT down the create path,
    // which inserts a second plan rather than refusing.
    final existing = switch (ref.read(taperSnapshotProvider)) {
      AsyncData<Result<TaperSnapshot, StorageFailure>>(:final value) =>
        switch (value) {
          Ok<TaperSnapshot, StorageFailure>(value: final facts) => facts.plan,
          Err<TaperSnapshot, StorageFailure>() => null,
        },
      _ => null,
    };

    final draft = TaperPlanDraft(
      drugName: state.drugName.trim(),
      startDate: state.startDate,
      currentDose: state.currentDose,
      targetDose: state.targetDose,
      strengths: state.strengths,
      allowHalves: state.allowHalves,
      method: state.method,
      stepSize: step,
      percentage: state.percentage,
      fixedStep: state.fixedStep,
      holdPeriodDays: state.holdPeriodDays,
    );

    // An EDIT, not a re-create: `updatePlanFacts` appends no step and touches
    // no `DoseLog`, so a prescription change recomposes future days and leaves
    // every day already swallowed exactly as it was recorded (SPEC §5.2).
    final result = existing == null
        ? await repository.savePlan(draft)
        : await repository.updatePlanFacts(draft);
    if (result is Ok) _touched = false;
    return result;
  }
}
