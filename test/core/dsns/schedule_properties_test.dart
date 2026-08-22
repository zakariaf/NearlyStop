// The invariants from SPEC.md §10, proven across the input space we care
// about. Seeded with Random(20260421), pinned, and echoed in every `reason:` so
// a failure is its own minimal repro.
//
// These are the tests the generator was written against; the file is numbered
// separately only for organisation.
import 'dart:math';

import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:test/test.dart';

import '../../fixtures/taper_fixture.dart';

const int _seed = 20260421;
const List<num> _strengthPool = <num>[0.5, 1, 2, 2.5, 5, 10, 20, 25];
const LocalDate _start = LocalDate(2026, 4, 1);

TaperPlanFacts _plan({
  required num starting,
  required num target,
  required List<num> strengths,
  required bool allowHalves,
  TaperMethod method = TaperMethod.dsns,
  int? percentage,
  num? fixedStep,
}) => TaperPlanFacts(
  drugName: 'Prednisolone',
  startDate: _start,
  startingDose: mg(starting),
  targetDose: mg(target),
  tabletStrengths: held(strengths),
  allowHalves: allowHalves,
  method: method,
  percentage: percentage,
  fixedStep: fixedStep == null ? null : mg(fixedStep),
);

StepFacts _step({
  required num from,
  required num to,
  LocalDate startDate = _start,
  int id = 1,
  int index = 0,
  StepStatus status = StepStatus.active,
}) => StepFacts(
  id: id,
  index: index,
  fromDose: mg(from),
  toDose: mg(to),
  startDate: startDate,
  status: status,
  patternVersion: 1,
);

void _assertDsnsShape(List<DayPlan> days, String reason) {
  final nonHold = days.where((d) => !d.isHoldDay).toList();
  expect(nonHold, hasLength(52), reason: reason);
  expect(
    nonHold.where((d) => d.doseKind == DoseKind.newDose),
    hasLength(26),
    reason: reason,
  );
  expect(
    nonHold.where((d) => d.doseKind == DoseKind.oldDose),
    hasLength(26),
    reason: reason,
  );

  final lengths = <int>[];
  for (final day in nonHold) {
    if (day.dayInBlock == 1) {
      lengths.add(1);
    } else {
      lengths[lengths.length - 1]++;
    }
  }
  expect(lengths, <int>[7, 6, 5, 4, 3, 2, 3, 4, 5, 6, 7], reason: reason);

  // The single day LEADS every block: position 1 is the new dose in blocks 1-6
  // and the old dose from block 7.
  for (final day in nonHold.where((d) => d.dayInBlock == 1)) {
    final expected = day.blockIndex! <= 6 ? DoseKind.newDose : DoseKind.oldDose;
    expect(day.doseKind, expected, reason: '$reason block ${day.blockIndex}');
  }

  // The crossover: block 6's last day and block 7's first day are both old.
  expect(nonHold[26].doseKind, DoseKind.oldDose, reason: reason);
  expect(nonHold[27].doseKind, DoseKind.oldDose, reason: reason);

  for (var i = 1; i < days.length; i++) {
    expect(
      days[i].date,
      days[i - 1].date.addDays(1),
      reason: '$reason index $i',
    );
  }
}

void main() {
  test('every DSNS step is 52 days, 26/26, with the block table intact', () {
    final rng = Random(_seed);
    for (var iteration = 0; iteration < 1000; iteration++) {
      final subset = <num>[
        for (final s in _strengthPool)
          if (rng.nextBool()) s,
      ];
      if (subset.isEmpty) subset.add(_strengthPool[rng.nextInt(8)]);
      final allowHalves = rng.nextBool();
      final fromHundredths = (rng.nextInt(120) + 1) * 50;
      final toHundredths = rng.nextInt(fromHundredths ~/ 50) * 50;
      final reason =
          'iteration=$iteration seed=$_seed strengths=$subset '
          'halves=$allowHalves from=$fromHundredths to=$toHundredths';

      final plan = _plan(
        starting: fromHundredths / 100,
        target: toHundredths / 100,
        strengths: subset,
        allowHalves: allowHalves,
      );
      final steps = <StepFacts>[
        _step(from: fromHundredths / 100, to: toHundredths / 100),
      ];

      final days = generated(plan: plan, steps: steps);
      _assertDsnsShape(days, reason);
      expect(
        generated(plan: plan, steps: steps),
        days,
        reason: reason,
      );
    }
  });

  test(
    'a flare regenerates identically and never touches the days before it',
    () {
      final beforeFlare = generated(steps: <StepFacts>[fixtureStep]);
      for (var flareDay = 1; flareDay <= 52; flareDay++) {
        final flareDate = _start.addDays(flareDay - 1);
        final steps = <StepFacts>[
          // The truncated step is ABANDONED, so this exercises the
          // ignore-status rule instead of passing vacuously.
          _step(from: 10, to: 9, status: StepStatus.abandoned),
          _step(from: 10, to: 9.5, startDate: flareDate, id: 2, index: 1),
        ];
        final flares = <FlareEvent>[
          FlareEvent(date: flareDate, revertToDose: mg(10)),
        ];

        final first = generated(steps: steps, flares: flares);
        for (var run = 0; run < 50; run++) {
          expect(
            generated(steps: steps, flares: flares),
            first,
            reason: 'flareDay=$flareDay run=$run',
          );
        }
        for (var i = 0; i < flareDay - 1; i++) {
          expect(
            first[i],
            beforeFlare[i],
            reason: 'flareDay=$flareDay index=$i',
          );
        }
      }
    },
  );

  group('coverage: every date in range has EXACTLY one DayPlan', () {
    void assertCovers(
      List<DayPlan> days,
      LocalDate from,
      LocalDate to,
      String reason,
    ) {
      // An independent date walk, built here and compared as a multiset, so a
      // gap AND a duplicate each fail naming the offending date.
      final emitted = <String, int>{};
      for (final day in days) {
        emitted[day.date.toIso8601()] =
            (emitted[day.date.toIso8601()] ?? 0) + 1;
      }
      for (var date = from; date <= to; date = date.addDays(1)) {
        expect(
          emitted[date.toIso8601()],
          1,
          reason: '$reason: ${date.toIso8601()}',
        );
      }
      expect(emitted, hasLength(to.difference(from) + 1), reason: reason);
    }

    test('with the last step still running', () {
      final until = _start.addDays(200);
      final days = generated(
        steps: <StepFacts>[
          _step(from: 10, to: 9),
          _step(
            from: 9,
            to: 8.5,
            startDate: _start.addDays(180),
            id: 2,
            index: 1,
          ),
        ],
        until: until,
      );
      assertCovers(days, _start, until, 'last step running');
    });

    test('with the last step ended 40 days ago and no successor', () {
      // "Finished on a Friday, tapped Start next step on Monday" — the case
      // that had no DayPlan at all before CONTRACTS.md §5.
      final until = _start.addDays(200);
      final days = generated(
        steps: <StepFacts>[_step(from: 10, to: 9)],
        until: until,
      );
      assertCovers(days, _start, until, 'no successor');
      expect(days.last.kind, DayKind.steadyState);
      expect(days.last.dose, mg(9));
    });

    test('with the target reached', () {
      final until = _start.addDays(200);
      final days = generated(
        steps: <StepFacts>[_step(from: 0.5, to: 0)],
        until: until,
      );
      assertCovers(days, _start, until, 'target reached');
      expect(days.last.dose, Milligrams.zero);
      expect(days.last.kind, DayKind.steadyState);
    });
  });

  test(
    'percentage and fixedMg descend monotonically and clamp at the target',
    () {
      for (final method in <TaperMethod>[
        TaperMethod.percentage,
        TaperMethod.fixedMg,
      ]) {
        final plan = _plan(
          starting: 20,
          target: 0,
          strengths: const <num>[5, 1],
          allowHalves: true,
          method: method,
          percentage: method == TaperMethod.percentage ? 10 : null,
          fixedStep: method == TaperMethod.fixedMg ? 2 : null,
        );
        final steps = <StepFacts>[
          _step(from: 20, to: 18),
          _step(
            from: 18,
            to: 16,
            startDate: _start.addDays(52),
            id: 2,
            index: 1,
          ),
          _step(
            from: 16,
            to: 0,
            startDate: _start.addDays(104),
            id: 3,
            index: 2,
          ),
        ];
        final days = generated(plan: plan, steps: steps);

        for (var i = 1; i < days.length; i++) {
          expect(
            days[i].date,
            days[i - 1].date.addDays(1),
            reason: '$method $i',
          );
          expect(
            days[i].dose <= days[i - 1].dose,
            isTrue,
            reason: '$method dose rose at index $i',
          );
        }
        for (final day in days) {
          expect(day.doseKind, DoseKind.newDose, reason: '$method');
          expect(day.blockIndex, isNull, reason: '$method');
          expect(day.dose >= Milligrams.zero, isTrue, reason: '$method');
        }
        expect(days.last.dose, Milligrams.zero, reason: '$method');
      }
    },
  );
}
