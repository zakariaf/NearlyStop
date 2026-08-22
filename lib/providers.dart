/// App-wide providers that must not live under `lib/core/`.
///
/// `lib/core/` may not import Riverpod (`tool/check_core_purity.sh` enforces
/// it), so the provider half of every pure seam lives here instead.
library;

import 'package:nearlystop/core/time/clock.dart';
import 'package:riverpod/riverpod.dart';

/// The app's single time source.
///
/// Override with `clockProvider.overrideWithValue(Clock.fixed(instant))` in a
/// test; never read `DateTime.now()` directly — `tool/check_bans.sh` fails the
/// build on it outside `lib/core/time/clock.dart`.
final Provider<Clock> clockProvider = Provider<Clock>((ref) => systemClock);
