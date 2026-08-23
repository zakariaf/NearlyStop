// Every recipe against the platform accessibility guidelines, in one place.
//
// The per-component suites assert what each one MEANS — the shapes, the words,
// the degradation boundaries. This file asserts the floors that apply to all
// of them, and it does so as a table so a thirteenth recipe added without a
// row here is a recipe with no guideline coverage.
//
// Four guidelines, and they check different things:
//
// * `androidTapTargetGuideline` — 48x48.
// * `iOSTapTargetGuideline` — 44x44.
// * `labeledTapTargetGuideline` — every tappable node has a LABEL. This is the
//   one that catches an `ExcludeSemantics` swallowing a button, which is a
//   real defect this epic shipped and fixed.
// * `textContrastGuideline` — 4.5:1 against the composited background, which
//   is stronger than measuring a slot against a nominal surface: it sees the
//   tint the component actually painted underneath.
//
// Run at 1.0 AND 2.0, because a target that clears 48 at 1.0 can be pushed
// under it by a neighbour that grew.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/features/plan/presentation/widgets/method_segmented_control.dart';
import 'package:nearlystop/features/plan/presentation/widgets/strength_chip.dart';
import 'package:nearlystop/features/progress/presentation/widgets/progress_stat_block.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_row.dart';
import 'package:nearlystop/features/shared/presentation/widgets/backfill_banner.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tab_bar.dart';
import 'package:nearlystop/features/shared/presentation/widgets/taper_empty_state.dart';
import 'package:nearlystop/features/shared/presentation/widgets/undo_row.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_hero_card.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/disclaimer_sheet.dart';

import '../support/harness.dart';

/// One recipe under test, by its number in the epic's table.
typedef Recipe = ({int number, String name, Widget Function() build});

void main() {
  const recipes = <Recipe>[
    (number: 1, name: 'DoseHeroCard', build: _heroCard),
    (number: 2, name: 'DayStateRow', build: _dayStateRows),
    (number: 3, name: 'BlockHeader', build: _blockHeader),
    (number: 4, name: 'button ladder', build: _buttonLadder),
    (number: 5, name: 'StrengthChipGroup', build: _chips),
    (number: 6, name: 'MethodSegmentedControl', build: _methodControl),
    (number: 7, name: 'DaybreakTabBar', build: _tabBar),
    (number: 7, name: 'DaybreakNavigationRail', build: _rail),
    (number: 8, name: 'BackfillBanner', build: _banner),
    (number: 9, name: 'ProgressStatBlock', build: _statBlock),
    (number: 10, name: 'DisclaimerSheet', build: _disclaimer),
    (number: 11, name: 'TaperEmptyState', build: _emptyState),
    (number: 12, name: 'ConfirmSheet', build: _confirmSheet),
    (number: 12, name: 'UndoRow', build: _undoRow),
  ];

  for (final recipe in recipes) {
    for (final locale in <Locale>[const Locale('en'), const Locale('fa')]) {
      for (final scale in <double>[1, 2]) {
        final label =
            'recipe ${recipe.number} ${recipe.name} — '
            '${locale.languageCode} at $scale';
        testWidgets(label, (tester) async {
          final handle = tester.ensureSemantics();
          await pumpApp(
            tester,
            Material(
              child: SingleChildScrollView(child: recipe.build()),
            ),
            locale: locale,
            textScaler: TextScaler.linear(scale),
            surfaceSize: const Size(390, 844),
          );

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(tester.takeException(), isNull);
          handle.dispose();
        });
      }
    }
  }
}

Widget _heroCard() => const DoseHeroCard(
  doseText: '9',
  unitText: 'mg',
  tabletsText: '1 × 5mg · 4 × 1mg',
  dateText: 'Thursday 16 April',
  dayKindLabel: 'New dose day',
  semanticsLabel: 'Today, 9 milligrams. Not yet taken.',
  takenLabel: 'Mark as taken',
  isTaken: false,
  onTaken: _noop,
);

Widget _dayStateRows() => Column(
  mainAxisSize: MainAxisSize.min,
  children: <Widget>[
    for (final state in DayState.values)
      DayStateRow(
        state: state,
        weekdayText: 'Thursday',
        dateText: '16 April',
        doseText: '9mg',
        tabletsText: '1 × 5mg · 4 × 1mg',
        stateLabel: switch (state) {
          DayState.taken => 'Taken',
          DayState.missed => 'Not ticked',
          DayState.today => 'Today',
          DayState.upcoming => 'Upcoming',
        },
        semanticsLabel: 'Thursday 16 April, 9 milligrams.',
        isNewDose: state == DayState.today,
        newDoseLabel: 'New dose day',
      ),
  ],
);

Widget _blockHeader() => const BlockHeader(
  title: 'Block 3 of 11',
  doseSummary: 'one day at 9mg, then 4 days at 10mg',
  semanticsLabel: 'Block 3 of 11 — one day at 9mg, then 4 days at 10mg',
  isCurrent: true,
  isCompleted: true,
  completedLabel: 'Completed',
);

Widget _buttonLadder() => const Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: <Widget>[
    PrimaryPillButton(label: 'Next step', expand: true, onPressed: _noop),
    SizedBox(height: 8),
    SecondaryButton(label: 'Add note', expand: true, onPressed: _noop),
    SizedBox(height: 8),
    TertiaryButton(label: 'Hold', onPressed: _noop),
    SizedBox(height: 8),
    DestructiveButton(
      label: 'Delete plan',
      expand: true,
      confirm: ConfirmRequest(
        title: 'Delete this plan?',
        body: 'Your history and your total are kept.',
        confirmLabel: 'Delete plan',
        cancelLabel: 'Cancel',
      ),
      onConfirmed: _noop,
    ),
    SizedBox(height: 8),
    TakenButton(label: 'Mark as taken', onPressed: _noop),
    SizedBox(height: 8),
    // Disabled, because "changes fill AND says the word" has to clear contrast
    // too — a disabled label nobody can read is not an improvement on one
    // nobody can hear.
    PrimaryPillButton(label: 'Next step', expand: true, onPressed: null),
  ],
);

Widget _chips() => const StrengthChipGroup(
  chips: <({String label, String value})>[
    (label: '0.5mg', value: '0.5'),
    (label: '1mg', value: '1'),
    (label: '2.5mg', value: '2.5'),
    (label: '5mg', value: '5'),
  ],
  selected: <String>{'1', '5'},
  onSelected: _noopString,
);

Widget _methodControl() => const MethodSegmentedControl(
  value: TaperMethod.dsns,
  labels: <TaperMethod, String>{
    TaperMethod.dsns: 'Dead Slow and Nearly Stop',
    TaperMethod.percentage: 'Percentage',
    TaperMethod.fixedMg: 'Fixed mg',
  },
  onChanged: _noopMethod,
);

const _destinations = <DaybreakDestination>[
  DaybreakDestination(
    label: 'Today',
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny,
  ),
  DaybreakDestination(
    label: 'Schedule',
    icon: Icons.view_agenda_outlined,
    selectedIcon: Icons.view_agenda,
  ),
  DaybreakDestination(
    label: 'Progress',
    icon: Icons.trending_down_outlined,
    selectedIcon: Icons.trending_down,
  ),
  DaybreakDestination(
    label: 'Plan',
    icon: Icons.medication_outlined,
    selectedIcon: Icons.medication,
  ),
  DaybreakDestination(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

Widget _tabBar() => const DaybreakTabBar(
  destinations: _destinations,
  selectedIndex: 0,
  onDestinationSelected: _noopInt,
);

Widget _rail() => const Row(
  children: <Widget>[
    DaybreakNavigationRail(
      destinations: _destinations,
      selectedIndex: 3,
      onDestinationSelected: _noopInt,
    ),
  ],
);

Widget _banner() => const BackfillBanner(
  message: "You haven't marked the last 3 days.",
  primaryActionLabel: 'Mark them now',
  onPrimaryAction: _noop,
  secondaryActionLabel: 'Not now',
  onSecondaryAction: _noop,
);

Widget _statBlock() => const ProgressStatBlock(
  overline: 'Adherence',
  value: '341',
  unit: 'taken 341 of 350 days',
);

Widget _disclaimer() => const SizedBox(
  height: 560,
  child: DisclaimerSheet(
    title: 'Welcome to NearlyStop',
    body:
        'NearlyStop arranges the plan you and your doctor agreed. It does not '
        'give medical advice. Always follow the instructions you were given.',
    actionLabel: 'I understand',
    isGate: true,
    onAccept: _noop,
    onClose: _noop,
  ),
);

Widget _emptyState() => const SizedBox(
  height: 700,
  child: TaperEmptyState(
    heading: 'Your plan starts here',
    message: 'Add the plan you and your doctor agreed.',
    actionLabel: 'Set up my plan',
    onAction: _noop,
  ),
);

Widget _confirmSheet() => const ConfirmSheet(
  request: ConfirmRequest(
    title: 'Delete this plan?',
    body: 'Your history and your total are kept.',
    confirmLabel: 'Delete plan',
    cancelLabel: 'Cancel',
  ),
);

Widget _undoRow() => const UndoRow(
  message: 'Marked Thursday as taken.',
  undoLabel: 'Undo',
  onUndo: _noop,
  dismissLabel: 'Close',
  onDismiss: _noop,
);

void _noop() {}

void _noopInt(int index) {}

void _noopString(String value) {}

void _noopMethod(TaperMethod method) {}
