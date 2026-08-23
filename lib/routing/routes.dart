/// Every route path in the app, in one place.
///
/// **No route string literal exists anywhere else** — `tool/check_bans.sh`
/// enforces it. A `'/today'` typed into a screen is a navigation that compiles,
/// runs, and silently goes nowhere; here a typo is a name that does not
/// resolve.
library;

/// The app's route paths.
abstract final class Routes {
  /// The disclaimer gate. Outside the shell, and not dismissible until
  /// accepted.
  static const String welcome = '/welcome';

  /// Today's dose. The app's home, and where every launch lands.
  static const String today = '/today';

  /// The taper laid out in blocks. Never a seven-column calendar.
  static const String schedule = '/schedule';

  /// How far the taper has come.
  static const String progress = '/progress';

  /// The plan the patient and their doctor agreed.
  static const String plan = '/plan';

  /// App settings.
  static const String settings = '/settings';

  /// Re-reading the disclaimer, **dismissible**.
  ///
  /// A child of the Settings branch, so back returns to Settings and that tab
  /// keeps its stack. Deliberately not `/welcome?readOnly=true`: reusing the
  /// gate's own path would force its redirect to special-case a query
  /// parameter, which is how a gate develops a hole.
  static const String disclaimerReread = '/settings/disclaimer';

  /// The five destinations the shell's tab bar shows, in order.
  static const List<String> branches = <String>[
    today,
    schedule,
    progress,
    plan,
    settings,
  ];
}
