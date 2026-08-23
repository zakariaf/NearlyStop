// The component that replaces the forbidden month grid.
//
// `SPEC.md` §4.2 makes this the teaching device: "Block 3 of 11 — one day at
// 9mg, then 4 days at 10mg" is the sentence that answers the question this app
// exists to answer. So the header is not chrome, and the tests below are about
// whether it can still be read at 200% in German while pinned to the top of a
// 52-day list.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

void main() {
  const title = 'Block 3 of 11';
  const summary = 'one day at 9mg, then 4 days at 10mg';
  const sentence = 'Block 3 of 11 — one day at 9mg, then 4 days at 10mg';

  BlockHeader header({
    bool isCurrent = false,
    bool isCompleted = false,
    String headerTitle = title,
  }) => BlockHeader(
    title: headerTitle,
    doseSummary: summary,
    semanticsLabel: sentence,
    isCurrent: isCurrent,
    isCompleted: isCompleted,
    completedLabel: 'Completed',
  );

  Future<void> pumpHeader(
    WidgetTester tester, {
    bool isCurrent = false,
    bool isCompleted = false,
    String headerTitle = title,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
  }) => pumpApp(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: Material(
        child: header(
          isCurrent: isCurrent,
          isCompleted: isCompleted,
          headerTitle: headerTitle,
        ),
      ),
    ),
    locale: locale,
    textScaler: textScaler,
    surfaceSize: const Size(390, 1400),
  );

  testWidgets('maxExtent is MEASURED, and grows with the text', (tester) async {
    // The classic bug in this component: a hardcoded `maxExtent` looks right at
    // 1.0 and clips the teaching sentence at 2.0, which is the scale this
    // audience actually uses. Measured against the rendered height, then
    // against itself at a larger scale.
    Future<(double delegate, double rendered)> measure(double scale) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => CustomScrollView(
            slivers: <Widget>[
              SliverPersistentHeader(
                pinned: true,
                delegate: BlockHeaderDelegate(
                  header: header(),
                  context: context,
                ),
              ),
            ],
          ),
        ),
        textScaler: TextScaler.linear(scale),
        surfaceSize: const Size(390, 1400),
      );
      final delegate = tester
          .widget<SliverPersistentHeader>(find.byType(SliverPersistentHeader))
          .delegate;
      return (
        delegate.maxExtent,
        tester.getSize(find.byType(BlockHeader)).height,
      );
    }

    final (small, smallRendered) = await measure(1);
    expect(small, closeTo(smallRendered, 0.5));

    final (large, largeRendered) = await measure(2);
    expect(large, closeTo(largeRendered, 0.5));
    expect(
      large,
      greaterThan(small),
      reason: 'a hardcoded maxExtent passes the first half and fails here',
    );
  });

  testWidgets('shouldRebuild is true per field and false for none', (
    tester,
  ) async {
    await pumpHeader(tester);
    final context = tester.element(find.byType(BlockHeader));
    BlockHeaderDelegate delegate({
      String t = title,
      String s = summary,
      bool current = false,
      bool completed = false,
    }) => BlockHeaderDelegate(
      header: BlockHeader(
        title: t,
        doseSummary: s,
        semanticsLabel: sentence,
        isCurrent: current,
        isCompleted: completed,
        completedLabel: 'Completed',
      ),
      context: context,
    );

    final base = delegate();
    expect(base.shouldRebuild(delegate()), isFalse);
    for (final (label, other) in <(String, BlockHeaderDelegate)>[
      ('title', delegate(t: 'Block 4 of 11')),
      ('summary', delegate(s: 'two days at 8mg')),
      ('isCurrent', delegate(current: true)),
      ('isCompleted', delegate(completed: true)),
    ]) {
      expect(base.shouldRebuild(other), isTrue, reason: label);
    }
  });

  testWidgets('pinned: it stays at the top after scrolling', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => CustomScrollView(
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: BlockHeaderDelegate(header: header(), context: context),
            ),
            SliverList.builder(
              itemCount: 60,
              itemBuilder: (_, index) =>
                  SizedBox(height: 40, child: Text('row $index')),
            ),
          ],
        ),
      ),
      surfaceSize: const Size(390, 844),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(BlockHeader)).dy, 0);
  });

  testWidgets('at 200% in de the sentence wraps and nothing clips', (
    tester,
  ) async {
    // German is the longest-string locale and where layouts overflow.
    await pumpHeader(
      tester,
      locale: const Locale('de'),
      headerTitle: 'Block 3 von 11',
      textScaler: const TextScaler.linear(2),
    );

    // Line count from the selection boxes rather than `computeLineMetrics`,
    // which `RenderParagraph` does not expose: one box per line fragment, so
    // the distinct tops ARE the lines.
    final paragraph =
        tester.renderObject(find.text(summary)) as RenderParagraph;
    final tops = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: summary.length),
        )
        .map((box) => box.top.round())
        .toSet();
    expect(
      tops.length,
      greaterThanOrEqualTo(2),
      // Was 3, which was a count taken against a 17pt summary. The reference
      // sets `.bh-txt` to `--fs-label` (15), so the same German sentence at
      // 200% now needs two lines rather than three. The CLAIM is that it
      // wraps rather than shrinking, and two lines is that claim.
      reason: 'the teaching sentence should wrap, not shrink',
    );
    expect(
      tester.widget<Text>(find.text(summary)).overflow,
      isNot(TextOverflow.ellipsis),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('isCurrent takes the tint and the SLOT border', (tester) async {
    late DaybreakColors colors;
    Future<BoxDecoration> decorationWhen({required bool isCurrent}) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            colors = DaybreakColors.of(context);
            return Align(
              alignment: Alignment.topCenter,
              child: Material(child: header(isCurrent: isCurrent)),
            );
          },
        ),
        surfaceSize: const Size(390, 1400),
      );
      return tester
              .widget<Container>(find.byKey(BlockHeader.containerKey))
              .decoration!
          as BoxDecoration;
    }

    final current = await decorationWhen(isCurrent: true);
    expect(current.color, colors.tintPrimary);
    // The SLOT, not a lerp at the call site: a computed colour here would fail
    // this equality as well as tripping `tool/check_raw_values.sh`.
    expect(current.border!.top.color, colors.borderCurrentBlock);

    final other = await decorationWhen(isCurrent: false);
    expect(other.color, colors.surfaceRaised);
    expect(other.border!.top.color, colors.border);
  });

  testWidgets('isCompleted adds tint AND glyph AND word', (tester) async {
    late DaybreakColors colors;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = DaybreakColors.of(context);
          return Align(
            alignment: Alignment.topCenter,
            child: Material(child: header(isCompleted: true)),
          );
        },
      ),
      surfaceSize: const Size(390, 1400),
    );

    final decoration =
        tester
                .widget<Container>(find.byKey(BlockHeader.containerKey))
                .decoration!
            as BoxDecoration;
    expect(decoration.color, colors.tintSuccess);
    expect(find.byIcon(BlockHeader.completedGlyph), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('it is a HEADER node reading the teaching sentence', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHeader(tester);

    final node = tester.getSemantics(find.byType(BlockHeader));
    expect(node.label, sentence);
    expect(node.flagsCollection.isHeader, isTrue);
    handle.dispose();
  });

  testWidgets('the leading tile is 36x36 and does not scale with text', (
    tester,
  ) async {
    for (final scale in <double>[1, 2]) {
      await pumpHeader(tester, textScaler: TextScaler.linear(scale));

      expect(
        tester.getSize(find.byKey(BlockHeader.glyphTileKey)),
        const Size(36, 36),
        reason: 'scale $scale',
      );
    }
  });
  testWidgets('the sentence is sized the way frame 3 sizes it', (
    tester,
  ) async {
    // `.blockhead .bh-txt` is `--fs-label` (15) and its `b` is `--fs-body`
    // (17). This component was built one step up on both, which is why the
    // teaching sentence wraps to two lines at 390pt where the reference keeps
    // it on one — and the wrap is what makes the header look like a card
    // rather than a label.
    late TextStyle title;
    late TextStyle summary;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          title = BlockHeader.titleStyle(context);
          summary = BlockHeader.summaryStyle(context);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(title.fontSize, 17);
    expect(summary.fontSize, 15);
  });
}
