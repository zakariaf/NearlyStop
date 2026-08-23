/// Browsing the other steps, read-only.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// The app-bar control that opens the step switcher.
///
/// The glyph is `Icons.adaptive.arrow_forward`, which mirrors itself in RTL.
/// EPIC-01's ban gate rejects the non-adaptive names for exactly that reason.
class StepSwitcherButton extends StatelessWidget {
  /// Creates the button.
  const StepSwitcherButton({
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  /// Finds the button, for tests that tap it.
  static const Key buttonKey = Key('schedule-step-switcher');

  /// The button's label, already localized. Never a bare glyph.
  final String tooltip;

  /// Opens the sheet.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(Icons.adaptive.arrow_forward),
  );
}

/// Lists every step and resolves to the one chosen, or null.
Future<int?> showStepSwitcherSheet(
  BuildContext context,
  List<StepOption> options,
  AppLocalizations l10n, {
  required int current,
}) => showDaybreakSheet<int>(
  context: context,
  builder: (context) => DaybreakSheetShell(
    routeLabel: l10n.stepSwitcherTitle,
    child: StepSwitcherSheet(
      options: options,
      current: current,
      title: l10n.stepSwitcherTitle,
      completedLabel: l10n.blockCompleted,
      readOnlyLabel: l10n.pastStepReadOnly,
    ),
  ),
);

/// The sheet's body.
class StepSwitcherSheet extends StatelessWidget {
  /// Creates the sheet.
  const StepSwitcherSheet({
    required this.options,
    required this.current,
    required this.title,
    required this.completedLabel,
    required this.readOnlyLabel,
    super.key,
  });

  /// Every step, already localized.
  final List<StepOption> options;

  /// The step on screen now.
  final int current;

  /// The sheet's heading, already localized.
  final String title;

  /// The word for a finished step, already localized.
  final String completedLabel;

  /// What browsing a finished step means, already localized.
  final String readOnlyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.ink,
          ),
        ),
        SizedBox(height: shapes.s2),
        Text(
          readOnlyLabel,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
        ),
        SizedBox(height: shapes.s4),
        for (final option in options)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: shapes.s2),
            child: _StepTile(
              option: option,
              isCurrent: option.index == current,
              completedLabel: completedLabel,
            ),
          ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.option,
    required this.isCurrent,
    required this.completedLabel,
  });

  final StepOption option;
  final bool isCurrent;
  final String completedLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final done = option.status == StepStatus.completed;

    return Material(
      color: isCurrent ? colors.tintPrimary : colors.surface,
      borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(option.index),
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: shapes.s4,
            vertical: shapes.s3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
            border: Border.all(
              color: isCurrent ? colors.primaryDeep : colors.border,
              width: shapes.hairlineWidth,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  option.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
              if (done) ...<Widget>[
                SizedBox(width: shapes.s2),
                // Glyph AND word: the tint alone is colour on its own.
                Icon(Icons.check_circle, size: 18, color: colors.success),
                SizedBox(width: shapes.s1),
                Text(
                  completedLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.success,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
