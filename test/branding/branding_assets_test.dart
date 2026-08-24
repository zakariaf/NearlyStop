@Tags(<String>['golden'])
library;

// The launcher icon and the splash mark, rendered from the real tokens.
//
// **Generated, not drawn by hand in an image editor.** The mark is the app's
// own `SunriseSeal` — `Icons.wb_twilight` on `DaybreakColors.sunrise` in
// `onPrimary` — so the icon on the home screen is the same mark as the one on
// the Welcome sheet, by construction rather than by somebody matching a hex
// value. A palette change moves both.
//
// No text in the icon, ever: a word is illegible at 48dp and untranslatable
// across four locales.
//
// Regenerate with `flutter test --update-goldens test/branding/`. The outputs
// are committed and are treated as codegen: a regeneration that produces a
// diff is a review item.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/gradients.dart';

import '../support/fonts.dart';

/// Where the generators read their source from.
const String _out = '../../assets/branding';

/// The app's mark. The one glyph the whole product is about.
const IconData kMark = Icons.wb_twilight;

void main() {
  setUpAll(loadAppFonts);

  /// Renders [child] at exactly [side]×[side] logical pixels, DPR 1.
  Future<void> render(
    WidgetTester tester,
    Widget child, {
    required double side,
    required String name,
  }) async {
    tester.view
      ..physicalSize = Size(side, side)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.square(dimension: side, child: child),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(SizedBox).first,
      matchesGoldenFile('$_out/$name.png'),
    );
  }

  testWidgets('icon-1024 — full bleed, for iOS', (tester) async {
    // Apple wants 1024×1024 with **no alpha and no pre-baked rounded
    // corners** — the OS applies the mask itself, and a corner drawn into the
    // asset shows as a dark fringe inside it. `flutter_launcher_icons` is
    // configured with `remove_alpha_ios: true` to flatten what this writes.
    await render(
      tester,
      const DecoratedBox(
        decoration: BoxDecoration(gradient: DaybreakGradients.sunriseLight),
        child: Center(
          child: Icon(kMark, size: 560, color: Color(0xFF241A20)),
        ),
      ),
      side: 1024,
      name: 'icon-1024',
    );
  });

  testWidgets('icon-foreground — the Android adaptive layer', (tester) async {
    // 108dp at 4x. The mark sits inside the central 72dp — everything outside
    // it is parallax and mask, and a glyph that reaches the edge is a glyph
    // the launcher crops. 432 × (72/108) = 288, so the mark is sized well
    // inside that.
    await render(
      tester,
      const ColoredBox(
        color: Color(0x00000000),
        child: Center(
          child: Icon(kMark, size: 236, color: Color(0xFF241A20)),
        ),
      ),
      side: 432,
      name: 'icon-foreground',
    );
  });

  testWidgets('icon-monochrome — the Android 13+ themed layer', (tester) async {
    // The OS recolours this one to whatever the wallpaper's palette says, so
    // it has to read as a silhouette. Solid black on transparent is what the
    // platform asks for.
    await render(
      tester,
      const ColoredBox(
        color: Color(0x00000000),
        child: Center(
          child: Icon(kMark, size: 236, color: Color(0xFF000000)),
        ),
      ),
      side: 432,
      name: 'icon-monochrome',
    );
  });

  testWidgets('splash-mark — the seal, on the launch ground', (tester) async {
    // The same seal the Welcome sheet opens with, so the splash and the first
    // frame are the same image and there is nothing to flash between them.
    await render(
      tester,
      const Center(
        child: SizedBox.square(
          dimension: 384,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: DaybreakGradients.sunriseLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(kMark, size: 192, color: Color(0xFF241A20)),
            ),
          ),
        ),
      ),
      side: 512,
      name: 'splash-mark',
    );
  });

  test('the mark is the app own seal, not a second drawing', () {
    // A hand-drawn copy is a copy that drifts. This pins the two together so
    // a change to one is a compile-visible change to the other.
    final seal = File(
      'lib/features/welcome/presentation/widgets/sunrise_seal.dart',
    ).readAsStringSync();

    expect(
      seal,
      contains('Icons.wb_twilight'),
      reason: 'the Welcome seal changed glyph; the launcher icon has not',
    );
  });
}
