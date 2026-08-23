// Plan on a tablet propped on a kitchen table (SPEC §5.4).
//
// Both arms of every claim. A two-up assertion on its own passes just as well
// when the layout is two-up at every width, which is the bug that ships: a
// breakpoint that never fires looks exactly like one that always does until
// somebody opens a phone.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/app/window_size.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/features/plan/presentation/plan_cards.dart';
import 'package:nearlystop/features/plan/presentation/plan_screen.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/db_harness.dart';
import '../../support/harness.dart';

void main() {
  const today = LocalDate(2026, 4, 16);

  late AppDatabaseHolder holder;
  setUp(() => holder = AppDatabaseHolder(openTestDatabase()));

  /// Unmounts inside the body: drift schedules a zero-duration timer when a
  /// query stream is cancelled, and `testWidgets` runs its pending-timer
  /// assertion BEFORE `addTearDown`.
  void planTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double scale = 1,
  }) async {
    await pumpApp(
      tester,
      const PlanScreen(),
      overrides: <Override>[
        databaseProvider.overrideWithValue(holder.database),
        todayDateProvider.overrideWithValue(today),
        clockProvider.overrideWithValue(Clock.fixed(DateTime.utc(2026, 4, 16))),
        resolvedLocaleProvider.overrideWithValue(const Locale('en')),
      ],
      textScaler: TextScaler.linear(scale),
      surfaceSize: size,
    );
    await tester.pumpAndSettle();
  }

  double topOf(WidgetTester tester, Type card) =>
      tester.getTopLeft(find.byType(card)).dy;

  planTest('390pt at 200% text: nothing is clipped off the edge', (
    tester,
  ) async {
    // The audience runs at the largest OS text size routinely, and the widest
    // single line on this screen is the step pair — `10mg → 9mg` at
    // headlineLarge. Doubled, it is wider than the phone.
    await pumpAt(tester, const Size(390, 3600), scale: 2);

    expect(tester.takeException(), isNull);
  });

  planTest('1024x768: summary and strengths share a row', (tester) async {
    await pumpAt(tester, const Size(1024, 768));

    expect(
      topOf(tester, PlanSummaryCard),
      topOf(tester, PlanStrengthsCard),
      reason: 'two-up means the same top, not merely both present',
    );
    // And the next-step card runs the full content width beneath them.
    final summary = tester.getRect(find.byType(PlanSummaryCard));
    final strengths = tester.getRect(find.byType(PlanStrengthsCard));
    final next = tester.getRect(find.byType(PlanNextStepCard));
    expect(next.width, greaterThan(summary.width));
    expect(next.top, greaterThan(summary.bottom.clamp(0, strengths.bottom)));
  });

  planTest('390x844: every card gets its own row', (tester) async {
    await pumpAt(tester, const Size(390, 1600));

    final tops = <double>[
      topOf(tester, PlanSummaryCard),
      topOf(tester, PlanStrengthsCard),
      topOf(tester, PlanMethodCard),
      topOf(tester, PlanNextStepCard),
    ];
    expect(tops.toSet(), hasLength(tops.length));
  });

  planTest('the boundary is the expanded class, not a number near it', (
    tester,
  ) async {
    // Exactly at, and one logical pixel below. A breakpoint written `>` when
    // `>=` was meant is off by exactly this much and by nothing else.
    const boundary = WindowSizeClass.expanded;
    await pumpAt(tester, Size(boundary.minWidth, 900));
    expect(
      topOf(tester, PlanSummaryCard),
      topOf(tester, PlanStrengthsCard),
      reason: 'at ${boundary.minWidth} the layout is two-up',
    );

    await pumpAt(tester, Size(boundary.minWidth - 1, 1600));
    expect(
      topOf(tester, PlanSummaryCard),
      isNot(topOf(tester, PlanStrengthsCard)),
      reason: 'one pixel below it, the layout is one-up',
    );
  });

  for (final size in <Size>[
    const Size(390, 1600),
    Size(WindowSizeClass.medium.minWidth, 1200),
    const Size(1024, 768),
  ]) {
    planTest('${size.width.toInt()}x${size.height.toInt()}: nothing scrolls '
        'sideways', (tester) async {
      await pumpAt(tester, size);

      // Every `Scrollable` EXCEPT the ones a single-line text field builds
      // for itself: `EditableText` scrolls its own content sideways, which is
      // how a long medicine name stays typeable, and has nothing to do with
      // the page scrolling sideways.
      final inFields = tester
          .widgetList<Scrollable>(
            find.descendant(
              of: find.byType(EditableText),
              matching: find.byType(Scrollable),
            ),
          )
          .toSet();
      for (final scrollable in tester.widgetList<Scrollable>(
        find.byType(Scrollable),
      )) {
        if (inFields.contains(scrollable)) continue;
        expect(
          scrollable.axisDirection,
          anyOf(AxisDirection.down, AxisDirection.up),
          reason: 'a horizontal scroller hides content off the edge',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
