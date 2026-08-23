import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/app/user_preferences_layer.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/routing/app_router.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';

/// The root widget.
///
/// Every theme argument comes from state the launch already read, so frame one
/// is already the theme the user chose.
class NearlyStopApp extends ConsumerStatefulWidget {
  /// Creates the root widget.
  const NearlyStopApp({super.key});

  @override
  ConsumerState<NearlyStopApp> createState() => _NearlyStopAppState();
}

class _NearlyStopAppState extends ConsumerState<NearlyStopApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // The user changed the phone's language while the app was open. Both the
    // strings AND the theme have to follow: the theme was built from a locale
    // nobody recomputed, so without this the type scale stays Latin inside a
    // Persian UI.
    //
    // This widget carries the hook rather than the shell because the
    // disclaimer gate is a top-level route OUTSIDE the shell — on first run
    // the shell does not exist, and neither would the observer.
    ref.invalidate(resolvedLocaleProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    // Resolved ONCE, here, and handed to both consumers. `MaterialApp.theme` is
    // evaluated before `Localizations` resolves, so `localeResolutionCallback`
    // cannot be what tells the theme which script to render — and the failure
    // is silent: a Persian UI in the Latin type scale reads as slightly wrong
    // rather than broken.
    final locale = ref.watch(resolvedLocaleProvider);
    final script = scriptFor(locale);
    final highContrast = settings.highContrast;

    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kAppLocalizationsDelegates,
      debugShowCheckedModeBanner: false,
      // The stored choice, read before the first frame. `themeMode` is what
      // makes frame one dark for a user who asked for dark — not a repaint
      // after the database answers.
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      theme: buildDaybreakTheme(
        Brightness.light,
        script,
        highContrast: highContrast,
      ),
      darkTheme: buildDaybreakTheme(
        Brightness.dark,
        script,
        highContrast: highContrast,
      ),
      // The OS "Increase Contrast" switch reaches the palette here. Material
      // selects these automatically from `MediaQueryData.highContrast`, and
      // without them the high-contrast palettes exist but are unreachable —
      // which for this audience is a defect, not a deferral.
      highContrastTheme: buildDaybreakTheme(
        Brightness.light,
        script,
        highContrast: true,
      ),
      highContrastDarkTheme: buildDaybreakTheme(
        Brightness.dark,
        script,
        highContrast: true,
      ),
      // Material cross-fades ThemeData over kThemeAnimationDuration by default.
      // At 6am on a bedside table that is a luminance jolt nobody asked for.
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => UserPreferencesLayer(
        script: script,
        highContrast: highContrast,
        userTextScale: settings.textScale,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
