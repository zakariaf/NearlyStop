// Getting back to today, and browsing other steps read-only.
//
// The jump control's contract is BOTH transitions: a control that appears once
// and then stays is a control the reader learns to ignore.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/jump_to_today_button.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_day_row.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/step_switcher_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../support/harness.dart';
import 'support/schedule_fixture.dart';

void main() {
  const phone = Size(390, 844);

  setUpAll(initializeDateFormatting);

  late ProviderContainer container;

  /// Pumps the screen over fixed states for the active step and one before it.
  Future<AppLocalizations> pumpSchedule(
    WidgetTester tester, {
    String? focus,
    bool disableAnimations = false,
    Map<LocalDate, int>? focusDates,
  }) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final active = fixtureSchedule(l10n: l10n);
    final past = fixtureSchedule(
      l10n: l10n,
      today: const LocalDate(2027, 1, 1),
      status: StepStatus.completed,
    );
    await pumpApp(
      tester,
      ScheduleScreen(focus: focus),
      overrides: scheduleOverrides(
        active: active,
        activeIndex: 1,
        otherSteps: <int, ScheduleViewState>{0: past},
        options: const <StepOption>[
          StepOption(
            index: 0,
            label: 'Step 1 of 2 — 15mg to 14mg',
            status: StepStatus.completed,
          ),
          StepOption(
            index: 1,
            label: 'Step 2 of 2 — 10mg to 9mg',
            status: StepStatus.active,
          ),
        ],
        focusDates: focusDates,
      ),
      disableAnimations: disableAnimations,
      surfaceSize: phone,
    );
    // The overrides emit through a stream, so the first value lands a
    // microtask after the first frame.
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(ScheduleScreen)),
    );
    return l10n;
  }

  /// Whether [finder]'s box overlaps the scroll view's box.
  ///
  /// The question `hitTestable` cannot answer for a read-only row: those are
  /// deliberately not tap targets, so hit-testability would be false for the
  /// very reason the row is right.
  bool onScreen(WidgetTester tester, Finder finder) {
    if (finder.evaluate().isEmpty) return false;
    final viewport = tester.getRect(find.byType(CustomScrollView));
    return viewport.overlaps(tester.getRect(finder));
  }

  Future<void> dragBy(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(Scrollable), Offset(0, dy));
    // Two frames: the control is driven by a scroll LISTENER, so its
    // `setState` lands on the frame after the one that moved the list. In
    // production that is 16ms and nobody sees it.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the jump control appears and DISAPPEARS again', (tester) async {
    await pumpSchedule(tester);

    expect(
      find.byType(JumpToTodayButton),
      findsNothing,
      reason: 'today is on screen — there is nothing to jump to',
    );

    await dragBy(tester, -2000);
    expect(find.byType(JumpToTodayButton), findsOneWidget);

    await dragBy(tester, 2000);
    expect(
      find.byType(JumpToTodayButton),
      findsNothing,
      reason: 'the control appeared once and then stayed',
    );
  });

  testWidgets(
    'tapping it brings today back, in ONE frame under reduced motion',
    (tester) async {
      final l10n = await pumpSchedule(tester, disableAnimations: true);
      final today = fixtureSchedule(l10n: l10n).blocks
          .expand((block) => block.days)
          .firstWhere((day) => day.date == fixtureToday)
          .dayLabel;

      await dragBy(tester, -2000);
      expect(find.text(today).hitTestable(), findsNothing);

      await tester.tap(find.byType(JumpToTodayButton));
      // ONE pump, not `pumpAndSettle`: `resolveMotion` collapses the animation
      // to a jump when the OS asks for reduced motion, and a settle would pass
      // either way.
      await tester.pump();

      expect(find.text(today).hitTestable(), findsOneWidget);
    },
  );

  testWidgets('from a browsed step it returns to the ACTIVE one first', (
    tester,
  ) async {
    final l10n = await pumpSchedule(tester);
    container.read(browsedStepProvider.notifier).show(0);
    await tester.pumpAndSettle();
    expect(container.read(shownStepIndexProvider), 0);

    // A completed step has no today in it, so the control is showing from the
    // first frame.
    expect(find.byType(JumpToTodayButton), findsOneWidget);
    await tester.tap(find.byType(JumpToTodayButton));
    await tester.pumpAndSettle();

    expect(container.read(shownStepIndexProvider), 1);
    final today = fixtureSchedule(l10n: l10n).blocks
        .expand((block) => block.days)
        .firstWhere((day) => day.date == fixtureToday)
        .dayLabel;
    expect(find.text(today).hitTestable(), findsOneWidget);
  });

  testWidgets('the switcher lists every step and selects one', (tester) async {
    final l10n = await pumpSchedule(tester);

    await tester.tap(find.byKey(StepSwitcherButton.buttonKey));
    await tester.pumpAndSettle();

    expect(find.text(l10n.stepSwitcherTitle), findsOneWidget);
    expect(find.text('Step 1 of 2 — 15mg to 14mg'), findsOneWidget);
    expect(find.text('Step 2 of 2 — 10mg to 9mg'), findsOneWidget);

    await tester.tap(find.text('Step 1 of 2 — 15mg to 14mg'));
    await tester.pumpAndSettle();

    expect(container.read(shownStepIndexProvider), 0);
  });

  testWidgets('a completed step says so, and none of its rows can be tapped', (
    tester,
  ) async {
    final l10n = await pumpSchedule(tester);
    container.read(browsedStepProvider.notifier).show(0);
    await tester.pumpAndSettle();

    expect(find.text(l10n.pastStepReadOnly), findsAtLeastNWidgets(1));
    for (final row in tester.widgetList<ScheduleDayRow>(
      find.byType(ScheduleDayRow),
    )) {
      expect(
        find.descendant(
          of: find.byWidget(row),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('?focus=<a date> opens on that date’s STEP and row', (
    tester,
  ) async {
    // The step matters as much as the row: EPIC-08's backfill banner targets
    // the oldest outstanding day, which can sit in a step the reader is not
    // currently browsing. Landing on the right date in the wrong step shows
    // them a day with the same name and a different history.
    final l10n = await pumpSchedule(
      tester,
      focus: '2026-04-06',
      focusDates: <LocalDate, int>{const LocalDate(2026, 4, 6): 0},
    );
    await tester.pumpAndSettle();
    final focused = fixtureSchedule(l10n: l10n).blocks
        .expand((block) => block.days)
        .firstWhere((day) => day.date == const LocalDate(2026, 4, 6))
        .dayLabel;

    expect(
      container.read(shownStepIndexProvider),
      0,
      reason: 'the deep link landed on the wrong step',
    );
    // On screen, not hit-testable: a completed step's rows are deliberately
    // not tap targets (task 5), so `hitTestable` is the wrong question to ask
    // of one — it would fail for the reason the row is CORRECT.
    expect(
      onScreen(tester, find.text(focused)),
      isTrue,
      reason: 'the deep link did not land on its day',
    );
  });

  testWidgets('a nonsense ?focus falls back to today rather than throwing', (
    tester,
  ) async {
    // A deep link is user input. Both arms: unparseable, and a valid date the
    // plan has never heard of.
    for (final focus in <String>['not-a-date', '1999-01-01', '']) {
      final l10n = await pumpSchedule(tester, focus: focus);
      final today = fixtureSchedule(l10n: l10n).blocks
          .expand((block) => block.days)
          .firstWhere((day) => day.date == fixtureToday)
          .dayLabel;

      expect(tester.takeException(), isNull, reason: focus);
      expect(find.text(today).hitTestable(), findsOneWidget, reason: focus);
    }
  });

  testWidgets('the chevron mirrors itself and the curve comes from the theme', (
    tester,
  ) async {
    await pumpSchedule(tester);

    // `Icons.adaptive.arrow_forward` RESOLVES to `Icons.arrow_forward` off
    // iOS, so the rendered glyph cannot distinguish the two. The source can.
    expect(find.byIcon(Icons.adaptive.arrow_forward), findsOneWidget);
    final sources = Directory('lib/features/schedule')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    expect(sources, isNotEmpty);
    for (final file in sources) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(matches(RegExp(r'Icons\.(arrow_forward|arrow_back)\b'))),
        reason: '${file.path} uses a chevron that does not mirror in RTL',
      );
      expect(
        source,
        isNot(contains('Curves.')),
        reason: '${file.path} reaches past DaybreakMotion for a curve',
      );
    }
  });
}
