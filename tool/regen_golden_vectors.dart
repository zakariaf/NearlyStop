// Regenerates the committed golden vectors.
//
// FOR INTENTIONAL CHANGES ONLY. The committed file was hand-derived from
// SPEC.md §3.1 before the generator existed, and that is the only way a golden
// vector may be CREATED — a fixture dumped from the implementation under test
// enshrines that implementation's bugs, including the one you are about to
// introduce.
//
// Run it when the schedule a patient lives is deliberately changing, and
// explain the diff in the pull request body. CI never runs this: a pipeline
// that regenerates its own expectations is a gate that checks nothing.
//
//   dart run tool/regen_golden_vectors.dart
//
// The fixture below is deliberately spelled out rather than imported from
// test/fixtures/: a tool script cannot package-import a test file. If the two
// ever drift, test/core/dsns/golden_vector_test.dart goes red, because it
// generates from ITS fixture and compares against the file THIS wrote.
import 'dart:io';

import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/golden_vector_codec.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';

/// Writes every golden vector file from the current generator.
void main() {
  const strengths = <TabletStrength>[
    TabletStrength.fromHundredths(500),
    TabletStrength.fromHundredths(100),
  ];
  const plan = TaperPlanFacts(
    drugName: 'Prednisolone',
    startDate: LocalDate(2026, 4, 1),
    startingDose: Milligrams.fromHundredths(1000),
    targetDose: Milligrams.zero,
    tabletStrengths: strengths,
    allowHalves: true,
    method: TaperMethod.dsns,
  );
  const step = StepFacts(
    id: 1,
    index: 0,
    fromDose: Milligrams.fromHundredths(1000),
    toDose: Milligrams.fromHundredths(900),
    startDate: LocalDate(2026, 4, 1),
    status: StepStatus.active,
    patternVersion: 1,
  );

  final result = generateSchedule(
    plan: plan,
    steps: const <StepFacts>[step],
    flares: const <FlareEvent>[],
    holds: const <HoldEvent>[],
  );
  switch (result) {
    case Err(:final failure):
      stderr.writeln('refused: ${failure.code}');
      exitCode = 1;
    case Ok(:final value):
      const path = 'test/core/dsns/golden/step_10mg_to_9mg.json';
      File(path).writeAsStringSync(encodeGoldenVector(value));
      stdout.writeln('wrote $path (${value.length} rows)');
  }
}
