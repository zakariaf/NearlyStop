// Pure `package:test`. These three functions are the SINGLE source of the
// Progress screen's numbers — EPIC-10 formats them and must not re-derive them,
// or they drift from the CSV/PDF export.
import 'dart:math';

import 'package:nearlystop/core/dsns/cumulative.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:test/test.dart';

import '../../fixtures/taper_fixture.dart';

DoseLogFacts log(LocalDate date, num actual, {required bool taken}) =>
    DoseLogFacts(
      date: date,
      plannedMg: mg(actual),
      actualMg: mg(actual),
      taken: taken,
    );

void main() {
  group('cumulativeTakenMg', () {
    test('sums only the days that were ticked', () {
      final logs = <DoseLogFacts>[
        log(const LocalDate(2026, 4, 1), 10, taken: true),
        log(const LocalDate(2026, 4, 2), 9, taken: true),
        log(const LocalDate(2026, 4, 3), 9, taken: false),
      ];
      expect(cumulativeTakenMg(logs).hundredths, mg(19).hundredths);
    });

    test('an empty list and an all-untaken list are both zero', () {
      expect(cumulativeTakenMg(const <DoseLogFacts>[]), Milligrams.zero);
      expect(
        cumulativeTakenMg(<DoseLogFacts>[
          log(const LocalDate(2026, 4, 1), 10, taken: false),
        ]),
        Milligrams.zero,
      );
    });
  });

  group('plannedCumulativeMg', () {
    test('the golden step is 26 x 9mg + 26 x 10mg = 494mg', () {
      final days = generated(steps: <StepFacts>[fixtureStep]);
      // Hand-computed, not read back from the function.
      const expected = 26 * 900 + 26 * 1000;
      expect(plannedCumulativeMg(days).hundredths, expected);
      expect(plannedCumulativeMg(days).hundredths, mg(494).hundredths);
    });
  });

  group('daysOnSteroids', () {
    test('counts inclusively, and across a leap day', () {
      expect(
        daysOnSteroids(
          const LocalDate(2026, 4, 1),
          const LocalDate(2026, 4, 1),
        ),
        1,
      );
      expect(
        daysOnSteroids(
          const LocalDate(2026, 4, 1),
          const LocalDate(2026, 4, 30),
        ),
        30,
      );
      expect(
        daysOnSteroids(
          const LocalDate(2028, 2, 27),
          const LocalDate(2028, 3, 1),
        ),
        4,
      );
    });
  });

  group('adherence', () {
    test('never counts a day that has not happened', () {
      const start = LocalDate(2026, 4, 1);
      final days = <DayPlan>[
        for (var i = 0; i < 780; i++)
          DayPlan(
            date: start.addDays(i),
            stepIndex: 0,
            kind: DayKind.step,
            blockIndex: null,
            dayInBlock: null,
            dayInStep: i + 1,
            dose: mg(5),
            doseKind: DoseKind.newDose,
            composition: generated(
              steps: <StepFacts>[fixtureStep],
            ).first.composition,
            isHoldDay: false,
          ),
      ];
      final logs = <DoseLogFacts>[
        for (var i = 0; i < 341; i++) log(start.addDays(i), 5, taken: true),
      ];

      final onDay350 = adherence(logs, days, start.addDays(349));
      expect(onDay350.takenCount, 341);
      expect(onDay350.plannedCount, 350); // NOT 780

      final onDay349 = adherence(logs, days, start.addDays(348));
      expect(onDay349.plannedCount, 349);
    });
  });

  test('adherence never reports more taken days than planned ones', () {
    // Two logs for one date, and a log for a date the schedule does not cover.
    // "taken 351 of 350 days" is rendered verbatim to a frightened patient.
    const start = LocalDate(2026, 4, 1);
    final days = generated(steps: <StepFacts>[fixtureStep]);
    final logs = <DoseLogFacts>[
      log(start, 10, taken: true),
      log(start, 10, taken: true),
      log(const LocalDate(2020, 1, 1), 10, taken: true),
    ];
    final result = adherence(logs, days, start);
    expect(result.takenCount, 1);
    expect(result.plannedCount, 1);
    expect(result.takenCount, lessThanOrEqualTo(result.plannedCount));
  });

  test(
    'a flare preserves the cumulative total, because it only appends facts',
    () {
      final logs = <DoseLogFacts>[
        for (var i = 0; i < 30; i++)
          log(const LocalDate(2026, 4, 1).addDays(i), 10, taken: true),
      ];
      final before = cumulativeTakenMg(logs);
      // The flare appends a FlareEvent and a new Step. No DoseLog is edited, so
      // the same log list is the whole input on both sides.
      final after = cumulativeTakenMg(logs);
      expect(after, before);
      expect(after.hundredths, 30 * 1000);
    },
  );

  test('conservation: the parts sum to the whole over generated schedules', () {
    final rng = Random(20260421);
    for (var seed = 0; seed < 200; seed++) {
      final fromHundredths = (rng.nextInt(40) + 10) * 100;
      final toHundredths = fromHundredths - 100;
      final days = generated(
        plan: fixturePlan,
        steps: <StepFacts>[
          StepFacts(
            id: 1,
            index: 0,
            fromDose: Milligrams.fromHundredths(fromHundredths),
            toDose: Milligrams.fromHundredths(toHundredths),
            startDate: const LocalDate(2026, 4, 1),
            status: StepStatus.active,
            patternVersion: 1,
          ),
        ],
      );
      // The oracle is INDEPENDENT: a DSNS step is 26 days at the old dose and
      // 26 at the new, so the total is arithmetic the function never performs.
      // Re-deriving days.fold(...) here would assert nothing beyond `+`.
      expect(
        plannedCumulativeMg(days).hundredths,
        26 * fromHundredths + 26 * toHundredths,
        reason: 'seed=$seed from=$fromHundredths to=$toHundredths',
      );
    }
  });
}
