/// Every place the reconcile runs, and nowhere else.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/core/notifications/reminder_scheduler.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_providers.dart';
import 'package:nearlystop/services/notifications/sync_notifications.dart';

/// Whether the OS is refusing to post, while the reader still wants a reminder.
///
/// Written by the resume check, read by the Settings row. A `Notifier` rather
/// than a value the row derives, because the row cannot ask the OS itself —
/// only the resume path has a reason to, and only it should pay for the call.
final NotifierProvider<NotificationsBlockedNotifier, bool>
notificationsBlockedProvider =
    NotifierProvider<NotificationsBlockedNotifier, bool>(
      NotificationsBlockedNotifier.new,
    );

/// Holds "the OS says no".
class NotificationsBlockedNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Riverpod 3 disposes a provider the moment nothing listens, and this one
    // is WRITTEN from the resume path — which runs whether or not the Settings
    // screen is on show. Without this the write lands on an element that is
    // discarded before anybody reads it, and the row never learns the OS said
    // no.
    ref.keepAlive();
    return false;
  }

  /// Records what the OS last said.
  // ignore: use_setters_to_change_properties
  void set({required bool blocked}) => state = blocked;
}

/// The triggers, as one object with one run counter.
///
/// A class rather than loose functions so a test can count runs without
/// wrapping `syncNotifications` — and so every subscription this creates has
/// exactly one place to be closed.
class ReconcileTriggers {
  /// Creates the triggers over [_ref].
  ReconcileTriggers(this._ref);

  final Ref _ref;

  int _runCount = 0;

  /// How many reconciles have run since the last [resetRunCount].
  int get runCount => _runCount;

  /// Forgets the count. Tests assert on writes across a second run.
  void resetRunCount() => _runCount = 0;

  /// Runs the reconcile once.
  Future<Result<void, ReminderFailure>> run() {
    _runCount++;
    return _ref.read(reconcileNotificationsProvider)();
  }

  /// The resume path: ask the OS first, then reconcile.
  ///
  /// **Permission before pending.** A grant is not permanent — iOS and Android
  /// both let it be revoked at any time — and in that state `zonedSchedule`
  /// still succeeds and `pendingIds` still returns the entry. A reconcile that
  /// only diffed ids would be perfectly happy while nothing ever fired, and
  /// the Settings row would read "On · 8:00 am" for ever.
  ///
  /// The stored setting is **kept**: the reader's intent has not changed, and
  /// clearing it would mean re-allowing notifications in the OS silently does
  /// nothing because the app forgot they ever wanted one.
  Future<void> onResume() async {
    final gateway = _ref.read(notificationGatewayProvider);
    final permission = await gateway.checkPermission();
    final wanted = _ref.read(settingsControllerProvider).reminderEnabled;
    _ref
        .read(notificationsBlockedProvider.notifier)
        .set(blocked: wanted && permission != PermissionState.granted);
    await run();
  }
}

/// The triggers for this container.
///
/// **The listeners are registered in the BODY**, because `Ref.listen` is only
/// valid during build — registering them afterwards from the object silently
/// does nothing, and the whole trigger system looks wired while no reconcile
/// ever runs.
final Provider<ReconcileTriggers> reconcileTriggersProvider =
    Provider<ReconcileTriggers>((ref) {
      // Kept alive, and this is load-bearing. Bootstrap reads this once; with
      // nothing holding the provider, Riverpod 3 disposes it in the same
      // microtask and takes every listener below with it.
      ref.keepAlive();
      final triggers = ReconcileTriggers(ref);

      // The reminder's two fields, never the whole `AppSettings`. Without the
      // `select` every text-scale drag and every contrast toggle cancels and
      // re-arms a perfectly good alarm — through a window where a process
      // death leaves nothing armed.
      ref
        ..listen<(bool, int?)>(
          settingsControllerProvider.select(
            (s) => (s.reminderEnabled, s.reminderMinuteOfDay),
          ),
          (_, _) => unawaited(triggers.run()),
        )
        // The body is part of the deterministic id, so a language switch
        // leaves an armed notification in the old language until something
        // re-arms it.
        ..listen<NotificationCopy>(
          notificationCopyProvider,
          (_, _) => unawaited(triggers.run()),
        );

      return triggers;
    });
