// Never colour alone, stated as sharply as it can be stated.
//
// The sharpest form of the claim is not "the four states have four colours
// that differ enough". It is: **hold the colour constant and the four states
// are still four states.** A palette-gap test says the current colours happen
// to separate; this says the app does not depend on them separating.
//
// The desaturation and CVD simulation passes are HUMAN, over task 12's stills.
// They are named in the sign-off and are deliberately not faked into a green
// test that would only assert an image was written.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_marker.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/primitives.dart';

void main() {
  test('with ONE colour for all four, the states are still four states', () {
    // The whole claim, in one assertion. Every state painted in the same ink,
    // and the descriptors still have to be pairwise distinct.
    final shapes = <DayState, DayStateShape>{
      for (final state in DayState.values) state: DayStateShape.forState(state),
    };

    final seen = <String, DayState>{};
    for (final MapEntry<DayState, DayStateShape>(key: state, value: shape)
        in shapes.entries) {
      // The descriptor, with colour deliberately absent from it — that is what
      // makes this a shape claim rather than a palette one.
      final descriptor =
          'filled=${shape.filled} stroke=${shape.strokeWidth} '
          'dashed=${shape.dashed} core=${shape.hasCore}';
      expect(
        seen,
        isNot(contains(descriptor)),
        reason:
            '${state.name} and ${seen[descriptor]?.name} paint the same shape, '
            'so only colour tells them apart',
      );
      seen[descriptor] = state;
    }

    expect(seen, hasLength(DayState.values.length));
  });

  test('every state has a shape AND a stroke weight of its own', () {
    // Three separate expectations rather than one, so a missing signal names
    // itself instead of hiding inside a compound boolean.
    for (final state in DayState.values) {
      final shape = DayStateShape.forState(state);

      expect(
        shape.filled || shape.strokeWidth > 0,
        isTrue,
        reason: '${state.name} paints nothing at all',
      );
      expect(
        shape.strokeWidth,
        greaterThanOrEqualTo(0),
        reason: '${state.name} has a negative stroke',
      );
    }
  });

  test('a missed dose is warm taupe, and is never red', () {
    // CONTRACTS §9, and one copy-paste away from being undone. Missing a dose
    // in a two-year taper is ordinary; painting it in `danger` tells somebody
    // who forgot once that they have done something dangerous.
    for (final palette in <(String, DaybreakColors)>[
      ('light', lightDaybreakColors),
      ('dark', darkDaybreakColors),
    ]) {
      expect(
        palette.$2.stateMissed,
        isNot(palette.$2.danger),
        reason: 'a missed dose reads as danger in ${palette.$1}',
      );
    }
    expect(lightDaybreakColors.stateMissed, Primitives.clay56);
  });
}
