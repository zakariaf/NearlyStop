// The taper method, chosen once and rarely changed.
//
// Three segments whose names are long in German and long in Persian. An
// equal-width row of them cannot survive a text scale this audience routinely
// uses, so the control reflows to a vertical list — and both sides of that
// boundary are tested, in both long-string locales.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/features/plan/presentation/widgets/method_segmented_control.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../../support/harness.dart';

void main() {
  /// The label for [method], from the real delegates.
  ///
  /// An exhaustive switch with no `default:`, so a fourth `TaperMethod` breaks
  /// this test's build rather than silently going unrendered (CONTRACTS.md §8).
  String labelFor(AppLocalizations l10n, TaperMethod method) =>
      switch (method) {
        TaperMethod.dsns => l10n.methodDsns,
        TaperMethod.percentage => l10n.methodPercentage,
        TaperMethod.fixedMg => l10n.methodFixed,
      };

  Future<AppLocalizations> pumpControl(
    WidgetTester tester, {
    TaperMethod value = TaperMethod.dsns,
    void Function(TaperMethod)? onChanged,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
    Size surfaceSize = const Size(390, 844),
  }) async {
    late AppLocalizations l10n;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return Align(
            alignment: Alignment.topCenter,
            child: Material(
              child: MethodSegmentedControl(
                value: value,
                labels: <TaperMethod, String>{
                  for (final method in TaperMethod.values)
                    method: labelFor(l10n, method),
                },
                onChanged: onChanged ?? (_) {},
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

  testWidgets('tapping a segment reports THAT method, once', (tester) async {
    for (final method in TaperMethod.values) {
      final reported = <TaperMethod>[];
      final l10n = await pumpControl(tester, onChanged: reported.add);

      await tester.tap(find.text(labelFor(l10n, method)));
      await tester.pumpAndSettle();

      expect(reported, <TaperMethod>[method], reason: '$method');
    }
  });

  testWidgets('exactly one segment is selected, and it is mutually exclusive', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final selected in TaperMethod.values) {
      final l10n = await pumpControl(tester, value: selected);

      for (final method in TaperMethod.values) {
        expect(
          tester.getSemantics(
            find.ancestor(
              of: find.text(labelFor(l10n, method)),
              matching: find.byType(MethodSegment),
            ),
          ),
          isSemantics(
            isSelected: method == selected,
            isInMutuallyExclusiveGroup: true,
          ),
          reason: '$method while $selected is chosen',
        );
      }
    }
    handle.dispose();
  });

  testWidgets('selection survives greyscale: weight and a raised tile', (
    tester,
  ) async {
    final l10n = await pumpControl(tester, value: TaperMethod.percentage);

    for (final method in TaperMethod.values) {
      final isSelected = method == TaperMethod.percentage;
      expect(
        tester
            .widget<Text>(find.text(labelFor(l10n, method)))
            .style!
            .fontWeight,
        isSelected ? FontWeight.w800 : FontWeight.w600,
        reason: '$method',
      );
      final tile = tester.widget<Container>(
        find.descendant(
          of: find.ancestor(
            of: find.text(labelFor(l10n, method)),
            matching: find.byType(MethodSegment),
          ),
          matching: find.byType(Container),
        ),
      );
      final shadows = (tile.decoration! as BoxDecoration).boxShadow;
      expect(
        shadows ?? const <BoxShadow>[],
        isSelected ? isNotEmpty : isEmpty,
        reason: '$method',
      );
    }
  });

  testWidgets('at 1.5x it is a ROW of equal segments; at 1.6x a list', (
    tester,
  ) async {
    // Both sides of the boundary, in both long-string locales. German is the
    // longest, and Persian's method names are long too — an equal-width row of
    // three of them at 1.6x is three columns of stacked letters.
    for (final locale in <Locale>[const Locale('de'), const Locale('fa')]) {
      final l10n = await pumpControl(
        tester,
        locale: locale,
        textScaler: const TextScaler.linear(1.5),
        surfaceSize: const Size(390, 1400),
      );
      final widths = <double>[
        for (final method in TaperMethod.values)
          tester
              .getSize(
                find.ancestor(
                  of: find.text(labelFor(l10n, method)),
                  matching: find.byType(MethodSegment),
                ),
              )
              .width,
      ];
      expect(
        widths.every((w) => (w - widths.first).abs() < 0.5),
        isTrue,
        reason: '${locale.languageCode} at 1.5: segments are unequal',
      );
      expect(tester.takeException(), isNull);

      await pumpControl(
        tester,
        locale: locale,
        textScaler: const TextScaler.linear(1.6),
        surfaceSize: const Size(390, 1400),
      );
      final tops = <double>[
        for (final method in TaperMethod.values)
          tester
              .getTopLeft(
                find.ancestor(
                  of: find.text(labelFor(l10n, method)),
                  matching: find.byType(MethodSegment),
                ),
              )
              .dy,
      ];
      expect(
        tops,
        orderedEquals(<double>[...tops]..sort()),
        reason: '${locale.languageCode} at 1.6: not stacked',
      );
      expect(
        tops.toSet(),
        hasLength(TaperMethod.values.length),
        reason: '${locale.languageCode} at 1.6: segments share a row',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('every segment clears the tap-target guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    for (final scale in <double>[1, 2]) {
      await pumpControl(
        tester,
        textScaler: TextScaler.linear(scale),
        surfaceSize: const Size(390, 1400),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    }
    handle.dispose();
  });

  testWidgets('a labels map missing a method fails LOUDLY', (tester) async {
    // `labels[method]!` on a partial map throws "Null check operator used on a
    // null value" from inside a build, which names neither the widget nor the
    // missing member. A fourth `TaperMethod` added in EPIC-11 and not given a
    // string is exactly how that happens, and the Plan screen is where it
    // lands.
    await pumpApp(
      tester,
      const MethodSegmentedControl(
        value: TaperMethod.dsns,
        labels: <TaperMethod, String>{
          TaperMethod.dsns: 'Dead Slow and Nearly Stop',
        },
        onChanged: _ignore,
      ),
    );

    expect(
      tester.takeException(),
      isA<AssertionError>().having(
        (error) => error.toString(),
        'message',
        contains('every TaperMethod'),
      ),
    );
  });
}

void _ignore(TaperMethod method) {}
