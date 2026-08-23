/// The Schedule screen's fixture: the repo-wide taper, projected.
///
/// Projected through the real notifier rather than hand-built, so a widget
/// test is looking at the same strings, block boundaries and states the app
/// produces. A hand-built `ScheduleLoaded` drifts from the projection the
/// moment either changes, and then the screen tests pass against a shape the
/// screen never receives.
library;

import 'package:flutter/widgets.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../../fixtures/taper_fixture.dart';

/// The reference's day: block 3, day 16 of the 10mg → 9mg step.
const LocalDate fixtureToday = LocalDate(2026, 4, 16);

/// 14 and 15 April, the two rows above today in the reference frame.
const LocalDate fixtureTakenDay = LocalDate(2026, 4, 14);

/// The fixture step's days, straight from the generator.
List<DayPlan> fixtureDays({List<HoldEvent> holds = const <HoldEvent>[]}) =>
    generated(steps: const <StepFacts>[fixtureStep], holds: holds);

/// The repo-wide taper as one step's blocks.
///
/// [takenThrough] ticks every day up to and including that date, which is what
/// gives the frame its taken rows above today.
ScheduleLoaded fixtureSchedule({
  required AppLocalizations l10n,
  Locale locale = const Locale('en'),
  LocalDate today = fixtureToday,
  LocalDate? takenThrough = fixtureTakenDay,
  StepStatus status = StepStatus.active,
  List<HoldEvent> holds = const <HoldEvent>[],
}) {
  final days = fixtureDays(holds: holds);
  final logs = <DoseLogFacts>[
    if (takenThrough != null)
      for (final day in days)
        if (day.date <= takenThrough)
          DoseLogFacts(
            date: day.date,
            plannedMg: day.dose,
            actualMg: day.dose,
            taken: true,
          ),
  ];

  return ScheduleNotifier.project(
        snapshot: TaperSnapshot(
          plan: fixturePlan,
          steps: <StepFacts>[
            StepFacts(
              id: fixtureStep.id,
              index: fixtureStep.index,
              fromDose: fixtureStep.fromDose,
              toDose: fixtureStep.toDose,
              startDate: fixtureStep.startDate,
              status: status,
              patternVersion: fixtureStep.patternVersion,
            ),
          ],
          logs: logs,
          flares: const <FlareEvent>[],
          holds: holds,
          statusByStepId: <int, StepStatus>{fixtureStep.id: status},
        ),
        schedule: days,
        stepIndex: 0,
        today: today,
        l10n: l10n,
        locale: locale,
      )
      as ScheduleLoaded;
}

/// The fixture's dose on [date], for a test that needs the number.
Milligrams fixtureDose(LocalDate date) =>
    fixtureDays().firstWhere((day) => day.date == date).dose;
