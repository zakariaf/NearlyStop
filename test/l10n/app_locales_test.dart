// The alias table IS the test.
//
// `basicLocaleListResolution` handles most of this on its own; the cases it
// does not — `ku`, and the ordering guarantee — are the only ones that prove
// anything about our code, so they are named individually rather than folded
// into a loop over "some locales".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/l10n/app_locales.dart';

const Locale ckbArab = Locale.fromSubtags(
  languageCode: 'ckb',
  scriptCode: 'Arab',
);

void main() {
  /// One row of the resolution table: what the OS offers, what we render.
  final table = <String, (List<Locale>, Locale)>{
    'en exactly': (<Locale>[const Locale('en')], const Locale('en')),
    'de exactly': (<Locale>[const Locale('de')], const Locale('de')),
    'fa exactly': (<Locale>[const Locale('fa')], const Locale('fa')),
    'ckb-Arab exactly': (<Locale>[ckbArab], ckbArab),

    // `basicLocaleListResolution` will NOT do this on its own. The alias is
    // explicit code and this row is the only thing that proves it is wired.
    'ku aliases to Kurdish Sorani': (
      <Locale>[const Locale('ku')],
      ckbArab,
    ),

    // Kurmanji — Northern Kurdish, written in LATIN. A different language from
    // Sorani, and one this app does not ship. Aliasing it to `ckb` hands the
    // user Sorani text in a script they may not read, with the whole UI
    // mirrored to RTL.
    'ku-Latn is Kurmanji and falls back, NOT to Sorani': (
      <Locale>[
        const Locale.fromSubtags(languageCode: 'ku', scriptCode: 'Latn'),
      ],
      const Locale('en'),
    ),
    'ku-Arab is Sorani': (
      <Locale>[
        const Locale.fromSubtags(languageCode: 'ku', scriptCode: 'Arab'),
      ],
      ckbArab,
    ),
    'ku-Latn then de picks de, not the alias': (
      <Locale>[
        const Locale.fromSubtags(languageCode: 'ku', scriptCode: 'Latn'),
        const Locale('de'),
      ],
      const Locale('de'),
    ),

    // Country and script noise a real device produces.
    'ckb-IQ ignores the country': (
      <Locale>[const Locale('ckb', 'IQ')],
      ckbArab,
    ),
    'ckb-IR ignores the country': (
      <Locale>[const Locale('ckb', 'IR')],
      ckbArab,
    ),
    'ckb-Arab-IQ ignores the country': (
      <Locale>[
        const Locale.fromSubtags(
          languageCode: 'ckb',
          scriptCode: 'Arab',
          countryCode: 'IQ',
        ),
      ],
      ckbArab,
    ),
    'de-CH ignores the country': (
      <Locale>[const Locale('de', 'CH')],
      const Locale('de'),
    ),
    'en-GB ignores the country': (
      <Locale>[const Locale('en', 'GB')],
      const Locale('en'),
    ),

    // Dari. Persian, not the English fallback.
    'fa-AF is Persian': (
      <Locale>[const Locale('fa', 'AF')],
      const Locale('fa'),
    ),

    // Unsupported falls back rather than throwing.
    'ar falls back': (<Locale>[const Locale('ar')], const Locale('en')),
    'ja-JP falls back': (
      <Locale>[const Locale('ja', 'JP')],
      const Locale('en'),
    ),
    'an empty preference list falls back': (
      <Locale>[],
      const Locale('en'),
    ),

    // PREFERENCE order, not list position: the first SUPPORTED entry wins.
    'ar then de picks de': (
      <Locale>[const Locale('ar'), const Locale('de')],
      const Locale('de'),
    ),
    'de then fa picks de': (
      <Locale>[const Locale('de'), const Locale('fa')],
      const Locale('de'),
    ),
    'ku then de picks the alias, because it comes first': (
      <Locale>[const Locale('ku'), const Locale('de')],
      ckbArab,
    ),
  };

  group('resolveAppLocale', () {
    table.forEach((name, row) {
      final (preferred, expected) = row;
      test(name, () => expect(resolveAppLocale(preferred), expected));
    });

    test('supportedLocales is exactly the four the app ships', () {
      expect(kSupportedLocales, <Locale>[
        const Locale('en'),
        const Locale('de'),
        const Locale('fa'),
        ckbArab,
      ]);
    });
  });

  group('the two consumers cannot disagree', () {
    // MaterialApp.theme is evaluated BEFORE Localizations resolves, so
    // `localeResolutionCallback` cannot be what tells the theme which script to
    // render. Resolving once, in a pure function both sides call, is the fix —
    // and this is the test that proves they agree.
    table.forEach((name, row) {
      final (preferred, expected) = row;
      testWidgets('$name — MaterialApp renders the same locale', (
        tester,
      ) async {
        late Locale seen;
        late TextDirection direction;

        await tester.pumpWidget(
          MaterialApp(
            locale: resolveAppLocale(preferred),
            supportedLocales: kSupportedLocales,
            localizationsDelegates: kAppLocalizationsDelegates,
            home: Builder(
              builder: (context) {
                seen = Localizations.localeOf(context);
                direction = Directionality.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(seen, expected);
        // Direction is never hardcoded — there is no root `Directionality` in
        // the tree above. It follows the resolved locale through
        // GlobalWidgetsLocalizations, which is what makes an LTR island inside
        // a Persian screen work.
        expect(
          direction,
          switch (expected.languageCode) {
            'fa' || 'ckb' => TextDirection.rtl,
            _ => TextDirection.ltr,
          },
          reason: expected.toLanguageTag(),
        );
      });
    });
  });
}
