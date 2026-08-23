/// Reads and writes the single settings row.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/data/db/app_database.dart' as db;
import 'package:nearlystop/data/storage_failure.dart';
import 'package:ulid/ulid.dart';

/// The user's stored preferences.
///
/// A plain value type, not a drift row: `textScale`, `highContrast`,
/// `themeMode` and `localeTag` are read **before first paint**, so the shape
/// the bootstrap sees must not depend on the data layer.
@immutable
final class AppSettings {
  /// Creates a settings value.
  const AppSettings({
    required this.reminderEnabled,
    required this.reminderMinuteOfDay,
    required this.textScale,
    required this.highContrast,
    required this.disclaimerAcceptedAt,
    required this.localeTag,
    required this.themeMode,
  });

  /// The defaults a fresh install starts from.
  static const AppSettings defaults = AppSettings(
    reminderEnabled: false,
    reminderMinuteOfDay: null,
    textScale: 1,
    highContrast: false,
    disclaimerAcceptedAt: null,
    localeTag: null,
    themeMode: 'system',
  );

  /// Whether the daily reminder is on.
  final bool reminderEnabled;

  /// Minutes since **local** midnight. A reminder is a wall-clock time.
  final int? reminderMinuteOfDay;

  /// The user's text-scale preference, on top of the OS setting.
  final double textScale;

  /// Whether the high-contrast palette is selected.
  final bool highContrast;

  /// When the disclaimer was accepted, in UTC.
  final DateTime? disclaimerAcceptedAt;

  /// The chosen locale tag, or `null` to follow the OS.
  final String? localeTag;

  /// `system`, `light` or `dark`.
  final String themeMode;

  /// Whether the first-run disclaimer has been accepted.
  bool get hasAcceptedDisclaimer => disclaimerAcceptedAt != null;

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.reminderEnabled == reminderEnabled &&
      other.reminderMinuteOfDay == reminderMinuteOfDay &&
      other.textScale == textScale &&
      other.highContrast == highContrast &&
      other.disclaimerAcceptedAt == disclaimerAcceptedAt &&
      other.localeTag == localeTag &&
      other.themeMode == themeMode;

  @override
  int get hashCode => Object.hash(
    reminderEnabled,
    reminderMinuteOfDay,
    textScale,
    highContrast,
    disclaimerAcceptedAt,
    localeTag,
    themeMode,
  );
}

/// The one object the rest of the app talks to about settings.
final class SettingsRepository {
  /// Creates the repository over [_db], reading "now" from [_clock].
  SettingsRepository(this._db, this._clock);

  final db.AppDatabase _db;
  final Clock _clock;

  /// Creates the defaults row if it is not there. Idempotent.
  Future<Result<void, StorageFailure>> ensureExists() =>
      _write(() => _db.settingsDao.ensureRowExists(Ulid().toString()));

  /// The settings, re-emitted on every write.
  ///
  /// Falls back to [AppSettings.defaults] on a read error rather than
  /// propagating it. These are **preferences**: an unreadable text-scale is a
  /// cosmetic loss, and every default here is safe. The taper itself goes
  /// through `TaperRepository`, which types its failures instead — losing a
  /// dose log silently would be the opposite call.
  Stream<AppSettings> watchSettings() => _db.settingsDao
      .watchSettings()
      .map((row) => row == null ? AppSettings.defaults : _from(row))
      .handleError((_) {});

  /// The settings, read once — the pre-first-paint path.
  ///
  /// **Cannot throw.** `bootstrap()` awaits this before the first frame, so an
  /// exception here is a cold-start crash on a device holding the user's only
  /// copy of their taper. A corrupt preferences row costs them a theme; it must
  /// not cost them the app.
  Future<AppSettings> readOnce() async {
    try {
      final row = await _db.settingsDao.readSettingsOnce();
      return row == null ? AppSettings.defaults : _from(row);
    } on Object {
      return AppSettings.defaults;
    }
  }

  /// Turns the daily reminder on or off.
  Future<Result<void, StorageFailure>> setReminderEnabled({
    required bool enabled,
  }) => _patch(db.SettingsRowsCompanion(reminderEnabled: Value<bool>(enabled)));

  /// Sets the reminder time, in minutes since local midnight.
  Future<Result<void, StorageFailure>> setReminderMinuteOfDay(int? minute) =>
      _patch(
        db.SettingsRowsCompanion(reminderMinuteOfDay: Value<int?>(minute)),
      );

  /// Sets the user's text-scale preference.
  Future<Result<void, StorageFailure>> setTextScale(double scale) =>
      _patch(db.SettingsRowsCompanion(textScale: Value<double>(scale)));

  /// Selects or deselects the high-contrast palette.
  Future<Result<void, StorageFailure>> setHighContrast({
    required bool enabled,
  }) => _patch(db.SettingsRowsCompanion(highContrast: Value<bool>(enabled)));

  /// Records that the disclaimer was read, at the injected clock's instant.
  Future<Result<void, StorageFailure>> acceptDisclaimer() => _patch(
    db.SettingsRowsCompanion(
      disclaimerAcceptedAt: Value<DateTime?>(_clock.now()),
    ),
  );

  /// Sets the chosen locale, or `null` to follow the OS.
  Future<Result<void, StorageFailure>> setLocaleTag(String? tag) =>
      _patch(db.SettingsRowsCompanion(localeTag: Value<String?>(tag)));

  /// Sets `system`, `light` or `dark`.
  Future<Result<void, StorageFailure>> setThemeMode(String mode) =>
      _patch(db.SettingsRowsCompanion(themeMode: Value<String>(mode)));

  AppSettings _from(db.SettingsRow row) => AppSettings(
    reminderEnabled: row.reminderEnabled,
    reminderMinuteOfDay: row.reminderMinuteOfDay,
    textScale: row.textScale,
    highContrast: row.highContrast,
    disclaimerAcceptedAt: row.disclaimerAcceptedAt,
    localeTag: row.localeTag,
    themeMode: row.themeMode,
  );

  Future<Result<void, StorageFailure>> _patch(
    db.SettingsRowsCompanion patch,
  ) => _write(() async {
    await _db.settingsDao.ensureRowExists(Ulid().toString());
    await _db.settingsDao.updateSettings(patch);
  });

  Future<Result<void, StorageFailure>> _write(
    Future<void> Function() body,
  ) async {
    try {
      await _db.transaction(body);
      return const Ok(null);
    } on Object catch (error) {
      // The same mapper the taper repository uses. Returning `Io` for
      // everything made three of the five arms unreachable, so a constraint
      // failure and a full disk were indistinguishable to the caller.
      return Err(storageFailureFrom(error));
    }
  }
}
