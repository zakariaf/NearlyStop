// The app's own wiring: the OS locale reaches BOTH the MaterialApp and the
// theme, and they agree.
//
// This is the ordering bug the pure function exists to prevent. `theme:` is
// evaluated before `Localizations` resolves, so a `localeResolutionCallback`
// cannot be what tells the theme which script to use — and the failure mode is
// silent: a Persian UI rendered in the Latin type scale, which looks merely
// slightly wrong rather than broken.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/app.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/providers.dart';
import 'package:riverpod/misc.dart' show Override;

void main() {
  Future<void> pumpIn(WidgetTester tester, List<Locale> platformLocales) async {
    tester.platformDispatcher.localesTestValue = platformLocales;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          // The app reads its theme from state the launch supplies. Without
          // this override `bootstrapSettingsProvider` throws by design.
          bootstrapSettingsProvider.overrideWithValue(AppSettings.defaults),
        ],
        child: const NearlyStopApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (platform, expected, expectedDirection)
      in <
        (
          List<Locale>,
          Locale,
          TextDirection,
        )
      >[
        (<Locale>[const Locale('en')], const Locale('en'), TextDirection.ltr),
        (<Locale>[const Locale('de')], const Locale('de'), TextDirection.ltr),
        (<Locale>[const Locale('fa')], const Locale('fa'), TextDirection.rtl),
        (<Locale>[const Locale('ku')], kurdishSorani, TextDirection.rtl),
        (<Locale>[const Locale('ja')], const Locale('en'), TextDirection.ltr),
      ]) {
    testWidgets('${platform.first} renders as ${expected.toLanguageTag()}', (
      tester,
    ) async {
      await pumpIn(tester, platform);

      final context = tester.element(find.byType(Scaffold));

      expect(Localizations.localeOf(context), expected);
      expect(Directionality.of(context), expectedDirection);

      // The theme agrees with the locale, which is the whole point.
      final family = Theme.of(context).textTheme.bodyLarge!.fontFamily;
      expect(
        family,
        switch (expected.languageCode) {
          'fa' || 'ckb' => 'Vazirmatn',
          _ => 'Nunito',
        },
        reason: 'the theme must not disagree with Localizations',
      );

      // And an app-owned string is actually in that language.
      expect(AppLocalizations.of(context).localeName, expected.languageCode);
    });
  }

  testWidgets('the OS switching language re-resolves both', (tester) async {
    await pumpIn(tester, <Locale>[const Locale('en')]);
    expect(
      Theme.of(
        tester.element(find.byType(Scaffold)),
      ).textTheme.bodyLarge!.fontFamily,
      'Nunito',
    );

    // `didChangeLocales`: the user changed the phone's language while the app
    // was open. Both consumers have to follow, not just the strings.
    tester.platformDispatcher.localesTestValue = <Locale>[const Locale('fa')];
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context), const Locale('fa'));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Theme.of(context).textTheme.bodyLarge!.fontFamily, 'Vazirmatn');
  });
}
