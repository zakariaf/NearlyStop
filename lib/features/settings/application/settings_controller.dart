/// Settings as live app state.
library;

import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/providers.dart';
import 'package:riverpod/riverpod.dart';

/// The app's **one** settings controller.
///
/// `Notifier`, deliberately **not** `StreamNotifier`. A `StreamNotifier`'s
/// state starts as `AsyncLoading`, and drift's `.watch()` never emits
/// synchronously — so frame one would have no settings, `requireValue` would
/// throw, and the no-flash promise would fail on its own acceptance test.
///
/// Instead `build()` returns the bootstrap value **synchronously**: frame one
/// comes from the row the launch already read, and the stream only pushes
/// later changes.
///
/// Mutators write through the repository and return a [Result]; the stream is
/// the source of truth. Nothing is mutated optimistically and reconciled — a
/// setting that flickers to the new value and back is worse than one that takes
/// a frame to arrive, especially for a reader who is unsure whether they
/// tapped.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final bootstrapped = ref.watch(bootstrapSettingsProvider);
    try {
      final subscription = ref
          .watch(settingsRepositoryProvider)
          .watchSettings()
          .listen((settings) => state = settings);
      ref.onDispose(subscription.cancel);
    } on Object {
      // No database to watch — a launch that could not open one, or a test
      // that supplies settings without a repository. `databaseProvider` throws
      // by design rather than opening one silently, and letting that
      // propagate here would take the whole app down over a preference.
      //
      // The user still gets their settings: `bootstrapped` is the row the
      // launch already read, or the defaults it fell back to. What they lose
      // is later CHANGES arriving, which is exactly the right thing to lose.
    }
    return bootstrapped;
  }

  /// Turns the daily reminder on or off.
  Future<Result<void, StorageFailure>> setReminderEnabled({
    required bool enabled,
  }) =>
      ref.read(settingsRepositoryProvider).setReminderEnabled(enabled: enabled);

  /// Sets the reminder's wall-clock time, or `null` to clear it.
  Future<Result<void, StorageFailure>> setReminderMinuteOfDay(int? minute) =>
      ref.read(settingsRepositoryProvider).setReminderMinuteOfDay(minute);

  /// Sets the app's own text-scale multiplier.
  Future<Result<void, StorageFailure>> setTextScale(double scale) =>
      ref.read(settingsRepositoryProvider).setTextScale(scale);

  /// Turns the high-contrast palette on or off.
  Future<Result<void, StorageFailure>> setHighContrast({
    required bool enabled,
  }) => ref.read(settingsRepositoryProvider).setHighContrast(enabled: enabled);

  /// Records that the disclaimer was read. This is what opens the gate.
  Future<Result<void, StorageFailure>> acceptDisclaimer() =>
      ref.read(settingsRepositoryProvider).acceptDisclaimer();

  /// Sets the chosen locale, or `null` to follow the OS.
  Future<Result<void, StorageFailure>> setLocaleTag(String? tag) =>
      ref.read(settingsRepositoryProvider).setLocaleTag(tag);

  /// Sets light, dark, or follow-the-OS.
  Future<Result<void, StorageFailure>> setThemeMode(AppThemeMode mode) =>
      ref.read(settingsRepositoryProvider).setThemeMode(mode.name);
}

/// The one settings controller. EPIC-11 adds mutators here, never a second
/// class: two owners of `themeMode` is two sources of truth for the theme.
final NotifierProvider<SettingsController, AppSettings>
settingsControllerProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
