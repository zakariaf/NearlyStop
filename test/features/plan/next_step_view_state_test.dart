// The next-step card's numbers, as `f(input) → output`.
//
// The engine's own rule table is EPIC-04's. What this pins is that the card
// renders **the engine's return value** and nothing it recomputed — the
// failure mode being a `to` derived from `tenPercent`, which is a different
// number for ten of the fifteen steps.
import 'package:nearlystop/core/dsns/step_size.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/plan/presentation/next_step_view_state.dart';
import 'package:test/test.dart';

void main() {
  Milligrams mg(num value) => Milligrams.fromHundredths((value * 100).round());

  test('the pair is current − SUGGESTED, never current − tenPercent', () {
    // 9mg with 5mg + 1mg and halves: 10% is 0.9mg, the largest achievable
    // increment under it is 0.5mg. A `to` from `tenPercent` gives 8.1mg — a
    // dose nobody can make out of the tablets they hold.
    final state = NextStepViewState.from(
      StepSuggestion(
        suggested: mg(0.5),
        tenPercent: mg(0.9),
        communityPracticeDiffers: true,
      ),
      current: mg(9),
      target: Milligrams.zero,
    );

    expect(state.from, mg(9));
    expect(state.to, mg(8.5));
    expect(state.suggested, mg(0.5));
    expect(state.showsCaveat, isTrue);
  });

  test('an override wins, and the engine’s figure is still reported', () {
    // SPEC 3.2: a default the user can override, never a lock. They see both
    // numbers — the app's suggestion and the one their doctor gave them.
    final state = NextStepViewState.from(
      StepSuggestion(
        suggested: mg(0.5),
        tenPercent: mg(0.9),
        communityPracticeDiffers: true,
      ),
      current: mg(9),
      target: Milligrams.zero,
      override: mg(1),
    );

    expect(state.to, mg(8));
    expect(state.suggested, mg(0.5), reason: 'the engine’s figure is hidden');
  });

  test('a step that would overshoot is CLAMPED to the target', () {
    final state = NextStepViewState.from(
      StepSuggestion(
        suggested: mg(0.5),
        tenPercent: mg(0.05),
        communityPracticeDiffers: true,
      ),
      current: mg(0.5),
      target: Milligrams.zero,
    );

    expect(state.to, Milligrams.zero);
    expect(state.clampedToTarget, isTrue);
  });

  test('at the target the card is COMPLETE, not a zero-length step', () {
    final state = NextStepViewState.from(
      const StepSuggestion(
        suggested: Milligrams.zero,
        tenPercent: Milligrams.zero,
        communityPracticeDiffers: false,
      ),
      current: Milligrams.zero,
      target: Milligrams.zero,
    );

    expect(state.isComplete, isTrue);
    expect(state.canStartNextStep, isFalse);
  });

  test('no input produces a negative dose', () {
    // Swept rather than asserted once: the clamp has to hold for every dose
    // and every step, and a negative milligram is a number this app must never
    // be able to render.
    for (var hundredths = 50; hundredths <= 1500; hundredths += 25) {
      for (final step in <int>[50, 100, 250, 5000]) {
        final state = NextStepViewState.from(
          StepSuggestion(
            suggested: Milligrams.fromHundredths(step),
            tenPercent: Milligrams.fromHundredths(hundredths ~/ 10),
            communityPracticeDiffers: false,
          ),
          current: Milligrams.fromHundredths(hundredths),
          target: Milligrams.zero,
        );

        expect(
          state.to.hundredths,
          greaterThanOrEqualTo(0),
          reason: '${hundredths}h − ${step}h went negative',
        );
        expect(state.to.hundredths, lessThanOrEqualTo(hundredths));
      }
    }
  });

  test('the caveat follows the engine’s own flag, not a recomputation', () {
    for (final differs in <bool>[true, false]) {
      final state = NextStepViewState.from(
        StepSuggestion(
          suggested: mg(1),
          tenPercent: mg(1),
          communityPracticeDiffers: differs,
        ),
        current: mg(10),
        target: Milligrams.zero,
      );
      expect(state.showsCaveat, differs, reason: '$differs');
    }
  });
}
