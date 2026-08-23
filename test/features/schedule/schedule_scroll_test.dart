// The list opens in the MIDDLE.
//
// Every assertion here is about the first frame, before any drag and with no
// programmatic scroll: that is the whole point of `CustomScrollView(center:)`,
// and a test that scrolled first would pass on a plain `ListView` with an
// initial offset. Slivers listed before the centre sliver grow toward the
// leading edge, which is why `minScrollExtent` is negative — the observable
// signature of the mechanism.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../support/harness.dart';
import 'support/schedule_fixture.dart';

void main() {
  const phone = Size(390, 844);

  setUpAll(initializeDateFormatting);

  /// Pumps the screen over a fixed [ScheduleLoaded] — no repository, no clock.
  Future<AppLocalizations> pumpSchedule(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
    Size size = phone,
  }) async {
    final l10n = await AppLocalizations.delegate.load(locale);
    final fixture = fixtureSchedule(l10n: l10n, locale: locale);
    await pumpApp(
      tester,
      const ScheduleScreen(),
      overrides: scheduleOverrides(active: fixture),
      locale: locale,
      textScaler: textScaler,
      surfaceSize: size,
    );
    await tester.pump();
    return l10n;
  }

  /// The one scroll position on screen.
  ScrollPosition positionOf(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position;

  /// The day label the fixture renders for [date].
  String rowLabel(AppLocalizations l10n, LocalDate date) =>
      fixtureSchedule(
            l10n: l10n,
          ).blocks
          .expand((block) => block.days)
          .firstWhere((day) => day.date == date)
          .dayLabel;

  testWidgets('the FIRST frame is already on today, with no scroll at all', (
    tester,
  ) async {
    final l10n = await pumpSchedule(tester);

    expect(find.text(rowLabel(l10n, fixtureToday)), findsOneWidget);
    expect(
      find.text(rowLabel(l10n, fixtureToday)).hitTestable(),
      findsOneWidget,
      reason: 'today is on screen but not hit-testable',
    );
    // The current block's header is the first thing above it.
    final header = tester.getTopLeft(find.byType(BlockHeader).first).dy;
    expect(header, lessThan(120));
  });

  testWidgets('the centre sliver puts zero at today and history below it', (
    tester,
  ) async {
    await pumpSchedule(tester);
    final position = positionOf(tester);

    expect(position.pixels, 0);
    expect(
      position.minScrollExtent,
      lessThan(0),
      reason: 'nothing was placed before the centre key — this is a plain list',
    );
    expect(position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('it scrolls BOTH ways across the whole step', (tester) async {
    final l10n = await pumpSchedule(tester);
    final firstDay = rowLabel(l10n, const LocalDate(2026, 4, 1));
    final lastDay = rowLabel(l10n, const LocalDate(2026, 5, 22));

    /// Drags [direction] until every one of [targets] is built, or the end.
    ///
    /// A loop rather than one big drag: the pixel height of 52 rows and 11
    /// headers changes with the font metrics, and a hardcoded offset that
    /// happens to be enough today is a test that starts failing for a reason
    /// with nothing to do with the claim.
    Future<void> dragUntil(List<String> targets, double direction) async {
      bool present() =>
          targets.every((text) => find.text(text).evaluate().isNotEmpty);
      for (var attempt = 0; attempt < 20; attempt++) {
        if (present()) return;
        final before = positionOf(tester).pixels;
        await tester.drag(find.byType(Scrollable), Offset(0, direction));
        await tester.pump();
        if (positionOf(tester).pixels == before) return;
      }
    }

    expect(find.text(firstDay), findsNothing);
    await dragUntil(<String>[firstDay], 600);
    expect(
      find.text(firstDay),
      findsOneWidget,
      reason: 'dragging back never reached the first day of the step',
    );
    expect(positionOf(tester).pixels, lessThan(0));

    // And the history reads DOWNWARDS in time, block boundaries included. The
    // leading region grows toward the top and lays its children out
    // nearest-the-centre first, so the WHOLE flattened region is reversed;
    // reversing the blocks and then flattening leaves every day present, every
    // day in order inside its block, and block 2 sitting above block 1.
    for (final (earlier, later) in const <(LocalDate, LocalDate)>[
      (LocalDate(2026, 4, 2), LocalDate(2026, 4, 3)),
      // Block 1 is seven days, so this pair straddles the boundary.
      (LocalDate(2026, 4, 7), LocalDate(2026, 4, 8)),
    ]) {
      final pair = <String>[rowLabel(l10n, earlier), rowLabel(l10n, later)];
      await dragUntil(pair, -100);
      expect(
        tester.getTopLeft(find.text(pair.first)).dy,
        lessThan(tester.getTopLeft(find.text(pair.last)).dy),
        reason: 'the row for $earlier is below the row for $later',
      );
    }
    // And each header is above its own first day.
    final blockTwo = l10n.blockOfTotal(2, 11);
    final eighth = rowLabel(l10n, const LocalDate(2026, 4, 8));
    await dragUntil(<String>[blockTwo, eighth], -100);
    expect(
      tester.getTopLeft(find.text(blockTwo)).dy,
      lessThan(tester.getTopLeft(find.text(eighth)).dy),
      reason: 'block 2 header sits under its own rows',
    );

    await dragUntil(<String>[lastDay], -600);
    expect(
      find.text(lastDay),
      findsOneWidget,
      reason: 'dragging forward never reached the last day of the step',
    );
  });

  testWidgets('a pinned header belongs to ITS block, never the next one', (
    tester,
  ) async {
    // The bug `SliverMainAxisGroup` fixes: with plain slivers, block 3's
    // header stays stuck at the top over block 4's rows.
    final l10n = await pumpSchedule(tester);
    final currentTitle = l10n.blockOfTotal(3, 11);

    /// Every header whose own span COVERS the top edge of the viewport.
    ///
    /// Not "sits at the top": during the handoff the outgoing header is being
    /// pushed up by the incoming one, so for about one header's height neither
    /// is at zero while the outgoing one still covers the edge. And not "is
    /// above the top" either — headers scrolled past stay built inside the
    /// cache extent at large negative offsets, and counting those reports
    /// pinning that is not happening (`pinned: false` passes that version).
    List<String> pinnedTitles() {
      final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
      return find
          .byType(BlockHeader)
          .evaluate()
          .map((element) => element.widget as BlockHeader)
          .where((header) {
            final finder = find.byWidget(header);
            final dy = tester.getTopLeft(finder).dy;
            return dy <= top && dy + tester.getSize(finder).height > top;
          })
          .map((header) => header.title)
          .toList();
    }

    expect(find.text(currentTitle), findsOneWidget);
    expect(pinnedTitles(), <String>[currentTitle]);

    // The invariant: at EVERY offset inside the trailing region, exactly one
    // header sits against the top edge, and it is the one that owns the rows
    // below it. A header that never pins satisfies this at the odd offset
    // where it happens to be passing the top edge, never at all of them.
    // Sampled finely: the failure mode is a NARROW band of scroll — the gap
    // between two blocks — during which nothing is pinned, and a coarse sweep
    // steps straight over it.
    final seen = <String>{};
    for (var step = 0; step < 40; step++) {
      await tester.drag(find.byType(Scrollable), const Offset(0, -40));
      await tester.pump();
      final titles = pinnedTitles();
      expect(
        titles,
        hasLength(1),
        reason:
            'no single header is pinned at offset ${positionOf(tester).pixels}',
      );
      seen.add(titles.single);
    }

    // And the pin CHANGED hands: block 3 did not follow us into block 4.
    expect(
      seen.length,
      greaterThan(1),
      reason: 'one header pinned itself over every block that followed',
    );
    expect(pinnedTitles(), isNot(contains(currentTitle)));
    expect(
      seen,
      containsAll(<String>[currentTitle, l10n.blockOfTotal(4, 11)]),
      reason: 'the pin never handed over from block 3 to block 4',
    );
  });

  testWidgets('at 2.0 the headers grow and nothing overflows', (tester) async {
    await pumpSchedule(tester, textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
    expect(find.byType(BlockHeader), findsAtLeastNWidgets(1));
  });
}
