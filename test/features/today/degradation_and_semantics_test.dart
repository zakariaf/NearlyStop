// The declared degradation order, and the screen as a sentence.
//
// **Both sides of every threshold.** A ladder tested only at 1.0 and 2.0
// passes with every threshold off by 0.3, which is exactly how a rung ends up
// firing at the wrong scale and nobody notices until a reader with large text
// reports that the number is gone.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_hero_card.dart';
import 'package:nearlystop/features/today/presentation/widgets/quiet_action_row.dart';
import 'package:nearlystop/features/today/presentation/widgets/sunrise_arc_painter.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

import '../../support/harness.dart';

void main() {
  const sentence =
      'Today, 9 milligrams: 1 × 5mg · 4 × 1mg. New dose day. Not yet taken.';

  Future<void> pumpHero(
    WidgetTester tester,
    double scale, {
    bool taken = false,
    String label = 'Mark as taken',
    Locale locale = const Locale('en'),
  }) => pumpApp(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: Material(
        child: DoseHeroCard(
          doseText: '9',
          unitText: 'mg',
          tabletsText: '1 × 5mg · 4 × 1mg',
          unachievableMessage: null,
          dayKindLabel: 'New dose day',
          isNewDoseDay: true,
          semanticsLabel: sentence,
          takenLabel: label,
          isTaken: taken,
          onTaken: () {},
          onUndo: () {},
        ),
      ),
    ),
    locale: locale,
    textScaler: TextScaler.linear(scale),
    surfaceSize: const Size(390, 1400),
  );

  group('the degradation ladder', () {
    testWidgets('the arc is there at 1.6 and GONE at 1.61', (tester) async {
      await pumpHero(tester, 1.6);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is SunriseArcPainter,
        ),
        findsOneWidget,
      );

      await pumpHero(tester, 1.61);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is SunriseArcPainter,
        ),
        findsNothing,
      );
    });

    testWidgets('amount and unit stay a Row at 1.3 and stack at 1.31', (
      tester,
    ) async {
      // The SECOND rung, and it fires earlier than the arc's: the numeral is
      // `displayLarge` beside a `titleLarge` unit, so the pair runs out of
      // width before the arc becomes the problem.
      await pumpHero(tester, 1.3);
      expect(
        (tester.getCenter(find.text('9')).dy -
                tester.getCenter(find.text('mg')).dy)
            .abs(),
        lessThan(40),
        reason: 'they stacked at 1.3',
      );

      await pumpHero(tester, 1.31);

      expect(tester.takeException(), isNull);
    });

    testWidgets('the numeral NEVER shrinks — five scales, one size', (
      tester,
    ) async {
      // No `FittedBox`, no computed `fontSize`, no ellipsis. Shrinking the one
      // number the patient reads every morning turns a loud layout failure
      // into a quietly wrong dose.
      final sizes = <double>[];
      for (final scale in <double>[1, 1.3, 1.6, 1.8, 2]) {
        await pumpHero(tester, scale);
        sizes.add(tester.widget<Text>(find.text('9')).style!.fontSize!);
        expect(find.byType(FittedBox), findsNothing, reason: 'scale $scale');
        expect(tester.takeException(), isNull, reason: 'scale $scale');
      }

      expect(
        sizes.toSet(),
        hasLength(1),
        reason: 'the numeral was resized at some scale: $sizes',
      );
    });

    testWidgets('the numeral is the display role, tabular', (tester) async {
      late DaybreakTypography type;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            type = DaybreakTypography.of(context);
            return Align(
              alignment: Alignment.topCenter,
              child: Material(
                child: DoseHeroCard(
                  doseText: '9',
                  unitText: 'mg',
                  tabletsText: '1 × 5mg',
                  unachievableMessage: null,
                  dayKindLabel: 'New dose day',
                  isNewDoseDay: true,
                  semanticsLabel: sentence,
                  takenLabel: 'Mark as taken',
                  isTaken: false,
                  onTaken: () {},
                  onUndo: () {},
                ),
              ),
            );
          },
        ),
        surfaceSize: const Size(390, 1400),
      );

      final numeral = tester.widget<Text>(find.text('9'));
      expect(numeral.style!.fontSize, type.doseNumeral.fontSize);
      expect(numeral.style!.fontFeatures, type.doseNumeral.fontFeatures);
    });

    testWidgets('the text scale is NEVER clamped anywhere in this feature', (
      tester,
    ) async {
      // Asserted over the source. A clamp is invisible in a rendering and
      // takes the reader's OS setting away from them.
      final offenders = <String>[];
      for (final file
          in Directory('lib/features/today')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        if (source.contains('textScaler:') && source.contains('MediaQuery(')) {
          offenders.add(file.path);
        }
        if (source.contains('withClampedTextScaling')) offenders.add(file.path);
      }

      expect(offenders, isEmpty);
    });
  });

  group('the screen as a sentence', () {
    testWidgets('the hero is ONE node with the whole sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHero(tester, 1);

      expect(tester.getSemantics(find.byType(DoseHeroCard)).label, sentence);
      handle.dispose();
    });

    testWidgets('the Taken control is a SEPARATE node, and a button', (
      tester,
    ) async {
      // Folded into the hero's label it would be a card a screen-reader user
      // can hear and has no way to act on — the one thing this screen is for.
      final handle = tester.ensureSemantics();
      await pumpHero(tester, 1);

      expect(
        tester.getSemantics(find.byType(TakenButton)),
        isSemantics(isButton: true, label: 'Mark as taken'),
      );
      handle.dispose();
    });

    testWidgets('taken flips the label and announces it', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHero(tester, 1, taken: true, label: 'Taken at 08:12');

      expect(
        tester.getSemantics(find.byType(TakenButton)).label,
        'Taken at 08:12',
      );
      // The live region wraps the ACTION, not the card: what is announced when
      // the state flips is "taken", and hanging it on the whole hero would
      // re-read the dose every time anything changed.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.liveRegion ?? false),
        ),
        findsOneWidget,
        reason: 'the confirmation was not announced',
      );
      handle.dispose();
    });

    testWidgets('the guidelines pass at 1.0 and at 2.0', (tester) async {
      for (final scale in <double>[1, 2]) {
        final handle = tester.ensureSemantics();
        await pumpHero(tester, scale);

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      }
    });
  });

  group('the quiet row ladder', () {
    testWidgets('Row at 1.5, Column at 1.51 — the OTHER threshold', (
      tester,
    ) async {
      Future<Set<double>> tops(double scale) async {
        await pumpApp(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: Material(
              child: QuietActionRow(
                noteLabel: 'Add note',
                holdLabel: 'Hold',
                flareLabel: 'Flare',
                holdDisabledReason: null,
                onAddNote: () {},
                onHold: () {},
                onFlare: () {},
              ),
            ),
          ),
          textScaler: TextScaler.linear(scale),
          surfaceSize: const Size(390, 1400),
        );
        return tester
            .widgetList<QuietActionTile>(find.byType(QuietActionTile))
            .map((tile) => tester.getTopLeft(find.byWidget(tile)).dy)
            .toSet();
      }

      expect(await tops(1.5), hasLength(1));
      expect(await tops(1.51), hasLength(3));
    });
  });

  group('the flare prompt reaches the screen intact', () {
    test('an empty candidate list is still a valid prompt', () {
      // Day one: nothing completed yet, and the sheet says so rather than
      // rendering an empty picker.
      const prompt = FlarePrompt(
        candidates: <FlareCandidate>[],
        defaultRevertTo: Milligrams.fromHundredths(900),
        suggestedStep: Milligrams.fromHundredths(50),
        stepDiffersFromCommunity: false,
      );

      expect(prompt.candidates, isEmpty);
      expect(prompt.defaultRevertTo.hundredths, 900);
    });
  });
}
