/// The button ladder: five variants over one skin.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tappable.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// The shared body of every Daybreak button.
///
/// The DECORATION only — the tap behaviour, the press feedback, the haptic and
/// the semantics node all live in [DaybreakTappable], which the chips, the
/// method segments and the tab destinations use too.
///
/// It is public because the tests read its resolved slots. A test that read a
/// literal would pass while the theme said something else.
class DaybreakButtonSkin extends StatelessWidget {
  /// Creates a button body from already-resolved values.
  const DaybreakButtonSkin({
    required this.label,
    required this.onPressed,
    required this.minHeight,
    required this.ink,
    required this.textStyle,
    this.fill,
    this.gradient,
    this.borderColor,
    this.borderWidth = 0,
    this.shadow = const <BoxShadow>[],
    this.expand = false,
    super.key,
  });

  /// The label, already localized and in its natural case.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// The floor on the button's height at 1.0 text scale.
  final double minHeight;

  /// The label's colour.
  final Color ink;

  /// The label's style before [ink] is applied.
  final TextStyle textStyle;

  /// The flat fill, or null for a transparent (tertiary) button.
  final Color? fill;

  /// The gradient fill, for the primary pill only.
  final Gradient? gradient;

  /// The outline colour, or null for no outline.
  final Color? borderColor;

  /// The outline width.
  final double borderWidth;

  /// The shadow stack.
  final List<BoxShadow> shadow;

  /// Whether the button fills its parent's width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final l10n = AppLocalizations.of(context);
    final enabled = onPressed != null;

    return DaybreakTappable(
      // The disabled state is SAID, not only shown. `Semantics(enabled:)`
      // alone is read by VoiceOver but is invisible to a sighted reader with
      // low contrast vision, and a dimmed fill is invisible to a screen
      // reader. Both channels, always.
      semanticsLabel: enabled ? label : '$label, ${l10n.stateUnavailable}',
      onPressed: onPressed,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        width: expand ? double.infinity : null,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: shapes.s5,
          vertical: shapes.s3,
        ),
        decoration: BoxDecoration(
          // `surfaceSunken` even for the transparent tertiary: "changes fill
          // AND says the word, never opacity alone" has to hold for the
          // variant that has no fill to change, or the one button with no
          // visual disabled state is the quiet one nobody notices is dead.
          color: enabled ? fill : colors.surfaceSunken,
          gradient: enabled ? gradient : null,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
          border: borderColor == null
              ? null
              : Border.all(
                  color: enabled ? borderColor! : colors.border,
                  width: borderWidth,
                ),
          boxShadow: enabled ? shadow : const <BoxShadow>[],
        ),
        // NOT `alignment:` on the Container. Setting it makes a Container
        // EXPAND to fill its parent whenever the incoming constraints are
        // bounded — which turned every button in the ladder into a
        // full-screen slab, and made "min height 56" read as 844.
        child: Center(
          heightFactor: 1,
          widthFactor: expand ? null : 1,
          child: Text(
            // Never `toUpperCase()`: it no-ops in Persian and shouts in
            // English.
            label,
            textAlign: TextAlign.center,
            style: textStyle.copyWith(color: enabled ? ink : colors.inkFaint),
          ),
        ),
      ),
    );
  }
}

/// The signature action: a sunrise pill.
class PrimaryPillButton extends StatelessWidget {
  /// Creates a primary action.
  const PrimaryPillButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
    super.key,
  });

  /// The label, already localized.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Whether it fills its parent's width.
  final bool expand;

  /// The floor on its height.
  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    return DaybreakButtonSkin(
      label: label,
      onPressed: onPressed,
      minHeight: minHeight,
      ink: colors.onPrimary,
      textStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w800,
      ),
      gradient: colors.sunrise,
      expand: expand,
    );
  }
}

/// The second action: an outlined pill on the surface.
class SecondaryButton extends StatelessWidget {
  /// Creates a secondary action.
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
    super.key,
  });

  /// The label, already localized.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Whether it fills its parent's width.
  final bool expand;

  /// The floor on its height.
  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    return DaybreakButtonSkin(
      label: label,
      onPressed: onPressed,
      minHeight: minHeight,
      ink: colors.ink,
      textStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
      ),
      fill: colors.surface,
      borderColor: colors.borderStrong,
      borderWidth: 2,
      expand: expand,
    );
  }
}

/// The quiet action: a label, no fill.
class TertiaryButton extends StatelessWidget {
  /// Creates a tertiary action.
  const TertiaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// The label, already localized.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// The floor on its height. Lower than the others, and still above 44.
  static const double minHeight = 48;

  @override
  Widget build(BuildContext context) => DaybreakButtonSkin(
    label: label,
    onPressed: onPressed,
    minHeight: minHeight,
    ink: DaybreakColors.of(context).primaryDeep,
    textStyle: Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
  );
}

/// An action that cannot be undone — and therefore cannot act directly.
///
/// **The confirmation is not optional and not the caller's discipline.** The
/// constructor requires a [ConfirmRequest], and [onConfirmed] is only ever
/// reached through the sheet. A destructive button that could be wired
/// straight to a delete is a destructive button somebody eventually wires
/// straight to a delete.
class DestructiveButton extends StatelessWidget {
  /// Creates a guarded destructive action.
  const DestructiveButton({
    required this.label,
    required this.confirm,
    required this.onConfirmed,
    this.expand = false,
    super.key,
  }) : _immediate = false;

  /// The confirm action **inside** a [ConfirmSheet].
  ///
  /// The sheet IS the confirmation, so this one acts directly — the only
  /// variant that may, and the reason it is a named constructor rather than a
  /// flag anyone could pass.
  const DestructiveButton.immediate({
    required this.label,
    required VoidCallback? onPressed,
    this.expand = false,
    super.key,
  }) : onConfirmed = onPressed,
       confirm = null,
       _immediate = true;

  /// The label, already localized.
  final String label;

  /// What the sheet says. Null only for [DestructiveButton.immediate].
  final ConfirmRequest? confirm;

  /// Runs after the sheet is confirmed. Null disables the button.
  final VoidCallback? onConfirmed;

  /// Whether it fills its parent's width.
  final bool expand;

  final bool _immediate;

  /// The floor on its height.
  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    return DaybreakButtonSkin(
      label: label,
      onPressed: onConfirmed == null
          ? null
          : () async {
              if (_immediate) {
                onConfirmed!();
                return;
              }
              final result = await showConfirmSheet(context, confirm!);
              if (result == ConfirmResult.confirmed) onConfirmed!();
            },
      minHeight: minHeight,
      ink: colors.danger,
      textStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w800,
      ),
      fill: colors.tintDanger,
      borderColor: colors.dangerFill,
      borderWidth: 1,
      expand: expand,
    );
  }
}

/// The one action this app is opened to perform.
///
/// **88 logical px tall, not 56.** It is pressed one-handed by a 74-year-old
/// with a tremor, half awake, roughly 780 times. It is `surface` fill with
/// `ink` label — the reference's `.btn-onhero`, a light button ON the sunrise
/// card, never a second sunrise surface stacked on the first — and its shadow
/// is `level2`, because `glow` stays reserved for the card beneath it.
class TakenButton extends StatelessWidget {
  /// Creates the Taken action.
  const TakenButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// The label, already localized.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// The floor on its height. Deliberately larger than the rest of the ladder.
  static const double minHeight = 88;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    return DaybreakButtonSkin(
      label: label,
      onPressed: onPressed,
      minHeight: minHeight,
      ink: colors.ink,
      textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
        fontWeight: FontWeight.w800,
      ),
      fill: colors.surface,
      shadow: DaybreakElevation.of(context).level2,
      expand: true,
    );
  }
}
