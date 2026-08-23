@Tags(<String>['golden'])
library;

// Frame 3 — the Schedule screen — as a GATE, not a driver.
//
// Nine captures: {light, dark} × {en, fa} × {1.0, 2.0}, plus a greyscale lane.
// The greyscale one is the load-bearing capture on this screen: four day
// states, a new-dose day and a hold day all have to stay distinguishable with
// every colour removed, which is what makes the shape-and-word rule a rule
// rather than a preference.
//
// Tagged `golden` and excluded from the default CI lane for the reason EPIC-02
// set out: authored on macOS, and a gate that goes red for the host is a gate
// somebody switches off.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../support/harness.dart';
import 'support/schedule_fixture.dart';

/// Saturation zero — the same matrix the EPIC-02 greyscale gate uses.
const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

void main() {
  setUpAll(initializeDateFormatting);

  Future<void> pumpFrame(
    WidgetTester tester, {
    required String languageCode,
    required Brightness brightness,
    required double scale,
    bool greyscale = false,
  }) async {
    final l10n = await AppLocalizations.delegate.load(Locale(languageCode));
    await pumpApp(
      tester,
      greyscale
          ? const ColorFiltered(
              colorFilter: _greyscale,
              child: ScheduleScreen(),
            )
          : const ScheduleScreen(),
      overrides: scheduleOverrides(
        active: fixtureSchedule(l10n: l10n, locale: Locale(languageCode)),
        // Two steps, so the app-bar chevron is present the way frame 3 has
        // it. A capture without it is a capture of a plan one step long.
        options: <StepOption>[
          StepOption(
            index: 0,
            label: l10n.stepRangeLabel(1, 2, '11mg', '10mg'),
            status: StepStatus.completed,
          ),
          StepOption(
            index: 1,
            label: l10n.stepRangeLabel(2, 2, '10mg', '9mg'),
            status: StepStatus.active,
          ),
        ],
      ),
      locale: Locale(languageCode),
      brightness: brightness,
      textScaler: TextScaler.linear(scale),
      // The shell's real height, not the device's: this screen never gets 844
      // with a 96pt tab bar under it.
      surfaceSize: const Size(390, 720),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'schedule_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpFrame(
            tester,
            languageCode: languageCode,
            brightness: brightness,
            scale: scale,
          );

          await expectLater(
            find.byType(ScheduleScreen),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }

  testWidgets('schedule_greyscale', (tester) async {
    // Colour removed entirely. Every state must still be answerable from the
    // marker's shape and the word beside it.
    await pumpFrame(
      tester,
      languageCode: 'en',
      brightness: Brightness.light,
      scale: 1,
      greyscale: true,
    );

    await expectLater(
      find.byType(ColorFiltered),
      matchesGoldenFile('goldens/schedule_greyscale.png'),
    );
  });
}
