@Tags(<String>['golden'])
library;

// The twelve recipes on one page — the PR's parity evidence.
//
// Not a substitute for the per-recipe sheets, which is where a single
// component's states are compared. This one answers the question a reviewer
// actually asks about a component-library PR: do these twelve read as one
// family, in both themes, and does anything look wrong beside its neighbours.
//
// Tagged `golden` and excluded from the default CI lane for the reason EPIC-02
// set out: authored on macOS, and a gate that goes red for the host gets
// switched off.
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
import 'package:nearlystop/features/shared/presentation/widgets/undo_row.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_hero_card.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    final name = 'contact_sheet_${brightness.name}';
    testWidgets(name, (tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ColoredBox(
            color: DaybreakColors.of(context).bg,
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 1 — dose hero card
                  const DoseHeroCard(
                    doseText: '9',
                    unitText: 'mg',
                    tabletsText: '1 × 5mg · 4 × 1mg',
                    unachievableMessage: null,
                    dateText: 'Thursday 16 April',
                    dayKindLabel: 'New dose day',
                    isNewDoseDay: true,
                    semanticsLabel: 'Today, 9 milligrams.',
                    takenLabel: 'Mark as taken',
                    isTaken: false,
                    onTaken: _noop,
                    onUndo: _noop,
                  ),
                  const SizedBox(height: 14),
                  // 3 — block header
                  const BlockHeader(
                    title: 'Block 3 of 11',
                    doseSummary: 'one day at 9mg, then 4 days at 10mg',
                    semanticsLabel: 'Block 3 of 11',
                    isCurrent: true,
                    isCompleted: false,
                  ),
                  const SizedBox(height: 8),
                  // 2 — the four day states
                  for (final state in DayState.values) ...<Widget>[
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
                      semanticsLabel: 'x',
                    ),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 8),
                  // 4 — the ladder
                  const PrimaryPillButton(
                    label: 'Next step',
                    expand: true,
                    onPressed: _noop,
                  ),
                  const SizedBox(height: 8),
                  const SecondaryButton(
                    label: 'Add note',
                    expand: true,
                    onPressed: _noop,
                  ),
                  const SizedBox(height: 8),
                  const TertiaryButton(label: 'Hold', onPressed: _noop),
                  const SizedBox(height: 8),
                  const DestructiveButton(
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
                  const SizedBox(height: 14),
                  // 5 — strength chips
                  const StrengthChipGroup(
                    chips: <({String label, String value})>[
                      (label: '1mg', value: '1'),
                      (label: '2.5mg', value: '2.5'),
                      (label: '5mg', value: '5'),
                    ],
                    selected: <String>{'1', '5'},
                    onSelected: _noopString,
                  ),
                  const SizedBox(height: 14),
                  // 6 — method segmented control
                  const MethodSegmentedControl(
                    value: TaperMethod.dsns,
                    labels: <TaperMethod, String>{
                      TaperMethod.dsns: 'DSNS',
                      TaperMethod.percentage: 'Percentage',
                      TaperMethod.fixedMg: 'Fixed mg',
                    },
                    onChanged: _noopMethod,
                  ),
                  const SizedBox(height: 14),
                  // 8 — backfill banner
                  const BackfillBanner(
                    message: "You haven't marked the last 3 days.",
                    primaryActionLabel: 'Mark them now',
                    onPrimaryAction: _noop,
                    secondaryActionLabel: 'Not now',
                    onSecondaryAction: _noop,
                  ),
                  const SizedBox(height: 14),
                  // 12b — undo row
                  const UndoRow(
                    message: 'Marked Thursday as taken.',
                    undoLabel: 'Undo',
                    onUndo: _noop,
                    dismissLabel: 'Close',
                    onDismiss: _noop,
                  ),
                  const SizedBox(height: 14),
                  // 9 — progress stat block
                  const ProgressStatBlock(
                    overline: 'Adherence',
                    value: '341',
                    unit: 'taken 341 of 350 days',
                  ),
                  const SizedBox(height: 14),
                  // 7 — tab bar
                  const DaybreakTabBar(
                    destinations: <DaybreakDestination>[
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
                    ],
                    selectedIndex: 0,
                    onDestinationSelected: _noopInt,
                  ),
                ],
              ),
            ),
          ),
        ),
        brightness: brightness,
        surfaceSize: const Size(390, 2100),
      );

      await expectLater(
        find.byType(ColoredBox).first,
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }
}

void _noop() {}

void _noopInt(int index) {}

void _noopString(String value) {}

void _noopMethod(TaperMethod method) {}
