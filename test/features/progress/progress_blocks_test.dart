// The three blocks under the chart.
//
// All three take pre-formatted strings, so there is no container here and no
// projection — what these assert is that the numbers arrive with their UNITS
// IN WORDS and that nothing truncates in the longest-string locale.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/features/progress/presentation/widgets/encouragement_card.dart';
import 'package:nearlystop/features/progress/presentation/widgets/progress_stat_grid.dart';
import 'package:nearlystop/features/progress/presentation/widgets/taper_start_line.dart';

import '../../support/harness.dart';

void main() {
  const stats = ProgressStats(
    daysOnDrug: '581',
    cumulativeMg: '6,842',
    adherence: '574 of 581',
    adherenceCaption: 'days ticked so far — a few gaps change nothing',
  );

  Future<void> pumpGrid(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
    Locale locale = const Locale('en'),
    Size size = const Size(390, 900),
  }) => pumpApp(
    tester,
    const Material(
      child: SingleChildScrollView(
        child: ProgressStatGrid(stats: stats, medicine: 'Prednisolone'),
      ),
    ),
    locale: locale,
    textScaler: textScaler,
    surfaceSize: size,
  );

  testWidgets('every stat states its unit IN WORDS', (tester) async {
    // A number with no unit is a number a reader has to guess at, and this
    // screen's numbers go to a rheumatologist.
    await pumpGrid(tester);

    expect(find.text('581'), findsOneWidget);
    expect(find.text('574 of 581'), findsOneWidget);
    // "6,842 mg": the unit rides with the figure, as frame 4's `.u` span does,
    // so the number never appears without it.
    expect(find.textContaining('6,842'), findsOneWidget);
    expect(find.textContaining('mg'), findsWidgets);
    expect(find.textContaining('days'), findsWidgets);
  });

  testWidgets('the grid is never a GridView — the ban applies here too', (
    tester,
  ) async {
    await pumpGrid(tester);

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(SliverGrid), findsNothing);
  });

  testWidgets('two across at 1.3, one column at 1.31', (tester) async {
    await pumpGrid(tester, textScaler: const TextScaler.linear(1.3));
    final blocks = find.byType(ProgressStatBlockSlot);
    expect(blocks, findsNWidgets(3));
    expect(
      tester.getTopLeft(blocks.at(0)).dy,
      tester.getTopLeft(blocks.at(1)).dy,
      reason: 'the first two should share a row at 1.3',
    );

    await pumpGrid(tester, textScaler: const TextScaler.linear(1.31));
    expect(
      tester.getTopLeft(find.byType(ProgressStatBlockSlot).at(1)).dy,
      greaterThan(
        tester.getTopLeft(find.byType(ProgressStatBlockSlot).at(0)).dy,
      ),
      reason: 'above the rung every block is full width',
    );
  });

  testWidgets('de at 1.0 and 2.0: no stat label is truncated', (tester) async {
    // German is the longest-string locale and the adherence caption is the
    // longest string on this screen.
    for (final scale in <double>[1, 2]) {
      await pumpGrid(
        tester,
        locale: const Locale('de'),
        textScaler: TextScaler.linear(scale),
        size: const Size(390, 2400),
      );

      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          text.overflow,
          isNot(TextOverflow.ellipsis),
          reason: 'a stat label truncates at ${scale}x: ${text.data}',
        );
      }
      expect(tester.takeException(), isNull, reason: '${scale}x');
    }
  });

  testWidgets('the encouragement card shows what it is handed', (tester) async {
    // No `if (delta == 0)` in the widget: that branch is the projection's, and
    // two places deciding the same thing is one place too many.
    await pumpApp(
      tester,
      const Material(
        child: EncouragementCard(
          message: 'You are 6mg lower than when you started.',
        ),
      ),
      surfaceSize: const Size(390, 400),
    );

    expect(
      find.text('You are 6mg lower than when you started.'),
      findsOneWidget,
    );
  });

  testWidgets('the start line is one sentence to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const Material(
        child: TaperStartLine(text: 'Started 12 September 2024 at 15mg'),
      ),
      surfaceSize: const Size(390, 200),
    );

    expect(find.text('Started 12 September 2024 at 15mg'), findsOneWidget);
    // The glyph is decoration: the line is ONE node, and a reader that stops
    // on the sunrise has been told about a sunrise.
    final node = tester.getSemantics(find.byType(TaperStartLine));
    var children = 0;
    node.visitChildren((_) {
      children++;
      return true;
    });
    expect(children, lessThanOrEqualTo(1));
    handle.dispose();
  });
}
