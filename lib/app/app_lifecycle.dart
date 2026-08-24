/// The app's resume hook for the reminder engine.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/services/notifications/reconcile_triggers.dart';

/// Runs the reconcile every time the app comes to the front.
///
/// **The reliability backbone.** With no server there is no way to learn that
/// the OS dropped a reminder, that a reboot lost one, or that the reader
/// revoked notification permission in system settings — except by looking
/// again the next time they open the app. Everything else in this engine is
/// best-effort; this is the part that repairs it.
///
/// A second `AppLifecycleListener` alongside `DayTicker`'s, on purpose: they
/// watch the same signal for disjoint reasons, and folding the reminder
/// reconcile into the date ticker would make one class own two unrelated
/// recoveries.
class NotificationLifecycle with WidgetsBindingObserver {
  /// Starts observing.
  NotificationLifecycle(this._ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;
  bool _observing = true;

  /// **The raw observer callback, not `AppLifecycleListener`.** That class
  /// derives `onResume` from a state machine, and a platform that jumps
  /// straight from `paused` to `resumed` produces no `onResume` at all — which
  /// is exactly what the test binding does, and what some embedders do. The
  /// state itself always arrives.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_ref.read(reconcileTriggersProvider).onResume());
  }

  /// Stops observing. A leaked observer keeps a disposed container's providers
  /// reachable, and the next resume runs against them.
  void dispose() {
    if (!_observing) return;
    WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }
}

/// The observer for this container.
final Provider<NotificationLifecycle> notificationLifecycleProvider =
    Provider<NotificationLifecycle>((ref) {
      // Kept alive for the same reason the triggers are: bootstrap reads this
      // once and holds nothing, and a disposed observer observes nothing.
      ref.keepAlive();
      final observer = NotificationLifecycle(ref);
      ref.onDispose(observer.dispose);
      return observer;
    });
