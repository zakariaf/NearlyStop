// Every screen, in every locale, with the locale data the LAUNCH actually
// loads.
//
// **This file must never call `initializeDateFormatting()` with no
// arguments.** That loads symbol data for all 116 locales `intl` ships, and
// registers a `fallback` entry that makes `verifiedLocale` succeed for a
// locale the app has no data for. `bootstrap()` loads `en` and `de` only, on
// purpose — materialising every table on the pre-first-frame path for an app
// with four locales is work nobody asked for.
//
// The gap between those two setups is exactly where a `ckb-Arab` reached
// `intl` and Settings came up as a red box on a device while the whole suite
// was green.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:riverpod/misc.dart' show Override;

import '../support/harness.dart';

void main() {
  setUpAll(() async {
    // The two the launch loads. See the file comment.
    for (final tag in <String>['en', 'de']) {
      await initializeDateFormatting(tag);
    }
  });

  for (final locale in kSupportedLocales) {
    testWidgets('Settings comes up in ${locale.toLanguageTag()}', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const SettingsScreen(),
        overrides: <Override>[
          // The STORED tag as well as the widget locale.
          // `resolvedLocaleProvider` reads the settings row rather than
          // `Localizations.localeOf`, and every
          // notifier formats through it — so a test that sets only the widget
          // locale leaves half the screen rendering in English and never
          // reaches the locale it claims to be testing.
          settingsControllerProvider.overrideWith(
            () => _Fixed(locale.languageCode),
          ),
        ],
        locale: locale,
        surfaceSize: const Size(390, 1400),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}

final class _Fixed extends SettingsController {
  _Fixed(this.tag);

  final String tag;

  @override
  AppSettings build() => AppSettings(
    themeMode: AppThemeMode.system,
    localeTag: tag,
    textScale: 1,
    highContrast: false,
    reminderEnabled: true,
    reminderMinuteOfDay: 545,
  );
}
