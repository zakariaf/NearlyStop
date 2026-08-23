// Midnight, a flight, and a device asleep across both.
//
// **This epic builds no timer and no lifecycle hook.** EPIC-06's `DayTicker`
// owns the only one; `TodayNotifier.build()` watches `todayDateProvider`, so
// an invalidation rebuilds it. A second ticker here would double-fire the
// resume handler and make one of EPIC-06's two rollover suites vacuous — which
// is why the last test in this file greps this feature's source.
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/features/today/application/today_view_provider.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

import '../../support/db_harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  late AppDatabaseHolder holder;
  setUp(() => holder = AppDatabaseHolder(openTestDatabase()));

  ProviderContainer containerAt(DateTime now) {
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(holder.database),
        // The REAL `todayDateProvider`, derived from the clock, so the ticker
        // invalidating it is what moves the day — exactly as in the app.
        clockProvider.overrideWithValue(Clock(() => now)),
        resolvedLocaleProvider.overrideWithValue(const Locale('en')),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the SCREEN follows the day, without a manual refresh', () async {
    // EPIC-06 owns the timer and already tests it in fake time. What this epic
    // adds is the wiring: `TodayNotifier.build()` watches `todayDateProvider`,
    // so an invalidation re-projects. Real async, because the notifier reads a
    // real database — a `FakeAsync` around this hangs, since the stream never
    // completes in fake time.
    var now = DateTime(2026, 4, 16, 23, 59);
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(holder.database),
        clockProvider.overrideWithValue(Clock(() => now)),
        resolvedLocaleProvider.overrideWithValue(const Locale('en')),
      ],
    );
    addTearDown(container.dispose);
    await container.read(taperRepositoryProvider).savePlan(seededDraft());
    container.listen(todayViewProvider, (_, _) {});
    await container.read(todayViewProvider.future);
    final before = container.read(todayViewProvider).requireValue as TodayDose;

    // Midnight passes and the ticker invalidates, exactly as EPIC-06's
    // `DayTicker` does.
    now = DateTime(2026, 4, 17, 0, 1);
    container.invalidate(todayDateProvider);
    await container.read(todayViewProvider.future);

    final after = container.read(todayViewProvider).requireValue as TodayDose;
    expect(after.dateLine, isNot(before.dateLine));
    expect(after.dateLine, contains('17'));
    expect(
      after.taken,
      isFalse,
      reason: 'a new day starts un-ticked',
    );
  });

  test('a device asleep across midnight SKIPS to the day it woke on', () async {
    // The timer never fired — the phone was asleep for 32 hours. What brings
    // the screen back is the resume hook re-reading the clock, not a timer
    // catching up one day at a time.
    var now = DateTime(2026, 4, 16, 23);
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(holder.database),
        clockProvider.overrideWithValue(Clock(() => now)),
        resolvedLocaleProvider.overrideWithValue(const Locale('en')),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(todayDateProvider), const LocalDate(2026, 4, 16));

    now = DateTime(2026, 4, 18, 7);
    container.invalidate(todayDateProvider);

    expect(
      container.read(todayDateProvider),
      const LocalDate(2026, 4, 18),
      reason: 'it landed on the 17th, catching up rather than re-reading',
    );
  });

  test('a timezone change does not move the day INDEX', () async {
    // `SPEC.md` §7: every comparison is on `LocalDate`, never on elapsed
    // seconds. A flight moves which day is today; it never moves which dose
    // belongs to a day.
    final container = containerAt(DateTime(2026, 4, 16, 8));
    await container.read(taperRepositoryProvider).savePlan(seededDraft());
    container.listen(todayViewProvider, (_, _) {});
    await container.read(todayViewProvider.future);
    final before = container.read(todayViewProvider).requireValue as TodayDose;

    // Same calendar day, eight hours later on the wall clock — which is what
    // a long flight east looks like to the app.
    final shifted = containerAt(DateTime(2026, 4, 16, 16));
    await shifted.read(taperRepositoryProvider).savePlan(seededDraft());
    shifted.listen(todayViewProvider, (_, _) {});
    await shifted.read(todayViewProvider.future);
    final after = shifted.read(todayViewProvider).requireValue as TodayDose;

    expect(after.dayInStep, before.dayInStep);
    expect(after.doseAmount, before.doseAmount);
  });

  test('this feature builds NO timer and NO lifecycle hook', () {
    // Asserted over the source, so a second ticker cannot be added quietly.
    // Two would each fire on resume, and one of EPIC-06's rollover suites
    // would then be asserting nothing.
    final offenders = <String>[];
    for (final file
        in Directory('lib/features/today')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final banned in <String>[
        'Timer(',
        'Timer.periodic',
        'WidgetsBindingObserver',
        'AppLifecycleListener',
      ]) {
        if (source.contains(banned)) offenders.add('${file.path}: $banned');
      }
    }

    expect(offenders, isEmpty);
  });
}
