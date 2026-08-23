// The taper method, chosen once and rarely changed.
//
// Three segments whose names are long in German and long in Persian. An
// equal-width row of them cannot survive a text scale this audience routinely
// uses, so the control reflows to a vertical list — and both sides of that
// boundary are tested, in both long-string locales.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/features/plan/presentation/widgets/method_segmented_control.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../../support/harness.dart';

/// Whether `word` was laid out on a single line inside `paragraph`.
///
/// A word split across a line break produces TWO selection boxes; one that
/// wrapped whole produces one. A paragraph with several lines is not the
/// failure — "Dead Slow and Nearly Stop" is supposed to wrap — a word cut in
/// half is.
int _lineCount(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText();
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  return boxes.map((box) => box.top.round()).toSet().length;
}

bool _isWhole(RenderParagraph paragraph, String word) {
  final text = paragraph.text.toPlainText();
  final start = text.indexOf(word);
  if (start < 0) return false;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + word.length),
  );
  return boxes.length == 1;
}

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
    Map<TaperMethod, String>? labels,
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
                labels:
                    labels ??
                    <TaperMethod, String>{
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

  testWidgets('it is a row while the labels fit, and a list once they do not', (
    tester,
  ) async {
    // Both sides of the boundary, in both long-string locales — but the
    // boundary is MEASURED, not a number. Pinning it at "1.5 is a row, 1.6 is
    // a list" is what let English at 1.0 split "Percentage" in half on a 390pt
    // phone: the threshold was fitted to German and never asked about the
    // width it actually had.
    for (final locale in <Locale>[const Locale('de'), const Locale('fa')]) {
      // Wide enough that every label fits on one line.
      final l10n = await pumpControl(
        tester,
        locale: locale,
        surfaceSize: const Size(900, 1400),
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
        tops.toSet(),
        hasLength(1),
        reason: '${locale.languageCode} with room: not one row',
      );
      // Widths follow the LABELS, not equal thirds: the longest name gets the
      // widest segment, which is what the reference frame shows.
      final byWidth = <TaperMethod, double>{
        for (final method in TaperMethod.values)
          method: tester
              .getSize(
                find.ancestor(
                  of: find.text(labelFor(l10n, method)),
                  matching: find.byType(MethodSegment),
                ),
              )
              .width,
      };
      final widest = byWidth.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final longest = TaperMethod.values.reduce(
        (a, b) => labelFor(l10n, a).length >= labelFor(l10n, b).length ? a : b,
      );
      expect(
        widest.key,
        longest,
        reason:
            '${locale.languageCode}: the widest segment is not the '
            'longest label — the row is still equal thirds',
      ); // STRICTLY widest. Equal thirds also make the longest label "the
      // widest" by a tie, so the plant that reverts to `Expanded(child:)`
      // would pass an ordinary max.
      for (final other in TaperMethod.values.where((m) => m != widest.key)) {
        expect(
          byWidth[widest.key],
          greaterThan(byWidth[other]!),
          reason:
              '${locale.languageCode}: ${other.name} is the same width as '
              'the longest label',
        );
      }

      expect(tester.takeException(), isNull);

      // A 390pt phone at 2.0, where no share holds a whole label in three
      // lines.
      await pumpControl(
        tester,
        locale: locale,
        textScaler: const TextScaler.linear(2),
        surfaceSize: const Size(390, 1400),
      );
      final stackedTops = <double>[
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
        stackedTops,
        orderedEquals(<double>[...stackedTops]..sort()),
        reason: '${locale.languageCode} at 2.0: not stacked',
      );
      expect(
        stackedTops.toSet(),
        hasLength(TaperMethod.values.length),
        reason: '${locale.languageCode} at 2.0: segments share a row',
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

  testWidgets('one wrapping label is a row; two is a list', (tester) async {
    // The reference's own tolerance, both ways. At 1.0 on a 390pt phone
    // "Dead Slow and Nearly Stop" wraps and the other two sit whole beside
    // it — that is the frame. Once a second label has to wrap, nothing on the
    // row is reading as a label any more.
    await pumpControl(
      tester,
      labels: <TaperMethod, String>{
        TaperMethod.dsns: 'Dead Slow and Nearly Stop',
        TaperMethod.percentage: 'Percentage',
        TaperMethod.fixedMg: 'Fixed mg',
      },
      surfaceSize: const Size(390, 900),
    );

    final tops = <double>[
      for (final label in <String>[
        'Dead Slow and Nearly Stop',
        'Percentage',
        'Fixed mg',
      ])
        tester
            .getTopLeft(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(MethodSegment),
              ),
            )
            .dy,
    ];
    expect(
      tops.toSet(),
      hasLength(1),
      reason: 'the reference frame shows these three in ONE row at 390pt',
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Dead Slow and Nearly Stop'),
    );
    expect(
      _lineCount(paragraph),
      greaterThan(1),
      reason: 'the long name is meant to wrap — that is what buys the room',
    );
    for (final label in <String>['Percentage', 'Fixed mg']) {
      expect(
        _lineCount(tester.renderObject<RenderParagraph>(find.text(label))),
        1,
        reason: '"$label" wrapped, so two labels wrapped',
      );
    }
  });

  testWidgets('a label that needs a fourth line makes it a list', (
    tester,
  ) async {
    // Every word here fits any share — they are one character each — so the
    // word rule cannot catch this. What makes the row wrong is DEPTH: six
    // lines of one word each is a column pretending to be a segment, and the
    // reference frame's own tolerance is three.
    await pumpControl(
      tester,
      labels: <TaperMethod, String>{
        TaperMethod.dsns: 'a a a a a a a a a a a a a a a a a a a a',
        TaperMethod.percentage: 'b',
        TaperMethod.fixedMg: 'c',
      },
      surfaceSize: const Size(150, 1200),
    );

    final tops = <double>[
      for (final label in <String>[
        'a a a a a a a a a a a a a a a a a a a a',
        'b',
        'c',
      ])
        tester
            .getTopLeft(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(MethodSegment),
              ),
            )
            .dy,
    ];
    expect(tops.toSet(), hasLength(3), reason: 'the segments share a row');
    expect(tops, orderedEquals(<double>[...tops]..sort()));
  });

  testWidgets('a word wider than any share stacks rather than breaking', (
    tester,
  ) async {
    // ONE unbreakable word beside two short ones, with room for everything
    // else. A fair share still leaves that word short — and because it is the
    // only label that wraps, every other rule here is satisfied. Without a
    // floor at the longest word, this is the row that renders it in halves.
    const words = <TaperMethod, String>{
      TaperMethod.dsns: 'Wwwwwwwwwwwwww',
      TaperMethod.percentage: 'b',
      TaperMethod.fixedMg: 'c',
    };
    await pumpControl(
      tester,
      labels: words,
      surfaceSize: const Size(300, 900),
    );

    for (final word in words.values) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(word));
      expect(
        _isWhole(paragraph, word),
        isTrue,
        reason: '"$word" was broken across lines',
      );
    }
  });

  group('a label never breaks mid-word', () {
    // "Percentag / e" is what an equal-thirds row does to a word that does not
    // fit, and a fixed text-scale threshold cannot see it: the reference frame
    // is captured at 1.0, where three equal thirds are already too narrow in
    // English. The reflow decision has to be MEASURED against the constraints
    // the control actually has.
    for (final (name, width) in <(String, double)>[
      ('a 390pt phone', 390.0),
      ('a 320pt phone', 320.0),
    ]) {
      testWidgets('$name at 1.0 keeps every label whole', (tester) async {
        final l10n = await pumpControl(
          tester,
          surfaceSize: Size(width, 844),
        );

        for (final method in TaperMethod.values) {
          final label = labelFor(l10n, method);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          for (final word in label.split(' ')) {
            expect(
              _isWhole(paragraph, word),
              isTrue,
              reason: '"$word" was split across lines in "$label"',
            );
          }
        }
      });
    }
  });
}

void _ignore(TaperMethod method) {}
