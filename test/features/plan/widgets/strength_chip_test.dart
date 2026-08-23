// Tablet strengths, selected without relying on colour.
//
// The reader is choosing which tablets they actually hold. Getting that wrong
// makes every tablet breakdown in the app wrong, so "which ones are selected"
// has to survive greyscale, deuteranopia and a screen reader — three channels,
// not one tint.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/plan/presentation/widgets/strength_chip.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

void main() {
  Future<void> pumpChip(
    WidgetTester tester, {
    required bool selected,
    void Function(String)? onSelected,
    TextScaler textScaler = TextScaler.noScaling,
  }) => pumpApp(
    tester,
    Center(
      child: Material(
        child: StrengthChip(
          label: '5mg',
          value: '5',
          selected: selected,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
    textScaler: textScaler,
    surfaceSize: const Size(390, 844),
  );

  testWidgets('a tap reports the chip’s VALUE, exactly once', (tester) async {
    // The value, not the label: the label is "5mg" in English and "۵
    // میلی‌گرم" in Persian, and a handler keyed on the label would work in one
    // locale and silently fail in the other.
    final reported = <String>[];
    await pumpChip(tester, selected: false, onSelected: reported.add);

    await tester.tap(find.byType(StrengthChip));
    await tester.pumpAndSettle();

    expect(reported, <String>['5']);
  });

  testWidgets('selection carries all THREE non-colour signals', (tester) async {
    late DaybreakColors colors;
    Future<void> pump({required bool selected}) => pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = DaybreakColors.of(context);
          return Center(
            child: Material(
              child: StrengthChip(
                label: '5mg',
                value: '5',
                selected: selected,
                onSelected: (_) {},
              ),
            ),
          );
        },
      ),
      surfaceSize: const Size(390, 844),
    );

    await pump(selected: true);
    expect(find.byIcon(StrengthChip.selectedGlyph), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('5mg')).style!.fontWeight,
      FontWeight.w800,
    );
    final ring = tester.widget<Container>(
      find.byKey(StrengthChip.containerKey),
    );
    expect(
      ((ring.decoration! as BoxDecoration).border! as Border).top.width,
      2,
    );
    expect(
      ((ring.decoration! as BoxDecoration).border! as Border).top.color,
      colors.borderStrong,
    );

    // And the negative, so "all three" is not satisfied by a chip that always
    // shows them.
    await pump(selected: false);
    expect(find.byIcon(StrengthChip.selectedGlyph), findsNothing);
    expect(
      tester.widget<Text>(find.text('5mg')).style!.fontWeight,
      isNot(FontWeight.w800),
    );
    expect(
      ((tester
                          .widget<Container>(
                            find.byKey(StrengthChip.containerKey),
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border)
          .top
          .width,
      lessThan(2),
    );
  });

  testWidgets('it says "selected" to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpChip(tester, selected: true);

    // `isSemantics`, not `matchesSemantics`: the latter asserts the FULL
    // flag set, so it fails whenever an unrelated flag is added and says
    // nothing about the one thing this test is for.
    expect(
      tester.getSemantics(find.byType(StrengthChip)),
      isSemantics(isSelected: true, isButton: true, label: '5mg'),
    );

    await pumpChip(tester, selected: false);
    expect(
      tester.getSemantics(find.byType(StrengthChip)),
      isSemantics(isSelected: false, isButton: true, label: '5mg'),
    );
    handle.dispose();
  });

  testWidgets('at least 44x44, and larger at 2.0', (tester) async {
    await pumpChip(tester, selected: false);
    final small = tester.getSize(find.byType(StrengthChip));
    expect(small.width, greaterThanOrEqualTo(44));
    expect(small.height, greaterThanOrEqualTo(44));

    await pumpChip(
      tester,
      selected: false,
      textScaler: const TextScaler.linear(2),
    );

    expect(
      tester.getSize(find.byType(StrengthChip)).height,
      greaterThan(small.height),
    );
  });

  testWidgets('chips WRAP, they never scroll', (tester) async {
    // A horizontal strip hides options at 200% scale, and the option it hides
    // is a tablet strength the reader actually holds — which makes every
    // breakdown in the app wrong. This is the test that stops a strip
    // appearing later.
    await pumpApp(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: Material(
          child: StrengthChipGroup(
            chips: <({String label, String value})>[
              for (final mg in <String>[
                '0.5',
                '1',
                '2',
                '2.5',
                '5',
                '10',
                '20',
                '25',
              ])
                (label: '${mg}mg', value: mg),
            ],
            selected: const <String>{'5', '1'},
            onSelected: (_) {},
          ),
        ),
      ),
      surfaceSize: const Size(320, 844),
    );

    final rows = tester
        .widgetList<StrengthChip>(find.byType(StrengthChip))
        .map((chip) => tester.getTopLeft(find.byWidget(chip)).dy)
        .toSet();
    expect(rows.length, greaterThanOrEqualTo(2), reason: 'they did not wrap');
    expect(
      find.descendant(
        of: find.byType(StrengthChipGroup),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
      reason: 'a scroller hides options at 200%',
    );
  });
}
