/// "Stay at this dose for a few more days."
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// Asks how many extra days, and returns the number — or null.
///
/// Bounded 1–28: a longer stall is a plan change, not a hold. The body states
/// the consequence with the numbers filled in — "You stay at 9mg for 7 more
/// days. The step is not abandoned and nothing is lost." — rather than "your
/// schedule will be adjusted".
///
/// Presented through EPIC-07's shared [ConfirmSheet], not a private dialog.
Future<int?> showHoldSheet(
  BuildContext context,
  HoldPrompt prompt,
  AppLocalizations l10n, {
  required String doseLabel,
}) async {
  final days = ValueNotifier<int>(prompt.defaultExtraDays);
  try {
    final result = await showConfirmSheet(
      context,
      ConfirmRequest(
        title: l10n.holdTitle,
        body: prompt.blockLabel,
        confirmLabel: l10n.holdConfirm,
        cancelLabel: l10n.actionCancel,
        // Not destructive: a hold takes nothing away.
        isDestructive: false,
        content: (context) =>
            _HoldPicker(prompt: prompt, days: days, doseLabel: doseLabel),
      ),
    );
    return result == ConfirmResult.confirmed ? days.value : null;
  } finally {
    days.dispose();
  }
}

class _HoldPicker extends StatelessWidget {
  const _HoldPicker({
    required this.prompt,
    required this.days,
    required this.doseLabel,
  });

  final HoldPrompt prompt;
  final ValueNotifier<int> days;
  final String doseLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return ValueListenableBuilder<int>(
      valueListenable: days,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.holdExtraDays,
            style: text.labelLarge
                ?.atWeight(FontWeight.w800)
                .copyWith(color: colors.ink),
          ),
          SizedBox(height: shapes.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              HoldStepperButton(
                key: HoldStepperButton.decrementKey,
                glyph: Icons.remove,
                // Disabled at the floor rather than wrapping around: a
                // stepper that jumps from 1 to 28 is a stepper nobody trusts.
                onTap: value > prompt.minExtraDays
                    ? () => days.value = value - 1
                    : null,
              ),
              Text(
                '$value',
                style: text.headlineSmall
                    ?.atWeight(FontWeight.w800)
                    .copyWith(color: colors.ink),
              ),
              HoldStepperButton(
                key: HoldStepperButton.incrementKey,
                glyph: Icons.add,
                onTap: value < prompt.maxExtraDays
                    ? () => days.value = value + 1
                    : null,
              ),
            ],
          ),
          SizedBox(height: shapes.s3),
          Text(
            l10n.holdConsequence(doseLabel, '$value'),
            style: text.bodyMedium?.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}

/// One end of the stepper. Public so a test can drive it.
class HoldStepperButton extends StatelessWidget {
  /// Creates a stepper end.
  const HoldStepperButton({
    required this.glyph,
    required this.onTap,
    super.key,
  });

  /// Finds the minus.
  static const Key decrementKey = Key('hold-stepper-decrement');

  /// Finds the plus.
  static const Key incrementKey = Key('hold-stepper-increment');

  /// The side. Generous, because it is pressed repeatedly.
  static const double side = 48;

  /// Which end this is.
  final IconData glyph;

  /// Null at the bound.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final enabled = onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: enabled ? colors.surface : colors.surfaceSunken,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
          border: Border.all(
            color: enabled ? colors.borderStrong : colors.border,
            width: shapes.hairlineWidth,
          ),
        ),
        child: Icon(
          glyph,
          size: 22,
          color: enabled ? colors.ink : colors.inkFaint,
        ),
      ),
    );
  }
}
