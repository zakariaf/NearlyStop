import 'package:flutter/material.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';

/// The root widget.
///
/// EPIC-06 replaces this with `MaterialApp.router` and makes `themeMode`,
/// `highContrast` and the locale a setting the user can override; today the
/// locale follows the OS.
class NearlyStopApp extends StatefulWidget {
  /// Creates the root widget.
  const NearlyStopApp({super.key});

  @override
  State<NearlyStopApp> createState() => _NearlyStopAppState();
}

class _NearlyStopAppState extends State<NearlyStopApp>
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
    // The user changed the phone's language while the app was open. Without
    // this the strings follow — `MaterialApp` re-resolves on its own — but the
    // THEME does not, because it was built from a locale nobody recomputed.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Resolved ONCE, here, and handed to both consumers. `MaterialApp.theme` is
    // evaluated before `Localizations` resolves, so `localeResolutionCallback`
    // cannot be what tells the theme which script to render — and the failure
    // is silent: a Persian UI in the Latin type scale reads as slightly wrong
    // rather than broken.
    final locale = resolveAppLocale(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
    final script = scriptFor(locale);

    return MaterialApp(
      title: 'NearlyStop',
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kAppLocalizationsDelegates,
      theme: buildDaybreakTheme(Brightness.light, script),
      darkTheme: buildDaybreakTheme(Brightness.dark, script),
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
      builder: (context, child) => _applyBoldText(context, child, script),
      home: const _ThemePlaceholder(),
    );
  }
}

/// Rebuilds the theme one weight-step up when the OS asks for bold text.
///
/// It has to happen **here**, below `MaterialApp`, because that is the first
/// place a `MediaQuery` exists: `theme:` and `darkTheme:` are evaluated above
/// it, so no call site up there can read `boldTextOf`. Flutter does not apply
/// `boldText` on its own — it exposes the flag and leaves honouring it to the
/// app, and `accessibility-as-code` says honouring it is correctness.
Widget _applyBoldText(
  BuildContext context,
  Widget? child,
  DaybreakScript script,
) {
  final content = child ?? const SizedBox.shrink();
  if (!MediaQuery.boldTextOf(context)) return content;
  final selected = Theme.of(context);
  return Theme(
    data: buildDaybreakTheme(
      selected.brightness,
      // The SAME script the themes above were built from. Rebuilding in Latin
      // here would silently drop the Persian transform for exactly the users
      // who turned bold text on.
      script,
      highContrast: MediaQuery.highContrastOf(context),
      boldText: true,
    ),
    child: content,
  );
}

/// A placeholder until EPIC-06 wires the router and the five real screens.
class _ThemePlaceholder extends StatelessWidget {
  const _ThemePlaceholder();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
