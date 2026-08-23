// Three numbers, each of which has to say what it is a number OF.
//
// "341" alone is not information to someone two years into a taper. Every
// block states its unit in words, and the numerals are tabular so a column of
// them lines up rather than jittering as the digits change.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/progress/presentation/widgets/progress_stat_block.dart';

import '../../../support/harness.dart';

void main() {
  Future<void> pumpBlocks(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
  }) => pumpApp(
    tester,
    const Align(
      alignment: Alignment.topCenter,
      child: Material(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ProgressStatBlock(
              overline: 'Adherence',
              value: '341',
              unit: 'taken 341 of 350 days',
            ),
            ProgressStatBlock(
              overline: 'Cumulative dose',
              value: '12,480',
              unit: '12,480 mg cumulative',
            ),
            ProgressStatBlock(
              overline: 'Time on steroids',
              value: '402',
              unit: 'day 402 on steroids',
            ),
          ],
        ),
      ),
    ),
    textScaler: textScaler,
    surfaceSize: const Size(390, 1200),
  );

  testWidgets('every block states its unit in WORDS', (tester) async {
    await pumpBlocks(tester);

    for (final unit in <String>[
      'taken 341 of 350 days',
      '12,480 mg cumulative',
      'day 402 on steroids',
    ]) {
      expect(find.text(unit), findsOneWidget, reason: unit);
    }
  });

  testWidgets('the overline is byte-identical — no toUpperCase()', (
    tester,
  ) async {
    // Uppercasing no-ops in Persian and shouts in English, and the tracking
    // this overline carries is what makes it read as an overline anyway.
    await pumpBlocks(tester);

    for (final overline in <String>[
      'Adherence',
      'Cumulative dose',
      'Time on steroids',
    ]) {
      expect(find.text(overline), findsOneWidget, reason: overline);
      expect(find.text(overline.toUpperCase()), findsNothing, reason: overline);
    }
  });

  testWidgets('the numeral is TABULAR', (tester) async {
    // Without this, a column of figures jitters sideways as the digits change
    // — on a screen whose whole job is showing one number getting smaller.
    await pumpBlocks(tester);

    final numeral = tester.widget<Text>(find.text('12,480'));
    expect(
      numeral.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(numeral.style!.fontWeight, FontWeight.w800);
  });

  testWidgets('one semantics sentence per block, not three fragments', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpBlocks(tester);

    final node = tester.getSemantics(find.byType(ProgressStatBlock).first);
    expect(node.label, 'Adherence: taken 341 of 350 days');
    handle.dispose();
  });

  testWidgets('at 200% nothing overflows', (tester) async {
    await pumpBlocks(tester, textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
  });
}
