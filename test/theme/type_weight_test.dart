// Weight on a VARIABLE face, which is not what `copyWith` does.
//
// Both bundled families ship as a single variable TTF with a `wght` axis, so
// there is exactly one registered asset per family and Flutter has no second
// face to switch to. `TextStyle.fontWeight` selects among registered assets;
// with one asset it selects that one, at its default instance, and the text is
// painted at the weight the axis is currently pinned to. The axis is only moved
// by `fontVariations`.
//
// The failure mode is the worst kind: `copyWith(fontWeight: FontWeight.w700)`
// compiles, reads correctly, passes review, and paints nothing different. The
// test below is width-based rather than golden-based on purpose — a golden
// would have blessed the wrong weight the day it was written.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/type_weight.dart';

import '../support/harness.dart';

void main() {
  late TextTheme text;

  Future<void> readTheme(WidgetTester tester) => pumpApp(
    tester,
    Builder(
      builder: (context) {
        text = Theme.of(context).textTheme;
        return const SizedBox();
      },
    ),
  );

  double paintedWidth(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Tuesday 14 April', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  testWidgets('atWeight changes what is actually painted', (tester) async {
    await readTheme(tester);
    final base = text.bodyLarge!;

    expect(
      paintedWidth(base.copyWith(fontWeight: FontWeight.w700)),
      paintedWidth(base),
      reason:
          'copyWith(fontWeight:) is a no-op on a variable face — if this '
          'ever starts failing, Flutter gained synthetic weights and the '
          'atWeight extension can be reconsidered',
    );

    expect(
      paintedWidth(base.atWeight(FontWeight.w700)),
      greaterThan(paintedWidth(base)),
    );
  });

  testWidgets('atWeight moves BOTH the weight and the axis', (tester) async {
    await readTheme(tester);
    final heavier = text.bodyLarge!.atWeight(FontWeight.w800);

    expect(heavier.fontWeight, FontWeight.w800);
    expect(
      heavier.fontVariations,
      const <FontVariation>[FontVariation('wght', 800)],
    );
  });

  testWidgets('it replaces the wght axis rather than appending one', (
    tester,
  ) async {
    // Two `wght` entries is not a compile error and not a runtime error. The
    // renderer takes one of them, and which one is not something this codebase
    // should be relying on.
    await readTheme(tester);
    final twice = text.bodyLarge!
        .atWeight(FontWeight.w600)
        .atWeight(
          FontWeight.w800,
        );

    expect(
      twice.fontVariations!.where((v) => v.axis == 'wght'),
      hasLength(1),
    );
    expect(twice.fontVariations!.single.value, 800);
  });

  testWidgets('other axes on the style survive', (tester) async {
    await readTheme(tester);
    final withSlant = text.bodyLarge!
        .copyWith(
          fontVariations: const <FontVariation>[
            FontVariation('wght', 400),
            FontVariation('slnt', -10),
          ],
        )
        .atWeight(FontWeight.w700);

    expect(
      withSlant.fontVariations,
      containsAll(const <FontVariation>[FontVariation('slnt', -10)]),
    );
  });
}
