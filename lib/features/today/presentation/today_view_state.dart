/// The whole Today screen as one immutable value.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// What the Today screen is showing.
///
/// **Sealed, with exactly four variants**, so the widget layer renders it with
/// an exhaustive `switch` and not a single conditional over a domain type. A
/// fifth variant is a compile error at every call site, which is how a new
/// state gets rendered rather than silently falling through to the happy one.
///
/// Every field is a **pre-formatted, pre-localized `String`**. Formatting lives
/// in the projection where the locale is known; a widget that formatted a dose
/// would need to know about locales, and then the same rounding lives in two
/// places.
@immutable
sealed class TodayViewState {
  const TodayViewState();
}

/// There is no plan yet — day zero.
final class TodayNoPlan extends TodayViewState {
  /// Creates the empty state.
  const TodayNoPlan();

  @override
  bool operator ==(Object other) => other is TodayNoPlan;

  @override
  int get hashCode => (TodayNoPlan).hashCode;
}

/// The taper reached its target.
///
/// `SPEC.md` §7: the taper ends cleanly. The generator keeps emitting
/// steady-state days at the target dose rather than stepping negative, and this
/// is the variant that says so.
final class TodayTaperComplete extends TodayViewState {
  /// Creates the finish state.
  const TodayTaperComplete();

  @override
  bool operator ==(Object other) => other is TodayTaperComplete;

  @override
  int get hashCode => (TodayTaperComplete).hashCode;
}

/// The ordinary day: a dose to take.
final class TodayDose extends TodayViewState {
  /// Creates today's dose.
  const TodayDose({
    required this.dateLine,
    required this.doseAmount,
    required this.doseUnit,
    required this.tablets,
    required this.unachievableMessage,
    required this.isNewDoseDay,
    required this.taken,
    required this.stepIndex,
    required this.stepCount,
    required this.fromDose,
    required this.toDose,
    required this.dayInStep,
    required this.stepLength,
    required this.isSteadyState,
    required this.holdingLabel,
    required this.backfill,
    required this.noteText,
    required this.flare,
    required this.hold,
  }) : assert(
         (tablets == null) == (unachievableMessage != null),
         'a null breakdown MUST carry its unachievableMessage, and a message '
         'MUST replace the breakdown. SPEC.md 3.3: an unachievable dose is '
         'flagged, never rounded — and never shown beside a breakdown that '
         'invites the reader to take it anyway.',
       ),
       assert(
         !isSteadyState || (dayInStep == null && stepLength == null),
         'a steady-state day has no dayInStep to format. `blockIndex` and '
         '`dayInStep` are null upstream on those days, and formatting them '
         'anyway is how "Day 0 of 52" reaches a screen.',
       ),
       assert(
         isSteadyState == (holdingLabel != null),
         'a steady-state day needs its holding label, and only a steady-state '
         'day has one — the context line has nothing else to print there.',
       );

  /// "Wednesday 16 April", already localized and in the active calendar.
  final String dateLine;

  /// The dose, in the locale's digits — Persian renders `۹`.
  final String doseAmount;

  /// The unit beside it.
  final String doseUnit;

  /// `1 × 5mg · 4 × 1mg`, or null when the composition is unachievable.
  final String? tablets;

  /// Why the dose cannot be made, when [tablets] is null.
  final String? unachievableMessage;

  /// Whether today takes the step's new dose.
  final bool isNewDoseDay;

  /// Whether it has been ticked.
  final bool taken;

  /// "3", already localized.
  final String stepIndex;

  /// "15", already localized.
  final String stepCount;

  /// "10mg", the dose this step steps down from.
  final String fromDose;

  /// "9mg", the dose it steps down to.
  final String toDose;

  /// "14", or null on a steady-state day.
  final String? dayInStep;

  /// "52", or null on a steady-state day.
  final String? stepLength;

  /// Whether today is a steady-state day that is not the end of a step.
  ///
  /// The context line then reads [holdingLabel] instead of "Day 14 of 52".
  final bool isSteadyState;

  /// "Holding at 9mg", already localized — null unless [isSteadyState].
  ///
  /// Carried rather than composed in the widget for the same reason every
  /// other string here is: the locale is known in the projection and nowhere
  /// else, and a widget that formatted it would be a widget that has to know
  /// about numeral systems.
  final String? holdingLabel;

  /// The trailing run of un-ticked past days, or null when there is none.
  final BackfillPrompt? backfill;

  /// Today's note, if one was written.
  final String? noteText;

  /// Everything the flare sheet needs.
  final FlarePrompt flare;

  /// Everything the hold sheet needs, or null when no step is active.
  final HoldPrompt? hold;

  List<Object?> get _props => <Object?>[
    dateLine,
    doseAmount,
    doseUnit,
    tablets,
    unachievableMessage,
    isNewDoseDay,
    taken,
    stepIndex,
    stepCount,
    fromDose,
    toDose,
    dayInStep,
    stepLength,
    isSteadyState,
    holdingLabel,
    backfill,
    noteText,
    flare,
    hold,
  ];

  @override
  bool operator ==(Object other) =>
      other is TodayDose && _listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

/// This step's days are used up and the next one has not been started.
///
/// **Without this variant day 53 of a 780-day taper renders nothing.** On those
/// dates the generator returns a steady-state day at the step's `toDose`, so
/// there is still a real dose to take — this variant carries it, plus the
/// *Start next step* action and the one-line explanation.
final class TodayStepFinished extends TodayViewState {
  /// Creates the step-finished state.
  const TodayStepFinished({
    required this.dateLine,
    required this.doseAmount,
    required this.doseUnit,
    required this.tablets,
    required this.unachievableMessage,
    required this.taken,
    required this.stepIndex,
    required this.stepCount,
    required this.nextStepPreview,
    required this.canStartNextStep,
    required this.flare,
    required this.hold,
  }) : assert(
         (tablets == null) == (unachievableMessage != null),
         'a null breakdown MUST carry its unachievableMessage (SPEC.md 3.3)',
       );

  /// "Wednesday 16 April", already localized.
  final String dateLine;

  /// The dose, in the locale's digits.
  final String doseAmount;

  /// The unit beside it.
  final String doseUnit;

  /// The tablet breakdown, or null when unachievable.
  final String? tablets;

  /// Why the dose cannot be made, when [tablets] is null.
  final String? unachievableMessage;

  /// Whether today has been ticked. Day 53 is still a day to tick.
  final bool taken;

  /// "3", already localized.
  final String stepIndex;

  /// "15", already localized.
  final String stepCount;

  /// "9mg → 8.5mg", pre-formatted.
  final String nextStepPreview;

  /// Whether the next step can be started now.
  final bool canStartNextStep;

  /// Everything the flare sheet needs.
  final FlarePrompt flare;

  /// Everything the hold sheet needs, or null when no step is active.
  final HoldPrompt? hold;

  List<Object?> get _props => <Object?>[
    dateLine,
    doseAmount,
    doseUnit,
    tablets,
    unachievableMessage,
    taken,
    stepIndex,
    stepCount,
    nextStepPreview,
    canStartNextStep,
    flare,
    hold,
  ];

  @override
  bool operator ==(Object other) =>
      other is TodayStepFinished && _listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

/// The trailing run of past days with no `taken` log.
///
/// **The run, not the lifetime total.** A day that WAS ticked terminates it: an
/// un-ticked day from three months ago is not something to prompt about every
/// morning for the rest of the taper.
@immutable
final class BackfillPrompt {
  /// Creates the prompt.
  const BackfillPrompt({
    required this.oldest,
    required this.count,
    required this.label,
  }) : assert(count > 0, 'a prompt for zero days is a banner with no reason');

  /// The earliest day in the run.
  final LocalDate oldest;

  /// How many days the run is.
  final int count;

  /// The localized sentence, already pluralised in the active locale.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is BackfillPrompt &&
      other.oldest == oldest &&
      other.count == count &&
      other.label == label;

  @override
  int get hashCode => Object.hash(oldest, count, label);
}

/// One dose the person has actually been on.
@immutable
final class FlareCandidate {
  /// Creates a candidate.
  const FlareCandidate({required this.dose, required this.label});

  /// The dose to revert to.
  final Milligrams dose;

  /// "9mg — from 3 March to 24 April", already localized.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is FlareCandidate && other.dose == dose && other.label == label;

  @override
  int get hashCode => Object.hash(dose, label);
}

/// Everything the flare sheet needs to let the reader CHOOSE.
///
/// "Go back to the last dose that worked" is a judgement, not a value the app
/// holds — so the sheet lists the doses they have actually been on rather than
/// picking one for them. `SPEC.md` §5.2 names the hardcoded two-button dialog
/// as the thing every competitor gets wrong.
@immutable
final class FlarePrompt {
  /// Creates the prompt.
  const FlarePrompt({
    required this.candidates,
    required this.defaultRevertTo,
    required this.suggestedStep,
    required this.stepDiffersFromCommunity,
  });

  /// Prior step doses, newest first.
  final List<FlareCandidate> candidates;

  /// The previous step's `fromDose` — preselected, not imposed.
  final Milligrams defaultRevertTo;

  /// What `suggestStep` proposes from [defaultRevertTo].
  final Milligrams suggestedStep;

  /// Whether that suggestion differs from community practice, which the sheet
  /// says out loud rather than quietly resolving.
  final bool stepDiffersFromCommunity;

  @override
  bool operator ==(Object other) =>
      other is FlarePrompt &&
      _listEquals(other.candidates, candidates) &&
      other.defaultRevertTo == defaultRevertTo &&
      other.suggestedStep == suggestedStep &&
      other.stepDiffersFromCommunity == stepDiffersFromCommunity;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(candidates),
    defaultRevertTo,
    suggestedStep,
    stepDiffersFromCommunity,
  );
}

/// Everything the hold sheet needs.
@immutable
final class HoldPrompt {
  /// Creates the prompt.
  const HoldPrompt({
    required this.stepId,
    required this.blockLabel,
    required this.defaultExtraDays,
    required this.minExtraDays,
    required this.maxExtraDays,
  }) : assert(
         minExtraDays <= maxExtraDays,
         'an inverted range offers the reader nothing to pick',
       ),
       assert(
         defaultExtraDays >= minExtraDays && defaultExtraDays <= maxExtraDays,
         'the default has to be inside the range the stepper allows',
       );

  /// The active step to hold.
  final int stepId;

  /// "Block 3 of 11", already localized.
  final String blockLabel;

  /// 7 — a week is the unit people think in.
  final int defaultExtraDays;

  /// 1.
  final int minExtraDays;

  /// 28. A longer stall is a plan change, not a hold.
  final int maxExtraDays;

  @override
  bool operator ==(Object other) =>
      other is HoldPrompt &&
      other.stepId == stepId &&
      other.blockLabel == blockLabel &&
      other.defaultExtraDays == defaultExtraDays &&
      other.minExtraDays == minExtraDays &&
      other.maxExtraDays == maxExtraDays;

  @override
  int get hashCode => Object.hash(
    stepId,
    blockLabel,
    defaultExtraDays,
    minExtraDays,
    maxExtraDays,
  );
}

/// Element-wise list equality.
///
/// Hand-rolled rather than `package:collection`'s: this file is pure data and
/// takes no dependency it does not need, which is what lets it be tested with
/// `package:test` alone.
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
