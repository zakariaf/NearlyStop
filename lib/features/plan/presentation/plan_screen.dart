/// The Plan screen: where the taper is created, and edited.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/plan/presentation/plan_cards.dart';
import 'package:nearlystop/features/plan/presentation/plan_editor_notifier.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// The plan, its next step, and the two things that can destroy it.
///
/// The screen a person touches at setup and then roughly every 52 days, which
/// makes it the one place where a wrong keystroke costs two years of history —
/// so nothing here writes until Save, and nothing destructive happens without
/// a second, deliberate tap.
class PlanScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PlanScreen({super.key});

  /// Above this width the cards go two-up.
  static const double twoPaneBreakpoint = 840;

  /// Finds the save/failure notice.
  static const Key noticeKey = Key('plan-notice');

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  String? _notice;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(planEditorProvider.notifier).save();
    if (!mounted) return;
    setState(
      () => _notice = switch (result) {
        Ok<void, StorageFailure>() => l10n.planSaved,
        Err<void, StorageFailure>() => l10n.errorTitle,
      },
    );
  }

  Future<void> _startNextStep() async {
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(taperRepositoryProvider).startNextStep();
    if (!mounted) return;
    setState(
      () => _notice = switch (result) {
        Ok<void, StorageFailure>() => null,
        Err<void, StorageFailure>() => l10n.planStepNotDue,
      },
    );
  }

  Future<void> _delete() async {
    await ref.read(taperRepositoryProvider).deletePlan();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shapes = DaybreakShapes.of(context);
    final locale = ref.watch(resolvedLocaleProvider);
    final draft = ref.watch(planEditorProvider);
    final editor = ref.watch(planEditorProvider.notifier);
    final snapshot = ref.watch(taperSnapshotProvider);
    final today = ref.watch(todayDateProvider);

    final facts = switch (snapshot) {
      AsyncData<Result<TaperSnapshot, StorageFailure>>(:final value) =>
        switch (value) {
          Ok<TaperSnapshot, StorageFailure>(value: final data) => data,
          Err<TaperSnapshot, StorageFailure>() => null,
        },
      _ => null,
    };
    final preview = editor.preview();
    final wide =
        MediaQuery.sizeOf(context).width > PlanScreen.twoPaneBreakpoint;

    final summary = PlanSummaryCard(draft: draft, locale: locale, l10n: l10n);
    final strengths = PlanStrengthsCard(
      draft: draft,
      locale: locale,
      l10n: l10n,
      onChanged: (next) => editor.edit((_) => next),
    );
    final method = PlanMethodCard(
      draft: draft,
      l10n: l10n,
      onChanged: (next) => editor.edit((_) => next),
    );
    final nextStep = PlanNextStepCard(
      preview: preview,
      draft: draft,
      locale: locale,
      l10n: l10n,
      canStart: _canStartNextStep(facts, today),
      onStart: _startNextStep,
      onOverride: (step) =>
          editor.edit((draft) => draft.copyWith(stepOverride: step)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabPlan)),
      body: ListView(
        padding: EdgeInsetsDirectional.all(shapes.s5),
        children: <Widget>[
          if (_notice case final message?)
            PlanNotice(message: message, key: PlanScreen.noticeKey),
          if (wide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: summary),
                  SizedBox(width: shapes.s4),
                  Expanded(child: strengths),
                ],
              ),
            )
          else ...<Widget>[summary, strengths],
          method,
          nextStep,
          SizedBox(height: shapes.s4),
          PrimaryPillButton(
            label: l10n.planSave,
            expand: true,
            onPressed: _save,
          ),
          SizedBox(height: shapes.s6),
          PlanDangerZone(
            l10n: l10n,
            // The sheet names what is lost — the plan and the COUNT of
            // recorded days, read from the snapshot rather than typed.
            confirm: ConfirmRequest(
              title: l10n.planDeleteTitle,
              body: l10n.planDeleteBody(facts?.logs.length ?? 0),
              confirmLabel: l10n.planDeleteConfirm,
              cancelLabel: l10n.actionCancel,
            ),
            onConfirmed: facts?.plan == null ? null : _delete,
          ),
        ],
      ),
    );
  }

  /// Whether the active step is finished, by EPIC-04's ONE definition.
  ///
  /// `stepStatusFor` is the only thing that decides this. A second local rule
  /// — "52 days elapsed *or* all its days logged" — is two rules in one
  /// parenthesis, and they disagree the first time somebody backfills.
  bool _canStartNextStep(TaperSnapshot? facts, LocalDate today) {
    final plan = facts?.plan;
    if (plan == null || facts!.steps.isEmpty) return false;
    final last = facts.steps.last;
    if (last.toDose <= plan.targetDose) return false;
    final holds = <HoldEvent>[
      for (final hold in facts.holds)
        if (hold.stepId == last.id) hold,
    ];
    return stepStatusFor(
          last,
          holds,
          today,
          nominalLength: nominalStepLength(plan),
        ) ==
        StepStatus.completed;
  }
}
