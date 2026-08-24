/// Everything the reminder engine needs before the first frame.
library;

import 'package:nearlystop/services/notifications/fln_notification_gateway.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Loads the IANA database and points `tz.local` at the device's own zone.
///
/// **`package:timezone` defaults to UTC.** Skip this and every reminder fires
/// at the wrong local hour — 03:30 in the morning for somebody in Tehran — and
/// nothing anywhere reports it: `zonedSchedule` succeeds, `pendingIds` returns
/// the entry, and the app looks correct.
///
/// **Falls back to UTC rather than throwing.** A device can report a zone the
/// bundled database does not have (an OS newer than the package), and the
/// platform channel can fail outright. This runs before the first frame, on
/// the one path with no error UI at all, so the answer is a wrong-by-an-hour
/// reminder rather than a black screen.
Future<void> initializeNotificationTimeZone({
  Future<String> Function() readDeviceZone = deviceTimeZoneName,
}) async {
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation(await readDeviceZone()));
  } on Object {
    tz.setLocalLocation(tz.UTC);
  }
}
