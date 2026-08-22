/// The canonical serialisation of a [DayPlan].
///
/// One encoder, shared by `test/core/dsns/golden_vector_test.dart` and
/// `tool/regen_golden_vectors.dart`. Two encoders would be two encoders that
/// disagree, and the thing they encode is the schedule a patient lives.
///
/// Stable key order, two-space indent, trailing newline — so an unexplained
/// diff in a pull request is reviewable line by line.
library;

import 'dart:convert';

import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/result.dart';

const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

/// One row: `{date, kind, block, dayInBlock, dayInStep, mg, doseKind,
/// tablets}`.
///
/// `kind` and `doseKind` are **separate keys on every row** — a day is `kind:
/// step` *and* `doseKind: oldDose`. They are different axes and the file shows
/// both, so no refactor can collapse them silently.
///
/// `tablets` is `[[count, strength], …]` with the optional half tablet as a
/// trailing `[0.5, strength]` entry. `unachievable` replaces it when the dose
/// cannot be made from the held strengths — never a rounded value.
Map<String, dynamic> encodeGoldenRow(DayPlan day) => <String, dynamic>{
  'date': day.date.toIso8601(),
  'kind': day.kind.name,
  'block': day.blockIndex,
  'dayInBlock': day.dayInBlock,
  'dayInStep': day.dayInStep,
  'mg': day.dose.toDisplayString(),
  'doseKind': day.doseKind.name,
  'tablets': _encodeTablets(day.composition),
};

/// The whole vector, ready to write to disk.
String encodeGoldenVector(List<DayPlan> days) =>
    '${_encoder.convert(days.map(encodeGoldenRow).toList())}\n';

Object _encodeTablets(Result<TabletComposition, DomainFailure> composition) =>
    switch (composition) {
      Ok<TabletComposition, DomainFailure>(:final value) => <List<dynamic>>[
        for (final count in value.counts)
          <dynamic>[count.count, count.strength.toDisplayString()],
        if (value.half case final half?)
          <dynamic>[0.5, half.strength.toDisplayString()],
      ],
      Err<TabletComposition, DomainFailure>(:final failure) => failure.code,
    };
