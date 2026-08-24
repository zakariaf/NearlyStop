/// What a notification tap means.
library;

import 'package:nearlystop/core/notifications/scheduled_notification.dart';
import 'package:nearlystop/routing/routes.dart';

/// The route [payload] names, or null when it names nothing this build knows.
///
/// **Null, not a fallback.** A notification restored from a backup, or armed
/// by an older version, can carry a payload this build has never heard of —
/// and navigating on a guess is worse than staying where the reader was.
///
/// The payload is a route name and nothing else. Anything reconstructible from
/// it would be state living outside the database, which is the only source of
/// truth this app has: the screen reads what it needs after the route resolves.
String? payloadToRoute(String? payload) => switch (payload) {
  kTodayPayload => Routes.today,
  _ => null,
};
