@Tags(<String>['golden'])
library;

// Recipe 2's golden sheet — a GATE, not a driver.
//
// You cannot write a failing screenshot comparison before the widget exists,
// so the row's behaviour is driven test-first in `day_state_row_test.dart` and
// these hold it still afterwards. Eight sheets: {light, dark} x {en, fa} at
// 1.0 and 2.0, plus the greyscale variant that the "was this taken?" claim is
// actually judged against.
//
// Tagged `golden` and excluded from the default CI lane for the reason
// `day_state_greyscale_golden_test.dart` sets out: these were authored on
// macOS, text rasterises differently on a Linux runner, and a gate that goes
// red for the host is a gate somebody switches off. The claims CI needs are
// the measured ones in the sibling suite. EPIC-14 owns the pinned-runner
// sweep.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_row.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

/// Saturation zero — the same matrix the EPIC-02 greyscale gate uses.
const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// The copy for one row, per locale. Pre-formatted, exactly as the widget
/// wants it: the sheet exercises the WIDGET, not the formatters.
({String weekday, String date, String dose, String tablets, String newDose})
copyFor(String languageCode) => languageCode == 'fa'
    ? (
        weekday: 'پنجشنبه',
        date: '۲۷ فروردین',
        dose: '۹ میلی‌گرم',
        tablets: '۱ × ۵ · ۴ × ۱',
        newDose: 'روز دوز جدید',
      )
    : (
        weekday: 'Thursday',
        date: '16 April',
        dose: '9mg',
        tablets: '1 × 5mg · 4 × 1mg',
        newDose: 'New dose day',
      );

/// The state word per locale, so the sheet shows real glyphs rather than
/// English inside a Persian frame.
String wordFor(String languageCode, DayState state) => languageCode == 'fa'
    ? switch (state) {
        DayState.taken => 'مصرف شد',
        DayState.missed => 'ثبت نشده',
        DayState.today => 'امروز',
        DayState.upcoming => 'پیش‌رو',
      }
    : switch (state) {
        // The CASED forms, because that is what `.sstate` shows in Latin.
        DayState.taken => 'TAKEN',
        DayState.missed => 'NOT TICKED',
        DayState.today => 'TODAY',
        DayState.upcoming => 'UPCOMING',
      };

/// All four states stacked, plus the new-dose channel on `today`.
///
/// The fifth row is `today` WITH `isNewDose`, not a fifth state: that pairing
/// is the ordinary case the enum deliberately cannot express, and a sheet that
/// never showed it would leave the app's most common Tuesday untested.
Widget sheet(BuildContext context, String languageCode) {
  final copy = copyFor(languageCode);
  final colors = DaybreakColors.of(context);
  // `Align` gives the `ColoredBox` LOOSE constraints, so the sheet hugs its
  // rows instead of being stretched to the viewport. Without it the surface
  // height has to be guessed per locale and per scale, and a guess that is too
  // small bakes a yellow overflow stripe into the baseline.
  return Align(
    alignment: Alignment.topCenter,
    child: ColoredBox(
      color: colors.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (state, isNewDose) in <(DayState, bool)>[
            (DayState.taken, false),
            (DayState.missed, false),
            (DayState.today, false),
            (DayState.upcoming, false),
            (DayState.today, true),
          ])
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
              child: DayStateRow(
                state: state,
                dayLabel: '${copy.weekday} 16 April',
                doseText: copy.dose,
                tabletsText: copy.tablets,
                stateLabel: wordFor(languageCode, state),
                semanticsLabel: 'x',
                isNewDose: isNewDose,
                newDoseLabel: copy.newDose,
              ),
            ),
        ],
      ),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'day_state_row_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpApp(
            tester,
            Builder(builder: (context) => sheet(context, languageCode)),
            locale: Locale(languageCode),
            brightness: brightness,
            textScaler: TextScaler.linear(scale),
            // 2.0 needs the room; a clipped sheet would bake the clipping in.
            surfaceSize: Size(390, scale == 1 ? 700 : 2200),
          );

          await expectLater(
            find.byType(ColoredBox).first,
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }

  testWidgets('day_state_row_greyscale', (tester) async {
    // The sheet the "did I take it?" claim is judged against. Colour removed,
    // the four shapes are all that is left — which is the design.
    await pumpApp(
      tester,
      ColorFiltered(
        colorFilter: _greyscale,
        child: Builder(builder: (context) => sheet(context, 'en')),
      ),
      surfaceSize: const Size(390, 700),
    );

    await expectLater(
      find.byType(ColorFiltered),
      matchesGoldenFile('goldens/day_state_row_greyscale.png'),
    );
  });
}
