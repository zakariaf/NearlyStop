/// The Plan screen: where the taper is created, and edited.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/app/window_size.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/schedule_generator.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/plan/presentation/plan_cards.dart';
import 'package:nearlystop/features/plan/presentation/plan_edit_form.dart';
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

  /// Finds the save/failure notice.
  static const Key noticeKey = Key('plan-notice');

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  String? _notice;

  /// What each field last said, keyed by field.
  ///
  /// The Save button is derived from this rather than from a stored `bool`:
  /// `FormState.validate()` calls `setState` on every field and so cannot run
  /// during a build, which is exactly when the answer is needed.
  final Map<PlanField, String?> _fieldErrors = <PlanField, String?>{};

  /// Whether every field the CURRENT method shows reads back.
  ///
  /// Filtered by `appliesTo` rather than cleared on a method change: a map
  /// that has to be pruned is a map somebody forgets to prune, and the symptom
  /// — Save dead, nothing red — is invisible in review.
  bool _fieldsRead(TaperMethod method) => _fieldErrors.entries
      .where((entry) => entry.key.appliesTo(method))
      .every((entry) => entry.value == null);

  void _reportFieldError(PlanField field, String? error) {
    if (_fieldErrors[field] == error && _fieldErrors.containsKey(field)) return;
    setState(() => _fieldErrors[field] = error);
  }

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
    // The shared vocabulary, not a literal: the shell picks its rail off the
    // same enum, and two hand-tuned numbers drift the first time one is
    // changed. `isAtLeast` is inclusive on purpose — a 840pt tablet IS the
    // expanded class, and `>` would leave that exact device one-up.
    final wide = WindowSizeClass.forWidth(
      MediaQuery.sizeOf(context).width,
    ).isAtLeast(WindowSizeClass.expanded);

    final summary = PlanSummaryCard(
      draft: draft,
      locale: locale,
      l10n: l10n,
      onChanged: (next) => editor.edit((_) => next),
      onFieldError: _reportFieldError,
    );
    final strengths = PlanStrengthsCard(
      draft: draft,
      locale: locale,
      l10n: l10n,
      onChanged: (next) => editor.edit((_) => next),
    );
    final method = PlanMethodCard(
      draft: draft,
      locale: locale,
      l10n: l10n,
      onChanged: (next) => editor.edit((_) => next),
      onFieldError: _reportFieldError,
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
          // Beside the button that produced it, not at the top of the list.
          // Save sits at the bottom of a long scrolling form; a confirmation
          // rendered above the first card is one the reader who just tapped it
          // never sees, and the tap reads as having done nothing.
          if (_notice case final message?)
            PlanNotice(message: message, key: PlanScreen.noticeKey),
          PrimaryPillButton(
            label: l10n.planSave,
            expand: true,
            // Disabled only while a field cannot be READ. A warning — "that is
            // a very high dose" — leaves it enabled: 120mg is a real starting
            // dose for giant cell arteritis, and refusing it would tell
            // somebody with a prescription that their own dose is impossible.
            onPressed: _fieldsRead(draft.method) ? _save : null,
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
