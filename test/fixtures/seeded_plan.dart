/// The one seeded plan every UI epic renders — screens, goldens, parity.
///
/// *Prednisolone, current 10mg, target 0mg, strengths 5mg + 1mg, halves on,
/// DSNS, active step **10mg → 9mg**, day 14 of 52.*
///
/// **A separate file from `taper_fixture.dart`, and not a second definition.**
/// The domain fixture imports `package:test`, whose `expect`/`group`/`test`
/// collide with `flutter_test`'s the moment a widget test imports both — so
/// the values are imported from there and re-exposed here, never retyped. A
/// second copy is a fixture that drifts, and the whole point of pinning one is
/// that a golden and a parity sheet show the same plan.
///
/// The clock is pinned to **2026-04-14**, which is day 14 of a step that
/// starts 2026-04-01. The epics quote 2025-04-16 from an earlier draft of the
/// plan's start date; the invariant that matters — and the one the tests
/// assert — is `dayInStep == 14`, so the clock follows the fixture rather than
/// the prose.
library;

import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/taper_repository.dart';

import 'taper_fixture.dart' as domain;

/// The plan under test.
final TaperPlanFacts seededPlan = domain.fixturePlan;

/// Its one active step, 10mg → 9mg.
const StepFacts seededStep = domain.fixtureStep;

/// The day the pinned clock reports — day 14 of the step.
const LocalDate seededToday = LocalDate(2026, 4, 14);

/// The pinned instant, at eight in the morning.
final DateTime seededNow = DateTime.utc(
  seededToday.year,
  seededToday.month,
  seededToday.day,
  8,
);

/// Days elapsed in the active step at [seededToday], counting the first day.
int get seededDayInStep => seededToday.difference(seededStep.startDate) + 1;

/// The whole snapshot, ready to override `taperSnapshotProvider` with.
TaperSnapshot seededSnapshot({
  List<DoseLogFacts> logs = const <DoseLogFacts>[],
  List<FlareEvent> flares = const <FlareEvent>[],
  List<HoldEvent> holds = const <HoldEvent>[],
}) => TaperSnapshot(
  plan: seededPlan,
  steps: const <StepFacts>[seededStep],
  logs: logs,
  flares: flares,
  holds: holds,
  statusByStepId: <int, StepStatus>{seededStep.id: StepStatus.active},
);
