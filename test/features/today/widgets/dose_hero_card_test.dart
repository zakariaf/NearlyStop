// The card the patient looks at every morning for 780 days.
//
// The properties here are correctness with visual consequences, not styling:
// one sentence for a screen reader instead of four fragments, a numeral that
// never shrinks, and an action that cannot fire twice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_hero_card.dart';
import 'package:nearlystop/features/today/presentation/widgets/new_dose_badge.dart';
import 'package:nearlystop/features/today/presentation/widgets/sunrise_arc_painter.dart';
import 'package:nearlystop/features/today/presentation/widgets/tablet_breakdown_pill.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

import '../../../support/contrast.dart';
import '../../../support/harness.dart';

const _sentence =
    'Today, 9 milligrams: one 5 milligram tablet, four 1 milligram tablets. '
    'Not yet taken.';

void main() {
  var taps = 0;

  setUp(() => taps = 0);

  Future<void> pumpCard(
    WidgetTester tester, {
    bool isTaken = false,
    bool isNewDoseDay = true,
    String? tabletsText = '1 × 5mg · 4 × 1mg',
    String? unachievableMessage,
    String takenLabel = 'Taken',
    VoidCallback? onTaken,
    VoidCallback? onUndo,
    TextScaler textScaler = TextScaler.noScaling,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
  }) => pumpApp(
    tester,
    DoseHeroCard(
      doseText: '9',
      unitText: 'mg',
      tabletsText: tabletsText,
      unachievableMessage: unachievableMessage,
      dateText: 'Wed, Apr 16',
      dayKindLabel: 'New dose day',
      isNewDoseDay: isNewDoseDay,
      semanticsLabel: _sentence,
      takenLabel: takenLabel,
      isTaken: isTaken,
      onTaken: onTaken ?? () => taps++,
      onUndo: onUndo ?? () {},
    ),
    locale: locale,
    brightness: brightness,
    textScaler: textScaler,
  );

  testWidgets('one tap on the action records once; the card is not a button', (
    tester,
  ) async {
    await pumpCard(tester);

    await tester.tap(find.text('Taken'));
    await tester.pump();
    expect(taps, 1);

    // Tapping the card BODY must not record a dose: there is exactly one
    // place to say "I took it", and it is the button.
    await tester.tap(find.text('1 × 5mg · 4 × 1mg'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('an already-taken dose cannot be recorded again', (tester) async {
    await pumpCard(tester, isTaken: true);

    await tester.tap(find.text('Taken'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('the whole card is ONE sentence, not four fragments', (
    tester,
  ) async {
    // VoiceOver reading "Wed, Apr 16" … "New dose day" … "9" … "mg" is four
    // things a listener has to reassemble. SPEC 5.4 specifies the sentence.
    await pumpCard(tester);

    final node = tester.getSemantics(find.byType(DoseHeroCard));

    expect(node.label, contains(_sentence));
    expect(find.bySemanticsLabel('Wed, Apr 16'), findsNothing);
    expect(find.bySemanticsLabel('New dose day'), findsNothing);
  });

  // A slow press is covered below. Deliberately NOT "long-press does
  // nothing": this button is pressed by a 74-year-old with a tremor, half
  // awake, one-handed, and a press held past the tap threshold is the same
  // intent. What must not exist is a long-press-ONLY path — covered above by
  // the card body recording nothing.
  testWidgets('a slow press records, once', (tester) async {
    await pumpCard(tester);

    await tester.longPress(find.text('Taken'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('the action keeps its own button node', (tester) async {
    await pumpCard(tester);

    // Found by its LABEL, because the wrapping `Semantics` merges with the
    // button's own node and `find.byType(FilledButton)` lands on the widget
    // above the merge.
    final node = tester.getSemantics(find.bySemanticsLabel('Taken'));

    expect(node.flagsCollection.isButton, isTrue);
    // A tristate, not a bool: a node can be enabled, disabled, or carry no
    // enabled-state at all. `isTrue` is the one that means actionable.
    expect(node.flagsCollection.isEnabled.name, 'isTrue');
    expect(node.label, 'Taken');
  });

  testWidgets('degradation drops the ARC first, then the row', (tester) async {
    // Decoration goes before content, always. The arc carries no meaning; the
    // numeral and the tablet line do.
    await pumpCard(tester, textScaler: const TextScaler.linear(1.5));
    expect(find.byType(SunriseArcPainter), findsNothing);
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any(
            (paint) => paint.painter is SunriseArcPainter,
          ),
      isTrue,
      reason: 'the arc is still drawn at 1.5',
    );

    await pumpCard(tester, textScaler: const TextScaler.linear(1.7));

    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any(
            (paint) => paint.painter is SunriseArcPainter,
          ),
      isFalse,
      reason: 'the arc is gone at 1.7',
    );
  });

  testWidgets('the numeral NEVER shrinks, at any scale', (tester) async {
    // A FittedBox here turns a loud layout failure into a quietly wrong number
    // on a phone, and this audience will not notice the difference.
    for (final scale in <double>[1, 1.5, 2]) {
      await pumpCard(tester, textScaler: TextScaler.linear(scale));

      final context = tester.element(find.byType(DoseHeroCard));
      final numeral = tester.widget<Text>(find.text('9'));

      expect(
        numeral.style?.fontSize,
        DaybreakTypography.of(context).doseNumeral.fontSize,
        reason: 'scale $scale shrank the numeral',
      );
      expect(numeral.overflow, isNot(TextOverflow.ellipsis));
      expect(find.byType(FittedBox), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('onPrimary clears 4.5:1 on BOTH sunrise endpoints', (
    tester,
  ) async {
    // A gradient is only as readable as its worst stop, and the card's whole
    // job is to be readable.
    for (final brightness in Brightness.values) {
      await pumpCard(tester, brightness: brightness);
      final colors = DaybreakColors.of(
        tester.element(find.byType(DoseHeroCard)),
      );

      for (final stop in colors.sunrise.colors) {
        expect(
          contrastRatio(colors.onPrimary, stop),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness stop $stop',
        );
      }
    }
  });

  testWidgets('it mirrors, and meets the guidelines, in fa as well as en', (
    tester,
  ) async {
    for (final locale in <Locale>[const Locale('en'), const Locale('fa')]) {
      await pumpCard(tester, locale: locale);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(
        Directionality.of(tester.element(find.byType(DoseHeroCard))),
        locale.languageCode == 'fa' ? TextDirection.rtl : TextDirection.ltr,
      );
    }
  });

  testWidgets('the action is 88 tall — this is not a 48pt target', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(tester.getSize(find.byType(TakenButton)).height, 88);
  });

  testWidgets('the Taken action GROWS at 200%, it does not clip', (
    tester,
  ) async {
    // 88 is a FLOOR, not a height. Pinned as a fixed `height:` the label
    // overflows the moment the reader turns text up — on the one control this
    // app exists to be pressed. Recipe 4's `TakenButton` owns this; the hero
    // card had its own `FilledButton` from before that existed, with the wrong
    // ink slot, no shadow, no haptic and no press scale.
    await pumpCard(tester);
    final small = tester.getSize(find.byType(TakenButton)).height;
    expect(small, greaterThanOrEqualTo(88));

    await pumpCard(tester, textScaler: const TextScaler.linear(2));

    expect(
      tester.getSize(find.byType(TakenButton)).height,
      greaterThanOrEqualTo(tester.getSize(find.text('Taken')).height),
      reason: 'the label was clipped by a fixed height',
    );
    expect(tester.takeException(), isNull);
  });

  group('task 5: the badge, the pill and the unachievable path', () {
    testWidgets('isNewDoseDay renders the badge with a glyph AND words', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(find.byType(NewDoseBadge), findsOneWidget);
      expect(find.text('New dose day'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NewDoseBadge),
          matching: find.byIcon(NewDoseBadge.glyph),
        ),
        findsOneWidget,
        reason: 'shape + glyph + label, never the colour alone',
      );
    });

    testWidgets('an old-dose day leaves the slot EMPTY, not a second badge', (
      tester,
    ) async {
      await pumpCard(tester, isNewDoseDay: false);

      expect(find.byType(NewDoseBadge), findsNothing);
      expect(find.text('New dose day'), findsNothing);
    });

    testWidgets('the tablets pill carries the breakdown', (tester) async {
      await pumpCard(tester);

      expect(find.byType(TabletBreakdownPill), findsOneWidget);
      expect(find.text('1 × 5mg · 4 × 1mg'), findsOneWidget);
    });

    testWidgets('an unachievable dose replaces the pill with the FLAG', (
      tester,
    ) async {
      // SPEC.md §3.3 and CLAUDE.md rule 5: flagged, never rounded — and never
      // shown beside a breakdown that invites the reader to take it anyway.
      await pumpCard(
        tester,
        tabletsText: null,
        unachievableMessage: 'Cannot be made from the tablets you hold: 0.75mg',
      );

      expect(find.byType(TabletBreakdownPill), findsNothing);
      expect(
        find.text('Cannot be made from the tablets you hold: 0.75mg'),
        findsOneWidget,
      );
    });

    testWidgets('when taken, the action UNDOES rather than re-marking', (
      tester,
    ) async {
      var taken = 0;
      var undone = 0;
      await pumpCard(
        tester,
        isTaken: true,
        takenLabel: 'Taken at 08:12',
        onTaken: () => taken++,
        onUndo: () => undone++,
      );

      await tester.tap(find.text('Taken at 08:12'));
      await tester.pumpAndSettle();

      expect(taken, 0, reason: 'a second tap re-marked an already-taken day');
      expect(undone, 1);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
