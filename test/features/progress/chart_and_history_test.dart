// The chart card, and the thing it degrades to.
//
// A painted chart is a blank rectangle to a screen reader, and the population
// that needs this app most is the one most likely to be running VoiceOver at
// 200%. So the non-visual form is not a fallback nobody tests — it is what the
// layout BECOMES above 1.5×, and these are the tests that make that true.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/features/progress/presentation/widgets/dose_history_list.dart';
import 'package:nearlystop/features/progress/presentation/widgets/dose_staircase_chart.dart';
import 'package:nearlystop/features/progress/presentation/widgets/dose_staircase_painter.dart';

import '../../support/harness.dart';

void main() {
  const segments = <DoseSegment>[
    DoseSegment(
      startDayIndex: 0,
      endDayIndex: 51,
      dose: Milligrams.fromHundredths(1500),
    ),
    DoseSegment(
      startDayIndex: 52,
      endDayIndex: 103,
      dose: Milligrams.fromHundredths(900),
    ),
  ];
  const summary =
      'Chart: your dose fell from 15 milligrams in Sep 2024 to 9 milligrams '
      'in Apr 2026, with 2 flares and 1 hold recorded.';
  const rows = <String>[
    '15 milligrams from 12 September 2024 for 52 days',
    'Flare on 3 March 2025, back to 10 milligrams',
    '9 milligrams from 3 November 2024 for 52 days',
  ];

  Future<void> pumpChart(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
    Locale locale = const Locale('en'),
  }) => pumpApp(
    tester,
    const DoseStaircaseChart(
      segments: segments,
      flares: <FlareMark>[],
      holds: <HoldMark>[],
      todayDayIndex: 103,
      todayDose: Milligrams.fromHundredths(900),
      axis: ProgressAxis(
        minDose: Milligrams.fromHundredths(900),
        maxDose: Milligrams.fromHundredths(1500),
        firstLabel: 'Sep 2024',
        lastLabel: 'Apr 2026',
      ),
      summary: summary,
      historyRows: rows,
      eventCountLabel: '2 flares and 1 hold recorded',
    ),
    locale: locale,
    textScaler: textScaler,
    surfaceSize: const Size(390, 900),
  );

  testWidgets('the chart is one semantics node, and it is a SENTENCE', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpChart(tester);

    expect(find.byType(CustomPaint), findsWidgets);
    // ONE node carrying the whole sentence. A screen reader that stops on a
    // blank rectangle has been told nothing.
    expect(find.bySemanticsLabel(summary), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the painted subtree contributes NO semantics of its own', (
    tester,
  ) async {
    // Otherwise a screen reader stops on a blank rectangle between the summary
    // and the rest of the page.
    final handle = tester.ensureSemantics();
    await pumpChart(tester);

    expect(
      find.descendant(
        of: find.byType(DoseStaircaseChart),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('above 1.5× the chart becomes the LIST, on both sides', (
    tester,
  ) async {
    // A 176px canvas cannot carry legible axis labels at 200%, and shrinking
    // them is the defect `accessibility-as-code` bans. So the chart is not
    // squeezed — it is replaced.
    await pumpChart(tester, textScaler: const TextScaler.linear(1.5));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(DoseHistoryList), findsNothing);

    await pumpChart(tester, textScaler: const TextScaler.linear(1.51));
    expect(find.byType(DoseHistoryList), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DoseStaircaseChart),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );

    for (final scale in <double>[1.51, 1.8, 2]) {
      await pumpChart(tester, textScaler: TextScaler.linear(scale));
      expect(tester.takeException(), isNull, reason: '$scale');
    }
  });

  testWidgets('the history list is real text, in the order it was given', (
    tester,
  ) async {
    // Not a hidden `Semantics` string: a low-vision sighted reader needs this
    // as much as a screen-reader user does, and only one of them can hear it.
    await pumpApp(
      tester,
      const Material(
        child: DoseHistoryList(title: 'Dose history as a list', rows: rows),
      ),
      surfaceSize: const Size(390, 900),
    );

    for (final row in rows) {
      expect(find.text(row), findsOneWidget);
    }
    final tops = <double>[
      for (final row in rows) tester.getTopLeft(find.text(row)).dy,
    ];
    expect(
      tops,
      orderedEquals(<double>[...tops]..sort()),
      reason: 'the rows are not in the order the projection put them in',
    );
  });

  testWidgets('the chart card offers NO interaction — deliberately', (
    tester,
  ) async {
    // v1 has no tooltip, no crosshair and no pan. A tap target that does
    // nothing is worse than no tap target, and this is a read-only trend line.
    // The deferral gets a test so it is a decision rather than an omission.
    await pumpChart(tester);

    expect(
      find.descendant(
        of: find.byType(DoseStaircaseChart),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DoseStaircaseChart),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('the overline is cased for the script, not by Dart', (
    tester,
  ) async {
    await pumpChart(tester);
    final latin = tester.widget<Text>(find.text('YOUR DOSE OVER TIME'));
    expect(latin.style?.letterSpacing, isNotNull);
    expect(latin.style!.letterSpacing! > 0, isTrue);

    await pumpChart(tester, locale: const Locale('fa'));
    expect(find.text('دوز شما در طول زمان'), findsOneWidget);
    final perso = tester.widget<Text>(find.text('دوز شما در طول زمان'));
    expect(perso.style?.letterSpacing ?? 0, 0);
  });

  testWidgets('the list clears the guidelines at 2.0', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const Material(
        child: DoseHistoryList(title: 'Dose history as a list', rows: rows),
      ),
      textScaler: const TextScaler.linear(2),
      surfaceSize: const Size(390, 1400),
    );

    await expectLater(tester, meetsGuideline(textContrastGuideline));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
  testWidgets('a flat series does not print the same dose three times', (
    tester,
  ) async {
    // Found on a device, sixteen days into a plan: the taper has not reached
    // its first crossover, so every tread is 10mg — and the axis said "10mg",
    // "10mg", "10mg". Three labels that agree tell the reader nothing and look
    // like a bug on the screen that exists to be evidence.
    await pumpApp(
      tester,
      const DoseStaircaseChart(
        segments: <DoseSegment>[
          DoseSegment(
            startDayIndex: 0,
            endDayIndex: 15,
            dose: Milligrams.fromHundredths(1000),
          ),
        ],
        flares: <FlareMark>[],
        holds: <HoldMark>[],
        todayDayIndex: 15,
        todayDose: Milligrams.fromHundredths(1000),
        axis: ProgressAxis(
          minDose: Milligrams.fromHundredths(1000),
          maxDose: Milligrams.fromHundredths(1000),
          firstLabel: 'Aug 2026',
          lastLabel: 'Aug 2026',
        ),
        summary: 'x',
        historyRows: <String>['x'],
        eventCountLabel: 'No flares or holds recorded',
      ),
      surfaceSize: const Size(390, 500),
    );

    final chart = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(DoseStaircaseChart),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    final painter = chart.painter! as DoseStaircasePainter;
    expect(
      painter.labels.doses,
      hasLength(1),
      reason: 'a flat series has one dose to name, not three',
    );
    // And the two ends of the same month are one label, not two.
    expect(painter.labels.last.text!.toPlainText(), isEmpty);
  });
}
