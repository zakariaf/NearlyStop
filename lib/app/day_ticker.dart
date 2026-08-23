/// Midnight rollover, and the two clock edge cases `SPEC.md` §7 names.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/providers.dart';
import 'package:riverpod/riverpod.dart';

/// Invalidates "today" at local midnight, and on resume.
///
/// **Two edge cases, one owner.** A 780-day taper is opened every morning, so
/// the app is often already running when the date changes — a timer to the next
/// local midnight covers that. And a phone that was asleep across midnight, or
/// that flew to Sydney, comes back through the resume hook — and a timer
/// alone never fires for either.
///
/// The interval is computed with the **local** `DateTime` constructor on
/// purpose: a DST-shortened day is 23 hours, and `Duration(hours: 24)` would
/// land an hour late on the one morning of the year that already confuses
/// everyone.
///
/// **A time-zone change moves which day is today; it never moves which dose
/// belongs to a day.** Dates are stored as dates (EPIC-05), so the schedule is
/// invariant under travel — only the pointer into it moves. That distinction is
/// the whole reason this class is small.
///
/// **The locale hook is NOT here.** `_NearlyStopAppState.didChangeLocales`
/// owns it, because the disclaimer gate is a top-level route outside the shell
/// and the root widget is the only observer that exists on first run. So there
/// are two `WidgetsBindingObserver`s in the tree — this one's
/// `AppLifecycleListener` and the root widget — and they watch disjoint
/// signals: resume here, locale there.
///
/// It lives in `lib/app/` rather than `lib/core/` because it invalidates a
/// Riverpod provider, and `lib/core/` may not import Riverpod.
class DayTicker {
  /// Starts ticking against the container's clock.
  DayTicker(this._ref) {
    _schedule();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  final Ref _ref;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  /// How long until the next local midnight.
  ///
  /// Exposed so the DST case can be asserted directly rather than inferred
  /// from when a timer happened to fire.
  Duration get untilNextMidnight {
    final now = _ref.read(clockProvider).now();
    return DateTime(now.year, now.month, now.day + 1).difference(now);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(untilNextMidnight, _onMidnight);
  }

  void _onMidnight() {
    _ref.invalidate(todayDateProvider);
    // Rescheduled from the new "now", not by adding 24 hours: the latter
    // accumulates drift and lands an hour off after a DST boundary.
    _schedule();
  }

  void _onResume() {
    // The phone was asleep, or the user travelled. Recompute rather than trust
    // a timer that may have been suspended for hours.
    _ref.invalidate(todayDateProvider);
    _schedule();
  }

  /// Cancels the timer and stops observing. A leaked timer is the "Timer still
  /// pending" failure that poisons the next test.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

/// The app's one day ticker, disposed with the container.
///
/// **Autodispose is deliberately NOT used.** The ticker must keep running while
/// the app is up even if nothing is currently watching `todayDateProvider` —
/// the whole point is to be ready when the date turns.
final Provider<DayTicker> dayTickerProvider = Provider<DayTicker>((ref) {
  final ticker = DayTicker(ref);
  ref.onDispose(ticker.dispose);
  return ticker;
});
