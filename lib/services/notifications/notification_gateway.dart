/// The seam between this app and the OS notification service.
library;

import 'package:nearlystop/core/notifications/scheduled_notification.dart';

/// Whether the OS will actually post what we arm.
///
/// Not a `bool`. "Not yet asked" and "asked and refused" call for completely
/// different behaviour — one is a prompt, the other is an explanation — and a
/// nullable bool makes them two spellings that every call site has to remember
/// to tell apart.
enum PermissionState {
  /// The OS will post notifications.
  granted,

  /// The OS will not. Either refused, or revoked after having been granted.
  denied,

  /// Nobody has asked yet.
  notDetermined,
}

/// Something the platform refused.
///
/// Thrown by the gateway and caught at the reconcile, which turns it into a
/// `Result`. The port throws rather than returning a `Result` because the
/// plugin throws: a translation layer that swallowed it would be inventing a
/// success the OS never gave.
class NotificationGatewayException implements Exception {
  /// Creates the exception.
  const NotificationGatewayException(this.message);

  /// What the platform said.
  final String message;

  @override
  String toString() => 'NotificationGatewayException: $message';
}

/// Five methods, and nothing else.
///
/// Anything more is scheduling logic, and scheduling logic belongs in
/// `ReminderScheduler` where it can be tested without a device. Every test in
/// this app talks to `FakeNotificationGateway` through this port; exactly one
/// file implements it against the real plugin.
abstract interface class NotificationGateway {
  /// Arms [notification]. An id that is already armed is REPLACED.
  Future<void> schedule(ScheduledNotification notification);

  /// Disarms [id]. An id that is not armed is not an error — the OS may have
  /// fired it between the read and this call.
  Future<void> cancel(int id);

  /// Disarms everything. Used after a restore, where every pending id came
  /// from another device and means nothing here.
  Future<void> cancelAll();

  /// The ids armed right now.
  ///
  /// **Ids, and nothing else.** That is all the platform gives back:
  /// `pendingNotificationRequests()` carries `id`, `title`, `body` and
  /// `payload` — no fire time. Returning whole notifications here would mean
  /// the real adapter inventing a `fireAt` it cannot know, and the reconcile
  /// silently diffing against a fiction. It is also the reason the id has to
  /// fold everything the diff depends on: nothing else survives the round trip.
  Future<Set<int>> pendingIds();

  /// Whether the OS will post. A platform QUERY, not scheduler logic — and
  /// without it nothing in the app can ever discover that a grant was revoked.
  Future<PermissionState> checkPermission();

  /// Asks the OS. Called only when the reader turns the reminder on, which is
  /// the one moment the request explains itself.
  Future<PermissionState> requestPermission();
}
