// The structural choices that CAUSE good frames.
//
// The 16ms number is not assertable in a widget test — the runner's frame
// times mean nothing — so the profile-mode fling is a named manual
// pre-release measurement recorded in the PR (`testing-strategy` rule 11).
// What IS assertable is everything that decides whether those frames can be
// fast: how much is materialised, whether the keys are stable, and which
// raster layers each row asks for.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_block_group.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_day_row.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../support/harness.dart';
import 'support/schedule_fixture.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Future<void> pumpSchedule(WidgetTester tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      const ScheduleScreen(),
      overrides: scheduleOverrides(active: fixtureSchedule(l10n: l10n)),
      surfaceSize: const Size(390, 844),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('one step is materialised, never the whole taper', (
    tester,
  ) async {
    // 52 rows plus 11 headers is the whole of one step; the LIST holds that,
    // and the sliver builds a screenful of it. Other steps are reached through
    // the switcher, not by scrolling into them, which is what keeps the sliver
    // tree bounded and the centre arithmetic exact.
    await pumpSchedule(tester);

    expect(
      find.byType(ScheduleDayRow),
      findsAtLeastNWidgets(1),
      reason: 'nothing rendered — the count below would pass vacuously',
    );
    expect(
      tester.widgetList<ScheduleDayRow>(find.byType(ScheduleDayRow)).length,
      lessThanOrEqualTo(63),
    );
  });

  testWidgets('every row carries a stable, distinct key', (tester) async {
    await pumpSchedule(tester);

    final keys = tester
        .widgetList<ScheduleDayRowTile>(find.byType(ScheduleDayRowTile))
        .map((tile) => tile.key)
        .nonNulls
        .toList();
    expect(keys, isNotEmpty);
    expect(
      keys.whereType<ValueKey<String>>(),
      hasLength(keys.length),
      reason: 'a row is keyed by its position, so reordering reuses it wrongly',
    );
    expect(
      keys.toSet(),
      hasLength(keys.length),
      reason: 'two rows share a key, so the element tree cannot diff them',
    );
  });

  testWidgets('no row asks for its own raster layer', (tester) async {
    // A `ClipRRect` or an `Opacity` per row is a saveLayer per row on the
    // raster thread, over a list this reader flings through 780 days of. The
    // rounded corners come from `BoxDecoration(borderRadius:)` instead.
    await pumpSchedule(tester);

    for (final row in tester.widgetList<ScheduleDayRow>(
      find.byType(ScheduleDayRow),
    )) {
      expect(
        find.descendant(
          of: find.byWidget(row),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byWidget(row), matching: find.byType(Opacity)),
        findsNothing,
      );
    }
  });

  testWidgets('the sliver delegates keep nothing alive off screen', (
    tester,
  ) async {
    // Read off the widget rather than trusted: 780 rows of history kept alive
    // is how this screen gets slow at step 12, and the default is `true`.
    await pumpSchedule(tester);

    final delegates = tester
        .widgetList<SliverList>(find.byType(SliverList))
        .map((sliver) => sliver.delegate)
        .whereType<SliverChildBuilderDelegate>()
        .toList();
    expect(delegates, isNotEmpty);
    for (final delegate in delegates) {
      expect(delegate.addAutomaticKeepAlives, isFalse);
      expect(
        delegate.addRepaintBoundaries,
        isTrue,
        reason: 'without it every row repaints when any row does',
      );
    }
  });

  testWidgets('a fling does not rebuild the whole list per frame', (
    tester,
  ) async {
    await pumpSchedule(tester);
    final before = tester
        .widgetList<ScheduleDayRow>(find.byType(ScheduleDayRow))
        .length;

    await tester.fling(find.byType(Scrollable), const Offset(0, -1200), 3000);
    await tester.pumpAndSettle();

    expect(
      tester.widgetList<ScheduleDayRow>(find.byType(ScheduleDayRow)).length,
      lessThanOrEqualTo(before * 2),
      reason: 'the fling materialised everything it flew past',
    );
    expect(tester.takeException(), isNull);
  });
}
