/// "Go back to a dose that worked" — with the reader choosing which.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// Asks which earlier dose to revert to, and returns it — or null.
///
/// **The app never picks the dose.** "The last dose that worked" is a
/// judgement the person makes about their own body, so the sheet lists the
/// doses they have actually been on, newest first, with the previous step's
/// `fromDose` preselected rather than imposed. `SPEC.md` §5.2 names the
/// hardcoded two-button dialog as the thing every competitor gets wrong.
///
/// Presented through EPIC-07's shared [ConfirmSheet], not a private dialog.
Future<Milligrams?> showFlareSheet(
  BuildContext context,
  FlarePrompt prompt,
  AppLocalizations l10n,
) async {
  final selected = ValueNotifier<Milligrams>(prompt.defaultRevertTo);
  try {
    final result = await showConfirmSheet(
      context,
      ConfirmRequest(
        title: l10n.flareTitle,
        body: l10n.flareHistoryKept,
        confirmLabel: l10n.flareConfirm,
        cancelLabel: l10n.actionCancel,
        content: (context) => _FlarePicker(prompt: prompt, selected: selected),
      ),
    );
    return result == ConfirmResult.confirmed ? selected.value : null;
  } finally {
    selected.dispose();
  }
}

/// One row per dose the reader has actually been on.
class _FlarePicker extends StatelessWidget {
  const _FlarePicker({required this.prompt, required this.selected});

  final FlarePrompt prompt;
  final ValueNotifier<Milligrams> selected;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    if (prompt.candidates.isEmpty) {
      // An empty picker says nothing. This says why there is nothing to pick.
      return Text(
        l10n.flareNoHistory,
        style: text.bodyMedium?.copyWith(color: colors.inkMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.flarePickDose,
          style: text.labelLarge
              ?.atWeight(FontWeight.w800)
              .copyWith(color: colors.ink),
        ),
        SizedBox(height: shapes.s2),
        ValueListenableBuilder<Milligrams>(
          valueListenable: selected,
          builder: (context, value, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final candidate in prompt.candidates)
                Padding(
                  padding: EdgeInsetsDirectional.only(bottom: shapes.s2),
                  child: FlareCandidateTile(
                    candidate: candidate,
                    selected: candidate.dose == value,
                    onTap: () => selected.value = candidate.dose,
                  ),
                ),
            ],
          ),
        ),
        if (prompt.stepDiffersFromCommunity) ...<Widget>[
          SizedBox(height: shapes.s2),
          Text(
            // Said out loud rather than quietly resolved: the reader's doctor
            // decides, and hiding the disagreement decides for them.
            l10n
                .percentageExplainer(
                  '10',
                  '',
                  '',
                )
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim(),
            style: text.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
      ],
    );
  }
}

/// One selectable dose. Public so the tests can pick the SECOND one.
class FlareCandidateTile extends StatelessWidget {
  /// Creates a candidate row.
  const FlareCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// The dose and its date range.
  final FlareCandidate candidate;

  /// Whether it is the current choice.
  final bool selected;

  /// Chooses it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: candidate.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: EdgeInsetsDirectional.all(shapes.s3),
            decoration: BoxDecoration(
              color: selected ? colors.tintPrimary : colors.surface,
              borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
              border: Border.all(
                color: selected ? colors.borderStrong : colors.border,
                width: selected ? 2 : shapes.hairlineWidth,
              ),
            ),
            child: Row(
              children: <Widget>[
                // Selection is a glyph AND a ring AND a weight, not a tint.
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? colors.primaryDeep : colors.inkFaint,
                ),
                SizedBox(width: shapes.s2),
                Expanded(
                  child: Text(
                    candidate.label,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.atWeight(selected ? FontWeight.w800 : FontWeight.w600)
                        .copyWith(color: colors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
