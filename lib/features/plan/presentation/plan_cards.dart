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
import 'package:nearlystop/features/plan/presentation/plan_edit_form.dart';
import 'package:nearlystop/features/plan/presentation/plan_editor_notifier.dart';
import 'package:nearlystop/features/plan/presentation/widgets/method_segmented_control.dart';
import 'package:nearlystop/features/plan/presentation/widgets/strength_chip.dart';
import 'package:nearlystop/features/plan/presentation/widgets/strength_editor_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_card.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// A card on the Plan screen.
///
/// A thin naming layer over [DaybreakCard]: the surface, the radius, the
/// shadow and the overline treatment are shared with Settings, because the
/// reference frames show the same card on both screens.
class PlanCard extends StatelessWidget {
  /// Creates the card.
  const PlanCard({
    required this.children,
    this.heading,
    this.headingCaps,
    super.key,
  });

  /// The card's heading in sentence case, already localized.
  final String? heading;

  /// The same heading upper-cased by the translator, for Latin scripts.
  final String? headingCaps;

  /// Its contents.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(
      bottom: DaybreakShapes.of(context).s4,
    ),
    child: DaybreakCard(
      overline: heading,
      overlineCaps: headingCaps,
      children: children,
    ),
  );
}

/// Drug, current dose, target.
class PlanSummaryCard extends StatelessWidget {
  /// Creates the card.
  const PlanSummaryCard({
    required this.draft,
    required this.locale,
    required this.l10n,
    required this.onChanged,
    required this.onFieldError,
    super.key,
  });

  /// The draft being edited.
  final PlanDraft draft;

  /// The app's locale, for the numerals.
  final Locale locale;

  /// The strings.
  final AppLocalizations l10n;

  /// Hands back the edited draft.
  final ValueChanged<PlanDraft> onChanged;

  /// Hands back each field's current verdict.
  final PlanFieldErrorCallback onFieldError;

  @override
  Widget build(BuildContext context) => PlanCard(
    children: <Widget>[
      PlanEditForm(
        draft: draft,
        locale: locale,
        l10n: l10n,
        onChanged: onChanged,
        onFieldError: onFieldError,
      ),
    ],
  );
}

/// The strengths held, and whether they can be split.
class PlanStrengthsCard extends StatefulWidget {
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
  State<PlanStrengthsCard> createState() => _PlanStrengthsCardState();
}

class _PlanStrengthsCardState extends State<PlanStrengthsCard> {
  String? _refusal;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final l10n = widget.l10n;
    final draft = widget.draft;

    return PlanCard(
      heading: l10n.planStrengths,
      headingCaps: l10n.planStrengthsCaps,
      children: <Widget>[
        // A `Wrap`, never a horizontal scroller: a strength hidden off the
        // edge is a strength the person believes they do not have.
        Wrap(
          spacing: shapes.s2,
          runSpacing: shapes.s2,
          children: <Widget>[
            // BIGGEST FIRST, which is the order the box reads in and the order
            // the reference frame shows. The domain sorts ascending — it
            // deduplicates for storage — and rendering that order puts the
            // tablet somebody reaches for first at the end of the row.
            for (final strength in draft.strengths.reversed)
              StrengthChip(
                label:
                    '${formatDose(strength, widget.locale)}'
                    '${l10n.milligramUnit}',
                value: '${strength.hundredths}',
                selected: true,
                onSelected: (_) => _remove(strength),
              ),
          ],
        ),
        if (_refusal case final message?) ...<Widget>[
          SizedBox(height: shapes.s2),
          // Announced, not merely painted: a refusal a screen reader cannot
          // reach is a chip that silently would not go away.
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.danger),
            ),
          ),
        ],
        SizedBox(height: shapes.s2),
        Text(
          l10n.planStrengthsNote,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
        ),
        SizedBox(height: shapes.s3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TertiaryButton(label: l10n.planAddStrength, onPressed: _add),
        ),
        SizedBox(height: shapes.s3),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.planAllowHalves,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  // Which way it is set, in a word. A switch alone is a shape
                  // whose meaning depends on which end the knob is at, and
                  // that reading is the one this audience finds hardest.
                  Text(
                    draft.allowHalves ? l10n.settingsOn : l10n.settingsOff,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                ],
              ),
            ),
            Switch(
              value: draft.allowHalves,
              onChanged: (value) =>
                  widget.onChanged(draft.copyWith(allowHalves: value)),
            ),
          ],
        ),
      ],
    );
  }

  /// Removing the LAST strength is refused: with none held, every dose is
  /// unachievable and the app can only say so.
  ///
  /// Refused **out loud**. Silently ignoring the tap leaves the reader
  /// pressing a chip that will not go away with nothing to tell them why.
  void _remove(Milligrams strength) {
    if (widget.draft.strengths.length <= 1) {
      setState(() => _refusal = widget.l10n.planErrorLastStrength);
      return;
    }
    setState(() => _refusal = null);
    widget.onChanged(
      widget.draft.copyWith(
        strengths: <Milligrams>[
          for (final held in widget.draft.strengths)
            if (held != strength) held,
        ],
      ),
    );
  }

  Future<void> _add() async {
    final added = await showStrengthEditor(
      context: context,
      locale: widget.locale,
      l10n: widget.l10n,
    );
    if (added == null || !mounted) return;
    setState(() => _refusal = null);
    widget.onChanged(
      widget.draft.copyWith(
        strengths: <Milligrams>[...widget.draft.strengths, added],
      ),
    );
  }
}

/// DSNS, percentage or fixed — all three live.
class PlanMethodCard extends StatelessWidget {
  /// Creates the card.
  const PlanMethodCard({
    required this.draft,
    required this.locale,
    required this.l10n,
    required this.onChanged,
    required this.onFieldError,
    super.key,
  });

  /// The draft being edited.
  final PlanDraft draft;

  /// The app's locale, for the numerals.
  final Locale locale;

  /// The strings.
  final AppLocalizations l10n;

  /// Hands back the edited draft.
  final ValueChanged<PlanDraft> onChanged;

  /// Hands back each field's current verdict.
  final PlanFieldErrorCallback onFieldError;

  @override
  Widget build(BuildContext context) => PlanCard(
    heading: l10n.planMethod,
    headingCaps: l10n.planMethodCaps,
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
      PlanMethodFields(
        draft: draft,
        locale: locale,
        l10n: l10n,
        onChanged: onChanged,
        onFieldError: onFieldError,
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
        headingCaps: l10n.planNextStepCaps,
        children: <Widget>[Text(l10n.planTaperComplete)],
      );
    }

    return PlanCard(
      heading: l10n.planNextStep,
      headingCaps: l10n.planNextStepCaps,
      children: <Widget>[
        // A `Wrap`, not a `Row`. At the largest OS text size `10mg → 9mg` at
        // headlineLarge is 42pt wider than a 390pt phone, and a `Row` answers
        // that by clipping the dose the reader is heading FOR. Wrapping costs
        // a line; shrinking or clipping costs the number.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: shapes.s2,
          runSpacing: shapes.s1,
          children: <Widget>[
            Text(
              _dose(state.from),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.ink,
              ),
            ),
            // Mirrors itself in RTL, where the taper reads right to left.
            Icon(Icons.adaptive.arrow_forward, color: colors.primaryDeep),
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
    headingCaps: l10n.planDangerZoneCaps,
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
