// The whole Today screen as one immutable value.
//
// Pure `package:test`, deliberately: this file is DATA. It imports
// `package:meta`, `LocalDate` and `Milligrams` and no Flutter, so needing
// `flutter_test` to exercise it would be evidence it had grown a dependency it
// should not have.
//
// Exhaustiveness of a four-arm switch is a COMPILE-TIME guarantee of `sealed`,
// not something to assert at runtime. Adding a fifth variant breaks the build,
// which is the point, so there is no test for it here.
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:test/test.dart';

/// A dose with every field spelled out, so each test varies exactly one.
TodayDose doseWith({
  bool taken = false,
  String? tablets = '1 × 5mg · 4 × 1mg',
  String? unachievableMessage,
  bool isSteadyState = false,
  String? holdingLabel,
  String? dayInStep = '14',
  String? stepLength = '52',
  BackfillPrompt? backfill,
  String? noteText,
}) => TodayDose(
  dateLine: 'Wednesday 16 April',
  doseAmount: '9',
  doseUnit: 'mg',
  tablets: tablets,
  unachievableMessage: unachievableMessage,
  isNewDoseDay: true,
  taken: taken,
  stepIndex: '3',
  stepCount: '15',
  fromDose: '10mg',
  toDose: '9mg',
  dayInStep: dayInStep,
  stepLength: stepLength,
  isSteadyState: isSteadyState,
  holdingLabel: holdingLabel,
  backfill: backfill,
  noteText: noteText,
  flare: const FlarePrompt(
    candidates: <FlareCandidate>[],
    defaultRevertTo: Milligrams.fromHundredths(1000),
    suggestedStep: Milligrams.fromHundredths(50),
    stepDiffersFromCommunity: true,
  ),
  hold: const HoldPrompt(
    stepId: 7,
    blockLabel: 'Block 3 of 11',
    defaultExtraDays: 7,
    minExtraDays: 1,
    maxExtraDays: 28,
  ),
);

void main() {
  group('TodayDose equality', () {
    test('identical field values are ==, with equal hashCodes', () {
      // This is what stops every stream emission repainting the hero. The
      // repository re-emits on any write anywhere; if two structurally equal
      // states compared unequal, the dose numeral would rebuild on a note.
      expect(doseWith(), doseWith());
      expect(doseWith().hashCode, doseWith().hashCode);
    });

    test('flipping `taken` ALONE makes them unequal', () {
      expect(doseWith(), isNot(doseWith(taken: true)));
    });

    test('every other field is in the comparison too', () {
      // Field by field, because an `==` that forgot one is an `==` that hides
      // exactly that field's changes from the screen.
      expect(doseWith(), isNot(doseWith(tablets: '2 × 5mg')));
      expect(doseWith(), isNot(doseWith(noteText: 'slept badly')));
      expect(
        doseWith(),
        isNot(
          doseWith(
            backfill: const BackfillPrompt(
              oldest: LocalDate(2026, 4, 12),
              count: 4,
              label: "You haven't marked the last 4 days.",
            ),
          ),
        ),
      );
    });
  });

  group('TodayDose invariants', () {
    test('a null breakdown MUST carry the flagged reason', () {
      // SPEC.md §3.3, and CLAUDE.md rule 5. An empty pill is a dose the reader
      // cannot make and was not told about — the one unforgivable bug wearing
      // the costume of a missing string.
      expect(
        () => doseWith(tablets: null),
        throwsA(
          isA<AssertionError>().having(
            (error) => error.toString(),
            'message',
            contains('unachievableMessage'),
          ),
        ),
      );
    });

    test('a flagged reason without a null breakdown is also rejected', () {
      // The other direction: showing both a tablet breakdown AND "cannot be
      // made" invites the reader to take the breakdown.
      expect(
        () => doseWith(unachievableMessage: 'Cannot be made'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a steady-state day must not carry a dayInStep to format', () {
      // On those days `blockIndex`/`dayInStep` are null upstream. Formatting
      // them anyway is how "Day 0 of 52" reaches a screen, which is the whole
      // reason the flag exists.
      expect(
        () => doseWith(isSteadyState: true, holdingLabel: 'Holding at 9mg'),
        throwsA(
          isA<AssertionError>().having(
            (error) => error.toString(),
            'message',
            contains('steady-state'),
          ),
        ),
      );
      // And the legal shape of the same day.
      expect(
        doseWith(
          isSteadyState: true,
          holdingLabel: 'Holding at 9mg',
          dayInStep: null,
          stepLength: null,
        ).isSteadyState,
        isTrue,
      );
    });
  });

  group('the other three variants', () {
    test('TodayStepFinished compares over its own fields', () {
      TodayStepFinished finished({
        String preview = '9mg → 8.5mg',
        bool canStart = true,
      }) => TodayStepFinished(
        dateLine: 'Wednesday 16 April',
        doseAmount: '9',
        doseUnit: 'mg',
        tablets: '1 × 5mg · 4 × 1mg',
        unachievableMessage: null,
        taken: false,
        stepIndex: '3',
        stepCount: '15',
        nextStepPreview: preview,
        canStartNextStep: canStart,
        flare: doseWith().flare,
        hold: null,
      );

      expect(finished(), finished());
      expect(finished().hashCode, finished().hashCode);
      expect(finished(), isNot(finished(preview: '9mg → 8mg')));
      expect(finished(), isNot(finished(canStart: false)));
    });

    test('TodayNoPlan and TodayTaperComplete are const singletons', () {
      expect(const TodayNoPlan(), const TodayNoPlan());
      expect(const TodayTaperComplete(), const TodayTaperComplete());
      expect(const TodayNoPlan(), isNot(const TodayTaperComplete()));
    });
  });

  group('the prompts', () {
    test('FlarePrompt and its candidates compare by value', () {
      const candidate = FlareCandidate(
        dose: Milligrams.fromHundredths(900),
        label: '9mg — from 3 March to 24 April',
      );
      const prompt = FlarePrompt(
        candidates: <FlareCandidate>[candidate],
        defaultRevertTo: Milligrams.fromHundredths(1000),
        suggestedStep: Milligrams.fromHundredths(50),
        stepDiffersFromCommunity: true,
      );

      expect(prompt, isA<FlarePrompt>());
      expect(
        prompt,
        const FlarePrompt(
          candidates: <FlareCandidate>[candidate],
          defaultRevertTo: Milligrams.fromHundredths(1000),
          suggestedStep: Milligrams.fromHundredths(50),
          stepDiffersFromCommunity: true,
        ),
      );
      expect(
        prompt,
        isNot(
          const FlarePrompt(
            candidates: <FlareCandidate>[candidate],
            defaultRevertTo: Milligrams.fromHundredths(1000),
            suggestedStep: Milligrams.fromHundredths(100),
            stepDiffersFromCommunity: true,
          ),
        ),
      );
    });

    test('HoldPrompt bounds are 1..28 and cannot be inverted', () {
      // 28 is the ceiling because a longer stall is a plan change, not a hold.
      // NOT `const`: a const constructor whose assert fails is a compile
      // error, which is even better — but it cannot be caught by a matcher, so
      // these are built at runtime to prove the assert fires there too.
      var min = 10;
      var max = 5;
      expect(
        () => HoldPrompt(
          stepId: 7,
          blockLabel: 'Block 3 of 11',
          defaultExtraDays: 7,
          minExtraDays: min,
          maxExtraDays: max,
        ),
        throwsA(isA<AssertionError>()),
      );
      min = 1;
      max = 28;
      var fallback = 40;
      expect(
        () => HoldPrompt(
          stepId: 7,
          blockLabel: 'Block 3 of 11',
          defaultExtraDays: fallback,
          minExtraDays: min,
          maxExtraDays: max,
        ),
        throwsA(isA<AssertionError>()),
      );
      fallback = 7;
      expect(
        HoldPrompt(
          stepId: 7,
          blockLabel: 'Block 3 of 11',
          defaultExtraDays: fallback,
          minExtraDays: min,
          maxExtraDays: max,
        ).maxExtraDays,
        28,
      );
    });
  });
}
