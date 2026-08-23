// The staircase's treads.
//
// Pure `package:test`: the reduction takes no locale and no clock, so it is
// tested at the cheapest tier there is. The oracle for every case is the DAY
// LIST the generator emitted — never the reduction's own output, which would
// only prove it agrees with itself.
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:test/test.dart';

import '../../fixtures/taper_fixture.dart';

void main() {
  /// A 15mg → 9mg plan in the 1mg steps SPEC 3.2 mandates above 10mg.
  ///
  /// Six steps, and six steps at two treads each is the reference's twelve.
  List<StepFacts> sixSteps({LocalDate start = const LocalDate(2024, 9, 12)}) {
    final steps = <StepFacts>[];
    var from = 15;
    var day = start;
    for (var index = 0; index < 6; index++) {
      steps.add(
        StepFacts(
          id: index + 1,
          index: index,
          fromDose: mg(from),
          toDose: mg(from - 1),
          startDate: day,
          status: index == 5 ? StepStatus.active : StepStatus.completed,
          patternVersion: 1,
        ),
      );
      from -= 1;
      day = day.addDays(52);
    }
    return steps;
  }

  TaperPlanFacts planFrom(Milligrams start, Milligrams target) =>
      TaperPlanFacts(
        drugName: 'Prednisolone',
        startDate: const LocalDate(2024, 9, 12),
        startingDose: start,
        targetDose: target,
        tabletStrengths: fixtureStrengths,
        allowHalves: true,
        method: TaperMethod.dsns,
      );

  test('six 1mg steps make exactly twelve treads, on the right boundaries', () {
    // The acceptance case, and it is asserted as the FULL list. A length-only
    // check passes on twelve treads in the wrong places, which is the shape of
    // every plausible off-by-one in the crossover.
    final steps = sixSteps();
    final days = generated(
      plan: planFrom(mg(15), mg(9)),
      steps: steps,
      until: steps.last.startDate.addDays(51),
    );

    final segments = reduceToSegments(days);

    expect(segments, hasLength(12));
    for (var step = 0; step < 6; step++) {
      final base = step * 52;
      expect(
        segments[step * 2].startDayIndex,
        base,
        reason: 'step $step does not start where the plan says it does',
      );
      expect(segments[step * 2].dose, steps[step].fromDose);
      expect(
        segments[step * 2 + 1].startDayIndex,
        base + 26,
        reason: 'step $step crosses over on the wrong day',
      );
      expect(segments[step * 2 + 1].dose, steps[step].toDose);
      expect(segments[step * 2 + 1].endDayIndex, base + 51);
    }
  });

  test('a step is two treads, never one and never fifty-two', () {
    final steps = sixSteps().take(1).toList();
    final days = generated(
      plan: planFrom(mg(15), mg(14)),
      steps: steps,
      until: steps.first.startDate.addDays(51),
    );

    final segments = reduceToSegments(days);

    expect(segments, hasLength(2));
    expect(segments.first.length, 26);
    expect(segments.last.length, 26);
  });

  test('a step boundary between two EQUAL doses is kept', () {
    // Step n's `toDose` sits beside step n+1's `fromDose` at the same number.
    // The painter draws straight through — their y is identical — but the
    // boundary is a fact about the plan and the acceptance count depends on it.
    final steps = sixSteps().take(2).toList();
    final days = generated(
      plan: planFrom(mg(15), mg(13)),
      steps: steps,
      until: steps.last.startDate.addDays(51),
    );

    final segments = reduceToSegments(days);

    expect(segments, hasLength(4));
    expect(segments[1].dose, segments[2].dose, reason: '14mg either side');
    expect(segments[1].endDayIndex + 1, segments[2].startDayIndex);
  });

  test('the treads TILE the plan: no gap, no overlap, nothing missing', () {
    // The invariant the whole screen rests on. Swept over step counts and
    // increments rather than asserted once, because a reduction can be right
    // for six steps and wrong for one.
    for (var count = 1; count <= 6; count++) {
      final steps = sixSteps().take(count).toList();
      final days = generated(
        plan: planFrom(mg(15), mg(15 - count)),
        steps: steps,
        until: steps.last.startDate.addDays(51),
      );

      final segments = reduceToSegments(days);

      expect(segments.first.startDayIndex, 0, reason: '$count steps');
      expect(
        segments.last.endDayIndex,
        days.length - 1,
        reason: '$count steps',
      );
      for (var i = 1; i < segments.length; i++) {
        expect(
          segments[i].startDayIndex,
          segments[i - 1].endDayIndex + 1,
          reason: '$count steps: a gap or an overlap at tread $i',
        );
      }
      expect(
        segments.fold<int>(0, (sum, s) => sum + s.length),
        days.length,
        reason: '$count steps: the treads do not add up to the plan',
      );
    }
  });

  test('steady-state days extend the last tread rather than ending it', () {
    final steps = sixSteps().take(1).toList();
    // Twenty days past the step's realised length.
    final days = generated(
      plan: planFrom(mg(15), mg(14)),
      steps: steps,
      until: steps.first.startDate.addDays(71),
    );

    final segments = reduceToSegments(days);

    expect(segments.last.endDayIndex, days.length - 1);
    expect(
      segments.last.dose,
      mg(14),
      reason: 'the steady-state days are at the new dose',
    );
  });

  test('half-milligram steps survive the seam with no rounding', () {
    // `Milligrams` is integer hundredths, so `==` is legal and a `double`
    // round-trip anywhere in the reduction would show up here as 4.999999.
    final steps = <StepFacts>[
      for (var index = 0; index < 4; index++)
        StepFacts(
          id: index + 1,
          index: index,
          fromDose: Milligrams.fromHundredths(500 - index * 50),
          toDose: Milligrams.fromHundredths(450 - index * 50),
          startDate: const LocalDate(2024, 9, 12).addDays(index * 52),
          status: StepStatus.completed,
          patternVersion: 1,
        ),
    ];
    final days = generated(
      plan: planFrom(mg(5), Milligrams.zero),
      steps: steps,
      until: steps.last.startDate.addDays(51),
    );

    final emitted = reduceToSegments(days).map((s) => s.dose).toSet();
    final planned = days.map((day) => day.dose).toSet();

    expect(emitted, planned);
  });

  test('a 780-day plan stays under thirty-two treads', () {
    final steps = <StepFacts>[
      for (var index = 0; index < 15; index++)
        StepFacts(
          id: index + 1,
          index: index,
          fromDose: mg(15 - index),
          toDose: mg(14 - index),
          startDate: const LocalDate(2024, 9, 12).addDays(index * 52),
          status: StepStatus.completed,
          patternVersion: 1,
        ),
    ];
    final days = generated(
      plan: planFrom(mg(15), Milligrams.zero),
      steps: steps,
      until: const LocalDate(2024, 9, 12).addDays(779),
    );

    expect(days, hasLength(780));
    expect(reduceToSegments(days).length, lessThanOrEqualTo(32));
  });

  test('an empty plan is an empty staircase, not a crash', () {
    expect(reduceToSegments(const <DayPlan>[]), isEmpty);
  });
}
