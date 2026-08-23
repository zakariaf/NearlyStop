// The acceptance gate: the reference frame's numbers, end to end.
//
// `testing-strategy` rule 8. One fixture, projected the whole way, producing
// exactly what frame 4 shows — so the parity capture and the arithmetic cannot
// drift apart without this going red.
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
  // "Started 12 September 2024", and 581 whole days later.
  const start = LocalDate(2024, 9, 12);
  final today = start.addDays(580);

  late AppLocalizations en;
  setUpAll(() async {
    await initializeDateFormatting();
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// Six 1mg steps, 15mg down to 9mg — the reference's taper.
  List<StepFacts> steps() => <StepFacts>[
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

  test('the reference frame’s numbers, produced rather than typed', () {
    final days = generated(plan: plan(), steps: steps(), until: today);
    // 574 of the 581 elapsed days ticked: seven gaps, which is what the
    // reassurance line under the number exists to be gentle about.
    final logs = <DoseLogFacts>[
      for (var index = 0; index < 581; index++)
        if (index % 83 != 0)
          DoseLogFacts(
            date: start.addDays(index),
            plannedMg: days[index].dose,
            actualMg: days[index].dose,
            taken: true,
          ),
    ];
    final flares = <FlareEvent>[
      FlareEvent(date: start.addDays(200), revertToDose: mg(12)),
      FlareEvent(date: start.addDays(400), revertToDose: mg(10)),
    ];
    final holds = <HoldEvent>[
      HoldEvent(stepId: 3, fromDate: start.addDays(150), extraDays: 5),
    ];

    final loaded =
        ProgressNotifier.project(
              snapshot: TaperSnapshot(
                plan: plan(),
                steps: steps(),
                logs: logs,
                flares: flares,
                holds: holds,
                statusByStepId: const <int, StepStatus>{},
              ),
              schedule: days,
              today: today,
              l10n: en,
              locale: const Locale('en'),
            )
            as ProgressLoaded;

    expect(loaded.stats.daysOnDrug, '581');
    expect(loaded.stats.adherence, '574 of 581');
    expect(loaded.segments, hasLength(12));
    expect(loaded.flares, hasLength(2));
    expect(loaded.holds, hasLength(1));

    // The conservation invariant, computed independently of the projection:
    // the treads tile the elapsed days, and the total is the sum of what was
    // actually swallowed.
    final elapsed = <DayPlan>[
      for (final day in days)
        if (day.date <= today) day,
    ];
    var covered = 0;
    for (final segment in loaded.segments) {
      covered += segment.length;
    }
    expect(covered, elapsed.length);

    var total = 0;
    for (final log in logs) {
      if (log.taken) total += log.actualMg.hundredths;
    }
    expect(
      loaded.stats.cumulativeMg,
      _grouped(total ~/ 100),
      reason: 'the screen and the sum disagree about what was taken',
    );
  });
}

/// Thousands-grouped the way `en` groups, for the oracle side of the test.
String _grouped(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
