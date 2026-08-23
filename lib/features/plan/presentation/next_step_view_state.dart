/// The next-step card's numbers.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/dsns/step_size.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// What the next-step card renders.
///
/// **The pair is the ENGINE's return value.** `suggestStep` already decided
/// what is achievable out of the tablets the person holds; deriving the `to`
/// from `tenPercent` instead gives a dose they cannot make, and for ten of the
/// fifteen steps in a 15mg taper those two numbers are different.
@immutable
final class NextStepViewState {
  /// Creates the projection.
  const NextStepViewState({
    required this.from,
    required this.to,
    required this.suggested,
    required this.tenPercent,
    required this.showsCaveat,
    required this.clampedToTarget,
    required this.isComplete,
  });

  /// Projects [suggestion] onto the card, honouring [override].
  factory NextStepViewState.from(
    StepSuggestion suggestion, {
    required Milligrams current,
    required Milligrams target,
    Milligrams? override,
  }) {
    final complete = current.hundredths <= target.hundredths;
    // SPEC 3.2: the suggestion is a DEFAULT the user can override, never a
    // lock. The doctor's instruction wins, and the card shows both numbers.
    final step = override ?? suggestion.suggested;
    final raw = current.hundredths - step.hundredths;
    final landed = raw <= target.hundredths;
    return NextStepViewState(
      from: current,
      to: Milligrams.fromHundredths(landed ? target.hundredths : raw),
      suggested: suggestion.suggested,
      tenPercent: suggestion.tenPercent,
      showsCaveat: suggestion.communityPracticeDiffers && !complete,
      // "Reaches the target", not "was shortened": a step that lands exactly
      // on it is the last one, and the card says so either way.
      clampedToTarget: landed && !complete,
      isComplete: complete,
    );
  }

  /// The dose the step starts from.
  final Milligrams from;

  /// The dose it ends at, never below the target and never negative.
  final Milligrams to;

  /// What the engine suggested, reported even when overridden.
  final Milligrams suggested;

  /// The strict 10% figure, for the caveat's sentence.
  final Milligrams tenPercent;

  /// Whether community practice and the 10% rule disagree here.
  final bool showsCaveat;

  /// Whether this step reaches the target — shortened to it, or landing on it
  /// exactly. Either way it is the last one, and the card says so.
  final bool clampedToTarget;

  /// Whether the taper is already at its target.
  final bool isComplete;

  /// Whether there is a next step to start at all.
  bool get canStartNextStep => !isComplete;

  @override
  bool operator ==(Object other) =>
      other is NextStepViewState &&
      other.from == from &&
      other.to == to &&
      other.suggested == suggested &&
      other.tenPercent == tenPercent &&
      other.showsCaveat == showsCaveat &&
      other.clampedToTarget == clampedToTarget &&
      other.isComplete == isComplete;

  @override
  int get hashCode => Object.hash(
    from,
    to,
    suggested,
    tenPercent,
    showsCaveat,
    clampedToTarget,
    isComplete,
  );
}
