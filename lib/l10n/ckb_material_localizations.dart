/// Framework strings for Kurdish Sorani, which `flutter_localizations` has none
/// of.
///
/// `flutter_localizations` ships Material, Cupertino and Widgets translations
/// for 116 locales. `de` and `fa` are among them; **`ckb` is not**, and
/// `kMaterialSupportedLanguages` does not contain it. Without these three
/// delegates a `ckb` build warns at startup that no delegate supports the
/// locale and then — the part that actually hurts — resolves
/// `Directionality` to **LTR**, rendering the entire app left-to-right in a
/// right-to-left language.
///
/// **What this buys, and what it costs.** Each `load()` returns the **Persian**
/// instance from the global delegates. That buys correct `TextDirection.rtl`
/// (from the `fa` `WidgetsLocalizations`), Perso-Arabic framework strings a
/// Sorani reader can act on, and a working date picker and text-selection menu.
/// It costs accuracy: those strings read as *Persian*, not Kurdish — shared
/// script, different language, and the two differ in several of these words.
/// `MaterialLocalizations.localeName` reports `fa`, which is pinned in a test
/// so nobody later files it as a bug.
///
/// The consequence is a rule, not a shrug: **anything a patient reads in order
/// to make a decision is an app-owned ARB string in genuine Kurdish**, never a
/// framework string. Hand-translating ~70 framework strings was rejected as the
/// worse trade — it is a large surface to get subtly wrong and to keep current.
///
/// Not fixable by a `-u-` extension or a locale alias: the framework's data
/// tables simply have no `ckb` entry. `test/l10n/ckb_localizations_test.dart`
/// asserts that, so the day upstream adds it the test goes red and names this
/// file for deletion.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The locale the framework strings are borrowed from.
const Locale _borrowedFrom = Locale('fa');

/// True for Kurdish Sorani and nothing else.
///
/// Inertness is what makes it safe to place these delegates **before** the
/// global ones: they win for `ckb` and never intercept a locale the framework
/// already handles properly.
bool _isKurdishSorani(Locale locale) => locale.languageCode == 'ckb';

/// Material strings for `ckb`, borrowed from Persian.
class CkbMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  /// Creates the delegate.
  const CkbMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isKurdishSorani(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(_borrowedFrom);

  @override
  bool shouldReload(CkbMaterialLocalizationsDelegate old) => false;
}

/// Cupertino strings for `ckb`, borrowed from Persian.
class CkbCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  /// Creates the delegate.
  const CkbCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isKurdishSorani(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(_borrowedFrom);

  @override
  bool shouldReload(CkbCupertinoLocalizationsDelegate old) => false;
}

/// Widgets strings for `ckb`, borrowed from Persian.
///
/// **This is the one that supplies `TextDirection.rtl`.** Of the three it is
/// the least optional: without it the app mirrors nothing.
class CkbWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  /// Creates the delegate.
  const CkbWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isKurdishSorani(locale);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(_borrowedFrom);

  @override
  bool shouldReload(CkbWidgetsLocalizationsDelegate old) => false;
}
