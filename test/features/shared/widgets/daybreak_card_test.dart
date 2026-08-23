// The one card surface, and the one way a card is titled.
//
// Both the Plan and Settings screens were spelling this out separately, with
// different fills. The reference frames show the same card on both: WHITE on
// the cream page, not a warmer cream on it — the card lifts off the ground,
// it does not sink into it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_card.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

import '../../../support/harness.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    String? overline,
    String? overlineCaps,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
  }) async {
    await pumpApp(
      tester,
      Material(
        child: DaybreakCard(
          overline: overline,
          overlineCaps: overlineCaps,
          children: const <Widget>[Text('body')],
        ),
      ),
      locale: locale,
      brightness: brightness,
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: the card is `surface`, above the page', (
      tester,
    ) async {
      await pumpCard(tester, brightness: brightness);

      final context = tester.element(find.byType(DaybreakCard));
      final colors = DaybreakColors.of(context);
      final shapes = DaybreakShapes.of(context);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(DaybreakCard),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;

      expect(decoration.color, colors.surface);
      expect(
        decoration.borderRadius,
        BorderRadius.all(Radius.circular(shapes.radiusLg)),
      );
      expect(decoration.boxShadow, isNotEmpty);
    });
  }

  testWidgets('a Latin overline is the CASED string, with tracking', (
    tester,
  ) async {
    await pumpCard(tester, overline: 'Backup', overlineCaps: 'BACKUP');

    expect(find.text('BACKUP'), findsOneWidget);
    expect(find.text('Backup'), findsNothing);

    final context = tester.element(find.byType(DaybreakCard));
    final style = tester.widget<Text>(find.text('BACKUP')).style;
    expect(
      style?.letterSpacing,
      DaybreakTypography.of(context).overline.letterSpacing,
    );
  });

  testWidgets('a Perso-Arabic overline is NOT cased', (tester) async {
    // Upper case does not exist in the script, and positive tracking snaps the
    // joins. Both are properties of the TOKEN and of the ARB, so the test asks
    // for the uncased string and zero tracking.
    await pumpCard(
      tester,
      overline: 'پشتیبان',
      overlineCaps: 'PSHTIBAN',
      locale: const Locale('fa'),
    );

    expect(find.text('پشتیبان'), findsOneWidget);
    expect(find.text('PSHTIBAN'), findsNothing);
    expect(tester.widget<Text>(find.text('پشتیبان')).style?.letterSpacing, 0);
  });

  testWidgets('a card with no overline has no heading slot', (tester) async {
    await pumpCard(tester);

    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('the overline is a header to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpCard(tester, overline: 'Backup', overlineCaps: 'BACKUP');

    expect(
      tester.getSemantics(find.text('BACKUP')).flagsCollection.isHeader,
      isTrue,
    );
    handle.dispose();
  });
}
