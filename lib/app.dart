import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';

/// The root widget.
///
/// EPIC-03 attaches the localization delegates and the locale → script mapping;
/// EPIC-06 replaces this with `MaterialApp.router` and makes `themeMode` a
/// setting.
class NearlyStopApp extends StatelessWidget {
  /// Creates the root widget.
  const NearlyStopApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The script is hard-coded to Latin until EPIC-03 resolves it from the
    // locale; high contrast is hard-coded off until EPIC-11 ships the toggle.
    // Both arguments are passed explicitly so the seams are visible.
    return MaterialApp(
      title: 'NearlyStop',
      theme: buildDaybreakTheme(Brightness.light, DaybreakScript.latin),
      darkTheme: buildDaybreakTheme(Brightness.dark, DaybreakScript.latin),
      // themeMode defaults to ThemeMode.system; EPIC-06 makes it a setting.
      // Material cross-fades ThemeData over kThemeAnimationDuration by default.
      // At 6am on a bedside table that is a luminance jolt nobody asked for.
      themeAnimationStyle: AnimationStyle.noAnimation,
      home: const _ThemePlaceholder(),
    );
  }
}

/// A placeholder until EPIC-06 wires the router and the five real screens.
class _ThemePlaceholder extends StatelessWidget {
  const _ThemePlaceholder();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
