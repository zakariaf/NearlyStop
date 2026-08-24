@Tags(<String>['golden'])
library;

// Store screenshots, from the real app.
//
// Not mockups and not the design HTML: the same seeded taper and pinned clock
// the EPIC-14 sweep and the parity sheets use, so what a reviewer sees on the
// listing is what the app actually renders.
//
// **The exact dimensions matter and are easy to get wrong.** In particular
// this does NOT ship 1284×2778: `fastlane deliver` collides that into the 6.5″
// slot, where the ten-image cap then silently drops files — you find out by
// noticing a screenshot missing from the store, weeks later.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../a11y/app_screens.dart';
import '../support/fonts.dart';
import '../support/harness.dart';

const String _out = '../../store/screenshots';

/// One required display type: the store's name, and its exact pixel size.
typedef DisplayType = ({String slug, Size pixels, double dpr});

/// Every set the stores require for this app.
///
/// iPad 13″ is **mandatory** because the app ships universal
/// (`TARGETED_DEVICE_FAMILY = "1,2"`), which SPEC §5.4 asks for — people prop
/// tablets on a kitchen table — and which EPIC-14's expanded-width axis
/// verified. Discovering that requirement at submission is the expensive way.
const List<DisplayType> kDisplayTypes = <DisplayType>[
  (slug: 'ios-6.7', pixels: Size(1290, 2796), dpr: 3),
  (slug: 'ios-6.5', pixels: Size(1242, 2688), dpr: 3),
  (slug: 'ios-ipad-13', pixels: Size(2064, 2752), dpr: 2),
  // Play takes any reasonable phone size; this matches the 6.7″ shot so the
  // two stores show the same framing.
  (slug: 'play-phone', pixels: Size(1290, 2796), dpr: 3),
];

/// The four screens worth a listing slot, in the order they tell the story.
const List<String> kFeatured = <String>[
  'Today',
  'Schedule',
  'Progress',
  'Plan',
];

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  for (final type in kDisplayTypes) {
    for (var index = 0; index < kFeatured.length; index++) {
      final name = kFeatured[index];
      final slot = (index + 1).toString().padLeft(2, '0');

      testWidgets('${type.slug}/$slot-${name.toLowerCase()}', (tester) async {
        final screen = appScreens().firstWhere((s) => s.name == name);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // The store wants PIXELS; the harness works in logical units, so the
        // logical surface is the pixel size divided by the density the device
        // actually has. Getting this wrong produces a correctly-sized image of
        // a wrongly-sized layout.
        tester.view.devicePixelRatio = type.dpr;
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpApp(
          tester,
          screen.build(l10n),
          overrides: screen.overrides(const Locale('en')),
          surfaceSize: type.pixels / type.dpr,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '$_out/${type.slug}/$slot-${name.toLowerCase()}.png',
          ),
        );
      });
    }
  }

  test('the declared sizes are the ones the stores actually want', () {
    // Pinned, because these are transcribed numbers and a transposed digit is
    // invisible until an upload is rejected.
    expect(
      kDisplayTypes.map((t) => t.pixels).toList(),
      <Size>[
        const Size(1290, 2796),
        const Size(1242, 2688),
        const Size(2064, 2752),
        const Size(1290, 2796),
      ],
    );
    // The trap, asserted as its own absence.
    expect(
      kDisplayTypes.any((t) => t.pixels == const Size(1284, 2778)),
      isFalse,
      reason:
          '1284×2778 collides into the 6.5" slot in fastlane deliver, where '
          'the ten-image cap silently drops files',
    );
  });
}
