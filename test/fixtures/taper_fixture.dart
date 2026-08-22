/// The shared taper fixture every domain test reads.
///
/// *Prednisolone, current 10mg, target 0mg, strengths 5mg + 1mg, halves on,
/// DSNS, active step 10 → 9.5* — the repo-wide fixture named in
/// `epics/README.md`, minus the parts (day 14 of 52, the pinned clock) that
/// only the UI epics need. The active step here is **10 → 9**, which is the
/// step the golden vector pins.
library;

import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:test/test.dart';

/// Milligrams from a decimal count, for readable test literals.
Milligrams mg(num milligrams) =>
    Milligrams.fromHundredths((milligrams * 100).round());

/// Tablet strengths from decimal counts.
List<TabletStrength> held(List<num> strengths) => <TabletStrength>[
  for (final s in strengths) TabletStrength(mg(s)),
];

/// 5mg and 1mg — what a UK prednisolone patient actually holds.
final List<TabletStrength> fixtureStrengths = held(<num>[5, 1]);

/// Prednisolone, 10mg down to zero, starting 2026-04-01.
final TaperPlanFacts fixturePlan = TaperPlanFacts(
  drugName: 'Prednisolone',
  startDate: const LocalDate(2026, 4, 1),
  startingDose: mg(10),
  targetDose: Milligrams.zero,
  tabletStrengths: fixtureStrengths,
  allowHalves: true,
  method: TaperMethod.dsns,
);

/// The active step: 10mg → 9mg from 2026-04-01.
const StepFacts fixtureStep = StepFacts(
  id: 1,
  index: 0,
  fromDose: Milligrams.fromHundredths(1000),
  toDose: Milligrams.fromHundredths(900),
  startDate: LocalDate(2026, 4, 1),
  status: StepStatus.active,
  patternVersion: 1,
);

/// Generates and unwraps, failing the test with the domain failure's code if
/// generation refused.
List<DayPlan> generated({
  required List<StepFacts> steps,
  TaperPlanFacts? plan,
  List<FlareEvent> flares = const <FlareEvent>[],
  List<HoldEvent> holds = const <HoldEvent>[],
  LocalDate? until,
}) {
  final result = generateSchedule(
    plan: plan ?? fixturePlan,
    steps: steps,
    flares: flares,
    holds: holds,
    until: until,
  );
  switch (result) {
    case Ok<List<DayPlan>, DomainFailure>(:final value):
      return value;
    case Err<List<DayPlan>, DomainFailure>(:final failure):
      fail('generateSchedule refused: ${failure.code}');
  }
}

/// Unwraps the failure arm, failing the test if generation succeeded.
DomainFailure failureOf(Result<List<DayPlan>, DomainFailure> result) {
  switch (result) {
    case Ok<List<DayPlan>, DomainFailure>():
      fail('expected a DomainFailure, got a schedule');
    case Err<List<DayPlan>, DomainFailure>(:final failure):
      return failure;
  }
}
