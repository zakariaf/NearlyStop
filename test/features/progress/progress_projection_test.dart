// Progress, projected. **This epic formats; EPIC-04 computes.**
//
// The boundary is the point of this file. `daysOnSteroids`, `cumulativeTakenMg`
// and `adherence` are pure, tested and shipped in `lib/core/dsns/cumulative.dart`;
// re-deriving any of them here would put the arithmetic outside EPIC-04's
// purity gate and let it drift from the number EPIC-13 exports.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/progress/application/progress_view_provider.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../fixtures/taper_fixture.dart';

void main() {
  const start = LocalDate(2024, 9, 12);
  const today = LocalDate(2026, 4, 16);

  late Map<String, AppLocalizations> l10ns;
  setUpAll(() async {
    await initializeDateFormatting();
    l10ns = <String, AppLocalizations>{
      for (final code in <String>['en', 'de', 'fa', 'ckb'])
        code: await AppLocalizations.delegate.load(Locale(code)),
    };
  });

  /// The 15mg → 9mg plan the reference frame shows: six 1mg steps.
  List<StepFacts> sixSteps() => <StepFacts>[
    for (var index = 0; index < 6; index++)
      StepFacts(
        id: index + 1,
        index: index,
        fromDose: mg(15 - index),
        toDose: mg(14 - index),
        startDate: start.addDays(index * 52),
        status: index == 5 ? StepStatus.active : StepStatus.completed,
        patternVersion: 1,
      ),
  ];

  TaperPlanFacts plan() => TaperPlanFacts(
    drugName: 'Prednisolone',
    startDate: start,
    startingDose: mg(15),
    targetDose: Milligrams.zero,
    tabletStrengths: fixtureStrengths,
    allowHalves: true,
    method: TaperMethod.dsns,
  );

  List<DayPlan> days({List<HoldEvent> holds = const <HoldEvent>[]}) =>
      generated(
        plan: plan(),
        steps: sixSteps(),
        holds: holds,
        until: today,
      );

  ProgressViewState project({
    List<DoseLogFacts> logs = const <DoseLogFacts>[],
    List<FlareEvent> flares = const <FlareEvent>[],
    List<HoldEvent> holds = const <HoldEvent>[],
    String locale = 'en',
    TaperPlanFacts? overridePlan,
  }) => ProgressNotifier.project(
    snapshot: TaperSnapshot(
      plan: overridePlan ?? plan(),
      steps: sixSteps(),
      logs: logs,
      flares: flares,
      holds: holds,
      statusByStepId: const <int, StepStatus>{},
    ),
    schedule: days(holds: holds),
    today: today,
    l10n: l10ns[locale]!,
    locale: Locale(locale),
  );

  /// [count] ticked days from the plan's start.
  List<DoseLogFacts> ticked(int count) => <DoseLogFacts>[
    for (var index = 0; index < count; index++)
      DoseLogFacts(
        date: start.addDays(index),
        plannedMg: mg(10),
        actualMg: mg(10),
        taken: true,
      ),
  ];

  test('days on the drug are formatted per locale, never recomputed', () {
    // 12 September 2024 to 16 April 2026 inclusive is 582 days.
    const expected = <String, String>{
      'en': '582',
      'de': '582',
      'fa': '۵۸۲',
      'ckb': '۵۸۲',
    };
    for (final MapEntry<String, String>(:key, :value) in expected.entries) {
      final loaded = project(locale: key) as ProgressLoaded;
      expect(loaded.stats.daysOnDrug, value, reason: key);
    }
  });

  test('the cumulative total is grouped by the locale’s own formatter', () {
    // 684200 hundredths is 6,842mg. The separator is never hand-typed: `de`
    // groups with a dot, `fa` with its own, and asserting a literal would pin
    // this app's idea of German rather than ICU's.
    const logs = <DoseLogFacts>[
      DoseLogFacts(
        date: start,
        plannedMg: Milligrams.fromHundredths(684200),
        actualMg: Milligrams.fromHundredths(684200),
        taken: true,
      ),
    ];

    expect((project(logs: logs) as ProgressLoaded).stats.cumulativeMg, '6,842');
    expect(
      (project(logs: logs, locale: 'de') as ProgressLoaded).stats.cumulativeMg,
      '6.842',
    );
    final fa = (project(logs: logs, locale: 'fa') as ProgressLoaded)
        .stats
        .cumulativeMg;
    // Persian digits are U+06Fx. The Arabic block U+066x is a different set and
    // CONTRACTS 10 rejects it.
    expect(fa, contains('۶'));
    expect(
      fa.runes.where((r) => r >= 0x0660 && r <= 0x0669),
      isEmpty,
      reason: 'Arabic-block digits leaked into the Persian total',
    );
  });

  test('the cumulative total reads actualMg, not plannedMg', () {
    // A day backfilled at a reverted 10mg against a planned 9mg totals
    // honestly, or the number stops matching what the person swallowed.
    final logs = <DoseLogFacts>[
      DoseLogFacts(
        date: start,
        plannedMg: mg(9),
        actualMg: mg(10),
        taken: true,
      ),
    ];

    expect((project(logs: logs) as ProgressLoaded).stats.cumulativeMg, '10');
  });

  test('adherence is a ratio — never a percentage, never a streak', () {
    // SPEC 4.3 is a WORDING rule, and wording rules rot silently, so the
    // absences are asserted as loudly as the presence.
    final loaded = project(logs: ticked(574)) as ProgressLoaded;

    expect(loaded.stats.adherence, '574 of 582');
    expect(loaded.stats.adherence, isNot(contains('%')));
    for (final word in <String>['streak', 'broken', 'missed', 'failed']) {
      expect(
        '${loaded.stats.adherence} ${loaded.stats.adherenceCaption}'
            .toLowerCase(),
        isNot(contains(word)),
        reason: 'the adherence copy scolds: "$word"',
      );
    }
  });

  test('day one divides by nothing', () {
    final loaded =
        ProgressNotifier.project(
              snapshot: TaperSnapshot(
                plan: plan(),
                steps: sixSteps(),
                logs: const <DoseLogFacts>[],
                flares: const <FlareEvent>[],
                holds: const <HoldEvent>[],
                statusByStepId: const <int, StepStatus>{},
              ),
              schedule: generated(
                plan: plan(),
                steps: sixSteps(),
                until: start,
              ),
              today: start,
              l10n: l10ns['en']!,
              locale: const Locale('en'),
            )
            as ProgressLoaded;

    expect(loaded.stats.daysOnDrug, '1');
    expect(loaded.stats.adherence, '0 of 1');
  });

  test('encouragement never says "0mg lower"', () {
    final lower = project() as ProgressLoaded;
    expect(lower.encouragement, l10ns['en']!.lowerThanStart('6mg'));

    final flat =
        project(
              overridePlan: TaperPlanFacts(
                drugName: 'Prednisolone',
                startDate: start,
                startingDose: mg(9),
                targetDose: Milligrams.zero,
                tabletStrengths: fixtureStrengths,
                allowHalves: true,
                method: TaperMethod.dsns,
              ),
            )
            as ProgressLoaded;
    expect(flat.encouragement, l10ns['en']!.sameAsStart);
    expect(flat.encouragement, isNot(contains('0mg')));
  });

  test('the event line drops the clause a count of zero would fill', () {
    final none = project() as ProgressLoaded;
    expect(none.eventCountLabel, l10ns['en']!.noEventsRecorded);

    final flaresOnly =
        project(
              flares: <FlareEvent>[
                FlareEvent(date: start.addDays(300), revertToDose: mg(10)),
              ],
            )
            as ProgressLoaded;
    expect(flaresOnly.eventCountLabel, l10ns['en']!.flaresRecorded(1));
    expect(flaresOnly.eventCountLabel, isNot(contains('0')));

    final both =
        project(
              flares: <FlareEvent>[
                FlareEvent(date: start.addDays(300), revertToDose: mg(10)),
              ],
              holds: <HoldEvent>[
                HoldEvent(
                  stepId: 1,
                  fromDate: start.addDays(30),
                  extraDays: 5,
                ),
              ],
            )
            as ProgressLoaded;
    expect(both.eventCountLabel, l10ns['en']!.flaresAndHoldsRecorded(1, 1));
  });

  test('no plan is the empty state, not an empty chart', () {
    expect(
      ProgressNotifier.project(
        snapshot: const TaperSnapshot(
          plan: null,
          steps: <StepFacts>[],
          logs: <DoseLogFacts>[],
          flares: <FlareEvent>[],
          holds: <HoldEvent>[],
          statusByStepId: <int, StepStatus>{},
        ),
        schedule: const <DayPlan>[],
        today: today,
        l10n: l10ns['en']!,
        locale: const Locale('en'),
      ),
      const ProgressNoPlan(),
    );
  });

  test('the arithmetic is NOT re-implemented in this feature', () {
    // The boundary, as a source rule. A `fold` over dose logs here is the same
    // sum EPIC-04 already owns and EPIC-13 already exports — and the second
    // copy is the one that drifts.
    final sources = Directory('lib/features/progress')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    expect(sources, isNotEmpty);
    for (final file in sources) {
      final source = file.readAsStringSync();
      for (final banned in <String>['.fold(', '.reduce(', '.inDays']) {
        expect(
          source,
          isNot(contains(banned)),
          reason: '${file.path} re-derives what cumulative.dart already owns',
        );
      }
    }
  });
}
