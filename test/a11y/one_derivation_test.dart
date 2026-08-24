// CONTRACTS §4: the schedule is derived ONCE, app-wide.
//
// Today, Schedule and Progress all render the same 780 days. If each screen
// derived its own, the generator would run three times on every launch — and,
// worse, three copies could disagree the day somebody changed one of them.
// EPIC-06 put the derivation in `derivedScheduleProvider` and every screen
// projects from its output.
//
// Nothing in the suite noticed whether that held. Each screen's own tests pump
// that screen alone, so a second derivation is invisible until all three are
// alive at once — which is exactly the situation the app is always in.
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/features/progress/presentation/progress_screen.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/today/presentation/today_screen.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';
import 'package:riverpod/misc.dart' show Override;

import '../fixtures/seeded_plan.dart';
import '../support/db_harness.dart';
import '../support/fonts.dart';

/// Counts how many times each provider was built.
///
/// Keyed by IDENTITY, never by name: a provider's `toString()` is
/// `Provider<Result<List<DayPlan>, Failure>>#45608`, so a name match counts
/// zero and every assertion over it passes vacuously. That is the first
/// version of this file, and the `greaterThan(0)` guard below is what caught
/// it.
final class _BuildCounter extends ProviderObserver {
  final Map<Object, int> builds = <Object, int>{};

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    builds[context.provider] = (builds[context.provider] ?? 0) + 1;
  }
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  testWidgets('three screens at once derive the schedule once', (
    tester,
  ) async {
    // A REAL database and the real notifiers. Faking the three view providers
    // would fake the thing under test — the derivation is what they trigger.
    // Tall enough for three full screens stacked: an overflow here would be
    // a layout complaint about the harness, not a fact about the app.
    tester.view.physicalSize =
        const Size(390, 2600) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);

    final counter = _BuildCounter();
    final database = openTestDatabase();
    addTearDown(database.close);
    final container = ProviderContainer(
      observers: <ProviderObserver>[counter],
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        todayDateProvider.overrideWithValue(seededToday),
        clockProvider.overrideWithValue(Clock.fixed(seededNow)),
        resolvedLocaleProvider.overrideWithValue(const Locale('en')),
      ],
    );
    addTearDown(container.dispose);
    await seedTaperInto(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: kAppLocalizationsDelegates,
          supportedLocales: kSupportedLocales,
          theme: buildDaybreakTheme(Brightness.light, DaybreakScript.latin),
          home: const Scaffold(
            body: Column(
              children: <Widget>[
                Expanded(child: TodayScreen()),
                Expanded(child: ScheduleScreen()),
                Expanded(child: ProgressScreen()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final derivations = counter.builds[derivedScheduleProvider] ?? 0;

    // Never vacuous: if the identity match ever stops working this is zero,
    // and the assertion below would pass over a provider nobody counted.
    expect(
      derivations,
      greaterThan(0),
      reason:
          'no derivation was observed at all — the counter is broken. '
          'Providers seen: ${counter.builds.keys}',
    );
    expect(
      derivations,
      1,
      reason: 'the schedule was derived $derivations times for one launch',
    );
    // And all three screens really rendered, so the count is over a live app.
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(ScheduleScreen), findsOneWidget);
    expect(find.byType(ProgressScreen), findsOneWidget);
  });

  test('exactly one place in lib/ calls the generator', () {
    // The other half of the same claim, and the half the observer cannot
    // make: a screen that called `generateSchedule` directly would never
    // build `derivedScheduleProvider` twice, so the count above would stay at
    // one while the app derived the taper a second time.
    final callers = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      if (file.path.endsWith('schedule_generator.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('generateSchedule(')) callers.add(file.path);
      }
    }

    // The FILE, not a line number: pinning the line makes the test fail for
    // an edit three functions above it, which teaches people to update the
    // number rather than to read the rule.
    expect(
      callers,
      <String>['lib/app/derived_schedule_provider.dart'],
      reason: 'CONTRACTS §4: one derivation, in derivedScheduleProvider',
    );
  });
}
