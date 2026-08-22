// Pure `package:test`. The suggestion is a DEFAULT the user overrides, never a
// lock — but it has to have an answer at every dose, including the ten steps
// below 5mg where the strict 10% rule has none.
import 'dart:math';

import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/step_size.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:test/test.dart';

import '../../fixtures/taper_fixture.dart';

StepSuggestion suggested(
  num current, {
  num target = 0,
  List<num> strengths = const [5, 1],
  bool allowHalves = true,
}) {
  final result = suggestStep(
    currentDose: mg(current),
    targetDose: mg(target),
    strengths: held(strengths),
    allowHalves: allowHalves,
  );
  expect(
    result,
    isA<Ok<StepSuggestion, DomainFailure>>(),
    reason: 'current=$current target=$target',
  );
  return (result as Ok<StepSuggestion, DomainFailure>).value;
}

void main() {
  group('strengths [5, 1] with halves, target 0', () {
    // current | tenPercent | suggested | differs | why
    const rows = <(num, num, num, bool, String)>[
      (10, 1.0, 1.0, false, '10% is exactly achievable — no banner'),
      (9, 0.9, 0.5, true, 'largest achievable increment <= 0.9'),
      (7.5, 0.75, 0.5, true, 'largest achievable increment <= 0.75'),
      (5, 0.5, 0.5, false, 'exactly achievable — no banner'),
      (4, 0.4, 0.5, true, 'fallback: nothing <= 0.4 is achievable'),
      (2, 0.2, 0.5, true, 'fallback'),
      (1, 0.1, 0.5, true, 'fallback'),
      (0.5, 0.05, 0.5, true, 'fallback, clamped to the 0.5mg gap to target'),
    ];

    for (final (current, tenPercent, step, differs, why) in rows) {
      test('$current mg -> step $step mg ($why)', () {
        final s = suggested(current);
        expect(s.tenPercent, mg(tenPercent), reason: 'tenPercent');
        expect(s.suggested, mg(step), reason: 'suggested');
        expect(s.communityPracticeDiffers, differs, reason: 'differs');
      });
    }
  });

  group('strengths [5, 1] with halves OFF, target 0', () {
    test('the floor is 1mg, so the fallback returns 1mg', () {
      for (final current in <num>[4, 2, 1]) {
        final s = suggested(current, allowHalves: false);
        expect(s.suggested, mg(1), reason: '$current mg');
        expect(s.communityPracticeDiffers, isTrue, reason: '$current mg');
      }
    });

    test('0.5mg clamps to the 0.5mg gap even though 0.5 is not achievable', () {
      // The clamp is about not stepping past the target; achievability of the
      // clamped value is a separate question, and the resulting dose IS the
      // target, which is always achievable.
      expect(suggested(0.5, allowHalves: false).suggested, mg(0.5));
    });
  });

  test(
    'clamps to the gap, and the divergence flag is judged BEFORE the clamp',
    () {
      // At 10mg the 10% rule WAS satisfiable exactly (1.0mg), so there is no
      // divergence to report; the clamp to the 0.5mg gap is a separate concern
      // and must not light the banner.
      final s = suggested(10, target: 9.5);
      expect(s.suggested, mg(0.5));
      expect(s.tenPercent, mg(1));
      expect(s.communityPracticeDiffers, isFalse);
    },
  );

  test('a completed taper suggests zero', () {
    final s = suggested(5, target: 5);
    expect(s.suggested, Milligrams.zero);
    expect(s.communityPracticeDiffers, isFalse);
  });

  group('refusals', () {
    DomainFailure failureFor({
      required num current,
      required num target,
      List<num> strengths = const [5, 1],
    }) {
      final result = suggestStep(
        currentDose: mg(current),
        targetDose: mg(target),
        strengths: held(strengths),
        allowHalves: true,
      );
      expect(result, isA<Err<StepSuggestion, DomainFailure>>());
      return (result as Err<StepSuggestion, DomainFailure>).failure;
    }

    test('no strengths held', () {
      expect(
        failureFor(current: 10, target: 0, strengths: const <num>[]),
        isA<NoStrengthsHeld>(),
      );
    });

    test('target above start carries both doses', () {
      expect(
        failureFor(current: 5, target: 10),
        isA<TargetAboveStart>()
            .having((f) => f.start, 'start', mg(5))
            .having((f) => f.target, 'target', mg(10)),
      );
    });
  });

  group('nextDose', () {
    test('clamps at the target and never goes negative', () {
      expect(nextDose(mg(10), mg(1), mg(0)), mg(9));
      expect(nextDose(mg(0.5), mg(1), mg(0)), Milligrams.zero);
      expect(nextDose(mg(9), mg(0.5), mg(8.5)), mg(8.5));
    });

    test('never returns a negative dose, even for a negative target', () {
      // Milligrams permits negative hundredths by design and nothing
      // constrains targetDose, so a sign-flipped restore must not produce a
      // step to a dose below zero.
      expect(nextDose(mg(1), mg(5), mg(-2)), Milligrams.zero);
    });
  });

  group('percentageStepSize', () {
    Milligrams sized(num from, int percent) {
      final result = percentageStepSize(
        mg(from),
        percent,
        held([5, 1]),
        allowHalves: true,
      );
      expect(result, isA<Ok<Milligrams, DomainFailure>>());
      return (result as Ok<Milligrams, DomainFailure>).value;
    }

    test('rounds a percentage down to an achievable increment', () {
      // 10% of 20mg is 2mg, which [5, 1] + halves makes exactly.
      expect(sized(20, 10), mg(2));
      // 10% of 9mg is 0.9mg; the largest achievable increment below it is 0.5.
      expect(sized(9, 10), mg(0.5));
    });

    test('falls back to the smallest achievable increment when none fits', () {
      expect(sized(2, 10), mg(0.5));
    });

    test('a percentage of zero or less is a refusal, never a step', () {
      // The fallback exists for "10% permits no achievable step". Letting it
      // fire for an input that means DO NOT STEP hands the patient a taper
      // nobody chose.
      for (final percent in <int>[0, -10]) {
        final result = percentageStepSize(
          mg(10),
          percent,
          held([5, 1]),
          allowHalves: true,
        );
        expect(
          result,
          isA<Err<Milligrams, DomainFailure>>(),
          reason: 'percent=$percent',
        );
        expect(
          (result as Err<Milligrams, DomainFailure>).failure,
          isA<NonPositiveStep>(),
          reason: 'percent=$percent',
        );
      }
    });
  });

  group('fuzz against an independent brute-force oracle', () {
    /// Enumerates achievable increments directly, never through suggestStep.
    bool oracleAchievable(
      int hundredths,
      List<int> strengths, {
      required bool allowHalves,
    }) {
      bool reach(int index, int remaining) {
        if (remaining == 0) return true;
        if (index >= strengths.length) return false;
        for (var count = 0; count * strengths[index] <= remaining; count++) {
          if (reach(index + 1, remaining - count * strengths[index])) {
            return true;
          }
        }
        return false;
      }

      if (reach(0, hundredths)) return true;
      if (!allowHalves) return false;
      for (final s in strengths) {
        if (!s.isEven) continue;
        final rest = hundredths - s ~/ 2;
        if (rest >= 0 && reach(0, rest)) return true;
      }
      return false;
    }

    test('picks the largest achievable <= 10%, or the smallest overall', () {
      final rng = Random(20260421);
      const pool = <num>[0.5, 1, 2, 2.5, 5, 10, 20, 25];
      for (var seed = 0; seed < 1000; seed++) {
        final subset = <num>[
          for (final s in pool)
            if (rng.nextBool()) s,
        ];
        if (subset.isEmpty) subset.add(pool[rng.nextInt(pool.length)]);
        final allowHalves = rng.nextBool();
        final currentHundredths = (rng.nextInt(120) + 1) * 50;
        final targetHundredths = rng.nextInt(currentHundredths ~/ 50 + 1) * 50;
        final strengthHundredths = <int>[
          for (final s in subset) (s * 100).round(),
        ]..sort((a, b) => b.compareTo(a));
        final reason =
            'seed=$seed strengths=$subset halves=$allowHalves '
            'current=$currentHundredths target=$targetHundredths';

        final result = suggestStep(
          currentDose: Milligrams.fromHundredths(currentHundredths),
          targetDose: Milligrams.fromHundredths(targetHundredths),
          strengths: held(subset),
          allowHalves: allowHalves,
        );
        expect(
          result,
          isA<Ok<StepSuggestion, DomainFailure>>(),
          reason: reason,
        );
        final s = (result as Ok<StepSuggestion, DomainFailure>).value;

        expect(
          s.tenPercent.hundredths,
          currentHundredths ~/ 10,
          reason: reason,
        );

        if (currentHundredths == targetHundredths) {
          expect(s.suggested, Milligrams.zero, reason: reason);
          continue;
        }

        int? largestUnderCeiling;
        for (var x = currentHundredths ~/ 10; x >= 1; x--) {
          if (oracleAchievable(
            x,
            strengthHundredths,
            allowHalves: allowHalves,
          )) {
            largestUnderCeiling = x;
            break;
          }
        }
        int? smallestOverall;
        for (var x = 1; x <= currentHundredths; x++) {
          if (oracleAchievable(
            x,
            strengthHundredths,
            allowHalves: allowHalves,
          )) {
            smallestOverall = x;
            break;
          }
        }
        final unclamped = largestUnderCeiling ?? smallestOverall;
        if (unclamped == null) continue; // nothing is achievable at all

        final gap = currentHundredths - targetHundredths;
        expect(
          s.suggested.hundredths,
          unclamped < gap ? unclamped : gap,
          reason: reason,
        );
        expect(
          s.communityPracticeDiffers,
          unclamped != currentHundredths ~/ 10,
          reason: reason,
        );
        expect(s.suggested.hundredths, greaterThan(0), reason: reason);
        expect(s.suggested.hundredths, lessThanOrEqualTo(gap), reason: reason);
      }
    });
  });
}
