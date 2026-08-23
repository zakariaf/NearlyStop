// One step's blocks, and the SPEC.md §5.2 join.
//
// The join is the correctness rule this screen exists to get right. EPIC-04's
// generator recomposes EVERY day from the plan's CURRENT strengths, past
// included — so a Schedule that renders past rows from the `DayPlan` silently
// rewrites every day the person already swallowed the moment the prescription
// changes. Presentation joins; it does not overwrite.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

void main() {
  const start = LocalDate(2026, 4, 1);
  const today = LocalDate(2026, 4, 16);
  const fives = <TabletStrength>[
    TabletStrength.fromHundredths(500),
    TabletStrength.fromHundredths(100),
  ];
  const halves = <TabletStrength>[
    TabletStrength.fromHundredths(250),
    TabletStrength.fromHundredths(100),
  ];

  late AppLocalizations en;
  setUpAll(() async {
    await initializeDateFormatting();
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  DayPlan dayWith({
    required LocalDate date,
    required int blockIndex,
    Milligrams dose = const Milligrams.fromHundredths(1000),
    bool isHoldDay = false,
    int? dayInStep,
    List<TabletStrength> strengths = fives,
  }) => DayPlan(
    date: date,
    stepIndex: 0,
    kind: DayKind.step,
    blockIndex: blockIndex,
    dayInBlock: 1,
    dayInStep: dayInStep ?? 1,
    dose: dose,
    doseKind: DoseKind.oldDose,
    composition: composeTablets(
      target: dose,
      strengths: strengths,
      allowHalves: true,
    ),
    isHoldDay: isHoldDay,
  );

  TaperSnapshot snapshotWith({
    List<DoseLogFacts> logs = const <DoseLogFacts>[],
    List<TabletStrength> strengths = fives,
    StepStatus status = StepStatus.active,
  }) => TaperSnapshot(
    plan: TaperPlanFacts(
      drugName: 'Prednisolone',
      startDate: start,
      startingDose: const Milligrams.fromHundredths(1000),
      targetDose: Milligrams.zero,
      tabletStrengths: strengths,
      allowHalves: true,
      method: TaperMethod.dsns,
      holdPeriodDays: 0,
    ),
    steps: <StepFacts>[
      StepFacts(
        id: 1,
        index: 0,
        fromDose: const Milligrams.fromHundredths(1000),
        toDose: const Milligrams.fromHundredths(900),
        startDate: start,
        status: status,
        patternVersion: 1,
      ),
    ],
    logs: logs,
    flares: const <FlareEvent>[],
    holds: const <HoldEvent>[],
    statusByStepId: <int, StepStatus>{1: status},
  );

  ScheduleViewState project({
    required List<DayPlan> schedule,
    TaperSnapshot? snapshot,
  }) => ScheduleNotifier.project(
    snapshot: snapshot ?? snapshotWith(),
    schedule: schedule,
    stepIndex: 0,
    today: today,
    l10n: en,
    locale: const Locale('en'),
  );

  test('SPEC 5.2: changing the strengths does NOT rewrite a taken day', () {
    // The defect: the person took one 5mg and four 1mg tablets. Their doctor
    // changes the prescription to 2.5mg tablets. If the row renders from the
    // DayPlan, that day now claims they took four 2.5mg — a breakdown they
    // never held, on a record they may hand to a clinician.
    final past = today.addDays(-2);
    final future = today.addDays(2);
    final schedule = <DayPlan>[
      dayWith(date: past, blockIndex: 1),
      dayWith(date: today, blockIndex: 1),
      dayWith(date: future, blockIndex: 1),
    ];
    final logs = <DoseLogFacts>[
      const DoseLogFacts(
        date: LocalDate(2026, 4, 14),
        plannedMg: Milligrams.fromHundredths(1000),
        actualMg: Milligrams.fromHundredths(1000),
        taken: true,
      ),
    ];

    final before =
        project(
              schedule: schedule,
              snapshot: snapshotWith(logs: logs),
            )
            as ScheduleLoaded;
    final takenBefore = _rowFor(before, past);
    final futureBefore = _rowFor(before, future);

    // The prescription changes. The generator recomposes EVERY day from it.
    final recomposed = <DayPlan>[
      for (final day in schedule)
        dayWith(
          date: day.date,
          blockIndex: day.blockIndex!,
          dose: day.dose,
          strengths: halves,
        ),
    ];
    final after =
        project(
              schedule: recomposed,
              snapshot: snapshotWith(logs: logs, strengths: halves),
            )
            as ScheduleLoaded;

    expect(
      _rowFor(after, past).tabletsLabel,
      takenBefore.tabletsLabel,
      reason: 'a day already swallowed rewrote itself',
    );
    expect(_rowFor(after, past).doseLabel, takenBefore.doseLabel);
    // And the other half: a FUTURE day must recompose, or the change did
    // nothing.
    expect(
      _rowFor(after, future).tabletsLabel,
      isNot(futureBefore.tabletsLabel),
      reason: 'the new strengths never reached the days ahead',
    );
  });

  test('every generated date lands in exactly one block', () {
    final schedule = <DayPlan>[
      for (var offset = 0; offset < 20; offset++)
        dayWith(date: start.addDays(offset), blockIndex: 1 + offset ~/ 7),
    ];

    final loaded = project(schedule: schedule) as ScheduleLoaded;

    expect(
      loaded.blocks.expand((block) => block.days).length,
      schedule.length,
    );
    expect(
      loaded.blocks
          .expand((block) => block.days)
          .map((day) => day.date)
          .toSet(),
      schedule.map((day) => day.date).toSet(),
    );
  });

  test('days with no block land in the trailing steady-state group', () {
    final schedule = <DayPlan>[
      dayWith(date: start, blockIndex: 1),
      DayPlan(
        date: start.addDays(1),
        stepIndex: 0,
        kind: DayKind.steadyState,
        blockIndex: null,
        dayInBlock: null,
        dayInStep: null,
        dose: const Milligrams.fromHundredths(900),
        doseKind: DoseKind.newDose,
        composition: composeTablets(
          target: const Milligrams.fromHundredths(900),
          strengths: fives,
          allowHalves: true,
        ),
        isHoldDay: false,
      ),
    ];

    final loaded = project(schedule: schedule) as ScheduleLoaded;

    expect(loaded.blocks.last.blockNumber, isNull);
    expect(loaded.blocks.last.title, en.steadyStateTitle('9mg'));
    expect(loaded.blocks.last.days, hasLength(1));
  });

  test('a hold day is MARKED, not five identical day-14 rows', () {
    // A hold repeats its host's `dayInStep`, so without the flag the list
    // grows five rows all reading "day 14 of 52" — which looks like a bug on
    // the one screen whose job is making the structure legible.
    final schedule = <DayPlan>[
      dayWith(date: start, blockIndex: 3, dayInStep: 14),
      for (var offset = 1; offset <= 5; offset++)
        dayWith(
          date: start.addDays(offset),
          blockIndex: 3,
          dayInStep: 14,
          isHoldDay: true,
        ),
    ];

    final loaded = project(schedule: schedule) as ScheduleLoaded;
    final days = loaded.blocks.expand((block) => block.days).toList();

    expect(days.where((day) => day.isHoldDay), hasLength(5));
    expect(days.first.isHoldDay, isFalse);
  });

  test('a completed step is entirely read-only', () {
    final schedule = <DayPlan>[
      for (var offset = 0; offset < 5; offset++)
        dayWith(date: start.addDays(offset), blockIndex: 1),
    ];

    final loaded =
        project(
              schedule: schedule,
              snapshot: snapshotWith(status: StepStatus.completed),
            )
            as ScheduleLoaded;

    expect(loaded.steps.isActive, isFalse);
    expect(
      loaded.blocks.expand((block) => block.days).every((day) => !day.tickable),
      isTrue,
    );
  });

  test('a future day is never tickable, even in the active step', () {
    final schedule = <DayPlan>[
      dayWith(date: today, blockIndex: 1),
      dayWith(date: today.addDays(1), blockIndex: 1),
    ];

    final loaded = project(schedule: schedule) as ScheduleLoaded;
    final days = loaded.blocks.expand((block) => block.days).toList();

    expect(days.first.tickable, isTrue);
    expect(days.last.tickable, isFalse);
    expect(days.last.state, DayState.upcoming);
  });

  test('today is located, and a step without today is not', () {
    final schedule = <DayPlan>[
      dayWith(date: today.addDays(-1), blockIndex: 1),
      dayWith(date: today, blockIndex: 1),
    ];

    expect(
      (project(schedule: schedule) as ScheduleLoaded).todayLocator,
      (0, 1),
    );
    expect(
      (project(
                schedule: <DayPlan>[dayWith(date: start, blockIndex: 1)],
              )
              as ScheduleLoaded)
          .todayLocator,
      isNull,
    );
  });

  test('no plan', () {
    expect(
      ScheduleNotifier.project(
        snapshot: const TaperSnapshot(
          plan: null,
          steps: <StepFacts>[],
          logs: <DoseLogFacts>[],
          flares: <FlareEvent>[],
          holds: <HoldEvent>[],
          statusByStepId: <int, StepStatus>{},
        ),
        schedule: const <DayPlan>[],
        stepIndex: 0,
        today: today,
        l10n: en,
        locale: const Locale('en'),
      ),
      const ScheduleNoPlan(),
    );
  });
}

ScheduleDayVm _rowFor(ScheduleLoaded loaded, LocalDate date) => loaded.blocks
    .expand((block) => block.days)
    .firstWhere((day) => day.date == date);
