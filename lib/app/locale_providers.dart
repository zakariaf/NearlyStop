/// The locale seam every notifier formats its strings through.
library;

import 'package:flutter/widgets.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:riverpod/riverpod.dart';

/// The one locale the app renders in.
///
/// Resolved from the stored override first and the OS list second, through
/// EPIC-03's pure `resolveAppLocale`. **Both consumers read this** — the
/// `MaterialApp`'s `locale:` and the theme builder's `scriptFor` — because
/// `theme:` is evaluated above the `Localizations` scope and cannot ask what
/// the locale turned out to be.
///
/// It watches the settings controller, so choosing a language in Settings
/// re-emits; the shell's lifecycle hook invalidates it on an OS locale change.
final Provider<Locale> resolvedLocaleProvider = Provider<Locale>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  return resolveAppLocale(preferredLocalesFor(settings));
});

/// The preference list `resolveAppLocale` is given.
///
/// A stored override goes in **front** of the OS list rather than replacing
/// it: if the user's choice is later dropped from `kSupportedLocales`, their
/// phone's own languages are still a better answer than English.
List<Locale> preferredLocalesFor(
  AppSettings settings, {
  List<Locale>? osLocales,
}) => <Locale>[
  if (settings.localeTag case final tag?) Locale(tag),
  ...osLocales ?? WidgetsBinding.instance.platformDispatcher.locales,
];

/// `AppLocalizations` for the resolved locale.
///
/// **The only sanctioned way to reach a string outside a widget.** Inside a
/// widget the rule is still `AppLocalizations.of(context)`; this exists for
/// notifiers, which sit above the `Localizations` scope where that call is
/// illegal. Nobody reaches for a global navigator key.
///
/// Keyed on the **resolved** locale, not the launch locale — otherwise every
/// string freezes at launch and switching language does nothing until the app
/// is relaunched.
final Provider<AppLocalizations> appLocalizationsProvider =
    Provider<AppLocalizations>(
      (ref) => lookupAppLocalizations(ref.watch(resolvedLocaleProvider)),
    );
