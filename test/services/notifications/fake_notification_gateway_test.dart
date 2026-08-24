// The fake is what every other test in this epic trusts, so its semantics get
// asserted rather than assumed.
//
// The one that matters most is "schedule with an existing id REPLACES it":
// that is the plugin's real behaviour, and the whole reconcile diff is built
// on it. A fake that appended instead would make the reconcile look correct
// here and duplicate every reminder on a phone.
import 'package:nearlystop/core/notifications/reminder_scheduler.dart';
import 'package:nearlystop/services/notifications/fake_notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location berlin;

  setUpAll(() {
    tzdata.initializeTimeZones();
    berlin = tz.getLocation('Europe/Berlin');
  });

  ScheduledNotification entry({int id = 1, int hour = 8, String body = 'b'}) =>
      ScheduledNotification(
        id: id,
        fireAt: tz.TZDateTime(berlin, 2025, 4, 16, hour),
        title: 't',
        body: body,
        payload: kTodayPayload,
        channelId: kDailyReminderChannelId,
      );

  test('what goes in comes back out', () async {
    final gateway = FakeNotificationGateway();

    await gateway.schedule(entry());

    expect(gateway.pending, <ScheduledNotification>[entry()]);
    expect(await gateway.pendingIds(), <int>{1});
  });

  test('an existing id is REPLACED, never appended', () async {
    final gateway = FakeNotificationGateway();

    await gateway.schedule(entry());
    await gateway.schedule(entry(hour: 14));

    expect(gateway.pending, hasLength(1));
    expect(gateway.pending.single.fireAt.hour, 14);
  });

  test('cancel takes one, cancelAll takes the rest', () async {
    final gateway = FakeNotificationGateway();
    await gateway.schedule(entry());
    await gateway.schedule(entry(id: 2));

    await gateway.cancel(1);
    expect(await gateway.pendingIds(), <int>{2});

    await gateway.cancelAll();
    expect(await gateway.pendingIds(), isEmpty);
  });

  test('cancelling an id that was never there is not an error', () async {
    // The reconcile cancels ids it read a moment ago; the OS may have fired
    // one in between. A throw here would turn an ordinary race into a failure
    // the user sees.
    final gateway = FakeNotificationGateway();

    await gateway.cancel(999);

    expect(await gateway.pendingIds(), isEmpty);
  });

  group('permission', () {
    test('it reports what it was set to', () async {
      final gateway = FakeNotificationGateway();

      expect(await gateway.checkPermission(), PermissionState.granted);

      gateway.permission = PermissionState.denied;
      expect(await gateway.checkPermission(), PermissionState.denied);
    });

    test('it can be REVOKED after having been granted', () async {
      // Without this the revoked-after-grant path is untestable, and that path
      // is the one where the Settings row reads "On · 8:00" for ever while
      // nothing fires.
      final gateway = FakeNotificationGateway();
      expect(await gateway.requestPermission(), PermissionState.granted);
      await gateway.schedule(entry());

      gateway.permission = PermissionState.denied;

      expect(await gateway.checkPermission(), PermissionState.denied);
      expect(
        await gateway.pendingIds(),
        hasLength(1),
        reason: 'the OS keeps the entry; it just never posts it',
      );
    });
  });

  group('the counters a caller asserts on', () {
    test('every method is recorded, in order', () async {
      final gateway = FakeNotificationGateway();

      await gateway.checkPermission();
      await gateway.pendingIds();
      await gateway.schedule(entry());
      await gateway.cancel(1);
      await gateway.cancelAll();

      expect(gateway.calls, <String>[
        'checkPermission',
        'pendingIds',
        'schedule',
        'cancel',
        'cancelAll',
      ]);
      expect(gateway.scheduleCount, 1);
      expect(gateway.cancelCount, 1);
    });

    test('resetting clears the counters and keeps the pending set', () async {
      // Idempotence is asserted by counting writes across a SECOND run, so a
      // reset that also emptied the set would make every such test vacuous.
      final gateway = FakeNotificationGateway();
      await gateway.schedule(entry());

      gateway.resetCalls();

      expect(gateway.calls, isEmpty);
      expect(gateway.scheduleCount, 0);
      expect(await gateway.pendingIds(), hasLength(1));
    });
  });

  test('a scheduling failure is expressible', () async {
    // Task 4 asserts the reconcile converges after a refusal. A fake that
    // could only succeed would make that test pass without the code that
    // makes it true.
    final gateway = FakeNotificationGateway()..failNextSchedule = true;

    expect(
      () => gateway.schedule(entry()),
      throwsA(isA<NotificationGatewayException>()),
    );
  });
}
