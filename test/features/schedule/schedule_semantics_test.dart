// Rows and headers that read as sentences.
//
// The sentences are COPY decisions, so they are written here as literals
// before the tree exists. A screen-reader user traverses 52 days on this
// screen; six fragments per row is 312 stops.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_day_row.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../support/harness.dart';
import 'support/schedule_fixture.dart';

void main() {
  setUpAll(initializeDateFormatting);

  ScheduleDayVm vm({
    DayState state = DayState.taken,
    bool tickable = true,
    String? holdLabel,
    int? holdBlockNumber = 3,
    bool isNewDose = false,
    bool isToday = false,
    String dayLabel = 'Wed, Apr 16',
  }) => ScheduleDayVm(
    date: const LocalDate(2026, 4, 16),
    dayLabel: dayLabel,
    doseLabel: '9mg',
    spokenDose: '9',
    tabletsLabel: '1 × 5mg · 4 × 1mg',
    unachievable: false,
    state: isToday ? DayState.today : state,
    isNewDose: isNewDose,
    isHoldDay: holdLabel != null,
    holdLabel: holdLabel,
    holdBlockNumber: holdLabel == null ? null : holdBlockNumber,
    tickable: tickable,
    plannedMg: const Milligrams.fromHundredths(900),
    recordedSource: state == DayState.taken && !isToday,
  );

  Future<(AppLocalizations, SemanticsNode)> pumpRow(
    WidgetTester tester,
    ScheduleDayVm day, {
    Locale locale = const Locale('en'),
    bool tappable = true,
  }) async {
    late AppLocalizations l10n;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return Align(
            alignment: Alignment.topCenter,
            child: Material(
              child: ScheduleDayRow(
                day: day,
                onToggle: tappable ? (_) {} : null,
              ),
            ),
          );
        },
      ),
      locale: locale,
      surfaceSize: const Size(390, 500),
    );
    return (l10n, tester.getSemantics(find.byType(ScheduleDayRow)));
  }

  testWidgets('a taken row is ONE node, read as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    final (l10n, node) = await pumpRow(tester, vm());

    expect(
      node.label,
      l10n.scheduleDaySemantics(
        'Wed, Apr 16',
        '9',
        '1 × 5mg · 4 × 1mg',
        l10n.scheduleNoteState(l10n.stateTaken),
      ),
    );
    // ONE node: six fragments is six rotor stops per day, 312 for a step.
    var descendants = 0;
    node.visitChildren((_) {
      descendants++;
      return true;
    });
    expect(descendants, 0, reason: 'the row is $descendants nodes, not one');
    handle.dispose();
  });

  testWidgets('today’s row says so FIRST', (tester) async {
    final handle = tester.ensureSemantics();
    final (l10n, node) = await pumpRow(tester, vm(isToday: true));

    expect(
      node.label,
      l10n.scheduleTodaySemantics(
        'Wed, Apr 16',
        '9',
        '1 × 5mg · 4 × 1mg',
        l10n.scheduleNoteState(l10n.stateToday),
      ),
    );
    expect(
      node.label,
      startsWith('Today.'),
      reason: 'today is buried in the middle of the sentence',
    );
    handle.dispose();
  });

  testWidgets('a hold row explains the run of look-alike days', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (l10n, node) = await pumpRow(
      tester,
      vm(holdLabel: 'Held at block 3'),
    );

    expect(node.label, contains(l10n.scheduleNoteHeld(3).trim()));
    expect(
      node.label,
      contains(l10n.stateTaken),
      reason: 'the hold clause ate the state',
    );
    expect(node.label, isNot(contains('52')));
    handle.dispose();
  });

  testWidgets('the same two sentences in fa, from the ARB', (tester) async {
    final handle = tester.ensureSemantics();
    final (fa, node) = await pumpRow(
      tester,
      vm(holdLabel: 'نگه‌داشته'),
      locale: const Locale('fa'),
    );

    expect(node.label, contains(fa.scheduleNoteHeld(3).trim()));
    expect(node.label, contains(fa.stateTaken));
    expect(
      node.label,
      isNot(contains('milligrams')),
      reason: 'an English fragment leaked into the Persian sentence',
    );
    handle.dispose();
  });

  testWidgets('tickable rows are buttons; read-only rows carry the reason', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (_, tickable) = await pumpRow(tester, vm());
    expect(tickable, isSemantics(isButton: true));

    final (l10n, readOnly) = await pumpRow(
      tester,
      vm(tickable: false),
      tappable: false,
    );
    expect(readOnly, isSemantics(isButton: false));
    expect(readOnly.getSemanticsData().hint, contains(l10n.pastStepReadOnly));
    handle.dispose();
  });

  testWidgets('every block header is a HEADING, so the rotor jumps blocks', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      const ScheduleScreen(),
      overrides: scheduleOverrides(active: fixtureSchedule(l10n: l10n)),
      surfaceSize: const Size(390, 844),
    );
    await tester.pumpAndSettle();

    final headers = find.byType(BlockHeader).evaluate();
    expect(headers, isNotEmpty);
    for (final element in headers) {
      expect(
        tester.getSemantics(find.byWidget(element.widget)),
        isSemantics(isHeader: true),
        reason: '${(element.widget as BlockHeader).title} is not a heading',
      );
    }
    handle.dispose();
  });

  testWidgets('the whole screen clears the guidelines at 1.0 and at 2.0', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    for (final scale in <double>[1, 2]) {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const ScheduleScreen(),
        overrides: scheduleOverrides(active: fixtureSchedule(l10n: l10n)),
        textScaler: TextScaler.linear(scale),
        surfaceSize: const Size(390, 844),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull, reason: 'at ${scale}x');
      handle.dispose();
    }
  });
}
