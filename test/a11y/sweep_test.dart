@Tags(<String>['golden'])
library;

// The end-of-build sweep, as files a reviewer looks at.
//
// `design-review-workflow` asks for a release-build sweep with a standardized
// status bar. This produces the same matrix from the widget harness instead,
// and the trade is stated rather than hidden: what is LOST is the release
// build's rasterisation and the real status bar; what is GAINED is that every
// cell is deterministic, seeded from the same taper as the overflow matrix and
// the parity sheets, and that the axes a manual device sweep is slowest at —
// high contrast, expanded width, largest scale, grayscale — are all actually
// covered rather than sampled.
//
// The on-device half is not replaced by this. It is recorded separately in
// `docs/design-review/on-device-pass.md`.
//
// **Largest text scale and bold are applied to every phone still**, not kept
// as a separate axis: this audience sets them and leaves them set, so that is
// what the app looks like.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../support/fonts.dart';
import '../support/harness.dart';
import 'app_screens.dart';

/// Where a reviewer finds the stills.
const String _out = '../../docs/design-review/sweep';

/// The smallest supported phone. Every reflow failure shows here first.
const Size _phone = Size(320, 640);

/// Landscape, and the size class SPEC §5.4 puts on a kitchen table.
const Size _expanded = Size(1024, 768);

/// The scale this audience actually runs at.
const double _large = 2;

/// Drops all colour, for the never-colour-alone read.
const ColorFilter _grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  String number(int index) => (index + 1).toString().padLeft(2, '0');

  Future<void> shoot(
    WidgetTester tester, {
    required AppScreen screen,
    required String name,
    required Locale locale,
    required Brightness brightness,
    required Size size,
    bool highContrast = false,
    bool grayscale = false,
    double scale = _large,
  }) async {
    final l10n = await AppLocalizations.delegate.load(locale);
    final built = screen.build(l10n);
    await pumpApp(
      tester,
      grayscale ? ColorFiltered(colorFilter: _grayscale, child: built) : built,
      overrides: screen.overrides(locale),
      locale: locale,
      brightness: brightness,
      highContrast: highContrast,
      textScaler: TextScaler.linear(scale),
      boldText: true,
      surfaceSize: size,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/$name.png'),
    );
  }

  final screens = appScreens();
  for (var index = 0; index < screens.length; index++) {
    final screen = screens[index];
    final slug = '${number(index)}--${screen.name.toLowerCase()}';

    for (final brightness in Brightness.values) {
      for (final locale in <Locale>[const Locale('en'), const Locale('fa')]) {
        final dir = locale.languageCode == 'fa' ? 'rtl' : 'ltr';

        testWidgets('$slug--${brightness.name}--$dir', (tester) async {
          await shoot(
            tester,
            screen: screen,
            name: '$slug--${brightness.name}--$dir',
            locale: locale,
            brightness: brightness,
            size: _phone,
          );
        });

        // SPEC §5.4 makes landscape and tablet a v1 requirement, and EPIC-15
        // ships `TARGETED_DEVICE_FAMILY = "1,2"` on the strength of it. The
        // rail swap and the landscape reflow get looked at here, not
        // discovered at the iPad screenshot upload.
        testWidgets('$slug--${brightness.name}--$dir--expanded', (
          tester,
        ) async {
          await shoot(
            tester,
            screen: screen,
            name: '$slug--${brightness.name}--$dir--expanded',
            locale: locale,
            brightness: brightness,
            size: _expanded,
            // Landscape at 2.0 bold is a legitimate cell, but the point of
            // this axis is the LAYOUT, so it is shot at 1.0 where the rail
            // and the two-pane split are actually visible.
            scale: 1,
          );
        });
      }

      // The high-contrast palette is new in EPIC-02 and this is the first
      // time all six screens are looked at in it.
      testWidgets('$slug--${brightness.name}-hc--ltr', (tester) async {
        await shoot(
          tester,
          screen: screen,
          name: '$slug--${brightness.name}-hc--ltr',
          locale: const Locale('en'),
          brightness: brightness,
          size: _phone,
          highContrast: true,
        );
      });
    }

    // The grayscale derivative task 6's human half reads. Light and English
    // only: what is judged is whether the STATES are nameable without colour,
    // and that does not change with the theme.
    testWidgets('$slug--light--ltr--grayscale', (tester) async {
      await shoot(
        tester,
        screen: screen,
        name: '$slug--light--ltr--grayscale',
        locale: const Locale('en'),
        brightness: Brightness.light,
        size: _phone,
        grayscale: true,
      );
    });
  }
}
