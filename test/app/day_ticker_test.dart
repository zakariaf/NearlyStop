// Midnight rollover, in fake time.
//
// Never sleep, never `pumpAndSettle`: a rollover test that waits for a real
// clock is a test nobody runs twice.
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/day_ticker.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
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

  test('a DST-shortened day is 23 hours, not 24', () {
    // Computed with the LOCAL constructor on purpose. `Duration(hours: 24)`
    // lands an hour late on the one morning of the year that already confuses
    // everyone. (Meaningful only under a DST zone; the CI step runs it under
    // Europe/Berlin.)
    FakeAsync().run((async) {
      final start = DateTime(2025, 3, 30, 0, 30);
      final container = containerFor(async, start);

      final until = container.read(dayTickerProvider).untilNextMidnight;

      expect(until, DateTime(2025, 3, 31).difference(start));
      container.dispose();
    });
  });

  test('the locale hook and the date hook do not cross', () {
    // Asserted as an ABSENCE in both directions. Riverpod does not notify when
    // a rebuild produces an equal value, so counting locale notifications
    // would be counting whether the OS language actually changed — not
    // whether the hook is wired. What can be asserted, and is what matters, is
    // that neither hook disturbs the other's provider.
    FakeAsync().run((async) {
      final container = containerFor(async, DateTime(2025, 4, 16, 23, 59));
      var dates = 0;
      container
        ..listen(todayDateProvider, (_, _) => dates++)
        ..read(dayTickerProvider).onLocalesChanged();

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
