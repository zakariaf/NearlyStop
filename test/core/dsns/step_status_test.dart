// Pure `package:test`. `today` is a parameter, not a clock read — this function
// is the single definition of step completion, and EPIC-11's "Start next step"
// button is gated on it.
import 'package:nearlystop/core/dsns/dsns_pattern.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:test/test.dart';

import '../../fixtures/taper_fixture.dart';

void main() {
  const noHolds = <HoldEvent>[];
  const threeDayHold = <HoldEvent>[
    HoldEvent(stepId: 1, fromDate: LocalDate(2026, 4, 10), extraDays: 3),
  ];

  StepStatus statusOn(
    LocalDate today, {
    List<HoldEvent> holds = noHolds,
    StepFacts step = fixtureStep,
    int nominalLength = dsnsStepDays,
  }) => stepStatusFor(step, holds, today, nominalLength: nominalLength);

  test('pending before the start date', () {
    expect(statusOn(const LocalDate(2026, 3, 31)), StepStatus.pending);
  });

  test('active from the start date through day 52', () {
    expect(statusOn(const LocalDate(2026, 4, 1)), StepStatus.active);
    expect(statusOn(const LocalDate(2026, 5, 22)), StepStatus.active);
  });

  test('completed the day after 52 days have run', () {
    expect(statusOn(const LocalDate(2026, 5, 23)), StepStatus.completed);
  });

  test('a three-day hold pushes completion out by exactly three days', () {
    expect(
      statusOn(const LocalDate(2026, 5, 25), holds: threeDayHold),
      StepStatus.active,
    );
    expect(
      statusOn(const LocalDate(2026, 5, 26), holds: threeDayHold),
      StepStatus.completed,
    );
  });

  test('a hold this step never reaches does not move completion', () {
    // The generator can only apply a hold anchored to a date it emits, so a
    // phantom hold must not extend the status either — otherwise "Start next
    // step" stays disabled while the schedule has run out of step days.
    const phantom = <HoldEvent>[
      HoldEvent(stepId: 1, fromDate: LocalDate(2027, 1, 1), extraDays: 3),
    ];
    expect(
      statusOn(const LocalDate(2026, 5, 23), holds: phantom),
      StepStatus.completed,
    );
  });

  test('a negative extraDays does not SHORTEN the step', () {
    // HoldEvent carries no positivity invariant — it is a stored fact, and a
    // bad import or an off-by-one in the hold UI can produce one. The schedule
    // ignores it, so the status must too.
    const negative = <HoldEvent>[
      HoldEvent(stepId: 1, fromDate: LocalDate(2026, 4, 10), extraDays: -5),
    ];
    expect(
      statusOn(const LocalDate(2026, 5, 18), holds: negative),
      StepStatus.active,
    );
    expect(
      statusOn(const LocalDate(2026, 5, 23), holds: negative),
      StepStatus.completed,
    );
  });

  test("another step's hold is ignored", () {
    const otherStep = <HoldEvent>[
      HoldEvent(stepId: 99, fromDate: LocalDate(2026, 4, 10), extraDays: 3),
    ];
    expect(
      statusOn(const LocalDate(2026, 5, 23), holds: otherStep),
      StepStatus.completed,
    );
  });

  test('an abandoned step reports abandoned on every date', () {
    const abandoned = StepFacts(
      id: 1,
      index: 0,
      fromDose: Milligrams.fromHundredths(1000),
      toDose: Milligrams.fromHundredths(900),
      startDate: LocalDate(2026, 4, 1),
      status: StepStatus.abandoned,
      patternVersion: 1,
    );
    for (final date in const <LocalDate>[
      LocalDate(2026, 3, 31),
      LocalDate(2026, 4, 1),
      LocalDate(2026, 5, 22),
      LocalDate(2026, 5, 23),
    ]) {
      expect(
        statusOn(date, step: abandoned),
        StepStatus.abandoned,
        reason: '$date',
      );
    }
  });

  test('a non-DSNS method uses its hold period in place of 52', () {
    expect(
      statusOn(const LocalDate(2026, 4, 15), nominalLength: 14),
      StepStatus.completed,
    );
    expect(
      nominalStepLength(fixturePlan),
      dsnsStepDays,
    );
    expect(
      nominalStepLength(
        TaperPlanFacts(
          drugName: 'Prednisolone',
          startDate: const LocalDate(2026, 4, 1),
          startingDose: mg(20),
          targetDose: Milligrams.zero,
          tabletStrengths: fixtureStrengths,
          allowHalves: true,
          method: TaperMethod.percentage,
          percentage: 10,
          holdPeriodDays: 14,
        ),
      ),
      14,
    );
  });
}
