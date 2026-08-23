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
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:riverpod/misc.dart' show Override;

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
      overrides: <Override>[
        currentStepIndexProvider.overrideWithValue(0),
        scheduleViewProvider(0).overrideWith(() => _FixedSchedule(fixture)),
      ],
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

    /// Every header sitting AGAINST the top edge — a band, not "above it".
    ///
    /// Headers scrolled past are still built inside the cache extent, at
    /// offsets well above the viewport. A bare `dy < top` therefore collects
    /// all of them and reports pinning that is not happening: the whole test
    /// passes with `pinned: false`. The band is what makes this measure the
    /// top edge rather than the direction of the top edge.
    List<String> pinnedTitles() {
      final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
      return find
          .byType(BlockHeader)
          .evaluate()
          .map((element) => element.widget as BlockHeader)
          .where((header) {
            final dy = tester.getTopLeft(find.byWidget(header)).dy;
            return dy >= top - 1 && dy < top + 8;
          })
          .map((header) => header.title)
          .toList();
    }

    expect(find.text(currentTitle), findsOneWidget);
    await tester.drag(find.byType(Scrollable), const Offset(0, -600));
    await tester.pump();
    final atTop = pinnedTitles();

    // The POSITIVE half: something IS pinned, and it STAYS pinned through a
    // further drag. A header that never pins can land against the top edge by
    // coincidence at one offset; it cannot stay there through two.
    expect(atTop, isNotEmpty, reason: 'nothing is pinned at all');
    await tester.drag(find.byType(Scrollable), const Offset(0, -40));
    await tester.pump();
    expect(
      pinnedTitles(),
      atTop,
      reason: 'the header at the top moved with the scroll — it is not pinned',
    );

    // The NEGATIVE half: and it is not block 3's, sitting over block 4's rows.
    expect(
      pinnedTitles(),
      isNot(contains(currentTitle)),
      reason: 'block 3 pinned itself over block 4',
    );
    expect(find.text(l10n.blockOfTotal(4, 11)), findsOneWidget);
  });

  testWidgets('at 2.0 the headers grow and nothing overflows', (tester) async {
    await pumpSchedule(tester, textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
    expect(find.byType(BlockHeader), findsAtLeastNWidgets(1));
  });
}

/// A notifier that emits one fixed state and nothing else.
final class _FixedSchedule extends ScheduleNotifier {
  _FixedSchedule(this.fixture) : super(0);

  final ScheduleViewState fixture;

  @override
  Stream<ScheduleViewState> build() => Stream<ScheduleViewState>.value(fixture);
}
