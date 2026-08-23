// The boundary test: **this file imports no drift**, and it still names every
// public signature of both repositories.
//
// It stops compiling the day an `Insertable`, a `Value` or a generated row
// class reaches the API — because the call sites below would no longer type
// check. `tool/check_bans.sh` covers the coarser half (no `package:drift`
// import above `lib/data/`); this covers the half a grep cannot see.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';
import 'package:nearlystop/data/settings_repository.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';

import '../support/db_harness.dart';

void main() {
  test(
    'every TaperRepository method is callable in domain types alone',
    () async {
      final repository = TaperRepository(openTestDatabase(), fixedClock);

      final stream = repository.watchSnapshot();
      final first = await stream.first;

      final results = <Result<void, StorageFailure>>[
        await repository.savePlan(seededDraft()),
        await repository.markTaken(
          const LocalDate(2026, 4, 16),
          plannedMg: const Milligrams.fromHundredths(900),
        ),
        await repository.undoTaken(const LocalDate(2026, 4, 16)),
        await repository.setNote(
          const LocalDate(2026, 4, 16),
          'dizzy',
          plannedMg: const Milligrams.fromHundredths(900),
        ),
        await repository.recordHold(
          stepId: 1,
          from: const LocalDate(2026, 4, 20),
          extraDays: 2,
        ),
        await repository.recordFlare(
          on: const LocalDate(2026, 5, 1),
          revertTo: const Milligrams.fromHundredths(1000),
        ),
        await repository.updatePlanFacts(seededDraft()),
        await repository.updateStrengths(<Milligrams>[
          const Milligrams.fromHundredths(500),
        ]),
        await repository.startNextStep(),
        await repository.deletePlan(1),
      ];

      // The snapshot's own fields are domain types too.
      final snapshot = (first as Ok<TaperSnapshot, StorageFailure>).value;
      final plan = snapshot.plan;
      final steps = snapshot.steps;
      final logs = snapshot.logs;
      final flares = snapshot.flares;
      final holds = snapshot.holds;
      final status = snapshot.statusByStepId;

      expect(results, hasLength(10));
      expect(plan, isNull);
      expect(<Object>[
        steps,
        logs,
        flares,
        holds,
        status,
      ], everyElement(isEmpty));
    },
  );

  test(
    'every SettingsRepository method is callable in domain types alone',
    () async {
      final settings = SettingsRepository(openTestDatabase(), fixedClock);

      final results = <Result<void, StorageFailure>>[
        await settings.ensureExists(),
        await settings.setReminderEnabled(enabled: true),
        await settings.setReminderMinuteOfDay(450),
        await settings.setTextScale(1.2),
        await settings.setHighContrast(enabled: true),
        await settings.setLocaleTag('de'),
        await settings.setThemeMode('dark'),
        await settings.acceptDisclaimer(),
      ];
      final stream = settings.watchSettings();
      final read = await settings.readOnce();

      expect(results, everyElement(isA<Ok<void, StorageFailure>>()));
      expect(await stream.first, read);
    },
  );

  test('a plan draft is built from domain value objects only', () {
    // `TaperPlanDraft` is EPIC-11's input. If it ever grew a drift type this
    // construction would stop compiling.
    const draft = TaperPlanDraft(
      drugName: 'Prednisolone',
      startDate: LocalDate(2026, 4, 1),
      currentDose: Milligrams.fromHundredths(1000),
      targetDose: Milligrams.zero,
      strengths: <Milligrams>[Milligrams.fromHundredths(500)],
      allowHalves: true,
      method: TaperMethod.dsns,
      stepSize: Milligrams.fromHundredths(100),
    );

    expect(draft.strengths.single, const TabletStrength.fromHundredths(500).mg);
  });
}
