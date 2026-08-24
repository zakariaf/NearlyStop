// The launch order the whole reminder engine rests on.
//
// `package:timezone` defaults to UTC. Skip `setLocalLocation` and every
// reminder fires at the wrong local hour — for somebody in Tehran, at 03:30 in
// the morning. The failure is silent: `zonedSchedule` succeeds, `pendingIds`
// returns the entry, and the app looks correct.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/services/notifications/notification_startup.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('the device’s zone becomes tz.local', () async {
    await initializeNotificationTimeZone(
      readDeviceZone: () async => 'Asia/Tehran',
    );

    expect(tz.local.name, 'Asia/Tehran');
  });

  test('an unknown zone name falls back to UTC rather than throwing', () async {
    // A device can report a zone the bundled IANA database does not have — an
    // OS newer than the `timezone` package. Throwing here is a black screen
    // before the first frame, on the one path that has no error UI at all.
    await initializeNotificationTimeZone(
      readDeviceZone: () async => 'Mars/Olympus_Mons',
    );

    expect(tz.local.name, tz.UTC.name);
  });

  test('a platform that cannot answer falls back to UTC too', () async {
    await initializeNotificationTimeZone(
      readDeviceZone: () async => throw Exception('no platform channel'),
    );

    expect(tz.local.name, tz.UTC.name);
  });

  test('the database is initialised, not assumed', () async {
    // `tz.getLocation` before `initializeTimeZones()` throws. Calling the
    // initializer here rather than relying on somebody else having done it is
    // what makes this function safe to call first.
    await initializeNotificationTimeZone(
      readDeviceZone: () async => 'Europe/Berlin',
    );

    expect(tz.getLocation('Europe/Berlin').name, 'Europe/Berlin');
  });

  tearDownAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });
}
