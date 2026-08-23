/// Which locales the app ships, and the one function that decides between them.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nearlystop/l10n/ckb_material_localizations.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_script.dart';

/// Kurdish Sorani, script-tagged.
///
/// The script subtag is not decoration: `ckb` is written in Perso-Arabic and a
/// bare `Locale('ckb')` leaves the framework to guess a direction.
const Locale kurdishSorani = Locale.fromSubtags(
  languageCode: 'ckb',
  scriptCode: 'Arab',
);

/// The four locales, in preference order. English is the fallback.
final List<Locale> kSupportedLocales = <Locale>[
  const Locale('en'),
  const Locale('de'),
  const Locale('fa'),
  kurdishSorani,
];

/// Language codes a real device offers that mean one of ours.
///
/// `ku` is Kurdish with no script or dialect: Android and iOS both emit it, and
/// `basicLocaleListResolution` will not map it to `ckb` on its own — a bare
/// language match against a different language code is not something it is
/// allowed to invent. So we invent it, here, once, where it is testable.
const Map<String, String> _languageAliases = <String, String>{'ku': 'ckb'};

/// Resolves the OS's preference list to exactly one supported locale.
///
/// **Pure, and called by both consumers.** `MaterialApp.theme` is evaluated
/// *before* `Localizations` resolves, so `localeResolutionCallback` cannot be
/// what tells the theme which script to render. Resolving once ourselves and
/// handing the same answer to `MaterialApp.locale` and to the theme builder is
/// what stops them disagreeing — the failure mode being a Persian UI rendered
/// in the Latin type scale.
Locale resolveAppLocale(List<Locale> preferred) {
  final canonical = <Locale>[
    for (final locale in preferred)
      Locale.fromSubtags(
        languageCode:
            _languageAliases[locale.languageCode] ?? locale.languageCode,
        scriptCode: locale.scriptCode,
        // Country is dropped rather than passed through: `de-CH` and `ckb-IQ`
        // are the same app, and keeping the subtag only gives
        // `basicLocaleListResolution` a chance to prefer a worse match.
      ),
  ];
  return basicLocaleListResolution(canonical, kSupportedLocales);
}

/// Which type scale a locale is rendered in.
///
/// `languageCode` only. A country or script subtag never changes the script the
/// text is written in, and switching on the full tag is how `fa-AF` quietly
/// falls to the Latin scale.
DaybreakScript scriptFor(Locale locale) => switch (locale.languageCode) {
  'fa' || 'ckb' => DaybreakScript.perso,
  _ => DaybreakScript.latin,
};

/// The delegates `MaterialApp` needs, **in the order it needs them**.
///
/// The three `ckb` delegates come FIRST. Flutter takes the first delegate whose
/// `isSupported` returns true, and the global ones return false for `ckb`
/// anyway — but ordering them after would mean relying on that, and each `ckb`
/// delegate is inert for every other locale precisely so this order is safe.
List<LocalizationsDelegate<Object>> get kAppLocalizationsDelegates =>
    <LocalizationsDelegate<Object>>[
      AppLocalizations.delegate,
      const CkbMaterialLocalizationsDelegate(),
      const CkbCupertinoLocalizationsDelegate(),
      const CkbWidgetsLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
