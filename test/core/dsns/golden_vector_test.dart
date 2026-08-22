// The committed golden vector.
//
// `test/core/dsns/golden/step_10mg_to_9mg.json` was **hand-derived from
// SPEC.md §3.1 before the generator existed**, never dumped from the code under
// test. A golden captured from the implementation only pins whatever that
// implementation happened to do, including the bug you are about to introduce.
//
// A diff to that file in a pull request must be explained in the PR body: an
// unexplained change to it means the schedule a patient lives has changed.
// `tool/regen_golden_vectors.dart` exists for INTENTIONAL changes only.
import 'dart:convert';
import 'dart:io';

import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/golden_vector_codec.dart';
import 'package:test/test.dart';

import '../../fixtures/taper_fixture.dart';

void main() {
  final file = File('test/core/dsns/golden/step_10mg_to_9mg.json');
  final committedText = file.readAsStringSync();
  final committed = (jsonDecode(committedText) as List<dynamic>)
      .cast<Map<String, dynamic>>();

  test('the fixture step reproduces all 52 committed rows', () {
    final days = generated(steps: <StepFacts>[fixtureStep]);
    expect(days, hasLength(committed.length));
    for (var i = 0; i < committed.length; i++) {
      // Compared on the serialised map, so a failure prints the offending row
      // rather than "lists differ".
      expect(encodeGoldenRow(days[i]), committed[i], reason: 'row ${i + 1}');
    }
  });

  test('row 1 is the new dose on the first day — the single day LEADS', () {
    expect(committed.first, <String, dynamic>{
      'date': '2026-04-01',
      'kind': 'step',
      'block': 1,
      'dayInBlock': 1,
      'dayInStep': 1,
      'mg': '9',
      'doseKind': 'newDose',
      'tablets': <List<dynamic>>[
        <dynamic>[1, '5'],
        <dynamic>[4, '1'],
      ],
    });
  });

  test('rows 2-7 are the old dose at 2 x 5mg', () {
    for (var i = 1; i <= 6; i++) {
      expect(committed[i]['mg'], '10', reason: 'row ${i + 1}');
      expect(committed[i]['doseKind'], 'oldDose', reason: 'row ${i + 1}');
      expect(
        committed[i]['tablets'],
        <List<dynamic>>[
          <dynamic>[2, '5'],
        ],
        reason: 'row ${i + 1}',
      );
    }
  });

  test('exactly 26 newDose rows and 26 oldDose rows', () {
    expect(committed.where((r) => r['doseKind'] == 'newDose'), hasLength(26));
    expect(committed.where((r) => r['doseKind'] == 'oldDose'), hasLength(26));
  });

  test('kind and doseKind are separate keys on every row', () {
    // A row is `kind: step` AND `doseKind: oldDose`. They are different axes,
    // and no future refactor may collapse them into one.
    for (final row in committed) {
      expect(row.containsKey('kind'), isTrue);
      expect(row.containsKey('doseKind'), isTrue);
      expect(row['kind'], 'step');
    }
    expect(committed.map((r) => r['doseKind']).toSet(), <String>{
      'newDose',
      'oldDose',
    });
  });

  test('re-serialising reproduces the committed bytes exactly', () {
    // Stable key order, two-space indent, trailing newline. This is what makes
    // an unexplained diff in a PR reviewable at all.
    final days = generated(steps: <StepFacts>[fixtureStep]);
    expect(encodeGoldenVector(days), committedText);
  });
}
