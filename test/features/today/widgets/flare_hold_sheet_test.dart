// Flare and Hold — the two SPEC.md §5.2 says every competitor gets wrong.
//
// The test that matters most is the second-candidate one: it is what catches a
// sheet that looks like a picker and confirms with a hardcoded default. It was
// written before either sheet existed, for exactly that reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:nearlystop/features/today/presentation/widgets/flare_sheet.dart';
import 'package:nearlystop/features/today/presentation/widgets/hold_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../../support/harness.dart';

void main() {
  const candidates = <FlareCandidate>[
    FlareCandidate(
      dose: Milligrams.fromHundredths(1000),
      label: '10mg — from 3 March to 24 April',
    ),
    FlareCandidate(
      dose: Milligrams.fromHundredths(1500),
      label: '15mg — from 1 January to 2 March',
    ),
  ];
  const prompt = FlarePrompt(
    candidates: candidates,
    defaultRevertTo: Milligrams.fromHundredths(1000),
    suggestedStep: Milligrams.fromHundredths(50),
    stepDiffersFromCommunity: false,
  );
  const holdPrompt = HoldPrompt(
    stepId: 7,
    blockLabel: 'Block 3 of 11',
    defaultExtraDays: 7,
    minExtraDays: 1,
    maxExtraDays: 28,
  );

  /// Opens a sheet from a button and hands back whatever it resolved to.
  Future<T?> open<T>(
    WidgetTester tester,
    Future<T?> Function(BuildContext, AppLocalizations) show, {
    TextScaler textScaler = TextScaler.noScaling,
    Locale locale = const Locale('en'),
  }) async {
    T? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async =>
                result = await show(context, AppLocalizations.of(context)),
            child: const Text('open'),
          ),
        ),
      ),
      locale: locale,
      textScaler: textScaler,
      surfaceSize: const Size(390, 844),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  group('the flare sheet', () {
    testWidgets('confirming the SECOND candidate returns THAT dose', (
      tester,
    ) async {
      // The test that catches the hardcoded-argument dialog. A sheet that
      // renders a picker and confirms with `defaultRevertTo` passes every
      // other test in this file.
      Milligrams? chosen;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => chosen = await showFlareSheet(
                context,
                prompt,
                AppLocalizations.of(context),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        surfaceSize: const Size(390, 844),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('15mg — from 1 January to 2 March'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record flare'));
      await tester.pumpAndSettle();

      expect(chosen, const Milligrams.fromHundredths(1500));
      expect(
        chosen,
        isNot(prompt.defaultRevertTo),
        reason: 'the sheet confirmed its default instead of the choice',
      );
    });

    testWidgets('cancelling returns null', (tester) async {
      final chosen = await open<Milligrams>(tester, (context, l10n) {
        final future = showFlareSheet(context, prompt, l10n);
        return future;
      });
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(chosen, isNull);
    });

    testWidgets('it states what is KEPT, verbatim', (tester) async {
      await open<Milligrams>(
        tester,
        (context, l10n) => showFlareSheet(context, prompt, l10n),
      );

      expect(
        find.text(
          'Your history and your total so far are kept. Days from today are '
          'rebuilt from this dose.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('with no completed steps it says so instead of an empty list', (
      tester,
    ) async {
      await open<Milligrams>(
        tester,
        (context, l10n) => showFlareSheet(
          context,
          const FlarePrompt(
            candidates: <FlareCandidate>[],
            defaultRevertTo: Milligrams.fromHundredths(1000),
            suggestedStep: Milligrams.fromHundredths(50),
            stepDiffersFromCommunity: false,
          ),
          l10n,
        ),
      );

      expect(find.byType(FlareCandidateTile), findsNothing);
      expect(
        find.textContaining('no earlier dose to go back to'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('the hold sheet', () {
    testWidgets('stepping to 5 and confirming returns 5', (tester) async {
      int? days;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => days = await showHoldSheet(
                context,
                holdPrompt,
                AppLocalizations.of(context),
                doseLabel: '9mg',
              ),
              child: const Text('open'),
            ),
          ),
        ),
        surfaceSize: const Size(390, 844),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Down from the default of 7.
      for (var press = 0; press < 2; press++) {
        await tester.tap(find.byKey(HoldStepperButton.decrementKey));
        await tester.pumpAndSettle();
      }
      expect(find.text('5'), findsOneWidget);
      await tester.tap(find.text('Hold'));
      await tester.pumpAndSettle();

      expect(days, 5);
    });

    testWidgets('the consequence names the dose AND the number of days', (
      tester,
    ) async {
      await open<int>(
        tester,
        (context, l10n) =>
            showHoldSheet(context, holdPrompt, l10n, doseLabel: '9mg'),
      );

      expect(
        find.textContaining('You stay at 9mg for 7 more days'),
        findsOneWidget,
      );
      expect(find.textContaining('nothing is lost'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('the stepper stops at its bounds, it does not wrap', (
      tester,
    ) async {
      await open<int>(
        tester,
        (context, l10n) =>
            showHoldSheet(context, holdPrompt, l10n, doseLabel: '9mg'),
      );

      // Down past 1.
      for (var press = 0; press < 10; press++) {
        await tester.tap(find.byKey(HoldStepperButton.decrementKey));
        await tester.pumpAndSettle();
      }
      expect(find.text('1'), findsOneWidget);
      expect(find.text('28'), findsNothing, reason: 'the stepper wrapped');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('cancelling returns null', (tester) async {
      final days = await open<int>(
        tester,
        (context, l10n) =>
            showHoldSheet(context, holdPrompt, l10n, doseLabel: '9mg'),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(days, isNull);
    });

    testWidgets('every target clears 44 at 2.0, with nothing overflowing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open<int>(
        tester,
        (context, l10n) =>
            showHoldSheet(context, holdPrompt, l10n, doseLabel: '9mg'),
        textScaler: const TextScaler.linear(2),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });
}
