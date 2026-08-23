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
///
/// `const`: it is handed straight to `MaterialApp.supportedLocales` and
/// iterated by five test files, so a growable list would let any caller change
/// which locales the whole app resolves against, from anywhere, with no
/// compile error.
const List<Locale> kSupportedLocales = <Locale>[
  Locale('en'),
  Locale('de'),
  Locale('fa'),
  kurdishSorani,
];

/// Language codes a real device offers that mean one of ours.
///
/// `ku` is Kurdish with no script or dialect: Android and iOS both emit it, and
/// `basicLocaleListResolution` will not map it to `ckb` on its own — a bare
/// language match against a different language code is not something it is
/// allowed to invent. So we invent it, here, once, where it is testable.
///
/// **`ku-Latn` is deliberately excluded.** Latin-script Kurdish is Kurmanji —
/// Northern Kurdish, a different language, which this app does not ship.
/// Aliasing it would hand that user Sorani text in a script they may not read,
/// with the whole interface mirrored to right-to-left. It falls back instead.
const Map<String, String> _languageAliases = <String, String>{'ku': 'ckb'};

/// The script subtag that makes an aliased language ours.
///
/// `null` means the device said nothing about script, which for `ku` is the
/// common Android case and is taken as Sorani.
bool _aliasApplies(Locale locale) =>
    locale.scriptCode == null || locale.scriptCode == 'Arab';

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
      if (_languageAliases.containsKey(locale.languageCode) &&
          _aliasApplies(locale))
        // The alias also drops the script subtag: carrying the device's own
        // through would produce e.g. `ckb-Latn`, which matches nothing and
        // then falls back for the wrong reason.
        Locale.fromSubtags(
          languageCode: _languageAliases[locale.languageCode]!,
          scriptCode: 'Arab',
        )
      else if (!_languageAliases.containsKey(locale.languageCode))
        Locale.fromSubtags(
          languageCode: locale.languageCode,
          scriptCode: locale.scriptCode,
          // Country is dropped rather than passed through: `de-CH` and
          // `ckb-IQ` are the same app, and keeping the subtag only gives
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
/// `const`, not a getter: this is read from `build()`, which now runs on every
/// locale, bold-text, high-contrast and platform-brightness change, and a
/// getter allocated a fresh seven-element list each time. Every delegate here
/// is const-constructible.
const List<LocalizationsDelegate<Object>> kAppLocalizationsDelegates =
    <LocalizationsDelegate<Object>>[
      AppLocalizations.delegate,
      CkbMaterialLocalizationsDelegate(),
      CkbCupertinoLocalizationsDelegate(),
      CkbWidgetsLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
