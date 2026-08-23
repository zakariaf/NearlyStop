/// The four cards of the Plan screen, plus its notice and its danger zone.
///
/// **Not under `widgets/`.** They take a draft and hand back a new one, which
/// is a screen section's job; the dumb components they are built from —
/// `StrengthChip`, `MethodSegmentedControl` — live there.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/plan/presentation/next_step_view_state.dart';
import 'package:nearlystop/features/plan/presentation/plan_editor_notifier.dart';
import 'package:nearlystop/features/plan/presentation/widgets/method_segmented_control.dart';
import 'package:nearlystop/features/plan/presentation/widgets/strength_chip.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// A card on the Plan screen.
class PlanCard extends StatelessWidget {
  /// Creates the card.
  const PlanCard({required this.children, this.heading, super.key});

  /// The card's heading, already localized.
  final String? heading;

  /// Its contents.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: shapes.s4),
      child: Container(
        padding: EdgeInsetsDirectional.all(shapes.s4),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
          boxShadow: DaybreakElevation.of(context).level1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (heading case final title?) ...<Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.ink,
                  ),
                ),
              ),
              SizedBox(height: shapes.s3),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// One label-and-value line.
class PlanRowItem extends StatelessWidget {
  /// Creates the row.
  const PlanRowItem({
    required this.label,
    required this.value,
    this.sublabel,
    super.key,
  });

  /// What it is, already localized.
  final String label;

  /// Its value, already formatted.
  final String value;

  /// An optional second line under the label.
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: shapes.s2),
      child: Semantics(
        container: true,
        label: '$label $value',
        child: ExcludeSemantics(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    if (sublabel case final second?)
                      Text(
                        second,
                        style: text.bodySmall?.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              // A `Row` with a flexible label, not `Alignment.centerRight`:
              // the value belongs at the reading END, which is the left edge
              // in Persian and the right in English.
              SizedBox(width: shapes.s3),
              Text(
                value,
                style: text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.ink,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drug, current dose, target.
class PlanSummaryCard extends StatelessWidget {
  /// Creates the card.
  const PlanSummaryCard({
    required this.draft,
    required this.locale,
    required this.l10n,
    super.key,
  });

  /// The draft being edited.
  final PlanDraft draft;

  /// The app's locale, for the numerals.
  final Locale locale;

  /// The strings.
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => PlanCard(
    children: <Widget>[
      PlanRowItem(
        label: draft.drugName,
        sublabel: l10n.planMedicine,
        value: '',
      ),
      PlanRowItem(
        label: l10n.planCurrentDose,
        value: _dose(draft.currentDose),
      ),
      PlanRowItem(label: l10n.planTarget, value: _dose(draft.targetDose)),
    ],
  );

  String _dose(Milligrams dose) =>
      '${formatDose(dose, locale)}${l10n.milligramUnit}';
}

/// The strengths held, and whether they can be split.
class PlanStrengthsCard extends StatelessWidget {
  /// Creates the card.
  const PlanStrengthsCard({
    required this.draft,
    required this.locale,
    required this.l10n,
    required this.onChanged,
    super.key,
  });

  /// The draft being edited.
  final PlanDraft draft;

  /// The app's locale.
  final Locale locale;

  /// The strings.
  final AppLocalizations l10n;

  /// Hands back the edited draft. The screen decides what to do with it.
  final ValueChanged<PlanDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return PlanCard(
      heading: l10n.planStrengths,
      children: <Widget>[
        // A `Wrap`, never a horizontal scroller: a strength hidden off the
        // edge is a strength the person believes they do not have.
        Wrap(
          spacing: shapes.s2,
          runSpacing: shapes.s2,
          children: <Widget>[
            for (final strength in draft.strengths)
              StrengthChip(
                label: '${formatDose(strength, locale)}${l10n.milligramUnit}',
                value: '${strength.hundredths}',
                selected: true,
                onSelected: (_) => _remove(strength),
              ),
          ],
        ),
        SizedBox(height: shapes.s2),
        Text(
          l10n.planStrengthsNote,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
        ),
        SizedBox(height: shapes.s3),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.planAllowHalves,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
            ),
            Switch(
              value: draft.allowHalves,
              onChanged: (value) =>
                  onChanged(draft.copyWith(allowHalves: value)),
            ),
          ],
        ),
      ],
    );
  }

  /// Removing the LAST strength is refused: with none held, every dose is
  /// unachievable and the app can only say so.
  void _remove(Milligrams strength) {
    if (draft.strengths.length <= 1) return;
    onChanged(
      draft.copyWith(
        strengths: <Milligrams>[
          for (final held in draft.strengths)
            if (held != strength) held,
        ],
      ),
    );
  }
}

/// DSNS, percentage or fixed — all three live.
class PlanMethodCard extends StatelessWidget {
  /// Creates the card.
  const PlanMethodCard({
    required this.draft,
    required this.l10n,
    required this.onChanged,
    super.key,
  });

  /// The draft being edited.
  final PlanDraft draft;

  /// The strings.
  final AppLocalizations l10n;

  /// Hands back the edited draft.
  final ValueChanged<PlanDraft> onChanged;

  @override
  Widget build(BuildContext context) => PlanCard(
    heading: l10n.planMethod,
    children: <Widget>[
      MethodSegmentedControl(
        value: draft.method,
        labels: <TaperMethod, String>{
          TaperMethod.dsns: l10n.methodDsns,
          TaperMethod.percentage: l10n.methodPercentage,
          TaperMethod.fixedMg: l10n.methodFixed,
        },
        onChanged: (method) => onChanged(draft.copyWith(method: method)),
      ),
    ],
  );
}

/// The next step, its caveat, and the action that starts it.
class PlanNextStepCard extends StatelessWidget {
  /// Creates the card.
  const PlanNextStepCard({
    required this.preview,
    required this.draft,
    required this.locale,
    required this.l10n,
    required this.canStart,
    required this.onStart,
    required this.onOverride,
    super.key,
  });

  /// Finds the caveat banner.
  static const Key caveatKey = Key('plan-caveat');

  /// The engine's projection, or null when it refuses.
  final NextStepViewState? preview;

  /// The draft being edited.
  final PlanDraft draft;

  /// The app's locale.
  final Locale locale;

  /// The strings.
  final AppLocalizations l10n;

  /// Whether the active step is finished (EPIC-04's `stepStatusFor`).
  final bool canStart;

  /// Starts the next step.
  final Future<void> Function() onStart;

  /// Overrides the step size.
  final ValueChanged<Milligrams> onOverride;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final state = preview;

    if (state == null || state.isComplete) {
      return PlanCard(
        heading: l10n.planNextStep,
        children: <Widget>[Text(l10n.planTaperComplete)],
      );
    }

    return PlanCard(
      heading: l10n.planNextStep,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              _dose(state.from),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
            SizedBox(width: shapes.s2),
            // Mirrors itself in RTL, where the taper reads right to left.
            Icon(Icons.adaptive.arrow_forward, color: colors.primaryDeep),
            SizedBox(width: shapes.s2),
            Text(
              _dose(state.to),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primaryDeep,
              ),
            ),
          ],
        ),
        SizedBox(height: shapes.s2),
        Text(
          l10n.suggestedStep(_dose(state.suggested)),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
        ),
        if (state.clampedToTarget) ...<Widget>[
          SizedBox(height: shapes.s1),
          Text(
            l10n.planReachesTarget,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
        if (state.showsCaveat) ...<Widget>[
          SizedBox(height: shapes.s3),
          PlanCaveatBanner(
            key: caveatKey,
            message: l10n.planCaveat(
              // "10%", in the locale's own numerals.
              '${numberFormatFor(locale).format(10)}%',
              _dose(state.from),
              _dose(state.tenPercent),
            ),
          ),
        ],
        SizedBox(height: shapes.s3),
        Row(
          children: <Widget>[
            Expanded(
              child: SecondaryButton(
                label: l10n.planStepOverride,
                expand: true,
                onPressed: () => onOverride(_nextIncrement(state)),
              ),
            ),
          ],
        ),
        SizedBox(height: shapes.s2),
        // Present and DISABLED, never hidden: a control that disappears is a
        // control nobody can ask about.
        SecondaryButton(
          label: l10n.actionNextStep,
          expand: true,
          onPressed: canStart ? onStart : null,
        ),
        if (!canStart) ...<Widget>[
          SizedBox(height: shapes.s1),
          Text(
            l10n.planStepNotDue,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
      ],
    );
  }

  /// One achievable increment up from the current step.
  Milligrams _nextIncrement(NextStepViewState state) {
    final smallest = draft.strengths.isEmpty
        ? 100
        : draft.strengths.first.hundredths ~/ (draft.allowHalves ? 2 : 1);
    final next = (draft.stepOverride ?? state.suggested).hundredths + smallest;
    final ceiling = state.from.hundredths;
    return Milligrams.fromHundredths(next > ceiling ? ceiling : next);
  }

  String _dose(Milligrams dose) =>
      '${formatDose(dose, locale)}${l10n.milligramUnit}';
}

/// "10% of 9mg is 0.9mg — your doctor's instruction wins."
class PlanCaveatBanner extends StatelessWidget {
  /// Creates the banner.
  const PlanCaveatBanner({required this.message, super.key});

  /// The sentence, already localized and already numbered.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Container(
      padding: EdgeInsetsDirectional.all(shapes.s3),
      decoration: BoxDecoration(
        color: colors.tintWarning,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
        border: Border.all(color: colors.warning, width: shapes.hairlineWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              Icons.info_outline,
              size: 18,
              // The glyph is amber; the BODY is ink. A whole paragraph in the
              // warning colour is harder to read and reads as a telling-off,
              // and this sentence is not one.
              color: colors.warning,
            ),
          ),
          SizedBox(width: shapes.s2),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deleting the plan, behind two taps.
///
/// EPIC-07's `DestructiveButton` takes the `ConfirmRequest` in its
/// constructor and only ever reaches `onConfirmed` through the sheet — a
/// destructive button that COULD be wired straight to a delete is one somebody
/// eventually wires straight to a delete.
class PlanDangerZone extends StatelessWidget {
  /// Creates the zone.
  const PlanDangerZone({
    required this.l10n,
    required this.confirm,
    required this.onConfirmed,
    super.key,
  });

  /// The strings.
  final AppLocalizations l10n;

  /// What the sheet says, including how many recorded days are at stake.
  final ConfirmRequest confirm;

  /// Runs only after the sheet is confirmed. Null when there is no plan.
  final VoidCallback? onConfirmed;

  @override
  Widget build(BuildContext context) => PlanCard(
    heading: l10n.planDangerZone,
    children: <Widget>[
      DestructiveButton(
        label: l10n.planDelete,
        expand: true,
        confirm: confirm,
        onConfirmed: onConfirmed,
      ),
    ],
  );
}

/// A saved / failed line above the cards.
class PlanNotice extends StatelessWidget {
  /// Creates the notice.
  const PlanNotice({required this.message, super.key});

  /// What happened, already localized.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: EdgeInsetsDirectional.only(bottom: shapes.s4),
        padding: EdgeInsetsDirectional.all(shapes.s3),
        decoration: BoxDecoration(
          color: colors.tintSuccess,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
          border: Border.all(
            color: colors.success,
            width: shapes.hairlineWidth,
          ),
        ),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.ink),
        ),
      ),
    );
  }
}
