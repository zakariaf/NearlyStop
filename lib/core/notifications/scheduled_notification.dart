/// One notification the app wants armed.
library;

import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart' as tz;

/// The channel every daily reminder is posted on.
const String kDailyReminderChannelId = 'daily_reminder';

/// The payload a tap carries. Serializable, and it names a ROUTE, not a dose.
const String kTodayPayload = 'today';

/// A notification, resolved and ready to hand to the gateway.
///
/// **There is no dose field and no drug field, deliberately.** A lock-screen
/// preview reading "Prednisolone 9mg" tells anyone holding the phone that its
/// owner has a chronic illness (SPEC §11.4). Making that impossible by
/// construction is stronger than remembering not to do it.
@immutable
class ScheduledNotification {
  /// Creates a resolved notification.
  const ScheduledNotification({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.payload,
    required this.channelId,
    this.repeatsDaily = true,
  });

  /// The gateway's handle. Stable across days — see `deterministicId`.
  final int id;

  /// The FIRST instant it fires, in the plan's own zone.
  ///
  /// Only the first: with [repeatsDaily] the platform repeats it at the same
  /// wall clock thereafter, which is what keeps 08:00 at 08:00 across a DST
  /// boundary without the app being open to recompute anything.
  final tz.TZDateTime fireAt;

  /// The heading. Never an instruction — the app arranges, it does not tell
  /// anybody to swallow something.
  final String title;

  /// The sentence beneath it. No number, no drug name, no tablet count.
  final String body;

  /// What a tap carries back. A route name, and nothing reconstructible.
  final String payload;

  /// Which channel it posts on.
  final String channelId;

  /// Whether the platform repeats it daily at the same wall clock.
  final bool repeatsDaily;

  @override
  bool operator ==(Object other) =>
      other is ScheduledNotification &&
      other.id == id &&
      other.fireAt == fireAt &&
      other.title == title &&
      other.body == body &&
      other.payload == payload &&
      other.channelId == channelId &&
      other.repeatsDaily == repeatsDaily;

  @override
  int get hashCode =>
      Object.hash(id, fireAt, title, body, payload, channelId, repeatsDaily);

  @override
  String toString() =>
      'ScheduledNotification($id at $fireAt, repeats: $repeatsDaily)';
}

/// The words a notification carries, already localized.
///
/// Snapshotted at reconcile time and passed INTO the pure scheduler, so the
/// scheduler stays free of Flutter and of `AppLocalizations`.
@immutable
class NotificationCopy {
  /// Creates the copy.
  const NotificationCopy({required this.title, required this.body});

  /// The heading.
  final String title;

  /// The sentence beneath it.
  final String body;

  @override
  bool operator ==(Object other) =>
      other is NotificationCopy && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}
