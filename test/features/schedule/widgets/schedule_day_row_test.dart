// The Schedule's row: what a tap does, and what a hold day says.
//
// The four states, their shapes, their words and their colours are EPIC-07's
// `DayStateRow` and are tested there. What is new here is the wrapper: the tap
// contract, the read-only treatment, and the hold-day channel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_marker.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_row.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_day_row.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../../support/harness.dart';

void main() {
  const date = LocalDate(2026, 4, 16);

  ScheduleDayVm vm({
    DayState state = DayState.upcoming,
    bool tickable = true,
    bool isHoldDay = false,
    String? holdLabel,
    bool isNewDose = false,
    bool unachievable = false,
  }) => ScheduleDayVm(
    date: date,
    dayLabel: 'Thu, Apr 16',
    doseLabel: '9mg',
    tabletsLabel: unachievable
        ? 'Cannot be made from the tablets you hold: 9mg'
        : '1 × 5mg · 4 × 1mg',
    unachievable: unachievable,
    state: state,
    isNewDose: isNewDose,
    isHoldDay: isHoldDay,
    holdLabel: holdLabel,
    tickable: tickable,
    plannedMg: const Milligrams.fromHundredths(900),
    recordedSource: state == DayState.taken,
  );

  Future<AppLocalizations> pumpRow(
    WidgetTester tester,
    ScheduleDayVm day, {
    ValueChanged<ScheduleDayVm>? onToggle,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
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
              child: ScheduleDayRow(day: day, onToggle: onToggle),
            ),
          );
        },
      ),
      locale: locale,
      textScaler: textScaler,
      surfaceSize: const Size(390, 500),
    );
    return l10n;
  }

  testWidgets('tapping a tickable row reports THAT row, once', (tester) async {
    final taps = <ScheduleDayVm>[];
    await pumpRow(tester, vm(), onToggle: taps.add);

    await tester.tap(find.byType(ScheduleDayRow));
    await tester.pump();

    expect(taps, hasLength(1));
    expect(taps.single.date, date);
    // Never a `SnackBar`: it times out before this reader finishes reading it,
    // and what it reports is a change to their medication record.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a read-only row is not a tap target AT ALL', (tester) async {
    // A dead target that ripples and does nothing is worse than no target: it
    // teaches the reader the app is broken. The reason goes in the semantics
    // instead of in a tap that goes nowhere.
    final l10n = await pumpRow(
      tester,
      vm(tickable: false),
      onToggle: (_) => fail('a read-only row fired its callback'),
    );

    expect(
      find.descendant(
        of: find.byType(ScheduleDayRow),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ScheduleDayRow),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(ScheduleDayRow)).getSemanticsData().hint,
      contains(l10n.pastStepReadOnly),
    );
    handle.dispose();
  });

  testWidgets('a row with no callback is inert even when tickable', (
    tester,
  ) async {
    await pumpRow(tester, vm());

    expect(
      find.descendant(
        of: find.byType(ScheduleDayRow),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('a hold day says it is held, and STILL says taken', (
    tester,
  ) async {
    // A hold repeats its host day, so five look-alike rows appear in a row.
    // The chip is what explains them.
    //
    // It is a CHIP, not a replacement state. The epic asks for the tread
    // marker and the word "Held" in the trailing column where the state word
    // sits — which would take both the shape channel and the word channel away
    // from taken/not-taken for up to 28 consecutive days, on rows whose whole
    // job is answering "did I take it?". `isNewDose` already established the
    // pattern for exactly this: a separate channel beside the state, never a
    // fifth member of it (CONTRACTS.md §1).
    final l10n = await pumpRow(
      tester,
      vm(
        state: DayState.taken,
        isHoldDay: true,
        holdLabel: 'Held at block 3',
      ),
      onToggle: (_) {},
    );

    expect(find.byIcon(DayStateRow.holdGlyph), findsOneWidget);
    expect(find.text(l10n.heldAtBlock(3)), findsOneWidget);
    expect(
      find.text(l10n.stateTaken),
      findsOneWidget,
      reason: 'the hold chip ate the state word',
    );
    // The marker still carries the state's shape.
    expect(find.byType(DayStateMarker), findsOneWidget);
    expect(
      tester.widget<DayStateMarker>(find.byType(DayStateMarker)).state,
      DayState.taken,
    );
    expect(find.textContaining('52'), findsNothing);
  });

  testWidgets('a hold on a day with no block says just “held”', (
    tester,
  ) async {
    // A hold can land on a steady-state day, which belongs to no block. Naming
    // a block there would be a made-up number.
    final l10n = await pumpRow(
      tester,
      vm(isHoldDay: true, holdLabel: 'Held'),
      onToggle: (_) {},
    );

    expect(find.text(l10n.held), findsOneWidget);
    expect(find.textContaining('block'), findsNothing);
  });

  testWidgets('an ordinary day has no hold chip', (tester) async {
    final l10n = await pumpRow(tester, vm(), onToggle: (_) {});

    expect(find.byIcon(DayStateRow.holdGlyph), findsNothing);
    expect(find.text(l10n.held), findsNothing);
  });

  testWidgets('an unachievable dose shows the warning, not a number', (
    tester,
  ) async {
    await pumpRow(tester, vm(unachievable: true), onToggle: (_) {});

    expect(
      find.text('Cannot be made from the tablets you hold: 9mg'),
      findsOneWidget,
    );
    expect(
      find.text('9mg'),
      findsNothing,
      reason: 'a number beside "cannot be made" invites them to take it',
    );
  });

  testWidgets(
    'every state gets a different WORD, so colour alone cannot pass',
    (
      tester,
    ) async {
      final words = <String>{};
      for (final state in DayState.values) {
        final l10n = await pumpRow(tester, vm(state: state), onToggle: (_) {});
        words.add(ScheduleDayRow.stateWord(l10n, state));
        expect(
          find.text(ScheduleDayRow.stateWord(l10n, state)),
          findsOneWidget,
        );
      }
      expect(words, hasLength(DayState.values.length));
    },
  );

  testWidgets('the row clears 44 at 2.0 with the hold chip on it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpRow(
      tester,
      vm(state: DayState.taken, isHoldDay: true, holdLabel: 'Held at block 3'),
      onToggle: (_) {},
      textScaler: const TextScaler.linear(2),
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
