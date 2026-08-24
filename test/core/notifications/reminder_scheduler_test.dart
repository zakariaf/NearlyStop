// The scheduling maths, in pure Dart with a frozen clock and a pinned zone.
//
// Every case here is a wrong-hour notification somebody would have received.
// A stored UTC instant fires an hour early on the last Sunday in March; a
// rule resolved against the machine's own zone passes on the author's laptop
// and fires at 03:00 in Tehran; a rule that rolls forward at `>` instead of
// `>=` skips the morning somebody set it for.
import 'package:clock/clock.dart';
import 'package:nearlystop/core/notifications/reminder_scheduler.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location berlin;
  late tz.Location tehran;

  setUpAll(() {
    tzdata.initializeTimeZones();
    berlin = tz.getLocation('Europe/Berlin');
    tehran = tz.getLocation('Asia/Tehran');
  });

  /// [nextDailyAt] with the clock frozen at [now] in [zone].
  tz.TZDateTime nextAt(
    tz.Location zone,
    tz.TZDateTime now,
    int hour,
    int minute,
  ) => withClock(
    Clock.fixed(now),
    () => nextDailyAt(
      DailyReminderRule(hourLocal: hour, minuteLocal: minute),
      zone: zone,
      clock: clock,
    ),
  );

  group('nextDailyAt resolves a WALL CLOCK, in the plan’s own zone', () {
    test('before the time today → today', () {
      final fire = nextAt(
        berlin,
        tz.TZDateTime(berlin, 2025, 4, 16, 7, 30),
        8,
        0,
      );

      expect(fire, tz.TZDateTime(berlin, 2025, 4, 16, 8));
    });

    test('after the time today → tomorrow', () {
      final fire = nextAt(
        berlin,
        tz.TZDateTime(berlin, 2025, 4, 16, 8, 30),
        8,
        0,
      );

      expect(fire, tz.TZDateTime(berlin, 2025, 4, 17, 8));
    });

    test('AT the time, to the second → today, not tomorrow', () {
      // The boundary, on purpose. `>` here skips the morning somebody set it
      // for, and only on the one day their phone happened to be awake at 08:00
      // exactly — which is unreproducible for whoever they report it to.
      final fire = nextAt(berlin, tz.TZDateTime(berlin, 2025, 4, 16, 8), 8, 0);

      expect(fire, tz.TZDateTime(berlin, 2025, 4, 16, 8));
    });

    test('a midnight rule at 23:59 → the next day', () {
      final fire = nextAt(
        berlin,
        tz.TZDateTime(berlin, 2025, 4, 16, 23, 59),
        0,
        0,
      );

      expect(fire, tz.TZDateTime(berlin, 2025, 4, 17));
    });
  });

  group('DST: the LOCAL hour is what is promised', () {
    test('spring forward keeps 08:00 local, at +02:00', () {
      // Berlin jumps 02:00 → 03:00 on 2025-03-30. A stored instant computed the
      // day before fires at 07:00 here.
      final fire = nextAt(berlin, tz.TZDateTime(berlin, 2025, 3, 30, 1), 8, 0);

      expect(fire.hour, 8);
      expect(fire.timeZoneOffset, const Duration(hours: 2));
    });

    test('fall back keeps 08:00 local, at +01:00', () {
      final fire = nextAt(berlin, tz.TZDateTime(berlin, 2025, 10, 26, 1), 8, 0);

      expect(fire.hour, 8);
      expect(fire.timeZoneOffset, const Duration(hours: 1));
    });

    test('rolling forward ACROSS spring-forward still lands on 08:00', () {
      // The clock is on the 29th, after the rule time, so the answer is the
      // 30th — the day Berlin loses an hour. `today + 24h` gives 09:00 here,
      // and this is the only shape of test that separates the two: a rule
      // resolved on the DST day itself is identical either way.
      final fire = nextAt(berlin, tz.TZDateTime(berlin, 2025, 3, 29, 9), 8, 0);

      expect(fire, tz.TZDateTime(berlin, 2025, 3, 30, 8));
      expect(fire.hour, 8);
      expect(fire.timeZoneOffset, const Duration(hours: 2));
    });

    test('rolling forward ACROSS fall-back still lands on 08:00', () {
      // The mirror: `today + 24h` gives 07:00 on a 25-hour day.
      final fire = nextAt(berlin, tz.TZDateTime(berlin, 2025, 10, 25, 9), 8, 0);

      expect(fire, tz.TZDateTime(berlin, 2025, 10, 26, 8));
      expect(fire.hour, 8);
      expect(fire.timeZoneOffset, const Duration(hours: 1));
    });

    test('the ZONE is the argument, never the machine’s', () {
      final fire = nextAt(tehran, tz.TZDateTime(tehran, 2025, 4, 16, 7), 8, 0);

      expect(fire.location, tehran);
      expect(fire.hour, 8);
    });
  });

  test('the rule survives a round trip through minutes-since-midnight', () {
    // All 1440, because the one that fails will be 0 or 1439.
    for (var minute = 0; minute < 1440; minute++) {
      final rule = DailyReminderRule.fromMinuteOfDay(minute);
      expect(rule.minuteOfDay, minute, reason: 'minute $minute');
      expect(rule.hourLocal, minute ~/ 60);
      expect(rule.minuteLocal, minute % 60);
    }
  });

  group('seeded fuzz against component arithmetic', () {
    test('always in [now, now + 25h), always at the rule’s wall clock', () {
      // 25 hours, not 24: a spring-forward day is 23 hours long and a
      // fall-back day is 25, so a bound of exactly 24 is wrong twice a year.
      // The oracle is TZDateTime component arithmetic written here, not the
      // function under test.
      var seed = 20250416;
      int next(int bound) {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
        return seed % bound;
      }

      for (var index = 0; index < 500; index++) {
        final zone = index.isEven ? berlin : tehran;
        final now = tz.TZDateTime(
          zone,
          2025,
          1 + next(12),
          1 + next(28),
          next(24),
          next(60),
          next(60),
        );
        final hour = next(24);
        final minute = next(60);
        final fire = nextAt(zone, now, hour, minute);
        final triple = '${zone.name} now=$now rule=$hour:$minute fire=$fire';

        expect(fire.isBefore(now), isFalse, reason: triple);
        expect(
          fire.difference(now) < const Duration(hours: 25),
          isTrue,
          reason: triple,
        );
        expect(fire.hour, hour, reason: triple);
        expect(fire.minute, minute, reason: triple);
        expect(fire.second, 0, reason: triple);
      }
    });
  });

  group('compute returns what SHOULD be armed, and nothing else', () {
    const copy = NotificationCopy(
      title: 'Your plan for today',
      body: "Open NearlyStop to see today's dose.",
    );

    Set<ScheduledNotification> computeAt({
      bool reminderEnabled = true,
      int? reminderMinuteOfDay = 8 * 60,
      bool taperActive = true,
      NotificationCopy copy = copy,
      tz.Location? zone,
    }) => withClock(
      Clock.fixed(tz.TZDateTime(berlin, 2025, 4, 16, 7)),
      () => ReminderScheduler.compute(
        settings: AppSettings.defaults.copyWith(
          reminderEnabled: reminderEnabled,
          reminderMinuteOfDay: reminderMinuteOfDay,
        ),
        taperActive: taperActive,
        zone: zone ?? berlin,
        clock: clock,
        copy: copy,
      ),
    );

    test('on, with an active taper → exactly one, repeating daily', () {
      final desired = computeAt();

      expect(desired, hasLength(1));
      final entry = desired.single;
      expect(entry.fireAt, tz.TZDateTime(berlin, 2025, 4, 16, 8));
      expect(entry.title, copy.title);
      expect(entry.body, copy.body);
      expect(entry.payload, kTodayPayload);
      expect(entry.channelId, kDailyReminderChannelId);
      // The assertion that pins REPEATING. A one-shot passes every other test
      // in this group, and then stops after one morning for anybody who does
      // not reopen the app — which is the failure this epic exists to prevent.
      expect(entry.repeatsDaily, isTrue);
    });

    test('the reminder is off → nothing', () {
      expect(computeAt(reminderEnabled: false), isEmpty);
    });

    test('there is no active taper → nothing', () {
      // Asserted separately from the case above, on purpose: one emptiness
      // test passes while the other two conditions are unimplemented.
      expect(computeAt(taperActive: false), isEmpty);
    });

    test('the reminder is on with no time set → nothing', () {
      expect(computeAt(reminderMinuteOfDay: null), isEmpty);
    });

    test('a different time is a different id; the same time is the same', () {
      final eight = computeAt().single;
      final two = computeAt(reminderMinuteOfDay: 14 * 60).single;

      expect(two.id, isNot(eight.id));
      expect(computeAt().single.id, eight.id);
    });

    test('a different locale’s copy is a different id', () {
      final other = computeAt(
        copy: const NotificationCopy(
          title: 'برنامه امروز شما',
          body: 'باز کنید',
        ),
      ).single;

      expect(other.id, isNot(computeAt().single.id));
    });

    test('the body carries no dose, and the value object cannot hold one', () {
      // Structural, not a copy review: there is no dose field to fill in.
      final entry = computeAt().single;
      expect(entry.payload, 'today');
      expect(entry.body.contains(RegExp('[0-9]')), isFalse);
    });
  });
}
