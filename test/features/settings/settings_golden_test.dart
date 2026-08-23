@Tags(<String>['golden'])
library;

// Frame 6 — the Settings screen — as a GATE, not a driver.
//
// Eight captures: {light, dark} × {en, fa} × {1.0, 2.0}, plus one of the
// language picker OPEN in `fa`. That ninth is the only picture that proves the
// claim the picker makes: every option renders in its own script and its own
// face, so somebody who has accidentally set the app to a language they cannot
// read can still find their way back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_cards.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Future<void> pumpFrame(
    WidgetTester tester, {
    required String languageCode,
    required Brightness brightness,
    required double scale,
  }) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: <Override>[
        settingsControllerProvider.overrideWith(
          FixedSettingsController.seeded,
        ),
      ],
      locale: Locale(languageCode),
      brightness: brightness,
      textScaler: TextScaler.linear(scale),
      surfaceSize: Size(390, scale == 1 ? 1200 : 2600),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'settings_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpFrame(
            tester,
            languageCode: languageCode,
            brightness: brightness,
            scale: scale,
          );

          await expectLater(
            find.byType(SettingsScreen),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }

  testWidgets('settings_language_picker_fa', (tester) async {
    await pumpFrame(
      tester,
      languageCode: 'fa',
      brightness: Brightness.light,
      scale: 1,
    );

    await tester.tap(find.byType(LanguageCard));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LanguagePickerSheet),
      matchesGoldenFile('goldens/settings_language_picker_fa.png'),
    );
  });
}
