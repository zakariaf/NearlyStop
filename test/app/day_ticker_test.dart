// Midnight rollover, in fake time.
//
// Never sleep, never `pumpAndSettle`: a rollover test that waits for a real
// clock is a test nobody runs twice.
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/day_ticker.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

void main() {
  /// A container whose clock advances with [async].
  ProviderContainer containerFor(FakeAsync async, DateTime start) =>
      ProviderContainer(
        overrides: <Override>[
          // Reads the FAKE clock, so elapsing time moves "now" for the ticker
          // and for `todayDateProvider` together.
          clockProvider.overrideWithValue(
            Clock(() => start.add(async.elapsed)),
          ),
          bootstrapSettingsProvider.overrideWithValue(AppSettings.defaults),
        ],
      );

  test('the date turns at local midnight, exactly once', () {
    FakeAsync().run((async) {
      final container = containerFor(async, DateTime(2025, 4, 16, 23, 59));
      var invalidations = 0;
      container
        ..listen(todayDateProvider, (_, _) => invalidations++)
        ..read(dayTickerProvider);

      async.elapse(const Duration(seconds: 59));
      expect(container.read(todayDateProvider), const LocalDate(2025, 4, 16));

      async.elapse(const Duration(seconds: 1));

      expect(container.read(todayDateProvider), const LocalDate(2025, 4, 17));
      expect(invalidations, 1, reason: 'a double tick is a double rebuild');
      container.dispose();
    });
  });

  test('it reschedules, so day eight is still right', () {
    // A ticker that fires once and stops passes the test above and fails the
    // user on the second morning.
    FakeAsync().run((async) {
      final container = containerFor(async, DateTime(2025, 4, 16, 23, 59))
        ..read(dayTickerProvider);

      async
        ..elapse(const Duration(minutes: 1))
        ..elapse(const Duration(days: 7));

      expect(container.read(todayDateProvider), const LocalDate(2025, 4, 24));
      container.dispose();
    });
  });

  test('the interval to midnight follows the zone, not a 24-hour day', () {
    // The oracle is built from the UTC OFFSETS, which `day_ticker.dart` never
    // reads — not from `DateTime(y, m, d + 1).difference(now)`, which is the
    // implementation's own line 49 and therefore agrees with any bug in it.
    //
    // wall-clock remainder, then corrected by however much the zone moved
    // across the boundary. Under UTC that correction is zero and this is
    // 23h30m; under Europe/Berlin, where 2025-03-30 loses an hour at 02:00,
    // it is 22h30m. A `Duration(hours: 24)` implementation fails under both,
    // and a local-constructor one that ignored the offset fails under Berlin.
    FakeAsync().run((async) {
      final start = DateTime(2025, 3, 30, 0, 30);
      final nextMidnight = DateTime(2025, 3, 31);
      final wallClockRemainder =
          const Duration(days: 1) -
          Duration(hours: start.hour, minutes: start.minute);
      final zoneShift = nextMidnight.timeZoneOffset - start.timeZoneOffset;
      final container = containerFor(async, start);

      final until = container.read(dayTickerProvider).untilNextMidnight;

      expect(until, wallClockRemainder - zoneShift);
      expect(
        until,
        isNot(const Duration(hours: 24)),
        reason: 'a fixed 24-hour reschedule is the bug this test exists for',
      );
      container.dispose();
    });
  });

  test('elapsing that interval is exactly what turns the date', () {
    // The interval is only interesting because the timer uses it. Asserted
    // separately so a correct duration wired to nothing still fails.
    FakeAsync().run((async) {
      final container = containerFor(async, DateTime(2025, 3, 30, 0, 30));
      final until = container.read(dayTickerProvider).untilNextMidnight;

      async.elapse(until - const Duration(seconds: 1));
      expect(container.read(todayDateProvider), const LocalDate(2025, 3, 30));

      async.elapse(const Duration(seconds: 1));

      expect(container.read(todayDateProvider), const LocalDate(2025, 3, 31));
      container.dispose();
    });
  });

  test('a locale change is not a new day', () {
    // The two hooks live on different observers — this ticker owns resume,
    // `_NearlyStopAppState.didChangeLocales` owns the language — so the claim
    // worth pinning is that they stay disjoint: re-resolving the locale must
    // not move the pointer into the taper. Driven through the provider the
    // root widget actually invalidates, not through a method on this class:
    // an earlier version of this test called a `DayTicker.onLocalesChanged`
    // that nothing in the app ever called, so it asserted only that a dead
    // method behaved.
    FakeAsync().run((async) {
      final container = containerFor(async, DateTime(2025, 4, 16, 23, 59));
      var dates = 0;
      container
        ..listen(todayDateProvider, (_, _) => dates++)
        ..read(dayTickerProvider)
        ..invalidate(resolvedLocaleProvider);

      expect(dates, 0, reason: 'a language change is not a new day');

      async.elapse(const Duration(minutes: 1));

      expect(dates, 1, reason: 'and a new day IS one');
      container.dispose();
    });
  });

  test('disposal leaves no pending timer', () {
    // A leaked timer is the "Timer still pending" failure that poisons the
    // next test — and in the app, a wakeup nobody owns.
    FakeAsync().run((async) {
      final container = containerFor(async, DateTime(2025, 4, 16, 23, 59))
        ..read(dayTickerProvider)
        ..dispose();

      expect(async.pendingTimers, isEmpty);
      expect(container.hashCode, isNotNull);
    });
  });
}
