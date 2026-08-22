/// The time seam. Every "now" in the app comes from here.
///
/// Imports `package:clock` and nothing else — no Flutter, no Riverpod — so
/// `lib/core/` stays pure and unit-testable without a widget harness. The
/// Riverpod side of the seam is `clockProvider` in `lib/providers.dart`,
/// deliberately outside this tree.
///
/// Tests pin time with `withClock(Clock.fixed(t), ...)` for ambient callers, or
/// `clockProvider.overrideWithValue(Clock.fixed(t))` for provider callers. A
/// plan runs for ~780 calendar days across DST boundaries, so a day index is
/// always derived from calendar dates, never from elapsed seconds.
library;

import 'package:clock/clock.dart';

export 'package:clock/clock.dart' show Clock;

/// The wall clock, used everywhere except tests.
///
/// `clockProvider` returns this unless a test overrides it.
const Clock systemClock = Clock();
