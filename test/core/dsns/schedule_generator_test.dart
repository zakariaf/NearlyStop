// Pure `package:test`. generateSchedule is dates in, days out — no I/O, no
// clock, no database — which is exactly what makes flare rollback incapable of
// corrupting anything and makes this file mock-free.
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:test/test.dart';

import '../../fixtures/taper_fixture.dart';

void main() {
  group('the fixture step: 2026-04-01, 10mg -> 9mg, [5, 1], halves, DSNS', () {
    final days = generated(steps: <StepFacts>[fixtureStep]);

    test('runs 52 days when `until` is null', () {
      expect(days, hasLength(52));
      expect(days.first.date, const LocalDate(2026, 4, 1));
      expect(days.last.date, const LocalDate(2026, 5, 22));
    });

    test('the single day leads: day 1 is the NEW dose', () {
      final first = days.first;
      expect(first.dose, mg(9));
      expect(first.doseKind, DoseKind.newDose);
      expect(first.kind, DayKind.step);
      expect(first.blockIndex, 1);
      expect(first.dayInBlock, 1);
      expect(first.dayInStep, 1);
      expect(first.isHoldDay, isFalse);
      expect(first.isNewDose, isTrue);
      expect(first.stepIndex, 0);
    });

    test(
      'days 2-7 are the old dose, and day 8 opens block 2 on the new one',
      () {
        for (var i = 1; i <= 6; i++) {
          expect(days[i].dose, mg(10), reason: 'day ${i + 1}');
          expect(days[i].doseKind, DoseKind.oldDose, reason: 'day ${i + 1}');
          expect(days[i].blockIndex, 1, reason: 'day ${i + 1}');
        }
        expect(days[7].dose, mg(9));
        expect(days[7].doseKind, DoseKind.newDose);
        expect(days[7].blockIndex, 2);
        expect(days[7].dayInBlock, 1);
      },
    );

    test('the crossover puts two consecutive old-dose days at 27 and 28', () {
      // Block 6 is (1 new, 1 old) so it ENDS old; block 7 is (1 old, 2 new) so
      // it OPENS old. SPEC.md §3.1 accepts this explicitly.
      expect(days[26].dayInStep, 27);
      expect(days[26].doseKind, DoseKind.oldDose);
      expect(days[26].blockIndex, 6);
      expect(days[27].dayInStep, 28);
      expect(days[27].doseKind, DoseKind.oldDose);
      expect(days[27].blockIndex, 7);
    });

    test('26 new and 26 old, block lengths 7 6 5 4 3 2 3 4 5 6 7', () {
      expect(days.where((d) => d.doseKind == DoseKind.newDose), hasLength(26));
      expect(days.where((d) => d.doseKind == DoseKind.oldDose), hasLength(26));
      final lengths = <int>[];
      for (final day in days) {
        if (day.dayInBlock == 1) {
          lengths.add(1);
        } else {
          lengths[lengths.length - 1]++;
        }
      }
      expect(lengths, <int>[7, 6, 5, 4, 3, 2, 3, 4, 5, 6, 7]);
    });

    test('dates are contiguous with no gap and no repeat', () {
      for (var i = 1; i < days.length; i++) {
        expect(days[i].date, days[i - 1].date.addDays(1), reason: 'index $i');
      }
    });

    test('composes each dose from the plan strengths', () {
      final nine = days.first.composition;
      expect(nine, isA<Ok<TabletComposition, DomainFailure>>());
      expect(
        (nine as Ok<TabletComposition, DomainFailure>).value.counts,
        <TabletCount>[TabletCount(mg(5), 1), TabletCount(mg(1), 4)],
      );
      final ten = days[1].composition;
      expect(
        (ten as Ok<TabletComposition, DomainFailure>).value.counts,
        <TabletCount>[TabletCount(mg(5), 2)],
      );
    });

    test('is deterministic', () {
      expect(generated(steps: <StepFacts>[fixtureStep]), days);
    });
  });

  group('holds', () {
    final days = generated(
      steps: <StepFacts>[fixtureStep],
      holds: const <HoldEvent>[
        HoldEvent(stepId: 1, fromDate: LocalDate(2026, 4, 10), extraDays: 3),
      ],
    );

    test('inserts three days that repeat the host day exactly', () {
      final host = days.firstWhere(
        (d) => d.date == const LocalDate(2026, 4, 10),
      );
      for (var offset = 1; offset <= 3; offset++) {
        final held = days.firstWhere(
          (d) => d.date == const LocalDate(2026, 4, 10).addDays(offset),
        );
        expect(held.isHoldDay, isTrue, reason: 'offset $offset');
        expect(held.dose, host.dose, reason: 'offset $offset');
        expect(held.blockIndex, host.blockIndex, reason: 'offset $offset');
        expect(held.dayInBlock, host.dayInBlock, reason: 'offset $offset');
        expect(held.dayInStep, host.dayInStep, reason: 'offset $offset');
      }
    });

    test('the step spans 55 days but dayInStep still reaches exactly 52', () {
      expect(days, hasLength(55));
      final nonHold = days.where((d) => !d.isHoldDay).toList();
      expect(nonHold, hasLength(52));
      expect(nonHold.last.dayInStep, 52);
      expect(days.last.date, const LocalDate(2026, 5, 25));
    });

    test('the day that was 2026-04-11 is now 2026-04-14', () {
      final shifted = days.firstWhere(
        (d) => d.date == const LocalDate(2026, 4, 14),
      );
      expect(shifted.isHoldDay, isFalse);
      expect(shifted.dayInStep, 11);
    });
  });

  group('flare truncation', () {
    const flareDate = LocalDate(2026, 4, 20); // dayInStep 20
    final beforeFlare = generated(steps: <StepFacts>[fixtureStep]);
    final afterFlare = generated(
      steps: <StepFacts>[
        // The truncated step is ABANDONED, so this fixture exercises the
        // ignore-status rule instead of passing vacuously.
        StepFacts(
          id: fixtureStep.id,
          index: fixtureStep.index,
          fromDose: fixtureStep.fromDose,
          toDose: fixtureStep.toDose,
          startDate: fixtureStep.startDate,
          status: StepStatus.abandoned,
          patternVersion: fixtureStep.patternVersion,
        ),
        const StepFacts(
          id: 2,
          index: 1,
          fromDose: Milligrams.fromHundredths(1000),
          toDose: Milligrams.fromHundredths(950),
          startDate: flareDate,
          status: StepStatus.active,
          patternVersion: 1,
        ),
      ],
      flares: const <FlareEvent>[
        FlareEvent(
          date: flareDate,
          revertToDose: Milligrams.fromHundredths(1000),
        ),
      ],
    );

    test('the running step contributes exactly 19 days', () {
      final first = afterFlare.where((d) => d.stepIndex == 0).toList();
      expect(first, hasLength(19));
      expect(first.last.date, const LocalDate(2026, 4, 19));
    });

    test('every day before the flare is identical field for field', () {
      for (var i = 0; i < 19; i++) {
        expect(afterFlare[i], beforeFlare[i], reason: 'index $i');
      }
    });

    test('an abandoned step still generates the days it was lived', () {
      for (final status in StepStatus.values) {
        final cycled = generated(
          steps: <StepFacts>[
            StepFacts(
              id: fixtureStep.id,
              index: fixtureStep.index,
              fromDose: fixtureStep.fromDose,
              toDose: fixtureStep.toDose,
              startDate: fixtureStep.startDate,
              status: status,
              patternVersion: fixtureStep.patternVersion,
            ),
          ],
        );
        expect(cycled, beforeFlare, reason: '$status');
      }
    });
  });

  group('steady state', () {
    test('fills the gap between a finished step and the next one', () {
      final days = generated(
        steps: <StepFacts>[fixtureStep],
        until: const LocalDate(2026, 6, 30),
      );
      final steady = days.where((d) => d.kind == DayKind.steadyState).toList();
      expect(steady.first.date, const LocalDate(2026, 5, 23));
      expect(steady.last.date, const LocalDate(2026, 6, 30));
      for (final day in steady) {
        expect(day.dose, mg(9));
        expect(day.doseKind, DoseKind.newDose);
        expect(day.blockIndex, isNull);
        expect(day.dayInBlock, isNull);
        expect(day.dayInStep, isNull);
        expect(day.isHoldDay, isFalse);
        expect(day.stepIndex, 0);
      }
    });

    test('a plan at target still renders every day, never an empty list', () {
      final days = generated(
        plan: fixturePlan,
        steps: const <StepFacts>[
          StepFacts(
            id: 1,
            index: 0,
            fromDose: Milligrams.fromHundredths(50),
            toDose: Milligrams.zero,
            startDate: LocalDate(2026, 4, 1),
            status: StepStatus.completed,
            patternVersion: 1,
          ),
        ],
        until: const LocalDate(2026, 8, 1),
      );
      expect(days.last.date, const LocalDate(2026, 8, 1));
      expect(days.last.kind, DayKind.steadyState);
      expect(days.last.dose, Milligrams.zero);
    });
  });

  group('guards', () {
    test('`until` before the plan start is PlanNotStarted', () {
      final result = generateSchedule(
        plan: fixturePlan,
        steps: <StepFacts>[fixtureStep],
        flares: const <FlareEvent>[],
        holds: const <HoldEvent>[],
        until: const LocalDate(2026, 3, 31),
      );
      expect(
        failureOf(result),
        isA<PlanNotStarted>().having(
          (f) => f.startDate,
          'startDate',
          const LocalDate(2026, 4, 1),
        ),
      );
    });

    test('a target above the starting dose is TargetAboveStart', () {
      final result = generateSchedule(
        plan: TaperPlanFacts(
          drugName: 'Prednisolone',
          startDate: const LocalDate(2026, 4, 1),
          startingDose: mg(5),
          targetDose: mg(10),
          tabletStrengths: fixtureStrengths,
          allowHalves: true,
          method: TaperMethod.dsns,
        ),
        steps: <StepFacts>[fixtureStep],
        flares: const <FlareEvent>[],
        holds: const <HoldEvent>[],
      );
      expect(failureOf(result), isA<TargetAboveStart>());
    });
  });

  group('percentage and fixedMg generate their own shape', () {
    TaperPlanFacts planWith(
      TaperMethod method, {
      int? percentage,
      num? fixed,
    }) => TaperPlanFacts(
      drugName: 'Prednisolone',
      startDate: const LocalDate(2026, 4, 1),
      startingDose: mg(20),
      targetDose: Milligrams.zero,
      tabletStrengths: fixtureStrengths,
      allowHalves: true,
      method: method,
      percentage: percentage,
      fixedStep: fixed == null ? null : mg(fixed),
    );

    const twentyToEighteen = StepFacts(
      id: 1,
      index: 0,
      fromDose: Milligrams.fromHundredths(2000),
      toDose: Milligrams.fromHundredths(1800),
      startDate: LocalDate(2026, 4, 1),
      status: StepStatus.active,
      patternVersion: 1,
    );

    test('percentage holds the new dose every day, with no blocks', () {
      final days = generated(
        plan: planWith(TaperMethod.percentage, percentage: 10),
        steps: const <StepFacts>[twentyToEighteen],
      );
      expect(days, hasLength(52));
      for (var i = 0; i < days.length; i++) {
        expect(days[i].dose, mg(18), reason: 'day ${i + 1}');
        expect(days[i].doseKind, DoseKind.newDose, reason: 'day ${i + 1}');
        expect(days[i].blockIndex, isNull, reason: 'day ${i + 1}');
        expect(days[i].dayInStep, i + 1, reason: 'day ${i + 1}');
      }
    });

    test('fixedMg has the same shape', () {
      final days = generated(
        plan: planWith(TaperMethod.fixedMg, fixed: 2),
        steps: const <StepFacts>[twentyToEighteen],
      );
      expect(days, hasLength(52));
      expect(days.every((d) => d.blockIndex == null), isTrue);
      expect(days.every((d) => d.doseKind == DoseKind.newDose), isTrue);
    });

    test(
      'a missing method parameter is a typed value, not a DSNS schedule',
      () {
        for (final (method, plan) in <(TaperMethod, TaperPlanFacts)>[
          (TaperMethod.percentage, planWith(TaperMethod.percentage)),
          (TaperMethod.fixedMg, planWith(TaperMethod.fixedMg)),
        ]) {
          final result = generateSchedule(
            plan: plan,
            steps: const <StepFacts>[twentyToEighteen],
            flares: const <FlareEvent>[],
            holds: const <HoldEvent>[],
          );
          expect(
            failureOf(result),
            isA<MissingMethodParameter>().having(
              (f) => f.method,
              'method',
              method,
            ),
            reason: '$method',
          );
        }
      },
    );
  });

  group('`until` is the right bound, even when a next step exists', () {
    // Taking only the next step's start here ran generation months past the
    // requested bound AND replaced the truncated step's remaining alternating
    // pattern with flat steady-state days at the lower dose.
    final steps = <StepFacts>[
      fixtureStep,
      const StepFacts(
        id: 2,
        index: 1,
        fromDose: Milligrams.fromHundredths(900),
        toDose: Milligrams.fromHundredths(850),
        startDate: LocalDate(2026, 8, 1),
        status: StepStatus.pending,
        patternVersion: 1,
      ),
    ];

    test('stops exactly at `until`', () {
      final days = generated(steps: steps, until: const LocalDate(2026, 4, 10));
      expect(days, hasLength(10));
      expect(days.last.date, const LocalDate(2026, 4, 10));
    });

    test('does not turn the running step into steady state', () {
      final days = generated(steps: steps, until: const LocalDate(2026, 6, 1));
      expect(days.where((d) => d.kind == DayKind.steadyState), isNotEmpty);
      // Days 1..52 of the running step keep their alternating pattern.
      final stepDays = days.where((d) => d.kind == DayKind.step).toList();
      expect(stepDays, hasLength(52));
      expect(
        stepDays.where((d) => d.doseKind == DoseKind.oldDose),
        hasLength(26),
      );
      expect(days.last.date, const LocalDate(2026, 6, 1));
    });
  });

  group('holds chain, and only where the step actually reaches', () {
    test('a hold anchored to an inserted hold day is applied, not dropped', () {
      final days = generated(
        steps: <StepFacts>[fixtureStep],
        holds: const <HoldEvent>[
          HoldEvent(stepId: 1, fromDate: LocalDate(2026, 4, 10), extraDays: 3),
          HoldEvent(stepId: 1, fromDate: LocalDate(2026, 4, 11), extraDays: 2),
        ],
      );
      expect(days, hasLength(57));
      expect(days.where((d) => d.isHoldDay), hasLength(5));
    });

    test('`until` can cut into a run of hold days', () {
      final days = generated(
        steps: <StepFacts>[fixtureStep],
        holds: const <HoldEvent>[
          HoldEvent(stepId: 1, fromDate: LocalDate(2026, 4, 10), extraDays: 3),
        ],
        until: const LocalDate(2026, 4, 11),
      );
      expect(days, hasLength(11));
      expect(days.last.date, const LocalDate(2026, 4, 11));
      expect(days.last.isHoldDay, isTrue);
      expect(days.last.dayInStep, 10);
    });

    test('a hold outside the step contributes nothing', () {
      final days = generated(
        steps: <StepFacts>[fixtureStep],
        holds: const <HoldEvent>[
          HoldEvent(stepId: 1, fromDate: LocalDate(2027, 1, 1), extraDays: 3),
        ],
      );
      expect(days, hasLength(52));
    });

    test('a negative extraDays contributes nothing', () {
      final days = generated(
        steps: <StepFacts>[fixtureStep],
        holds: const <HoldEvent>[
          HoldEvent(stepId: 1, fromDate: LocalDate(2026, 4, 10), extraDays: -5),
        ],
      );
      expect(days, hasLength(52));
    });
  });

  group("the first step must open on the plan's first day", () {
    // CONTRACTS.md §5 promises no holes, and that promise rests entirely on
    // this. savePlan inserts Step 0 on plan.startDate in the same transaction.
    StepFacts stepFrom(LocalDate date) => StepFacts(
      id: 1,
      index: 0,
      fromDose: mg(10),
      toDose: mg(9),
      startDate: date,
      status: StepStatus.active,
      patternVersion: 1,
    );

    test('a step starting BEFORE the plan is refused', () {
      final result = generateSchedule(
        plan: fixturePlan,
        steps: <StepFacts>[stepFrom(const LocalDate(2026, 1, 1))],
        flares: const <FlareEvent>[],
        holds: const <HoldEvent>[],
      );
      expect(failureOf(result), isA<PlanNotStarted>());
    });

    test('a step starting AFTER the plan is refused', () {
      final result = generateSchedule(
        plan: fixturePlan,
        steps: <StepFacts>[stepFrom(const LocalDate(2026, 5, 1))],
        flares: const <FlareEvent>[],
        holds: const <HoldEvent>[],
      );
      expect(failureOf(result), isA<PlanNotStarted>());
    });
  });

  test("a flare on a step's first day truncates that step to zero days", () {
    // This is the shape flare handling produces. The earlier step contributes
    // nothing because it was never lived, and the schedule opens on the flare's
    // step — deliberate, and pinned here so it cannot change by accident.
    final days = generated(
      steps: <StepFacts>[
        const StepFacts(
          id: 1,
          index: 0,
          fromDose: Milligrams.fromHundredths(1000),
          toDose: Milligrams.fromHundredths(900),
          startDate: LocalDate(2026, 4, 1),
          status: StepStatus.abandoned,
          patternVersion: 1,
        ),
        const StepFacts(
          id: 2,
          index: 1,
          fromDose: Milligrams.fromHundredths(1000),
          toDose: Milligrams.fromHundredths(950),
          startDate: LocalDate(2026, 4, 1),
          status: StepStatus.active,
          patternVersion: 1,
        ),
      ],
    );
    expect(days.where((d) => d.stepIndex == 0), isEmpty);
    expect(days.first.stepIndex, 1);
    expect(days, hasLength(52));
  });

  test('isNewDose is false on every steady-state day', () {
    // The new-dose/old-dose distinction only exists inside a step. Lighting the
    // marker on every day of a completed taper destroys the one signal this
    // audience most needs to trust.
    final days = generated(
      steps: <StepFacts>[fixtureStep],
      until: const LocalDate(2026, 5, 30),
    );
    final steady = days.where((d) => d.kind == DayKind.steadyState);
    expect(steady, isNotEmpty);
    for (final day in steady) {
      expect(day.doseKind, DoseKind.newDose);
      expect(day.isNewDose, isFalse, reason: '${day.date}');
    }
    expect(days.first.isNewDose, isTrue);
  });

  test('an unknown frozen pattern version refuses, never guesses', () {
    // Step.patternVersion exists so a corrected block table cannot rewrite what
    // a patient already lived. A version this build does not know is a typed
    // value, not a best-effort render.
    final result = generateSchedule(
      plan: fixturePlan,
      steps: const <StepFacts>[
        StepFacts(
          id: 1,
          index: 0,
          fromDose: Milligrams.fromHundredths(1000),
          toDose: Milligrams.fromHundredths(900),
          startDate: LocalDate(2026, 4, 1),
          status: StepStatus.active,
          patternVersion: 2,
        ),
      ],
      flares: const <FlareEvent>[],
      holds: const <HoldEvent>[],
    );
    expect(
      failureOf(result),
      isA<UnknownPatternVersion>().having((f) => f.version, 'version', 2),
    );
  });

  test('a plan with no steps has no schedule', () {
    final result = generateSchedule(
      plan: fixturePlan,
      steps: const <StepFacts>[],
      flares: const <FlareEvent>[],
      holds: const <HoldEvent>[],
    );
    expect(result, isA<Ok<List<DayPlan>, DomainFailure>>());
    expect((result as Ok<List<DayPlan>, DomainFailure>).value, isEmpty);
  });
}
