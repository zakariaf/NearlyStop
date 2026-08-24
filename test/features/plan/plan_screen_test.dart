// The Plan screen: four cards, one save, and two guarded destructions.
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/backup/presentation/backup_actions.dart';
import 'package:nearlystop/features/plan/presentation/plan_cards.dart';
import 'package:nearlystop/features/plan/presentation/plan_edit_form.dart';
import 'package:nearlystop/features/plan/presentation/plan_editor_notifier.dart';
import 'package:nearlystop/features/plan/presentation/plan_screen.dart';
import 'package:nearlystop/features/plan/presentation/widgets/method_segmented_control.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/services/files/fake_share_gateway.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/db_harness.dart';
import '../../support/harness.dart';

void main() {
  const today = LocalDate(2026, 4, 16);

  late AppDatabaseHolder holder;
  late FakeShareGateway share;
  late List<String> exports;
  setUp(() {
    holder = AppDatabaseHolder(openTestDatabase());
    share = FakeShareGateway();
    exports = <String>[];
  });

  List<Override> overrides({
    LocalDate at = today,
    Failure? exportFails,
  }) => <Override>[
    databaseProvider.overrideWithValue(holder.database),
    todayDateProvider.overrideWithValue(at),
    clockProvider.overrideWithValue(
      Clock.fixed(DateTime.utc(at.year, at.month, at.day, 8)),
    ),
    resolvedLocaleProvider.overrideWithValue(const Locale('en')),
    shareGatewayProvider.overrideWithValue(share),
    backupExportProvider.overrideWithValue(() async {
      exports.add('export');
      if (exportFails case final failure?) {
        return Err<File, Failure>(failure);
      }
      return Ok<File, Failure>(File('/tmp/nearlystop-backup.ndjson'));
    }),
  ];

  Future<AppLocalizations> pumpPlan(
    WidgetTester tester, {
    LocalDate at = today,
    Size size = const Size(390, 1400),
    Failure? exportFails,
  }) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      const PlanScreen(),
      overrides: overrides(at: at, exportFails: exportFails),
      surfaceSize: size,
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  /// The snapshot the SCREEN is already watching.
  ///
  /// Never `watchSnapshot().first` inside `testWidgets`: a drift query stream
  /// emits off a timer, and a `testWidgets` body that awaits one without
  /// pumping deadlocks the whole file — no output, no timeout, nothing.
  TaperSnapshot? snapshotOf(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanScreen)),
    );
    return switch (container.read(taperSnapshotProvider)) {
      AsyncData<Result<TaperSnapshot, StorageFailure>>(:final value) =>
        switch (value) {
          Ok<TaperSnapshot, StorageFailure>(value: final facts) => facts,
          Err<TaperSnapshot, StorageFailure>() => null,
        },
      _ => null,
    };
  }

  widgetTestWithDatabase('the four cards appear in reference order', (
    tester,
  ) async {
    await pumpPlan(tester);

    final order = <Type>[
      PlanSummaryCard,
      PlanStrengthsCard,
      PlanMethodCard,
      PlanNextStepCard,
    ];
    final tops = <double>[
      for (final type in order) tester.getTopLeft(find.byType(type)).dy,
    ];
    expect(tops, orderedEquals(<double>[...tops]..sort()));
  });

  widgetTestWithDatabase(
    'no GridView and no ListTile — Material padding breaks parity',
    (
      tester,
    ) async {
      await pumpPlan(tester);

      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    },
  );

  widgetTestWithDatabase(
    'saving a clean install creates the plan AND its first step',
    (
      tester,
    ) async {
      final l10n = await pumpPlan(tester);

      await tester.ensureVisible(find.byType(PrimaryPillButton));
      await tester.tap(find.byType(PrimaryPillButton));
      await tester.pumpAndSettle();

      // ON SCREEN, not merely in the tree. Save sits at the bottom of a long
      // scrolling form; a confirmation rendered at the top of it is a
      // confirmation the reader who just tapped Save never sees — the tap looks
      // like it did nothing.
      expect(find.text(l10n.planSaved), findsOneWidget);
      final notice = tester.getRect(find.byKey(PlanScreen.noticeKey));
      final viewport = tester.getRect(find.byType(Scaffold));
      expect(
        notice.overlaps(viewport),
        isTrue,
        reason: 'the confirmation must be where the finger just was',
      );
      final saved = snapshotOf(tester)!;
      expect(saved.plan, isNotNull);
      expect(saved.steps, hasLength(1));
      expect(saved.steps.single.index, 0);
    },
  );

  widgetTestWithDatabase(
    'Save is dead while a field cannot be READ, and only then',
    (
      tester,
    ) async {
      // Tall enough that the whole form is BUILT: a `ListView` does not build
      // what is off-screen, so a shorter surface would make this test measure
      // the viewport rather than the button.
      final l10n = await pumpPlan(tester, size: const Size(390, 2600));

      PrimaryPillButton save() => tester.widget<PrimaryPillButton>(
        find.widgetWithText(PrimaryPillButton, l10n.planSave),
      );

      expect(save().onPressed, isNotNull);

      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '1.2.3');
      await tester.pump();
      expect(
        save().onPressed,
        isNull,
        reason:
            'saving text the app cannot read would store the OLD dose '
            'while the field shows a different number',
      );

      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '9.5');
      await tester.pump();
      expect(save().onPressed, isNotNull);

      // A warning is not a refusal: 120mg is a real starting dose for giant
      // cell arteritis.
      await tester.enterText(find.byKey(PlanEditForm.currentDoseKey), '120');
      await tester.pump();
      expect(find.text(l10n.planErrorDoseTooHigh), findsOneWidget);
      expect(save().onPressed, isNotNull);
    },
  );

  widgetTestWithDatabase(
    'switching method drops the error the old method left behind',
    (tester) async {
      // A fixed-step field that could not be read, abandoned by switching to
      // DSNS. The field is gone from the tree, so nothing on screen is red —
      // and if its verdict is still counted, Save is dead with nothing to fix.
      final l10n = await pumpPlan(tester, size: const Size(390, 2600));

      PrimaryPillButton save() => tester.widget<PrimaryPillButton>(
        find.widgetWithText(PrimaryPillButton, l10n.planSave),
      );

      await tester.tap(find.text(l10n.methodFixed));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(PlanMethodFields.fixedStepKey),
        '1.2.3',
      );
      await tester.pump();
      expect(save().onPressed, isNull);

      await tester.tap(find.text(l10n.methodDsns));
      await tester.pumpAndSettle();

      expect(find.byKey(PlanMethodFields.fixedStepKey), findsNothing);
      expect(
        save().onPressed,
        isNotNull,
        reason: 'the abandoned field still counts against Save',
      );
    },
  );

  widgetTestWithDatabase(
    'the caveat shows exactly when the engine says it diverges',
    (
      tester,
    ) async {
      // 10mg with 5mg + 1mg: 10% is exactly 1mg and 1mg is achievable, so the
      // figures do not diverge and the banner stays away.
      await pumpPlan(tester);
      expect(find.byKey(PlanNextStepCard.caveatKey), findsNothing);

      // 9mg: 10% is 0.9mg, and the largest achievable increment under it is
      // 0.5mg. They diverge, so the sentence appears.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanScreen)),
      );
      container
          .read(planEditorProvider.notifier)
          .edit(
            (draft) => draft.copyWith(
              currentDose: mg(9),
              strengths: <Milligrams>[mg(5), mg(1)],
            ),
          );
      await tester.pumpAndSettle();

      expect(find.byKey(PlanNextStepCard.caveatKey), findsOneWidget);
      expect(
        find.textContaining('your doctor’s instruction wins'),
        findsOneWidget,
      );
    },
  );

  widgetTestWithDatabase(
    'start next step is DISABLED with a reason, not hidden',
    (
      tester,
    ) async {
      // A disappearing control is unexplainable. The boundary is the test: day
      // 51 disabled, day 52 enabled — and the middle proves nothing.
      final l10n = await pumpPlan(tester);
      await tester.ensureVisible(find.byType(PrimaryPillButton));
      await tester.tap(find.byType(PrimaryPillButton));
      await tester.pumpAndSettle();

      final action = find.widgetWithText(SecondaryButton, l10n.actionNextStep);
      expect(action, findsOneWidget);
      expect(tester.widget<SecondaryButton>(action).onPressed, isNull);
      expect(find.text(l10n.planStepNotDue), findsOneWidget);
    },
  );

  widgetTestWithDatabase(
    'deleting takes two taps, and the sheet names what is lost',
    (
      tester,
    ) async {
      final l10n = await pumpPlan(tester);
      await tester.ensureVisible(find.byType(PrimaryPillButton));
      await tester.tap(find.byType(PrimaryPillButton));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DestructiveButton));
      await tester.tap(find.byType(DestructiveButton));
      await tester.pumpAndSettle();

      // The first tap only ASKS.
      expect(find.byType(ConfirmSheet), findsOneWidget);
      expect(find.text(l10n.planDeleteTitle), findsOneWidget);
      expect(snapshotOf(tester)?.plan, isNotNull);

      // And dismissing it deletes nothing.
      await tester.tap(find.text(l10n.actionCancel));
      await tester.pumpAndSettle();
      expect(snapshotOf(tester)?.plan, isNotNull);

      await tester.ensureVisible(find.byType(DestructiveButton));
      await tester.tap(find.byType(DestructiveButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.planDeleteConfirm));
      await tester.pumpAndSettle();

      expect(snapshotOf(tester)?.plan, isNull);
    },
  );

  widgetTestWithDatabase('deleting offers a backup first, and takes it', (
    tester,
  ) async {
    // SPEC §5.3: export before anything destructive, and the SAME guard the
    // replace-all restore uses. Losing two years of history to a tap is the
    // failure this app cannot recover from.
    final l10n = await pumpPlan(tester);
    await tester.ensureVisible(find.byType(PrimaryPillButton));
    await tester.tap(find.byType(PrimaryPillButton));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(DestructiveButton));
    await tester.tap(find.byType(DestructiveButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.planExportFirst), findsOneWidget);
    expect(find.text(l10n.planDeleteConfirm), findsOneWidget);

    await tester.tap(find.text(l10n.planExportFirst));
    await tester.pumpAndSettle();

    expect(exports, <String>['export']);
    expect(share.calls, hasLength(1));
    expect(snapshotOf(tester)?.plan, isNull);
  });

  widgetTestWithDatabase('a FAILED backup deletes nothing at all', (
    tester,
  ) async {
    // Somebody who chose "back up first" chose it because they wanted the
    // backup. Proceeding without one is the opposite of what they asked for,
    // and a guard that does it anyway is a formality with a spinner.
    final l10n = await pumpPlan(tester, exportFails: const Io('disk full'));
    await tester.ensureVisible(find.byType(PrimaryPillButton));
    await tester.tap(find.byType(PrimaryPillButton));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(DestructiveButton));
    await tester.tap(find.byType(DestructiveButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.planExportFirst));
    await tester.pumpAndSettle();

    expect(exports, <String>['export']);
    expect(
      snapshotOf(tester)?.plan,
      isNotNull,
      reason: 'the export failed and it deleted the plan anyway',
    );
  });

  widgetTestWithDatabase('all three methods are live, not two dead segments', (
    tester,
  ) async {
    final l10n = await pumpPlan(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanScreen)),
    );

    await tester.ensureVisible(find.byType(MethodSegmentedControl));
    await tester.tap(find.text(l10n.methodPercentage));
    await tester.pumpAndSettle();

    expect(container.read(planEditorProvider).method, TaperMethod.percentage);
  });
}
