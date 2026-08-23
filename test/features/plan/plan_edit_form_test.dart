// The fields that create a taper — the one screen where a wrong keystroke
// costs two years of history.
//
// Every case here is about the same refusal: the app never guesses at a dose.
// A separator that is not this locale's is rejected rather than coerced, a
// value finer than a hundredth is flagged rather than rounded, and a target at
// or above the current dose is refused rather than quietly swapped.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/plan/presentation/plan_cards.dart';
import 'package:nearlystop/features/plan/presentation/plan_edit_form.dart';
import 'package:nearlystop/features/plan/presentation/plan_editor_notifier.dart';
import 'package:nearlystop/features/plan/presentation/widgets/strength_chip.dart';
import 'package:nearlystop/features/plan/presentation/widgets/strength_editor_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../support/harness.dart';

/// A draft with nothing unusual about it.
PlanDraft seed({
  TaperMethod method = TaperMethod.dsns,
  Milligrams current = const Milligrams.fromHundredths(1000),
  Milligrams target = Milligrams.zero,
  List<Milligrams> strengths = const <Milligrams>[
    Milligrams.fromHundredths(100),
    Milligrams.fromHundredths(500),
  ],
  int? percentage,
  Milligrams? fixedStep,
}) => PlanDraft(
  drugName: 'Prednisolone',
  startDate: const LocalDate(2026, 8, 22),
  currentDose: current,
  targetDose: target,
  strengths: strengths,
  allowHalves: true,
  method: method,
  percentage: percentage,
  fixedStep: fixedStep,
);

/// What the fields last said, after every rebuild is applied.
class Recorder {
  /// The newest draft the fields emitted.
  late PlanDraft draft;

  /// The newest error per field. A key present with `null` means "was wrong,
  /// now right" — which is not the same as never having been reported.
  final Map<PlanField, String?> errors = <PlanField, String?>{};

  /// Whether every field the form has spoken about reads back.
  bool get isValid => errors.values.every((error) => error == null);
}

class _Host extends StatefulWidget {
  const _Host({required this.recorder, required this.locale});

  final Recorder recorder;
  final Locale locale;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recorder = widget.recorder;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            PlanEditForm(
              draft: recorder.draft,
              locale: widget.locale,
              l10n: l10n,
              onChanged: (next) => setState(() => recorder.draft = next),
              onFieldError: (field, error) => recorder.errors[field] = error,
            ),
            PlanMethodFields(
              draft: recorder.draft,
              locale: widget.locale,
              l10n: l10n,
              onChanged: (next) => setState(() => recorder.draft = next),
              onFieldError: (field, error) => recorder.errors[field] = error,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pumps the fields over [draft] and hands back what they report.
Future<Recorder> pumpFields(
  WidgetTester tester, {
  required PlanDraft draft,
  Locale locale = const Locale('en'),
}) async {
  final recorder = Recorder()..draft = draft;
  await pumpApp(
    tester,
    _Host(recorder: recorder, locale: locale),
    locale: locale,
  );
  return recorder;
}

void main() {
  group('a dose reads back exactly as it was typed', () {
    const cases = <String, (String, String)>{
      'en': ('en', '9.5'),
      'de': ('de', '9,5'),
      'fa': ('fa', '۹٫۵'),
    };

    for (final MapEntry<String, (String, String)>(
          key: name,
          value: (tag, typed),
        )
        in cases.entries) {
      testWidgets('$name reads $typed as 9.5mg', (tester) async {
        final recorder = await pumpFields(
          tester,
          draft: seed(),
          locale: Locale(tag),
        );

        await tester.enterText(
          find.byKey(PlanEditForm.currentDoseKey),
          typed,
        );
        await tester.pump();

        expect(
          recorder.draft.currentDose,
          const Milligrams.fromHundredths(950),
        );
        expect(recorder.errors[PlanField.currentDose], isNull);
        // And back out again unchanged: a field that parses a string it cannot
        // re-render has lost the user's own notation.
        expect(
          find.widgetWithText(TextField, typed),
          findsOneWidget,
          reason: 'the field must still show what was typed',
        );
      });
    }
  });

  group('a separator that is not this locale’s is refused, never coerced', () {
    testWidgets('German rejects 9.5 rather than reading it as 95', (
      tester,
    ) async {
      final recorder = await pumpFields(
        tester,
        draft: seed(),
        locale: const Locale('de'),
      );

      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '9.5');
      await tester.pump();

      expect(recorder.errors[PlanField.currentDose], isNotNull);
      expect(
        recorder.draft.currentDose,
        const Milligrams.fromHundredths(1000),
        reason: 'an unreadable entry must not move the draft',
      );
    });

    for (final typed in <String>['1.2.3', '1,2.3']) {
      testWidgets('English rejects $typed', (tester) async {
        final recorder = await pumpFields(tester, draft: seed());

        await tester.enterText(
          find.byKey(PlanEditForm.currentDoseKey),
          typed,
        );
        await tester.pump();

        expect(recorder.errors[PlanField.currentDose], isNotNull);
        expect(
          recorder.draft.currentDose,
          const Milligrams.fromHundredths(1000),
        );
      });
    }

    testWidgets('letters never reach the field at all', (tester) async {
      final recorder = await pumpFields(tester, draft: seed());

      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), 'abc');
      await tester.pump();

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(PlanEditForm.currentDoseKey),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, isEmpty);
      expect(recorder.errors[PlanField.currentDose], isNotNull);
    });

    testWidgets('an empty dose is an error, not zero', (tester) async {
      final recorder = await pumpFields(tester, draft: seed());

      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '');
      await tester.pump();

      expect(recorder.errors[PlanField.currentDose], isNotNull);
      expect(recorder.draft.currentDose, const Milligrams.fromHundredths(1000));
    });

    testWidgets('a third decimal is FLAGGED, never rounded', (tester) async {
      final recorder = await pumpFields(tester, draft: seed());

      await tester.enterText(
        find.byKey(PlanEditForm.currentDoseKey),
        '0.255',
      );
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        recorder.errors[PlanField.currentDose],
        l10n.planErrorDoseTooPrecise('9.25'),
        reason:
            'telling somebody who typed 0.255 to use one decimal '
            'SEPARATOR sends them to fix the wrong character',
      );
      expect(
        recorder.draft.currentDose,
        isNot(const Milligrams.fromHundredths(26)),
        reason: 'rounding a dose silently is the one unforgivable bug',
      );
    });

    testWidgets('a minus sign never reaches the field', (tester) async {
      await pumpFields(tester, draft: seed());

      await tester.enterText(find.byKey(PlanEditForm.targetDoseKey), '-5');
      await tester.pump();

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(PlanEditForm.targetDoseKey),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '5');
    });
  });

  group('the target must be below the current dose', () {
    for (final (name, typed) in <(String, String)>[
      ('equal to', '10'),
      ('above', '12'),
    ]) {
      testWidgets('a target $name the current dose is refused', (tester) async {
        final recorder = await pumpFields(tester, draft: seed());

        await tester.enterText(
          find.byKey(PlanEditForm.targetDoseKey),
          typed,
        );
        await tester.pump();

        expect(recorder.errors[PlanField.targetDose], isNotNull);
      });
    }

    testWidgets('raising the current dose clears the target’s error', (
      tester,
    ) async {
      // The target's verdict depends on the current dose, so reporting only
      // the field that changed leaves a stale refusal on a form that is now
      // correct — and the Save button stays dead with nothing marked red.
      final recorder = await pumpFields(tester, draft: seed());

      await tester.enterText(find.byKey(PlanEditForm.targetDoseKey), '12');
      await tester.pump();
      expect(recorder.errors[PlanField.targetDose], isNotNull);

      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '20');
      await tester.pump();

      expect(recorder.errors[PlanField.targetDose], isNull);
      expect(recorder.isValid, isTrue);
    });

    testWidgets('a target below it is accepted', (tester) async {
      final recorder = await pumpFields(tester, draft: seed());

      await tester.enterText(find.byKey(PlanEditForm.targetDoseKey), '5');
      await tester.pump();

      expect(recorder.errors[PlanField.targetDose], isNull);
      expect(recorder.draft.targetDose, const Milligrams.fromHundredths(500));
    });
  });

  testWidgets('a very high dose warns and does NOT block', (tester) async {
    // 120mg is what somebody with giant cell arteritis is genuinely started
    // on. Refusing it would tell a person with a real prescription that their
    // own dose is impossible.
    final recorder = await pumpFields(tester, draft: seed());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '120');
    await tester.pump();

    expect(find.text(l10n.planErrorDoseTooHigh), findsOneWidget);
    // In the HELPER slot, not the error slot. A red field that still saves is
    // two contradictory signals, and the reader believes the red one.
    final state = tester.state<FormFieldState<String>>(
      find.descendant(
        of: find.byKey(PlanEditForm.currentDoseKey),
        matching: find.byType(TextFormField),
      ),
    );
    expect(state.errorText, isNull);
    expect(state.hasError, isFalse);
    expect(
      recorder.errors[PlanField.currentDose],
      isNull,
      reason: 'a warning is not an error — Save stays enabled',
    );
    expect(recorder.draft.currentDose, const Milligrams.fromHundredths(12000));
  });

  group('an error is announced, not merely painted', () {
    testWidgets('the message reaches the semantics tree', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFields(tester, draft: seed(), locale: const Locale('de'));
      final l10n = await AppLocalizations.delegate.load(const Locale('de'));

      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '9.5');
      await tester.pump();

      final expected = l10n.planErrorDoseUnreadable('9,5');
      expect(find.text(expected), findsOneWidget);

      // Settled, because Material fades the error in and `RenderOpacity` hides
      // a fully transparent child FROM THE SEMANTICS TREE as well as from the
      // screen. Asserting on the first frame would assert the fade, not the
      // error.
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(expected),
        findsOneWidget,
        reason: 'a painted-only error is invisible to a screen reader',
      );
      handle.dispose();
    });

    testWidgets('correcting the field clears the error it reported', (
      tester,
    ) async {
      final recorder = await pumpFields(
        tester,
        draft: seed(),
        locale: const Locale('de'),
      );

      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '9.5');
      await tester.pump();
      expect(recorder.errors[PlanField.currentDose], isNotNull);

      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '9,5');
      await tester.pump();

      expect(recorder.errors[PlanField.currentDose], isNull);
      expect(recorder.isValid, isTrue);
    });
  });

  group('the drug name', () {
    testWidgets('empty is refused', (tester) async {
      final recorder = await pumpFields(tester, draft: seed());

      await tester.enterText(find.byKey(PlanEditForm.drugNameKey), '');
      await tester.pump();

      expect(recorder.errors[PlanField.drugName], isNotNull);
    });

    testWidgets('sixty-one characters is refused', (tester) async {
      final recorder = await pumpFields(tester, draft: seed());

      await tester.enterText(
        find.byKey(PlanEditForm.drugNameKey),
        'x' * (kMaxDrugNameLength + 1),
      );
      await tester.pump();

      expect(recorder.errors[PlanField.drugName], isNotNull);
    });

    testWidgets('surrounding spaces are stored trimmed', (tester) async {
      final recorder = await pumpFields(tester, draft: seed());

      await tester.enterText(
        find.byKey(PlanEditForm.drugNameKey),
        '  Prednisolone  ',
      );
      await tester.pump();

      expect(recorder.draft.drugName, 'Prednisolone');
      expect(recorder.errors[PlanField.drugName], isNull);
    });
  });

  group('only the chosen method’s fields are in the tree', () {
    testWidgets('DSNS shows neither arithmetic field', (tester) async {
      await pumpFields(tester, draft: seed());

      expect(find.byKey(PlanMethodFields.percentageKey), findsNothing);
      expect(find.byKey(PlanMethodFields.fixedStepKey), findsNothing);
      expect(
        find.byKey(PlanMethodFields.holdPeriodKey),
        findsNothing,
        reason: 'DSNS owns its own eleven-block hold; it is not a field',
      );
    });

    testWidgets('percentage shows the percent field, defaulted to ten', (
      tester,
    ) async {
      final recorder = await pumpFields(
        tester,
        draft: seed(method: TaperMethod.percentage),
      );

      expect(find.byKey(PlanMethodFields.percentageKey), findsOneWidget);
      expect(find.byKey(PlanMethodFields.fixedStepKey), findsNothing);
      expect(recorder.draft.effectivePercentage, kDefaultPercentage);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(PlanMethodFields.percentageKey),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '10');
    });

    for (final typed in <String>['0', '51']) {
      testWidgets('a percentage of $typed is refused', (tester) async {
        final recorder = await pumpFields(
          tester,
          draft: seed(method: TaperMethod.percentage, percentage: 10),
        );

        await tester.enterText(
          find.byKey(PlanMethodFields.percentageKey),
          typed,
        );
        await tester.pump();

        expect(recorder.errors[PlanField.percentage], isNotNull);
      });
    }

    testWidgets('fixed-mg shows the step field and refuses a step past the '
        'target', (tester) async {
      final recorder = await pumpFields(
        tester,
        draft: seed(
          method: TaperMethod.fixedMg,
          target: const Milligrams.fromHundredths(500),
          fixedStep: const Milligrams.fromHundredths(100),
        ),
      );

      expect(find.byKey(PlanMethodFields.fixedStepKey), findsOneWidget);
      expect(find.byKey(PlanMethodFields.percentageKey), findsNothing);

      // The distance to the target is 5mg. A 6mg step overshoots it.
      await tester.enterText(find.byKey(PlanMethodFields.fixedStepKey), '6');
      await tester.pump();
      expect(recorder.errors[PlanField.fixedStep], isNotNull);

      await tester.enterText(find.byKey(PlanMethodFields.fixedStepKey), '5');
      await tester.pump();
      expect(recorder.errors[PlanField.fixedStep], isNull);
    });

    testWidgets('a count field has no decimal point to get wrong', (
      tester,
    ) async {
      // The keyboard offers no separator and neither does the formatter. With
      // the DOSE formatter here `5.2` would survive into a field whose parser
      // then refuses it — a keystroke the app accepts and then rejects, with
      // nothing on screen to tell the two apart.
      final recorder = await pumpFields(
        tester,
        draft: seed(method: TaperMethod.percentage, percentage: 10),
      );

      await tester.enterText(
        find.byKey(PlanMethodFields.holdPeriodKey),
        '5.2',
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(PlanMethodFields.holdPeriodKey),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '52');
      expect(recorder.errors[PlanField.holdPeriod], isNull);
      expect(recorder.draft.holdPeriodDays, 52);
    });

    testWidgets('the hold period defaults to 52 and refuses zero', (
      tester,
    ) async {
      final recorder = await pumpFields(
        tester,
        draft: seed(method: TaperMethod.percentage, percentage: 10),
      );

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(PlanMethodFields.holdPeriodKey),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '52');

      await tester.enterText(find.byKey(PlanMethodFields.holdPeriodKey), '0');
      await tester.pump();

      expect(recorder.errors[PlanField.holdPeriod], isNotNull);
      expect(
        recorder.draft.holdPeriodDays,
        TaperPlanFacts.dsnsHoldPeriodDays,
      );
    });
  });

  group('the strengths list', () {
    Future<List<Milligrams>> pumpStrengths(
      WidgetTester tester, {
      required List<Milligrams> strengths,
    }) async {
      var draft = seed(strengths: strengths);
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PlanStrengthsCard(
                draft: draft,
                locale: const Locale('en'),
                l10n: AppLocalizations.of(context),
                onChanged: (next) => setState(() => draft = next),
              ),
            ),
          ),
        ),
      );
      return draft.strengths;
    }

    testWidgets('the chips read biggest first, like the box does', (
      tester,
    ) async {
      // The reference frame shows 5mg then 1mg. Ascending is what the DOMAIN
      // sorts them to — it deduplicates and orders for storage — and rendering
      // that order puts the tablet somebody reaches for last in the row.
      await pumpStrengths(
        tester,
        strengths: const <Milligrams>[
          Milligrams.fromHundredths(100),
          Milligrams.fromHundredths(250),
          Milligrams.fromHundredths(500),
        ],
      );

      final labels = tester
          .widgetList<StrengthChip>(find.byType(StrengthChip))
          .map((chip) => chip.label)
          .toList();
      expect(labels, <String>['5mg', '2.5mg', '1mg']);
    });

    testWidgets('a chip is a tablet, not a tick', (tester) async {
      // Every chip in this row is held — that is what the row IS — so a check
      // glyph on all of them says nothing. The reference draws a tablet.
      await pumpStrengths(
        tester,
        strengths: const <Milligrams>[Milligrams.fromHundredths(100)],
      );

      expect(find.byIcon(StrengthChip.selectedGlyph), findsOneWidget);
      expect(StrengthChip.selectedGlyph, isNot(Icons.check));
    });

    testWidgets('the split-tablets row says which way it is set', (
      tester,
    ) async {
      // "On" under the label, as the reference shows. A switch alone is a
      // shape whose meaning depends on which end the knob is at, which is
      // exactly the reading this audience finds hardest.
      await pumpStrengths(
        tester,
        strengths: const <Milligrams>[Milligrams.fromHundredths(100)],
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.settingsOn), findsOneWidget);
    });

    testWidgets('removing the last one is refused, and says so', (
      tester,
    ) async {
      await pumpStrengths(
        tester,
        strengths: const <Milligrams>[Milligrams.fromHundredths(100)],
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.byType(StrengthChip).first);
      await tester.pump();

      expect(find.text(l10n.planErrorLastStrength), findsOneWidget);
      expect(find.byType(StrengthChip), findsOneWidget);
    });

    testWidgets('removing one of several is allowed', (tester) async {
      await pumpStrengths(
        tester,
        strengths: const <Milligrams>[
          Milligrams.fromHundredths(100),
          Milligrams.fromHundredths(250),
          Milligrams.fromHundredths(500),
        ],
      );

      await tester.tap(find.byType(StrengthChip).first);
      await tester.pumpAndSettle();

      expect(find.byType(StrengthChip), findsNWidgets(2));
    });

    testWidgets('a strength is added through the editor sheet', (tester) async {
      await pumpStrengths(
        tester,
        strengths: const <Milligrams>[Milligrams.fromHundredths(100)],
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.planAddStrength));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(StrengthEditorSheet.doseKey), '2.5');
      await tester.pump();
      await tester.tap(find.text(l10n.actionAdd));
      await tester.pumpAndSettle();

      expect(find.byType(StrengthChip), findsNWidgets(2));
    });
  });

  testWidgets('removing the fields disposes every controller', (tester) async {
    await pumpFields(tester, draft: seed(method: TaperMethod.percentage));

    await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '9.5');
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
