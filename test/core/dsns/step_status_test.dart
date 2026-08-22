// Pure `package:test`. `today` is a parameter, not a clock read — this function
// is the single definition of step completion, and EPIC-11's "Start next step"
// button is gated on it.
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

  test('pending before the start date', () {
    expect(
      stepStatusFor(fixtureStep, noHolds, const LocalDate(2026, 3, 31)),
      StepStatus.pending,
    );
  });

  test('active from the start date through day 52', () {
    expect(
      stepStatusFor(fixtureStep, noHolds, const LocalDate(2026, 4, 1)),
      StepStatus.active,
    );
    expect(
      stepStatusFor(fixtureStep, noHolds, const LocalDate(2026, 5, 22)),
      StepStatus.active,
    );
  });

  test('completed the day after 52 days have run', () {
    expect(
      stepStatusFor(fixtureStep, noHolds, const LocalDate(2026, 5, 23)),
      StepStatus.completed,
    );
  });

  test('a three-day hold pushes completion out by exactly three days', () {
    expect(
      stepStatusFor(fixtureStep, threeDayHold, const LocalDate(2026, 5, 25)),
      StepStatus.active,
    );
    expect(
      stepStatusFor(fixtureStep, threeDayHold, const LocalDate(2026, 5, 26)),
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
    for (final date in const [
      LocalDate(2026, 3, 31),
      LocalDate(2026, 4, 1),
      LocalDate(2026, 5, 22),
      LocalDate(2026, 5, 23),
    ]) {
      expect(
        stepStatusFor(abandoned, noHolds, date),
        StepStatus.abandoned,
        reason: '$date',
      );
    }
  });

  test('a non-DSNS method uses its hold period in place of 52', () {
    expect(
      stepStatusFor(
        fixtureStep,
        noHolds,
        const LocalDate(2026, 4, 15),
        nominalLength: 14,
      ),
      StepStatus.completed,
    );
  });
}
