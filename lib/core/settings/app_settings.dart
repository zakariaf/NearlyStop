/// The user's preferences, as a plain immutable value.
///
/// Pure Dart under `lib/core/`: **no drift types**. `themeMode`, `textScale`
/// and `highContrast` are read before the first frame, so they cross from the
/// database into the theme on the launch path, and a row class travelling that
/// far would put drift in `MaterialApp`'s argument list.
library;

import 'package:meta/meta.dart';

/// How the app chooses between the light and dark palettes.
enum AppThemeMode {
  /// Follow the operating system.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark;

  /// Parses a stored tag, falling back to [system] on anything unrecognised.
  ///
  /// Never throws: a preferences row is not worth a cold-start crash, and
  /// [system] is always a safe answer.
  static AppThemeMode fromTag(String tag) => values.firstWhere(
    (mode) => mode.name == tag,
    orElse: () => AppThemeMode.system,
  );
}

/// Everything the shell needs before it can paint.
@immutable
final class AppSettings {
  /// Creates a settings value.
  const AppSettings({
    required this.themeMode,
    required this.textScale,
    required this.highContrast,
    required this.reminderEnabled,
    this.localeTag,
    this.reminderMinuteOfDay,
    this.disclaimerAcceptedAt,
  });

  /// What a fresh install, and an unreadable database, both look like.
  ///
  /// Every value here is deliberately the safest one: follow the OS, do not
  /// scale, do not shout, do not remind, and **do not** count the disclaimer as
  /// accepted.
  static const AppSettings defaults = AppSettings(
    themeMode: AppThemeMode.system,
    textScale: 1,
    highContrast: false,
    reminderEnabled: false,
  );

  /// Light, dark, or follow the OS.
  final AppThemeMode themeMode;

  /// The chosen locale, or `null` to follow the OS.
  final String? localeTag;

  /// The app's own text-scale multiplier, on top of the OS setting.
  final double textScale;

  /// Whether the high-contrast palette is selected.
  final bool highContrast;

  /// Whether the daily reminder is on.
  final bool reminderEnabled;

  /// Minutes since **local** midnight. A reminder is a wall-clock time.
  final int? reminderMinuteOfDay;

  /// When the disclaimer was accepted. `null` gates the whole app.
  final DateTime? disclaimerAcceptedAt;

  /// Whether the disclaimer gate has been passed.
  bool get hasAcceptedDisclaimer => disclaimerAcceptedAt != null;

  /// A copy with the named fields replaced.
  ///
  /// The nullable fields take a sentinel rather than `null`, so "clear the
  /// locale override" and "leave the locale alone" are different calls.
  AppSettings copyWith({
    AppThemeMode? themeMode,
    Object? localeTag = _unchanged,
    double? textScale,
    bool? highContrast,
    bool? reminderEnabled,
    Object? reminderMinuteOfDay = _unchanged,
    Object? disclaimerAcceptedAt = _unchanged,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    localeTag: identical(localeTag, _unchanged)
        ? this.localeTag
        : localeTag as String?,
    textScale: textScale ?? this.textScale,
    highContrast: highContrast ?? this.highContrast,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinuteOfDay: identical(reminderMinuteOfDay, _unchanged)
        ? this.reminderMinuteOfDay
        : reminderMinuteOfDay as int?,
    disclaimerAcceptedAt: identical(disclaimerAcceptedAt, _unchanged)
        ? this.disclaimerAcceptedAt
        : disclaimerAcceptedAt as DateTime?,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.localeTag == localeTag &&
      other.textScale == textScale &&
      other.highContrast == highContrast &&
      other.reminderEnabled == reminderEnabled &&
      other.reminderMinuteOfDay == reminderMinuteOfDay &&
      other.disclaimerAcceptedAt == disclaimerAcceptedAt;

  @override
  int get hashCode => Object.hash(
    themeMode,
    localeTag,
    textScale,
    highContrast,
    reminderEnabled,
    reminderMinuteOfDay,
    disclaimerAcceptedAt,
  );

  @override
  String toString() =>
      'AppSettings(themeMode: $themeMode, localeTag: $localeTag, '
      'textScale: $textScale, highContrast: $highContrast, '
      'reminderEnabled: $reminderEnabled, '
      'reminderMinuteOfDay: $reminderMinuteOfDay, '
      'disclaimerAcceptedAt: $disclaimerAcceptedAt)';
}

/// Distinguishes "not passed" from "passed null" in [AppSettings.copyWith].
const Object _unchanged = Object();
