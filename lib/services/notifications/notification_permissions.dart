/// Asking at the right moment, and degrading honestly when refused.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_providers.dart';
import 'package:nearlystop/services/notifications/reconcile_triggers.dart';
import 'package:nearlystop/services/notifications/reminder_failure.dart';

/// The hour a reminder defaults to when the reader has not chosen one.
///
/// SPEC §11.3's default, and the same value the time picker opens on. Turning
/// the switch on with no time stored would otherwise arm nothing and leave the
/// row reading "Off" beside an On switch.
const int kDefaultReminderMinuteOfDay = 8 * 60;

/// Turns the daily reminder on or off, asking the OS only when turning it on.
///
/// **Never on launch.** A permission prompt on first run is a prompt somebody
/// denies before they know what it is for, and on both platforms a denial is
/// hard to walk back. The moment the reader flips this switch is the one
/// moment the request explains itself.
///
/// A refusal returns [PermissionDenied] and **does not persist the setting**:
/// a stored `reminderEnabled: true` that the OS will not honour is a Settings
/// row reading "On · 8:00 am" for ever while nothing fires, which is the exact
/// failure this whole epic exists to prevent.
final Provider<
  Future<Result<void, ReminderFailure>> Function({
    required bool enabled,
  })
>
setReminderEnabledProvider =
    Provider<
      Future<Result<void, ReminderFailure>> Function({required bool enabled})
    >(
      (ref) =>
          ({required enabled}) => _setReminderEnabled(ref, enabled),
    );

Future<Result<void, ReminderFailure>> _setReminderEnabled(
  Ref ref,
  bool enabled,
) async {
  final blocked = ref.read(notificationsBlockedProvider.notifier);
  if (!enabled) {
    // Turning it OFF needs no permission and clears the warning: there is
    // nothing left for the OS to refuse.
    blocked.set(blocked: false);
    await ref
        .read(settingsControllerProvider.notifier)
        .setReminderEnabled(
          enabled: false,
        );
    return const Ok<void, ReminderFailure>(null);
  }

  final permission = await ref
      .read(notificationGatewayProvider)
      .requestPermission();
  if (permission != PermissionState.granted) {
    blocked.set(blocked: true);
    return const Err<void, ReminderFailure>(PermissionDenied());
  }

  blocked.set(blocked: false);
  final controller = ref.read(settingsControllerProvider.notifier);
  // A time BEFORE the switch, so the reconcile the switch triggers has one to
  // arm. The other order turns the reminder on, computes "no time set", arms
  // nothing, and leaves the row reading "Off" beside an On switch.
  if (ref.read(settingsControllerProvider).reminderMinuteOfDay == null) {
    await controller.setReminderMinuteOfDay(kDefaultReminderMinuteOfDay);
  }
  await controller.setReminderEnabled(enabled: true);
  return const Ok<void, ReminderFailure>(null);
}
