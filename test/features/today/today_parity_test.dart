// The Today frame against `design/daybreak-screens.html`, measured.
//
// `daybreak-visual-parity` rule 10: a side-by-side that "looks right" has
// caught none of the value drifts this exists to catch. Every number below is
// read straight out of the mockup's CSS and is quoted beside the assertion, so
// the next person can re-derive it without opening Chrome.
//
// Captured at the reference's own geometry — 390x844 logical (rule 6). At any
// other width the spacing measurements compare two different layouts.
//
// This file is the exact tier and the tolerance tier. Rasterisation is not
// compared here and never will be (rule 1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/today/presentation/today_screen.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_hero_card.dart';
import 'package:nearlystop/features/today/presentation/widgets/new_dose_badge.dart';
import 'package:nearlystop/features/today/presentation/widgets/tablet_breakdown_pill.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

import '../../fixtures/seeded_plan.dart';
import '../../support/harness.dart';

/// The mockup's `.phone` content box. Not a device size — a contract.
const Size kReferenceFrame = Size(390, 844);

void main() {
  setUpAll(initializeDateFormatting);

  late BuildContext context;

  Future<void> pumpToday(WidgetTester tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      const TodayScreen(),
      overrides: seededScreenOverrides(l10n: l10n),
      surfaceSize: kReferenceFrame,
    );
    await tester.pumpAndSettle();
    context = tester.element(find.byType(TodayScreen));
  }

  group('exact tier — the values a human decided', () {
    testWidgets("the type scale is the mockup's seven steps", (tester) async {
      await pumpToday(tester);
      final text = Theme.of(context).textTheme;

      // --fs-display:72 --fs-title:34 --fs-heading:24
      // --fs-body-lg:20 --fs-body:17 --fs-label:15 --fs-caption:14
      expect(text.displayLarge!.fontSize, 72);
      expect(text.headlineLarge!.fontSize, 34);
      expect(text.titleLarge!.fontSize, 24);
      expect(text.bodyLarge!.fontSize, 20);
      expect(text.bodyMedium!.fontSize, 17);
      expect(text.labelMedium!.fontSize, 15);
      expect(text.labelSmall!.fontSize, 14);
    });

    testWidgets('each element takes the slot the mockup gives it', (
      tester,
    ) async {
      await pumpToday(tester);
      final type = DaybreakTypography.of(context);

      TextStyle styleOf(Finder finder) =>
          tester.widget<Text>(finder.first).style!;

      // .appbar h2 { font-size: var(--fs-title); font-weight: 800 }
      expect(styleOf(find.text('Today')).fontSize, 34);
      expect(styleOf(find.text('Today')).fontWeight, FontWeight.w800);

      // .hero .dose { font-size: var(--fs-display) }
      expect(
        styleOf(find.byKey(DoseHeroCard.numeralKey)).fontSize,
        72,
      );

      // .hero .dose .unit { font-size: 28px; font-weight: 700 }
      expect(type.doseUnit.fontSize, 28);
      expect(type.doseUnit.fontWeight, FontWeight.w700);

      // .badge { font-size: var(--fs-caption); font-weight: 800 }
      final badge = find.descendant(
        of: find.byType(NewDoseBadge),
        matching: find.byType(Text),
      );
      expect(styleOf(badge).fontSize, 14);
      expect(styleOf(badge).fontWeight, FontWeight.w800);

      // .hero .tablets { font-size: var(--fs-body); font-weight: 700 }
      final pill = find.descendant(
        of: find.byType(TabletBreakdownPill),
        matching: find.byType(Text),
      );
      expect(styleOf(pill).fontSize, 17);
      expect(styleOf(pill).fontWeight, FontWeight.w700);
    });

    testWidgets('every weight moved the axis, not just the field', (
      tester,
    ) async {
      // The defect this whole sweep came from: `copyWith(fontWeight:)` sets a
      // field the renderer ignores on a single-asset variable face, so the
      // text paints at the base slot's weight while claiming another. A style
      // whose `wght` axis disagrees with its `fontWeight` is that bug.
      await pumpToday(tester);

      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final style = text.style;
        if (style?.fontWeight == null || style?.fontVariations == null) {
          continue;
        }
        final axis = style!.fontVariations!
            .where((variation) => variation.axis == 'wght')
            .map((variation) => variation.value)
            .toList();
        if (axis.isEmpty) continue;

        expect(
          axis.single,
          style.fontWeight!.value.toDouble(),
          reason:
              '"${text.data}" asks for ${style.fontWeight} and pins the axis '
              'at ${axis.single} — it will paint at the axis, not the ask',
        );
      }
    });
  });

  group('tolerance tier — measured geometry, +/- 2 logical px', () {
    testWidgets("the frame is the mockup's .screenbody", (tester) async {
      await pumpToday(tester);

      // .screenbody { padding: var(--s-2) var(--s-5) var(--s-6) }
      final header = tester.getRect(find.byType(DoseHeroCard));
      expect(header.left, moreOrLessEquals(20, epsilon: 2));
      expect(
        header.right,
        moreOrLessEquals(kReferenceFrame.width - 20, epsilon: 2),
      );
    });

    testWidgets('the hero card is 350 wide, inset 20', (tester) async {
      await pumpToday(tester);

      final card = tester.getRect(find.byKey(DoseHeroCard.cardKey));
      expect(card.width, moreOrLessEquals(350, epsilon: 2));
      expect(card.left, moreOrLessEquals(20, epsilon: 2));
    });

    testWidgets('the hero pads its content by 20', (tester) async {
      await pumpToday(tester);

      // .hero { padding: var(--s-5) }
      final card = tester.getRect(find.byKey(DoseHeroCard.cardKey));
      final numeral = tester.getRect(find.byKey(DoseHeroCard.numeralKey));
      expect(numeral.left - card.left, moreOrLessEquals(20, epsilon: 2));
    });

    testWidgets('the badge is 34 tall', (tester) async {
      await pumpToday(tester);

      // .badge { min-height: 34px }
      expect(
        tester.getRect(find.byType(NewDoseBadge)).height,
        moreOrLessEquals(34, epsilon: 2),
      );
    });

    testWidgets('the Taken action is 88 tall — a DELIBERATE deviation', (
      tester,
    ) async {
      // `.btn { min-height: 56px }` in the mockup, and 88 here.
      //
      // Not drift. `daybreak-components` rule 10: 44 is the floor for a
      // secondary control, not the target for the one button a 74-year-old
      // with a tremor presses half-awake and one-handed. Accessibility
      // outranks parity, so the implementation is right and the REFERENCE is
      // the thing that is out of date.
      //
      // Pinned here so the deviation stays deliberate: if the reference is
      // ever regenerated at 88, this test still passes and the comment becomes
      // history. If somebody "fixes" the button to 56 to close a parity
      // finding, this fails and says why.
      await pumpToday(tester);

      expect(
        tester.getRect(find.byType(TakenButton)).height,
        moreOrLessEquals(88, epsilon: 2),
      );
      expect(TakenButton.minHeight, 88);
    });
  });
}
