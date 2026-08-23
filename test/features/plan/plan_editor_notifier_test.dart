// The draft, and the one path from it to storage.
//
// A real `NativeDatabase.memory()` engine, never a mocked DAO: what these
// assert is what reaches the rows, and a fake can happily record a write the
// database would have rejected.
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/dsns/dsns_pattern.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/plan/presentation/plan_editor_notifier.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

import '../../support/db_harness.dart';

void main() {
  const today = LocalDate(2026, 4, 16);

  late AppDatabaseHolder holder;
  setUp(() => holder = AppDatabaseHolder(openTestDatabase()));

  ProviderContainer containerAt({Locale locale = const Locale('en')}) {
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(holder.database),
        todayDateProvider.overrideWithValue(today),
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime.utc(2026, 4, 16, 8)),
        ),
        resolvedLocaleProvider.overrideWithValue(locale),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<TaperSnapshot> snapshotOf(ProviderContainer container) async {
    final result = await container
        .read(taperRepositoryProvider)
        .watchSnapshot()
        .first;
    return switch (result) {
      Ok<TaperSnapshot, StorageFailure>(:final value) => value,
      Err<TaperSnapshot, StorageFailure>(:final failure) => throw StateError(
        '$failure',
      ),
    };
  }

  test('a clean install seeds the region’s own drug and strengths', () async {
    final container = containerAt();
    container.listen(planEditorProvider, (_, _) {});
    await snapshotOf(container);
    container.invalidate(planEditorProvider);

    final draft = container.read(planEditorProvider);

    expect(draft.drugName, 'Prednisolone');
    expect(draft.strengths.map((s) => s.hundredths), <int>[100, 250, 500]);
    expect(draft.startDate, today);
  });

  test(
    'seeding from a saved plan sorts and deduplicates the strengths',
    () async {
      final container = containerAt();
      await container
          .read(taperRepositoryProvider)
          .savePlan(
            seededDraft(strengths: <Milligrams>[mg(5), mg(1), mg(5)]),
          );
      container.listen(planEditorProvider, (_, _) {});
      await container.read(taperSnapshotProvider.future);

      final draft = container.read(planEditorProvider);

      expect(draft.strengths.map((s) => s.hundredths), <int>[100, 500]);
      expect(draft.drugName, 'Prednisolone');
      expect(draft.currentDose, mg(10));
    },
  );

  test('editing every field and discarding writes NOTHING', () async {
    // The screen where a wrong keystroke costs two years of history. Changing
    // your mind has to cost nothing.
    final container = containerAt();
    await container.read(taperRepositoryProvider).savePlan(seededDraft());
    container.listen(planEditorProvider, (_, _) {});
    await container.read(taperSnapshotProvider.future);
    final before = await snapshotOf(container);

    container
        .read(planEditorProvider.notifier)
        .edit(
          (draft) => draft.copyWith(
            drugName: 'Something else',
            currentDose: mg(30),
            targetDose: mg(2),
            strengths: <Milligrams>[mg(20)],
            allowHalves: false,
            method: TaperMethod.percentage,
            percentage: 25,
          ),
        );
    container.read(planEditorProvider.notifier).discard();

    final after = await snapshotOf(container);
    expect(after.plan!.drugName, before.plan!.drugName);
    expect(after.plan!.startingDose, before.plan!.startingDose);
    expect(after.plan!.targetDose, before.plan!.targetDose);
    expect(
      after.plan!.tabletStrengths.map((s) => s.hundredths),
      before.plan!.tabletStrengths.map((s) => s.hundredths),
    );
    expect(after.steps, hasLength(before.steps.length));
  });

  test(
    'saving a new plan appends exactly one Step, and none thereafter',
    () async {
      // Without this, NOTHING anywhere creates step 0: `generateSchedule` takes
      // a list of steps, so a plan with none produces an empty schedule and
      // Today, Schedule and Progress all render empty for ever (CONTRACTS §7).
      final container = containerAt();
      container.listen(planEditorProvider, (_, _) {});
      await container.read(taperSnapshotProvider.future);
      container
          .read(planEditorProvider.notifier)
          .edit(
            (draft) => draft.copyWith(
              currentDose: mg(10),
              targetDose: Milligrams.zero,
              strengths: <Milligrams>[mg(5), mg(1)],
            ),
          );

      expect(
        await container.read(planEditorProvider.notifier).save(),
        isA<Ok>(),
      );

      final saved = await snapshotOf(container);
      expect(saved.steps, hasLength(1));
      expect(saved.steps.single.index, 0);
      expect(saved.steps.single.fromDose, mg(10));
      expect(saved.steps.single.toDose, mg(9));
      expect(saved.steps.single.startDate, today);
      expect(saved.steps.single.status, StepStatus.active);
      expect(saved.steps.single.patternVersion, const DsnsPattern.v1().version);

      // And none thereafter. The happy path alone never catches a repeated
      // insert.
      container
          .read(planEditorProvider.notifier)
          .edit(
            (draft) => draft.copyWith(drugName: 'Prednisolone '),
          );
      await container.read(planEditorProvider.notifier).save();

      expect((await snapshotOf(container)).steps, hasLength(1));
    },
  );

  test('an override beats the suggestion in the row that is written', () async {
    // 9mg with 5mg + 1mg and halves: the engine suggests 0.5mg. The doctor
    // said 1mg. The doctor wins (SPEC §3.2).
    final container = containerAt();
    container.listen(planEditorProvider, (_, _) {});
    await container.read(taperSnapshotProvider.future);
    container
        .read(planEditorProvider.notifier)
        .edit(
          (draft) => draft.copyWith(
            currentDose: mg(9),
            targetDose: Milligrams.zero,
            strengths: <Milligrams>[mg(5), mg(1)],
            allowHalves: true,
            stepOverride: mg(1),
          ),
        );

    await container.read(planEditorProvider.notifier).save();

    expect((await snapshotOf(container)).steps.single.toDose, mg(8));
  });

  test('re-saving with new strengths leaves every dose log alone', () async {
    // SPEC §5.2: past days stay exactly as recorded and only FUTURE days
    // recompose. Compared row for row, not by count — a count survives a
    // rewrite that changed every value.
    final container = containerAt();
    final repository = container.read(taperRepositoryProvider);
    await repository.savePlan(seededDraft());
    for (var day = 0; day < 40; day++) {
      await repository.markTaken(
        const LocalDate(2026, 4, 1).addDays(day),
        plannedMg: mg(10),
      );
    }
    final before = (await snapshotOf(container)).logs;
    container.listen(planEditorProvider, (_, _) {});
    await container.read(taperSnapshotProvider.future);

    container
        .read(planEditorProvider.notifier)
        .edit(
          (draft) => draft.copyWith(strengths: <Milligrams>[mg(2.5), mg(1)]),
        );
    expect(
      await container.read(planEditorProvider.notifier).save(),
      isA<Ok<void, StorageFailure>>(),
      reason: 'the edit was refused, so nothing below is being tested',
    );

    final saved = await snapshotOf(container);
    expect(
      saved.plan!.tabletStrengths.map((s) => s.hundredths).toSet(),
      <int>{100, 250},
      // As a SET: the row's own ordering is EPIC-05's converter's business,
      // and the draft's sorting is asserted on `sortedStrengths` directly.
      reason: 'the new strengths never reached the row',
    );
    // An EDIT appends no step, and leaves ONE plan. The create path does not
    // refuse loudly here — it inserts a second row, the snapshot then reports
    // the new one, and every assertion about the new strengths still passes
    // while the person's history sits orphaned behind it.
    expect(saved.steps, hasLength(1));
    expect(
      await holder.database.planDao.countPlans(),
      1,
      reason: 'the edit created a second plan and orphaned the first',
    );

    final after = saved.logs;
    expect(after, hasLength(before.length));
    for (final log in before) {
      final match = after.firstWhere((entry) => entry.date == log.date);
      expect(match.actualMg, log.actualMg, reason: '${log.date}');
      expect(match.plannedMg, log.plannedMg, reason: '${log.date}');
      expect(match.taken, log.taken, reason: '${log.date}');
    }
  });

  test('a later snapshot does not overwrite what is being typed', () async {
    // The draft follows the stored plan until the user touches it. After that
    // a tick, a note or any other write must not reach in and change the
    // number under their finger.
    final container = containerAt();
    final repository = container.read(taperRepositoryProvider);
    await repository.savePlan(seededDraft());
    container.listen(planEditorProvider, (_, _) {});
    await container.read(taperSnapshotProvider.future);

    container
        .read(planEditorProvider.notifier)
        .edit(
          (draft) => draft.copyWith(drugName: 'Half-typed na'),
        );
    await repository.markTaken(today, plannedMg: mg(10));
    // Drained, not re-read: `read(provider.future)` on an already-resolved
    // stream hands back the value it ALREADY has, so the second await returns
    // before the new emission has arrived and the test proves nothing.
    await pumpEventQueue();

    expect(container.read(planEditorProvider).drugName, 'Half-typed na');
  });

  test('a duplicate strength is one strength', () {
    // `[5, 1, 5]mg` is `[1, 5]mg`. A duplicate changes nothing about what can
    // be composed and everything about how the chip row reads. Asserted on the
    // function rather than through the database, because EPIC-05's converter
    // also dedupes — and a test that cannot tell which of the two did it is a
    // test of neither.
    expect(
      sortedStrengths(<Milligrams>[
        mg(5),
        mg(1),
        mg(5),
      ]).map((s) => s.hundredths),
      <int>[100, 500],
    );
    expect(sortedStrengths(<Milligrams>[]), isEmpty);
  });
}
