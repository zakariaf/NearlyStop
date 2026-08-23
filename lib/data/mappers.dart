/// Row → domain fact, in one place.
///
/// This is the boundary. A drift row class, an `Insertable` or a `Value` never
/// travels further up than here: the domain and the UI never learn that drift
/// exists, which is what keeps every layer above testable without a database.
library;

import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:nearlystop/data/db/app_database.dart' as db;

/// Projects a plan row onto the domain's plan record.
TaperPlanFacts planFactsFrom(db.TaperPlanRow row) => TaperPlanFacts(
  drugName: row.drugName,
  startDate: row.startDate,
  startingDose: row.startingDose,
  targetDose: row.targetDose,
  tabletStrengths: <TabletStrength>[
    for (final mg in row.tabletStrengths) TabletStrength(mg),
  ],
  allowHalves: row.allowHalves,
  method: row.method,
  percentage: row.percentage?.round(),
  fixedStep: row.fixedStep,
);

/// Projects a step row onto the domain's step record.
StepFacts stepFactsFrom(db.StepRow row) => StepFacts(
  id: row.id,
  index: row.stepIndex,
  fromDose: row.fromDose,
  toDose: row.toDose,
  startDate: row.startDate,
  status: row.status,
  patternVersion: row.patternVersion,
);

/// Projects a dose-log row onto the domain's log record.
DoseLogFacts doseLogFactsFrom(db.DoseLogRow row) => DoseLogFacts(
  date: row.date,
  plannedMg: row.plannedMg,
  actualMg: row.actualMg,
  taken: row.taken,
  note: row.note,
);

/// Projects a flare row onto the domain's flare record.
FlareEvent flareEventFrom(db.FlareEventRow row) =>
    FlareEvent(date: row.date, revertToDose: row.revertToDose, note: row.note);

/// Projects a hold row onto the domain's hold record.
HoldEvent holdEventFrom(db.HoldEventRow row) => HoldEvent(
  stepId: row.stepId,
  fromDate: row.fromDate,
  extraDays: row.extraDays,
  note: row.note,
);
