// The icon font has to be LOADED, not merely referenced.
//
// An unloaded font renders every codepoint as the same tofu box. Nothing
// throws, no test fails, and a golden baselines the box — so from then on the
// suite asserts that the placeholder has not changed. This app puts a glyph
// beside every state word precisely because colour is not allowed to be the
// only channel, so a silently-missing glyph is an accessibility regression
// that the a11y tests cannot see.
//
// The oracle is layout-invariant and needs no baseline: two DIFFERENT icons
// must not rasterise identically. When the font is missing they both draw the
// box and the bytes match exactly.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ui.Image> renderIcon(WidgetTester tester, IconData icon) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: Center(
            child: Icon(icon, size: 48, color: const Color(0xFF000000)),
          ),
        ),
      ),
    );
    final boundary =
        tester.renderObject(find.byType(RepaintBoundary))
            as RenderRepaintBoundary;
    return boundary.toImage();
  }

  Future<Uint8List> pixelsOf(ui.Image image) async {
    final data = await image.toByteData();
    return data!.buffer.asUint8List();
  }

  testWidgets('two different icons do not rasterise identically', (
    tester,
  ) async {
    // `runAsync`: `toByteData` is real async work, which never completes in
    // the fake-async zone `testWidgets` runs its body in.
    late Uint8List a;
    late Uint8List b;
    final first = await renderIcon(tester, Icons.south_east);
    final second = await renderIcon(tester, Icons.check);
    await tester.runAsync(() async {
      a = await pixelsOf(first);
      b = await pixelsOf(second);
    });

    expect(
      a,
      isNot(equals(b)),
      reason:
          'both icons drew the same shape — the MaterialIcons font is '
          'not loaded, so every glyph is the tofu box',
    );
  });

  testWidgets('an icon draws SOMETHING, not an empty box', (tester) async {
    // The other half: two boxes differ from each other in a rendering where
    // nothing draws at all, so "ink exists" is asserted separately.
    late Uint8List pixels;
    final image = await renderIcon(tester, Icons.check);
    await tester.runAsync(() async {
      pixels = await pixelsOf(image);
    });

    // Any pixel with alpha. RGBA, so every fourth byte.
    final inked = <int>[
      for (var i = 3; i < pixels.length; i += 4)
        if (pixels[i] != 0) pixels[i],
    ];
    expect(inked, isNotEmpty, reason: 'the icon painted nothing at all');
  });
}
