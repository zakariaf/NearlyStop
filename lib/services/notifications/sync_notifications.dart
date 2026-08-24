/// The one path from "what should be armed" to "what is armed".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/core/notifications/reminder_scheduler.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/providers.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_providers.dart';
import 'package:nearlystop/services/notifications/reminder_failure.dart';

export 'package:nearlystop/services/notifications/reminder_failure.dart';

/// Runs the reconcile from anywhere that can read a provider.
///
/// A provider rather than a bare function so a test can drive it through a
/// `ProviderContainer` with no widget pumped, and so every production trigger
/// — bootstrap, resume, a settings change, a locale change, a restore — reaches
/// exactly the same code path the tests do.
final Provider<Future<Result<void, ReminderFailure>> Function()>
reconcileNotificationsProvider =
    Provider<Future<Result<void, ReminderFailure>> Function()>(
      (ref) =>
          () => syncNotifications(ref),
    );

/// Brings the OS pending set in line with what the database says.
///
/// **The only caller of `schedule`/`cancel` in the app** —
/// `tool/check-adhoc-schedule-calls.sh` fails the build on any other. That is
/// what makes it idempotent: it diffs a set it computed against a set it read,
/// so running it twice with unchanged inputs performs no writes at all, and
/// running it on every resume is free.
///
/// Safe to call repeatedly and safe to call after a failure: a refusal leaves
/// the pending set part-way, and the next run converges it.
Future<Result<void, ReminderFailure>> syncNotifications(Ref ref) async {
  final gateway = ref.read(notificationGatewayProvider);

  final facts = await ref.read(taperFactsReaderProvider)();
  // An unreadable database is not a reason to cancel somebody's reminder.
  // Leave the pending set alone and let the next run decide.
  if (facts == null) return const Ok<void, ReminderFailure>(null);

  final desired = ReminderScheduler.compute(
    settings: ref.read(settingsControllerProvider),
    taperActive: taperActive(facts),
    zone: ref.read(notificationZoneProvider),
    clock: ref.read(clockProvider),
    copy: ref.read(notificationCopyProvider),
  );
  final pending = await gateway.pendingIds();

  final byId = <int, ScheduledNotification>{
    for (final notification in desired) notification.id: notification,
  };

  try {
    // Cancel first. An id the app no longer wants is a notification that will
    // fire saying something the reader did not ask for; an id it wants and
    // has not armed yet has simply not arrived. The first is worse.
    for (final id in pending) {
      if (!byId.containsKey(id)) await gateway.cancel(id);
    }
    for (final MapEntry(key: id, value: notification) in byId.entries) {
      if (!pending.contains(id)) await gateway.schedule(notification);
    }
  } on NotificationGatewayException catch (error) {
    return Err(SchedulingRefused(error.message));
  }

  return const Ok<void, ReminderFailure>(null);
}
