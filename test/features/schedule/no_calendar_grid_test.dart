// The Schedule is never a seven-column month grid.
//
// **This is an absence-of-a-failure-class test, and it passes vacuously the
// moment it is written.** So it has a POSITIVE half — the screen really did
// render blocks — and its red step was taken by hand: a `GridView(children:
// [])` was added to `schedule_screen.dart`, this file ran red, and the grid was
// removed. Without that, the test proves nothing at all.
//
// The other layer is a rule in `tool/check_bans.sh`, driven in both directions
// by `test/tool/check_bans_test.dart`: source can carry a grid that never
// renders, and a widget test cannot see it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_day_row.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../support/harness.dart';
import 'support/schedule_fixture.dart';

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('no cell of the rendered Schedule is a calendar square', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      const ScheduleScreen(),
      overrides: scheduleOverrides(active: fixtureSchedule(l10n: l10n)),
      surfaceSize: const Size(390, 844),
    );
    await tester.pump();

    // The POSITIVE half FIRST: an empty or crashed screen contains no grid
    // either, and would pass every assertion below.
    expect(find.byType(BlockHeader), findsAtLeastNWidgets(2));
    expect(find.byType(ScheduleDayRow), findsAtLeastNWidgets(4));

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(SliverGrid), findsNothing);
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.byType(Table), findsNothing);

    // And no row shares a horizontal band with another: a multi-column list is
    // a grid by another name, whatever it is built out of.
    final tops = tester
        .widgetList<ScheduleDayRow>(find.byType(ScheduleDayRow))
        .map((row) => tester.getTopLeft(find.byWidget(row)).dy)
        .toList();
    expect(
      tops.toSet(),
      hasLength(tops.length),
      reason: 'two rows are side by side — that is a grid',
    );
  });
}
