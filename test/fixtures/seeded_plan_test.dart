// The pinned fixture's own claims, before a single sheet is captured.
//
// A fixture whose prose and code disagree is the failure this catches: every
// parity sheet, golden and sweep cell in three epics is captured against it,
// and a wrong step size there is a wrong step size everywhere at once.
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/step_size.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:test/test.dart';

import 'seeded_plan.dart';
import 'taper_fixture.dart';

void main() {
  test('10mg with 5mg + 1mg steps to 9mg, and does not diverge', () {
    // This is the whole argument for rendering `10 → 9` with NO caveat banner,
    // and it belongs in a test rather than in a paragraph: 10% of 10mg is
    // exactly 1mg and 1mg is achievable, so community practice and the
    // arithmetic agree.
    final result = suggestStep(
      currentDose: mg(10),
      targetDose: Milligrams.zero,
      strengths: <TabletStrength>[TabletStrength(mg(5)), TabletStrength(mg(1))],
      allowHalves: true,
    );

    expect(result, isA<Ok<StepSuggestion, DomainFailure>>());
    final suggestion = (result as Ok<StepSuggestion, DomainFailure>).value;
    expect(suggestion.suggested, mg(1));
    expect(suggestion.tenPercent, mg(1));
    expect(suggestion.communityPracticeDiffers, isFalse);
  });

  test('the active step is 10mg to 9mg, on day 14', () {
    expect(seededStep.fromDose, mg(10));
    expect(seededStep.toDose, mg(9));
    expect(seededDayInStep, 14);
    expect(seededStep.status, StepStatus.active);
  });

  test('the UI seed and the domain fixture are the SAME objects', () {
    // Import identity, not equality: two fixtures that happen to agree today
    // are two fixtures, and one of them will be edited alone.
    expect(identical(seededPlan, fixturePlan), isTrue);
    expect(identical(seededStep, fixtureStep), isTrue);
  });

  test('the snapshot renders a plan that is mid-taper, not fresh', () {
    final snapshot = seededSnapshot();
    expect(snapshot.plan, isNotNull);
    expect(snapshot.steps, hasLength(1));
    expect(snapshot.statusByStepId[seededStep.id], StepStatus.active);
  });
}
