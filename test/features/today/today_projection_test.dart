// Facts in, one view state out.
//
// `flutter_test` but no `pumpWidget` and no container: `TodayNotifier.project`
// is a pure static function. The binding exists only so
// `AppLocalizations.delegate.load` can run, because the projection formats and
// formatting needs the locale.
//
// Inputs are built by hand — small, named, literal — rather than drawn from
// the golden fixture, so each case says what it is about.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/dsns/cumulative.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/today/application/today_view_provider.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:nearlystop/l10n/bidi.dart';
import 'package:nearlystop/l10n/date_formats.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

void main() {
  const today = LocalDate(2026, 4, 16);
  const strengths = <TabletStrength>[
    TabletStrength.fromHundredths(500),
    TabletStrength.fromHundredths(100),
  ];

  const enLocale = Locale('en');
  late AppLocalizations en;
  late AppLocalizations fa;

  setUpAll(() async {
    // `DateFormat` throws until its symbol data is loaded, and the projection
    // formats a full date line. `bootstrap.dart` does the same thing before
    // the first frame.
    await initializeDateFormatting();
    en = await AppLocalizations.delegate.load(const Locale('en'));
    fa = await AppLocalizations.delegate.load(const Locale('fa'));
  });

  TaperPlanFacts planWith({
    Milligrams target = Milligrams.zero,
    Milligrams start = const Milligrams.fromHundredths(1000),
  }) => TaperPlanFacts(
    drugName: 'Prednisolone',
    startDate: const LocalDate(2026, 1, 1),
    startingDose: start,
    targetDose: target,
    tabletStrengths: strengths,
    allowHalves: true,
    method: TaperMethod.dsns,
    holdPeriodDays: 0,
  );

  StepFacts stepWith({
    int id = 1,
    int index = 0,
    Milligrams from = const Milligrams.fromHundredths(1000),
    Milligrams to = const Milligrams.fromHundredths(900),
    LocalDate start = const LocalDate(2026, 4, 3),
    StepStatus status = StepStatus.active,
  }) => StepFacts(
    id: id,
    index: index,
    fromDose: from,
    toDose: to,
    startDate: start,
    status: status,
    patternVersion: 1,
  );

  DayPlan dayWith({
    LocalDate date = today,
    Milligrams dose = const Milligrams.fromHundredths(900),
    DoseKind doseKind = DoseKind.newDose,
    DayKind kind = DayKind.step,
    int? blockIndex = 3,
    int? dayInStep = 14,
    int stepIndex = 0,
  }) => DayPlan(
    date: date,
    stepIndex: stepIndex,
    kind: kind,
    blockIndex: blockIndex,
    dayInBlock: 1,
    dayInStep: dayInStep,
    dose: dose,
    doseKind: doseKind,
    composition: composeTablets(
      target: dose,
      strengths: strengths,
      allowHalves: true,
    ),
    isHoldDay: false,
  );

  TaperSnapshot snapshotWith({
    TaperPlanFacts? plan,
    List<StepFacts>? steps,
    List<DoseLogFacts> logs = const <DoseLogFacts>[],
  }) => TaperSnapshot(
    plan: plan ?? planWith(),
    steps: steps ?? <StepFacts>[stepWith()],
    logs: logs,
    flares: const <FlareEvent>[],
    holds: const <HoldEvent>[],
    statusByStepId: <int, StepStatus>{
      for (final step in steps ?? <StepFacts>[stepWith()]) step.id: step.status,
    },
  );

  DoseLogFacts logFor(
    LocalDate date, {
    bool taken = true,
    Milligrams planned = const Milligrams.fromHundredths(900),
  }) => DoseLogFacts(
    date: date,
    plannedMg: planned,
    actualMg: taken ? planned : Milligrams.zero,
    taken: taken,
  );

  TodayViewState project({
    required List<DayPlan> schedule,
    TaperSnapshot? snapshot,
    LocalDate date = today,
    AppLocalizations? l10n,
    Locale locale = const Locale('en'),
  }) => TodayNotifier.project(
    snapshot: snapshot ?? snapshotWith(),
    schedule: schedule,
    date: date,
    l10n: l10n ?? en,
    locale: locale,
  );

  test('a new-dose day', () {
    final state = project(schedule: <DayPlan>[dayWith()]);

    expect(state, isA<TodayDose>());
    final dose = state as TodayDose;
    expect(dose.isNewDoseDay, isTrue);
    expect(dose.taken, isFalse);
    expect(dose.doseAmount, '9');
    // The breakdown is bidi-ISOLATED: a run of Latin counts and units inside a
    // Perso-Arabic sentence reorders without it, and reports the wrong count
    // against the wrong strength. Asserted here rather than baked into every
    // expectation below.
    expect(dose.tablets, '\u2066${'1 × 5mg · 4 × 1mg'}\u2069');
    expect(stripIsolates(dose.tablets!), '1 × 5mg · 4 × 1mg');
    expect(dose.dayInStep, '14');
    expect(dose.stepLength, '52');
    expect(dose.isSteadyState, isFalse);
  });

  test('an old-dose day', () {
    final state = project(
      schedule: <DayPlan>[
        dayWith(
          dose: const Milligrams.fromHundredths(1000),
          doseKind: DoseKind.oldDose,
        ),
      ],
    );

    final dose = state as TodayDose;
    expect(dose.isNewDoseDay, isFalse);
    expect(dose.doseAmount, '10');
    expect(stripIsolates(dose.tablets!), '2 × 5mg');
  });

  test('a steady-state day says "holding at", never "day 0 of 52"', () {
    // The bug this branch exists to prevent: `dayInStep` is null on those days
    // and formatting it anyway prints 0.
    final state = project(
      schedule: <DayPlan>[
        dayWith(kind: DayKind.steadyState, blockIndex: null, dayInStep: null),
      ],
    );

    final dose = state as TodayDose;
    expect(dose.isSteadyState, isTrue);
    expect(dose.dayInStep, isNull);
    expect(dose.stepLength, isNull);
    expect(dose.holdingLabel, en.holdingAtDose('9mg'));
    expect(dose.holdingLabel, isNot(contains('0')));
  });

  test('an unachievable dose is FLAGGED, never rounded', () {
    // 0.75mg from 5mg and 1mg tablets, halves on. CLAUDE.md rule 5.
    final state = project(
      schedule: <DayPlan>[dayWith(dose: const Milligrams.fromHundredths(75))],
    );

    final dose = state as TodayDose;
    expect(dose.tablets, isNull);
    expect(dose.unachievableMessage, en.doseNotAchievable('0.75'));
    // And the flag carries the EXACT dose, so nothing anywhere reads 1mg.
    expect(dose.unachievableMessage, contains('0.75'));
  });

  test('already taken', () {
    final state = project(
      schedule: <DayPlan>[dayWith()],
      snapshot: snapshotWith(logs: <DoseLogFacts>[logFor(today)]),
    );

    final dose = state as TodayDose;
    expect(dose.taken, isTrue);
    expect(dose.backfill, isNull);
  });

  test('the backfill prompt is the trailing RUN, not the lifetime total', () {
    // Four un-ticked days behind today, then a taken day, then another
    // un-ticked one further back. The taken day terminates the run: the count
    // is 4, not 5. Prompting about a day from three months ago every morning
    // for the rest of a two-year taper is not a prompt, it is nagging.
    final schedule = <DayPlan>[
      for (var back = 6; back >= 0; back--) dayWith(date: today.addDays(-back)),
    ];
    final state = project(
      schedule: schedule,
      snapshot: snapshotWith(
        logs: <DoseLogFacts>[
          logFor(today.addDays(-6), taken: false),
          logFor(today.addDays(-5)),
        ],
      ),
    );

    final dose = state as TodayDose;
    expect(dose.backfill, isNotNull);
    expect(dose.backfill!.count, 4);
    expect(dose.backfill!.oldest, today.addDays(-4));
  });

  test('every past day ticked means no prompt at all', () {
    final schedule = <DayPlan>[
      for (var back = 3; back >= 0; back--) dayWith(date: today.addDays(-back)),
    ];
    final state = project(
      schedule: schedule,
      snapshot: snapshotWith(
        logs: <DoseLogFacts>[
          for (var back = 3; back >= 1; back--) logFor(today.addDays(-back)),
        ],
      ),
    );

    expect((state as TodayDose).backfill, isNull);
  });

  test('a FUTURE untaken day never counts toward the prompt', () {
    final schedule = <DayPlan>[
      dayWith(date: today.addDays(-1)),
      dayWith(),
      dayWith(date: today.addDays(1)),
      dayWith(date: today.addDays(2)),
    ];
    final state = project(
      schedule: schedule,
      snapshot: snapshotWith(logs: <DoseLogFacts>[logFor(today.addDays(-1))]),
    );

    expect((state as TodayDose).backfill, isNull);
  });

  test('one missed day reads as the singular form', () {
    final schedule = <DayPlan>[
      dayWith(date: today.addDays(-2)),
      dayWith(date: today.addDays(-1)),
      dayWith(),
    ];
    final state = project(
      schedule: schedule,
      snapshot: snapshotWith(
        logs: <DoseLogFacts>[logFor(today.addDays(-2))],
      ),
    );

    final backfill = (state as TodayDose).backfill!;
    expect(backfill.count, 1);
    expect(backfill.oldest, today.addDays(-1));
    expect(backfill.label, en.nDaysNotTicked(1));
  });

  test('no plan', () {
    final state = project(
      schedule: const <DayPlan>[],
      snapshot: const TaperSnapshot(
        plan: null,
        steps: <StepFacts>[],
        logs: <DoseLogFacts>[],
        flares: <FlareEvent>[],
        holds: <HoldEvent>[],
        statusByStepId: <int, StepStatus>{},
      ),
    );

    expect(state, const TodayNoPlan());
  });

  test('the step is finished and the next has not been started', () {
    // Day 53. The generator emits a steady-state day at the step's toDose, so
    // there is still a real dose — and the screen must offer to start the
    // next step rather than rendering nothing.
    final state = project(
      schedule: <DayPlan>[
        dayWith(kind: DayKind.steadyState, blockIndex: null, dayInStep: null),
      ],
      snapshot: snapshotWith(
        steps: <StepFacts>[stepWith(status: StepStatus.completed)],
      ),
    );

    expect(state, isA<TodayStepFinished>());
    final finished = state as TodayStepFinished;
    expect(finished.canStartNextStep, isTrue);
    // CONTRACTS.md 6's corrected worked example — 0.5mg, never 1mg.
    expect(stripIsolates(finished.nextStepPreview), '9mg → 8.5mg');
    // Day 53 is a real day with a real dose.
    expect(finished.doseAmount, '9');
    expect(stripIsolates(finished.tablets!), '1 × 5mg · 4 × 1mg');
    expect(finished.taken, isFalse);
  });

  test('the target is reached', () {
    final state = project(
      schedule: <DayPlan>[
        dayWith(
          dose: Milligrams.zero,
          kind: DayKind.steadyState,
          blockIndex: null,
          dayInStep: null,
        ),
      ],
      snapshot: snapshotWith(
        plan: planWith(),
        steps: <StepFacts>[
          stepWith(
            to: Milligrams.zero,
            status: StepStatus.completed,
          ),
        ],
      ),
    );

    expect(state, const TodayTaperComplete());
  });

  test('fa formats the numerals and the date, proving it happens HERE', () {
    final state = project(
      schedule: <DayPlan>[dayWith()],
      l10n: fa,
      locale: const Locale('fa'),
    );

    final dose = state as TodayDose;
    expect(dose.doseAmount, '۹');
    // Jalali, not Gregorian: 16 April 2026 is 27 Farvardin 1405.
    expect(dose.dateLine, contains('۲۷'));
    expect(dose.dateLine, isNot(contains('April')));
  });

  test('seeded fuzz: every date in range projects exactly one variant', () {
    // The independent oracle is the DayPlan list itself: whatever the
    // projection produced, its dose must parse back to that day's plan.
    final schedule = <DayPlan>[
      for (var offset = -100; offset < 100; offset++)
        dayWith(
          date: today.addDays(offset),
          dose: Milligrams.fromHundredths(500 + (offset.abs() % 6) * 100),
        ),
    ];

    for (final day in schedule) {
      final state = project(schedule: schedule, date: day.date);

      expect(
        state,
        anyOf(
          isA<TodayDose>(),
          isA<TodayStepFinished>(),
          isA<TodayTaperComplete>(),
          isA<TodayNoPlan>(),
        ),
        reason: '${day.date}',
      );
      if (state is TodayDose) {
        expect(
          state.doseAmount,
          isNotEmpty,
          reason: '${day.date} projected an empty dose',
        );
      }
    }
  });

  test('a flare appends a fact and rewrites no history', () {
    // The cumulative total is the number the reader watches for two years. A
    // flare must not move it.
    final logs = <DoseLogFacts>[
      for (var back = 5; back >= 1; back--) logFor(today.addDays(-back)),
    ];
    final before = cumulativeTakenMg(logs);

    final after = cumulativeTakenMg(<DoseLogFacts>[...logs]);

    expect(after, before);
    expect(after.hundredths, 5 * 900);
  });

  test('the hold prompt does not invent a block number', () {
    // On a steady-state day `blockIndex` is null. `blockIndex ?? 1` prints
    // "Block 1 of 11" — the FIRST block, on a day that is past the last one.
    // The reader opening the hold sheet is told they are somewhere they are
    // not, on the screen that asks them to make a decision about it.
    final state = project(
      schedule: <DayPlan>[
        dayWith(kind: DayKind.steadyState, blockIndex: null, dayInStep: null),
      ],
    );

    final hold = (state as TodayDose).hold;
    expect(hold, isNotNull);
    expect(
      hold!.blockLabel,
      isNot(en.blockOfTotal(1, 11)),
      reason: 'it claimed block 1 on a day with no block',
    );
  });

  test("a flare candidate's date range does not assume 52 days", () {
    // A step that was HELD ran longer than 52 days, and a candidate labelled
    // with the nominal length tells the reader they were on that dose over
    // dates they were not. They are choosing a dose to go back to from these
    // labels.
    final state = project(
      schedule: <DayPlan>[dayWith()],
      snapshot: snapshotWith(
        steps: <StepFacts>[
          stepWith(status: StepStatus.completed),
          stepWith(
            id: 2,
            index: 1,
            from: const Milligrams.fromHundredths(900),
            to: const Milligrams.fromHundredths(850),
            // The next step began 70 days later, not 52: the first was held.
            start: const LocalDate(2026, 6, 12),
          ),
        ],
      ),
    );

    final candidate = (state as TodayDose).flare.candidates.firstWhere(
      (candidate) => candidate.dose == const Milligrams.fromHundredths(1000),
    );
    expect(
      candidate.label,
      contains(formatDayLabel(const LocalDate(2026, 6, 12), enLocale)),
      reason: 'the range ended at the nominal 52 days, not where it really did',
    );
  });
}
