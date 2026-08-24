@Tags(<String>['golden'])
library;

// The full parity matrix: six screens × {light, dark} × {en, fa}.
//
// Every UI epic ran `daybreak-visual-parity` over its OWN screens. Nobody had
// laid all six side by side and asked whether they read as one app — and drift
// between epics is invisible one screen at a time: a spacing step that got
// rounded, a state pill that grew a different radius on Progress than on
// Schedule.
//
// **Captures, not comparisons.** These are written with `--update-goldens` and
// reviewed beside `ref--*.png` by a person, which is what
// `daybreak-visual-parity` asks for and what a pixel threshold cannot do:
// Chrome and Flutter shape text and blur shadows differently, so a diff number
// here would be a number about rasterisation. The MEASURABLE half of parity —
// resolved tokens, radii, type sizes, element order, landmark rects — is
// asserted in each epic's own parity test and in `design_parity_test.dart`.
//
// One fixture for all of it: the same seeded plan and pinned clock the
// overflow matrix uses, so a sheet and a matrix cell show the same taper.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../support/fonts.dart';
import '../support/harness.dart';
import 'app_screens.dart';

/// Where the pairs live.
const String _out = '../../parity/14-design-review';

/// The reference frames' logical size, at DPR 2.
const Size _frame = Size(390, 844);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  /// `01`, `02`, … in the order the reference sheets number them.
  String number(int index) => (index + 1).toString().padLeft(2, '0');

  final screens = appScreens();
  for (var index = 0; index < screens.length; index++) {
    final screen = screens[index];
    final slug = '${number(index)}-${screen.name.toLowerCase()}';

    for (final brightness in Brightness.values) {
      for (final locale in <Locale>[const Locale('en'), const Locale('fa')]) {
        final name = 'app--$slug--${brightness.name}-${locale.languageCode}';
        testWidgets(name, (tester) async {
          final l10n = await AppLocalizations.delegate.load(locale);
          await pumpApp(
            tester,
            screen.build(l10n),
            overrides: screen.overrides(locale),
            locale: locale,
            brightness: brightness,
            // The reference frame's size exactly, so a capture and a crop are
            // comparable without scaling either.
            surfaceSize: _frame,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('$_out/$name.png'),
          );
        });
      }
    }
  }
}
