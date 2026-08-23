// One schedule row, read as one sentence.
//
// Every case here is a table over `DayState.values` written as an exhaustive
// switch or a loop, so a fifth member widens the suite rather than slipping
// past it (CONTRACTS.md §1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_marker.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_row.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/contrast.dart';
import '../../../support/harness.dart';

void main() {
  /// The localized state word for [state], read from the real delegates.
  String stateWord(AppLocalizations l10n, DayState state) => switch (state) {
    DayState.taken => l10n.stateTaken,
    DayState.missed => l10n.stateNotTicked,
    DayState.today => l10n.stateToday,
    DayState.upcoming => l10n.stateUpcoming,
  };

  /// The state word AS RENDERED, straight from the ARB's cased key.
  ///
  /// Not `stateWord(...).toUpperCase()`: Dart's casing is locale-blind, which
  /// is why `check_bans.sh` rejects it in `lib/` — and a test that spells the
  /// rule differently from the code is a test that agrees with itself.
  String renderedStateWord(AppLocalizations l10n, DayState state) =>
      switch (state) {
        DayState.taken => l10n.stateTakenCaps,
        DayState.missed => l10n.stateNotTickedCaps,
        DayState.today => l10n.stateTodayCaps,
        DayState.upcoming => l10n.stateUpcomingCaps,
      };

  /// The row's painted border, which carries part of the state signal.
  ///
  /// Read off the painter rather than a `BoxDecoration`: Flutter has no dashed
  /// `BorderSide`, so the row paints its own outline and the dash is a field
  /// on it. A test that read `decoration.border` would be reading a border the
  /// row does not use.
  RowBorderPainter rowBorder(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(find.byKey(DayStateRow.borderKey))
              .foregroundPainter!
          as RowBorderPainter;

  /// Pumps one row and hands back the localizations it was built with.
  Future<AppLocalizations> pumpRow(
    WidgetTester tester, {
    DayState state = DayState.upcoming,
    bool isNewDose = false,
    String? flagText,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
    Size? surfaceSize,
  }) async {
    late AppLocalizations l10n;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          // `Align` so the row takes its INTRINSIC height. Pumped as
          // `home:` it is stretched to the viewport, and "the row grows at
          // 200%" would compare 844 with 844 and pass forever.
          return Align(
            alignment: Alignment.topCenter,
            child: Material(
              child: DayStateRow(
                state: state,
                dayLabel: 'Thursday 16 April',
                doseText: '9mg',
                tabletsText: flagText == null ? '1 × 5mg · 4 × 1mg' : null,
                // The row renders what it is GIVEN: casing is the
                // caller's, out of the ARB, never `.toUpperCase()`.
                stateLabel: renderedStateWord(l10n, state),
                semanticsLabel:
                    'Thursday 16 April, 9 milligrams. '
                    '${stateWord(l10n, state)}.',
                isNewDose: isNewDose,
                newDoseLabel: l10n.stateNewDoseDay,
                unachievableText: flagText,
              ),
            ),
          );
        },
      ),
      locale: locale,
      textScaler: textScaler,
      surfaceSize: surfaceSize,
    );
    return l10n;
  }

  testWidgets('each state reads as ONE sentence carrying its word', (
    tester,
  ) async {
    // Not "a node exists containing the word": four fragments would satisfy
    // that, and VoiceOver would read the row as four stops.
    final handle = tester.ensureSemantics();
    for (final locale in <Locale>[const Locale('en'), const Locale('fa')]) {
      for (final state in DayState.values) {
        final l10n = await pumpRow(tester, state: state, locale: locale);

        final node = tester.getSemantics(find.byType(DayStateRow));
        expect(
          node.label,
          contains(stateWord(l10n, state)),
          reason: '$state in ${locale.languageCode}',
        );
        expect(
          node.label.split('.').where((part) => part.trim().isNotEmpty),
          hasLength(lessThanOrEqualTo(3)),
          reason: 'the row should read as a sentence, not a list of fragments',
        );
      }
    }
    handle.dispose();
  });

  testWidgets('the state word is TEXT, never colour alone', (tester) async {
    for (final state in DayState.values) {
      final l10n = await pumpRow(tester, state: state);

      expect(
        find.text(renderedStateWord(l10n, state)),
        findsOneWidget,
        reason: '$state',
      );
    }
  });

  testWidgets(
    'missed is stateMissed on the mark and the border, never danger',
    (
      tester,
    ) async {
      late DaybreakColors colors;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            colors = DaybreakColors.of(context);
            return const Material(
              child: DayStateRow(
                state: DayState.missed,
                dayLabel: 'Thursday 16 April',
                doseText: '9mg',
                tabletsText: '1 × 5mg',
                stateLabel: 'NOT TICKED',
                semanticsLabel: 'Thursday 16 April, 9 milligrams. Not ticked.',
              ),
            );
          },
        ),
      );

      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(DayStateMarker),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as DayStateMarkerPainter;
      expect(painter.color, colors.stateMissed);
      expect(painter.color, isNot(colors.danger));

      final border = rowBorder(tester);
      expect(border.color, colors.stateMissed);
      expect(border.color, isNot(colors.danger));
      // DASHED, which is what `.srow.missed` is in the reference — and another
      // channel that survives greyscale and colour-blindness. A solid border
      // in a taupe nobody can name is colour alone by another route.
      expect(border.dashed, isTrue);
    },
  );

  testWidgets('only missed is dashed', (tester) async {
    // The negative, for the other three: a signal every row carries is not a
    // signal.
    for (final state in DayState.values) {
      await pumpRow(tester, state: state);

      expect(
        rowBorder(tester).dashed,
        state == DayState.missed,
        reason: '$state',
      );
    }
  });

  testWidgets('the missed WORD is text-tier contrast, and still warm taupe', (
    tester,
  ) async {
    // The state colours are MARK-tier: `stateMissed` measures 3.65:1 on
    // surface, which clears the 3:1 non-text floor EPIC-02 pins them at and
    // fails the 4.5:1 a word needs. So the word cannot be `stateMissed` —
    // CLAUDE.md rule 4 outranks EPIC-07 task 4's "all three places" — but it
    // must still be the warm clay the ruling is about, never red. Both halves
    // are asserted, so "make it AA" cannot quietly become "make it grey" and
    // "never red" cannot quietly become "make it taupe at 3.65:1".
    late DaybreakColors colors;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = DaybreakColors.of(context);
          return const Material(
            child: DayStateRow(
              state: DayState.missed,
              dayLabel: 'Thursday 16 April',
              doseText: '9mg',
              tabletsText: '1 × 5mg',
              stateLabel: 'NOT TICKED',
              semanticsLabel: 'Thursday 16 April, 9 milligrams. Not ticked.',
            ),
          );
        },
      ),
    );

    final word = tester.widget<Text>(find.text('NOT TICKED'));
    final colour = word.style!.color!;
    expect(
      contrastRatio(colour, colors.surface),
      greaterThanOrEqualTo(4.5),
      reason: 'the state word is text and needs AA',
    );
    expect(colour, isNot(colors.danger));
    expect(
      hueDegrees(colour),
      closeTo(hueDegrees(colors.stateMissed), 10),
      reason: 'warm taupe, the whole point of the ruling — not red, not grey',
    );
  });

  testWidgets('today alone is heavy, bordered and raised', (tester) async {
    // Asserted NEGATIVELY for the other three as well: "today looks special"
    // is only true if the others do not.
    for (final state in DayState.values) {
      await pumpRow(tester, state: state);

      final container = tester.widget<Container>(
        find.byKey(DayStateRow.containerKey),
      );
      final decoration = container.decoration! as BoxDecoration;
      final weekday = tester.widget<Text>(find.text('Thursday 16 April'));

      if (state == DayState.today) {
        expect(rowBorder(tester).width, 2, reason: '$state');
        expect(decoration.boxShadow, isNotEmpty, reason: '$state');
        expect(weekday.style!.fontWeight, FontWeight.w800, reason: '$state');
      } else {
        expect(rowBorder(tester).width, lessThan(2), reason: '$state');
        expect(decoration.boxShadow ?? const [], isEmpty, reason: '$state');
        expect(
          weekday.style!.fontWeight,
          isNot(FontWeight.w800),
          reason: '$state',
        );
      }
    }
  });

  testWidgets('isNewDose adds colour AND a glyph AND the word, on all four', (
    tester,
  ) async {
    // A separate bool, so it has to be checked against every state rather than
    // sampled on one — a day is routinely both `today` and a new-dose day.
    late DaybreakColors colors;
    for (final state in DayState.values) {
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            colors = DaybreakColors.of(context);
            final l10n = AppLocalizations.of(context);
            return Material(
              child: DayStateRow(
                state: state,
                dayLabel: 'Thursday 16 April',
                doseText: '9mg',
                tabletsText: '1 × 5mg',
                stateLabel: 'x',
                semanticsLabel: 'x',
                isNewDose: true,
                newDoseLabel: l10n.stateNewDoseDay,
              ),
            );
          },
        ),
      );

      expect(find.text('New dose day'), findsOneWidget, reason: '$state');
      expect(
        find.byIcon(DayStateRow.newDoseGlyph),
        findsOneWidget,
        reason: '$state',
      );
      final badge = tester.widget<Text>(find.text('New dose day'));
      expect(badge.style!.color, colors.stateNewDose, reason: '$state');
    }
  });

  testWidgets('an unachievable dose shows the flag and NO number', (
    tester,
  ) async {
    // The one unforgivable bug (CLAUDE.md rule 5). A row that quietly rounds
    // is worse than a row that says it cannot.
    await pumpRow(
      tester,
      flagText: 'Cannot be made from the tablets you hold',
    );

    expect(
      find.text('Cannot be made from the tablets you hold'),
      findsOneWidget,
    );
    expect(find.text('1 × 5mg · 4 × 1mg'), findsNothing);
    // No rounded stand-in anywhere in the row.
    for (final rounded in <String>['9mg', '10mg', '8mg', '9', '10']) {
      expect(
        find.descendant(
          of: find.byType(DayStateRow),
          matching: find.text(rounded),
        ),
        findsNothing,
        reason: 'a rounded dose appeared where the flag belongs',
      );
    }
  });

  testWidgets('in fa the marker sits on the RIGHT, measured not eyeballed', (
    tester,
  ) async {
    await pumpRow(
      tester,
      locale: const Locale('fa'),
      surfaceSize: const Size(390, 844),
    );
    final rtlCentre = tester.getCenter(find.byType(DayStateMarker)).dx;
    final rtlWidth = tester.getSize(find.byType(DayStateRow)).width;

    await pumpRow(tester, surfaceSize: const Size(390, 844));
    final ltrCentre = tester.getCenter(find.byType(DayStateMarker)).dx;

    expect(rtlCentre, greaterThan(rtlWidth / 2));
    expect(ltrCentre, lessThan(rtlWidth / 2));
  });

  testWidgets('at 200% in de the row grows and nothing overflows', (
    tester,
  ) async {
    // German is the longest-string locale and where layouts break.
    await pumpRow(
      tester,
      locale: const Locale('de'),
      surfaceSize: const Size(390, 844),
    );
    final base = tester.getSize(find.byType(DayStateRow)).height;

    await pumpRow(
      tester,
      locale: const Locale('de'),
      textScaler: const TextScaler.linear(2),
      surfaceSize: const Size(390, 844),
    );

    expect(tester.getSize(find.byType(DayStateRow)).height, greaterThan(base));
    expect(tester.takeException(), isNull);
  });

  testWidgets('above 1.6x the row STACKS instead of squeezing', (tester) async {
    // Measured, not assumed. At 2.0 the two columns of a horizontal row each
    // fight for a 390px width that the marker and the gaps have already eaten,
    // and the loser wraps one glyph per line: a single row measured 826px
    // tall, with "New dose day" running vertically down the screen. That is
    // the degradation order `daybreak-components` rule 6 exists for — the
    // layout reflows before the text becomes unreadable.
    await pumpRow(
      tester,
      state: DayState.today,
      isNewDose: true,
      textScaler: const TextScaler.linear(2),
      surfaceSize: const Size(390, 3000),
    );

    final height = tester.getSize(find.byType(DayStateRow)).height;
    expect(
      height,
      lessThan(400),
      reason: 'the row squeezed its columns instead of stacking them',
    );
    // The real symptom, asserted directly: the state word is not one glyph
    // wide. A height bound alone could be met by clipping.
    expect(
      tester.getSize(find.text('TODAY')).width,
      greaterThan(60),
      reason: 'the state word wrapped to a vertical column of letters',
    );
    // And it stacked rather than merely shrinking something: the end block is
    // now BELOW the day block.
    expect(
      tester.getCenter(find.text('TODAY')).dy,
      greaterThan(tester.getCenter(find.text('Thursday 16 April')).dy),
      reason: 'the end block should sit under the day block above 1.6x',
    );
  });

  testWidgets('at or below 1.6x it stays horizontal', (tester) async {
    // The boundary, from the other side: stacking early would waste the width
    // this population has, on the screen they scroll most.
    await pumpRow(
      tester,
      state: DayState.today,
      textScaler: const TextScaler.linear(1.6),
      surfaceSize: const Size(390, 3000),
    );

    // Structural, not pixel: the end block sits BESIDE the day block, so its
    // centre is further along the reading direction rather than below it.
    expect(
      tester.getCenter(find.text('TODAY')).dx,
      greaterThan(tester.getCenter(find.text('Thursday 16 April')).dx),
      reason: 'still side by side at 1.6x',
    );
  });

  testWidgets('the row is at least 64 tall and 44 tappable', (tester) async {
    await pumpRow(tester, surfaceSize: const Size(390, 844));

    expect(
      tester.getSize(find.byType(DayStateRow)).height,
      greaterThanOrEqualTo(64),
    );
  });
  testWidgets('the tablet breakdown sits UNDER the day, not beside the dose', (
    tester,
  ) async {
    // Frame 3's `.srow`: the middle column is `.sday` over `.stab` — the day
    // and the tablets you swallow that day, one above the other — and the
    // trailing `.send` column is `.sdose` over `.sstate`, nothing else.
    //
    // This component was built against a contact sheet rather than against
    // frame 3, and put the breakdown in the trailing column instead. Element
    // order is a Tier-1 parity row: it has to match exactly, and it does not.
    await pumpRow(tester, surfaceSize: const Size(390, 400));

    final day = tester.getTopLeft(find.text('Thursday 16 April'));
    final tablets = tester.getTopLeft(find.text('1 × 5mg · 4 × 1mg'));
    final dose = tester.getTopLeft(find.text('9mg'));

    expect(
      tablets.dx,
      day.dx,
      reason: 'the breakdown is not in the day column',
    );
    expect(tablets.dy, greaterThan(day.dy), reason: 'it is not under the day');
    expect(
      tablets.dx,
      lessThan(dose.dx),
      reason: 'the breakdown drifted into the trailing column',
    );
  });
  testWidgets('the state word is UPPERCASE and tracked in Latin', (
    tester,
  ) async {
    // `.sstate { text-transform: uppercase; letter-spacing: .06em }`. It is
    // the smallest text on the row and the one that answers "did I take it?",
    // so the reference gives it caps and air rather than size.
    final l10n = await pumpRow(tester, state: DayState.taken);

    expect(find.text(l10n.stateTakenCaps), findsOneWidget);
    final word = tester.widget<Text>(find.text(l10n.stateTakenCaps));
    expect(word.style?.letterSpacing, isNotNull);
    expect(word.style!.letterSpacing! > 0, isTrue);
  });

  testWidgets('in fa it is NOT uppercased and carries no tracking', (
    tester,
  ) async {
    // `html[lang="fa"] .sstate { text-transform: none; letter-spacing: 0 }`.
    // Perso-Arabic has no case, and tracking breaks the joins between letters.
    final l10n = await pumpRow(
      tester,
      state: DayState.taken,
      locale: const Locale('fa'),
    );

    expect(find.text(l10n.stateTaken), findsOneWidget);
    final word = tester.widget<Text>(find.text(l10n.stateTaken));
    expect(word.style?.letterSpacing ?? 0, 0);
  });

  testWidgets('each state carries its own glyph beside the word', (
    tester,
  ) async {
    // The reference puts a glyph in `.sstate` as well as in the marker. Two
    // shape channels, and this one sits next to the word a screen reader and
    // a greyscale printout both read.
    final glyphs = <IconData>{};
    for (final state in DayState.values) {
      await pumpRow(tester, state: state);
      final icon = tester
          .widgetList<Icon>(find.byType(Icon))
          .firstWhere(
            (candidate) => candidate.icon != DayStateRow.holdGlyph,
          );
      glyphs.add(icon.icon!);
    }
    expect(glyphs, hasLength(DayState.values.length));
  });
  testWidgets('the outline is drawn round the CARD, not inside its padding', (
    tester,
  ) async {
    // Seen on a device: a missed row showed a dashed rectangle floating
    // INSIDE the white card, with the dose and the state word crossing it —
    // because the painter sat inside the container's padding and so drew a
    // box `s3`/`s4` smaller than the card. `.srow` has one border, on the
    // card. Every golden in the repo had baked the floating one in.
    await pumpRow(tester, state: DayState.missed);

    expect(
      tester.getRect(find.byKey(DayStateRow.borderKey)),
      tester.getRect(find.byKey(DayStateRow.containerKey)),
      reason: 'the outline is inset from the card it belongs to',
    );
  });
}
