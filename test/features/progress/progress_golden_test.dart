@Tags(<String>['golden'])
library;

// Frame 4 — the Progress screen — as a GATE, not a driver.
//
// Nine captures: {light, dark} × {en, fa} × {1.0, 2.0}, plus a greyscale lane.
// The greyscale one is what proves the flare RING and the hold BRACKET are
// told apart by shape; the painter tests pin that as a rule, and this is the
// picture that shows it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/progress/application/progress_view_provider.dart';
import 'package:nearlystop/features/progress/presentation/progress_screen.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';
import 'support/progress_fixture.dart';

/// Saturation zero — the same matrix the EPIC-02 greyscale gate uses.
const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

ProgressLoaded fixtureFor(String languageCode) {
  final fa = languageCode == 'fa';
  return ProgressLoaded(
    segments: <DoseSegment>[
      for (var index = 0; index < 12; index++)
        DoseSegment(
          startDayIndex: index * 26,
          endDayIndex: index * 26 + 25,
          dose: Milligrams.fromHundredths(1500 - (index ~/ 2) * 100),
        ),
    ],
    flares: <FlareMark>[
      FlareMark(
        dayIndex: 200,
        dose: const Milligrams.fromHundredths(1200),
        label: fa ? 'عود' : 'Flare on 31 March 2025, back to 12 milligrams',
      ),
    ],
    holds: <HoldMark>[
      HoldMark(
        dayIndex: 150,
        days: 5,
        dose: const Milligrams.fromHundredths(1300),
        label: fa ? 'توقف' : 'Held at 13 milligrams for 5 days',
      ),
    ],
    todayDayIndex: 311,
    todayDose: const Milligrams.fromHundredths(900),
    axis: ProgressAxis(
      minDose: const Milligrams.fromHundredths(900),
      maxDose: const Milligrams.fromHundredths(1500),
      firstLabel: fa ? 'شهریور ۱۴۰۳' : 'Sep 2024',
      lastLabel: fa ? 'فروردین ۱۴۰۵' : 'Apr 2026',
    ),
    stats: ProgressStats(
      daysOnDrug: fa ? '۵۸۱' : '581',
      cumulativeMg: fa ? '۶٬۸۴۲' : '6,842',
      adherence: fa ? '۵۷۴ از ۵۸۱' : '574 of 581',
      adherenceCaption: fa
          ? 'روز تا اینجا ثبت شده — چند روز جا افتاده اهمیتی ندارد'
          : 'days ticked so far — a few gaps change nothing',
    ),
    startLine: fa
        ? 'شروع ۲۲ شهریور ۱۴۰۳ با ۱۵ میلی‌گرم'
        : 'Started 12 September 2024 at 15mg',
    encouragement: fa
        ? 'شما ۶ میلی‌گرم کمتر از زمان شروع هستید.'
        : 'You are 6mg lower than when you started.',
    eventCountLabel: fa
        ? '۱ عود و ۱ توقف ثبت شده'
        : '1 flare and 1 hold recorded',
    chartSummary: 'x',
    historyRows: const <String>['x'],
  );
}

void main() {
  setUpAll(initializeDateFormatting);

  Future<void> pumpFrame(
    WidgetTester tester, {
    required String languageCode,
    required Brightness brightness,
    required double scale,
    bool greyscale = false,
  }) async {
    await pumpApp(
      tester,
      greyscale
          ? const ColorFiltered(
              colorFilter: _greyscale,
              child: ProgressScreen(),
            )
          : const ProgressScreen(),
      overrides: <Override>[
        progressViewProvider.overrideWith(
          () => FixedProgress.data(fixtureFor(languageCode)),
        ),
      ],
      locale: Locale(languageCode),
      brightness: brightness,
      textScaler: TextScaler.linear(scale),
      // The shell's real height, not the device's.
      surfaceSize: Size(390, scale == 1 ? 720 : 1800),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'progress_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpFrame(
            tester,
            languageCode: languageCode,
            brightness: brightness,
            scale: scale,
          );

          await expectLater(
            find.byType(ProgressScreen),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }

  testWidgets('progress_greyscale', (tester) async {
    await pumpFrame(
      tester,
      languageCode: 'en',
      brightness: Brightness.light,
      scale: 1,
      greyscale: true,
    );

    await expectLater(
      find.byType(ColorFiltered),
      matchesGoldenFile('goldens/progress_greyscale.png'),
    );
  });
}
