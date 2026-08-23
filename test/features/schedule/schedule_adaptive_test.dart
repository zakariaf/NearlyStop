// Wide screens and landscape phones, asserted on BOTH sides of the boundary.
//
// A breakpoint test that only checks the wide side passes on a layout that is
// always wide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_day_row.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/step_switcher_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

import '../../support/harness.dart';
import 'support/schedule_fixture.dart';

void main() {
  setUpAll(initializeDateFormatting);

  const options = <StepOption>[
    StepOption(index: 0, label: 'Step 1 of 2', status: StepStatus.completed),
    StepOption(index: 1, label: 'Step 2 of 2', status: StepStatus.active),
  ];

  Future<AppLocalizations> pumpAt(
    WidgetTester tester,
    Size size, {
    TextScaler textScaler = TextScaler.noScaling,
    Locale locale = const Locale('en'),
  }) async {
    final l10n = await AppLocalizations.delegate.load(locale);
    final active = fixtureSchedule(l10n: l10n);
    await pumpApp(
      tester,
      const ScheduleScreen(),
      overrides: scheduleOverrides(
        active: active,
        activeIndex: 1,
        otherSteps: <int, ScheduleViewState>{
          0: fixtureSchedule(l10n: l10n, status: StepStatus.completed),
        },
        options: options,
      ),
      locale: locale,
      textScaler: textScaler,
      surfaceSize: size,
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('the step pane appears at 841 and is absent at 839', (
    tester,
  ) async {
    await pumpAt(tester, const Size(839, 1000));
    expect(
      find.byType(StepPane),
      findsNothing,
      reason: 'a phone-width screen grew a second pane',
    );
    expect(find.byType(StepSwitcherButton), findsOneWidget);

    await pumpAt(tester, const Size(841, 1000));
    expect(find.byType(StepPane).hitTestable(), findsOneWidget);
    expect(find.byType(CustomScrollView).hitTestable(), findsWidgets);
    expect(
      find.byType(StepSwitcherButton),
      findsNothing,
      reason: 'the sheet and the pane both offer the same choice',
    );
  });

  testWidgets('both panes read the SAME provider, so one frame updates both', (
    tester,
  ) async {
    final l10n = await pumpAt(tester, const Size(1024, 768));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScheduleScreen)),
    );
    expect(container.read(shownStepIndexProvider), 1);

    await tester.tap(find.text('Step 1 of 2'));
    await tester.pump();

    expect(container.read(shownStepIndexProvider), 0);
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.pastStepReadOnly),
      findsAtLeastNWidgets(1),
      reason: 'the trailing pane did not follow the leading one',
    );
  });

  testWidgets('a landscape phone drops the summary, never the title', (
    tester,
  ) async {
    // Height under 500: the teaching sentence is the first thing to go, and
    // the block's identity is the last.
    final l10n = await pumpAt(tester, const Size(844, 390));

    expect(find.text(l10n.blockOfTotal(3, 11)), findsOneWidget);
    expect(
      find.textContaining('one day at'),
      findsNothing,
      reason: 'the second line survived a 390pt-tall screen',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row is never narrower than the list — a grid by any name', (
    tester,
  ) async {
    for (final size in <Size>[
      const Size(390, 844),
      const Size(839, 1000),
      const Size(1024, 768),
    ]) {
      await pumpAt(tester, size);
      final rows = find.byType(ScheduleDayRow).evaluate().toList();
      expect(rows, isNotEmpty, reason: '$size');

      final widths = rows
          .map((element) => tester.getSize(find.byWidget(element.widget)).width)
          .toSet();
      expect(
        widths,
        hasLength(1),
        reason: 'rows have $widths different widths at $size — that is columns',
      );
      // And they all sit in one column: no two share a horizontal band.
      final tops = rows
          .map((element) => tester.getTopLeft(find.byWidget(element.widget)).dy)
          .toList();
      expect(tops.toSet(), hasLength(tops.length), reason: '$size');
    }
  });

  testWidgets('a row spans the inset, and the breakdown does not wrap', (
    tester,
  ) async {
    // Frame 3 insets the whole list by `s5` and gives the row its own `s3/s4`
    // padding INSIDE that. A second `s4` between the two costs 32pt of row —
    // and 32pt is the difference between "1 × 5mg, 4 × 1mg" on one line and
    // on two, for the app's most ordinary breakdown.
    await pumpAt(tester, const Size(390, 844));
    final shapes = DaybreakShapes.of(
      tester.element(find.byType(ScheduleDayRow).first),
    );

    final row = tester.getSize(find.byType(ScheduleDayRow).first);
    expect(row.width, 390 - shapes.s5 * 2);

    final breakdown = find.textContaining('×').first;
    final rendered = tester.getSize(breakdown);
    final unwrapped = tester
        .renderObject<RenderBox>(breakdown)
        .getMaxIntrinsicWidth(double.infinity);
    expect(
      rendered.width,
      greaterThanOrEqualTo(unwrapped - 0.5),
      reason: 'the breakdown wrapped',
    );
  });

  testWidgets('the state word stays inside the row’s padding', (
    tester,
  ) async {
    // Found on a device, not in a golden. `Row` hands a NON-flexible child
    // unbounded main-axis constraints, so the trailing column took its full
    // intrinsic width and the word ran out past the card's padding and over
    // its border — "NOT TICKED" and "TODAY" both touching the edge. 402pt is
    // an iPhone 16 Pro; the 390pt captures had just enough slack to hide it.
    await pumpAt(tester, const Size(402, 874));
    final shapes = DaybreakShapes.of(
      tester.element(find.byType(ScheduleDayRow).first),
    );

    final rows = find.byType(ScheduleDayRow).evaluate().toList();
    expect(rows, isNotEmpty);
    for (final element in rows) {
      final row = tester.getRect(find.byWidget(element.widget));
      final word = find.descendant(
        of: find.byWidget(element.widget),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.data == widget.data?.toUpperCase(),
        ),
      );
      if (word.evaluate().isEmpty) continue;
      expect(
        tester.getRect(word.first).right,
        lessThanOrEqualTo(row.right - shapes.s4 + 0.5),
        reason: 'the state word runs into the row border',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('two panes at 200% do not clip the teaching sentence', (
    tester,
  ) async {
    // The pinned header's extent is MEASURED, and above the breakpoint the
    // list is 280pt narrower than the screen. Measuring against the screen
    // wraps the sentence onto fewer lines than it takes, the extent comes out
    // too small, and the header clips — at the scale this audience uses.
    // German at 200%, just over the breakpoint: the list is 280pt narrower
    // than the screen and the longest strings in the app are in this locale,
    // which is where the 280pt of measuring error turns into a clipped line.
    await pumpAt(
      tester,
      const Size(880, 1000),
      textScaler: const TextScaler.linear(2),
      locale: const Locale('de'),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(BlockHeader), findsAtLeastNWidgets(1));
  });

  testWidgets('the header still pins on a short screen', (tester) async {
    await pumpAt(tester, const Size(844, 390));

    expect(find.byType(SliverPersistentHeader), findsWidgets);
    for (final header in tester.widgetList<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    )) {
      expect(header.pinned, isTrue);
    }
    expect(find.byType(BlockHeader), findsAtLeastNWidgets(1));
  });
}
