import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';

/// The root widget.
///
/// EPIC-03 attaches the localization delegates and resolves the script from the
/// locale; EPIC-06 replaces this with `MaterialApp.router` and makes
/// `themeMode`, `highContrast` and the locale settings the user can change.
class NearlyStopApp extends StatelessWidget {
  /// Creates the root widget.
  const NearlyStopApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Hard-coded to Latin until EPIC-03 resolves it from the locale. The
    // argument is passed explicitly so the seam is visible rather than
    // defaulted.
    const script = DaybreakScript.latin;

    return MaterialApp(
      title: 'NearlyStop',
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
      builder: _applyBoldText,
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
Widget _applyBoldText(BuildContext context, Widget? child) {
  final content = child ?? const SizedBox.shrink();
  if (!MediaQuery.boldTextOf(context)) return content;
  final selected = Theme.of(context);
  return Theme(
    data: buildDaybreakTheme(
      selected.brightness,
      DaybreakScript.latin,
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
