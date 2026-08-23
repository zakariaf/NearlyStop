/// App-wide providers that must not live under `lib/core/`.
///
/// `lib/core/` may not import Riverpod (`tool/check_core_purity.sh` enforces
/// it), so the provider half of every pure seam lives here instead.
library;

import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/core/time/clock.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:riverpod/riverpod.dart';

/// The app's single time source.
///
/// Override with `clockProvider.overrideWithValue(Clock.fixed(instant))` in a
/// test; never read `DateTime.now()` directly — `tool/check_bans.sh` fails the
/// build on it outside `lib/core/time/clock.dart`.
final Provider<Clock> clockProvider = Provider<Clock>((ref) => systemClock);

/// The settings read **before the first frame**, overridden at bootstrap.
///
/// Throws by default, like `databaseProvider`: a default value here would let a
/// screen render the wrong theme and never notice, which is precisely the flash
/// the whole launch order exists to prevent.
final Provider<AppSettings> bootstrapSettingsProvider = Provider<AppSettings>((
  ref,
) {
  throw UnimplementedError(
    'bootstrapSettingsProvider must be overridden at the composition root with '
    'the settings read before runApp (bootstrap) or a test value.',
  );
});

/// Why the launch could not read the settings, or `null` if it could.
///
/// The app still comes up — on defaults — because a person 400 days into a
/// taper needs the app to open far more than they need it to be right about
/// their theme. The shell surfaces this as a persistent banner.
///
/// A **typed** failure, not the raw exception: a consumer has to be able to
/// switch on it exhaustively and localize from a stable code, and a drift or
/// sqlite type crossing out of `lib/data/` is the leak the data layer's own
/// boundary test exists to prevent.
final Provider<StorageFailure?> bootstrapErrorProvider =
    Provider<StorageFailure?>((ref) => null);
