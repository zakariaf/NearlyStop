/// The button ladder: five variants over one skin.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tappable.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

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
    this.glyph,
    this.busy = false,
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

  /// An optional leading mark. **Decoration**: the label already says it.
  final IconData? glyph;

  /// Whether the button's own work is running.
  ///
  /// Progress belongs ON the control that started it, never on a barrier over
  /// the app: a modal scrim while a file is written says "you may not look at
  /// today's dose", which is the opposite of what this app is for. A busy
  /// button is disabled by construction — a second tap would start the work
  /// twice.
  final bool busy;

  /// The diameter of the inline spinner, at 1.0 text scale.
  ///
  /// Matched to the label's own size, so it reads as part of the word rather
  /// than as an ornament beside it.
  static const double spinnerSize = 18;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final l10n = AppLocalizations.of(context);
    final enabled = onPressed != null && !busy;

    return DaybreakTappable(
      // The disabled state is SAID, not only shown. `Semantics(enabled:)`
      // alone is read by VoiceOver but is invisible to a sighted reader with
      // low contrast vision, and a dimmed fill is invisible to a screen
      // reader. Both channels, always. A spinner has the same problem twice
      // over: it is pure animation, so it says nothing at all.
      semanticsLabel: busyAwareSemantics(
        label,
        busy: busy,
        enabled: enabled,
        l10n: l10n,
      ),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (busy) ...<Widget>[
                InlineSpinner(diameter: spinnerSize, color: colors.inkFaint),
                SizedBox(width: shapes.s2),
              ] else if (glyph case final mark?) ...<Widget>[
                // EXCLUDED from semantics: the glyph repeats the label, and
                // "tick, I understand" is the button read to you twice.
                ExcludeSemantics(
                  child: Icon(
                    mark,
                    size: MediaQuery.textScalerOf(
                      context,
                    ).scale(textStyle.fontSize ?? shapes.s5),
                    color: enabled ? ink : colors.inkFaint,
                  ),
                ),
                SizedBox(width: shapes.s2),
              ],
              Flexible(
                child: Text(
                  // Never `toUpperCase()`: it no-ops in Persian and shouts in
                  // English.
                  label,
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(
                    color: enabled ? ink : colors.inkFaint,
                  ),
                ),
              ),
            ],
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
    this.glyph,
    super.key,
  });

  /// The label, already localized.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Whether it fills its parent's width.
  final bool expand;

  /// An optional leading mark. **Decoration**: the label already says it.
  final IconData? glyph;

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
      textStyle: Theme.of(
        context,
      ).textTheme.titleMedium!.atWeight(FontWeight.w800),
      gradient: colors.sunrise,
      expand: expand,
      glyph: glyph,
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
    this.busy = false,
    super.key,
  });

  /// The label, already localized.
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Whether it fills its parent's width.
  final bool expand;

  /// Whether this button's own work is running. See [DaybreakButtonSkin.busy].
  final bool busy;

  /// The floor on its height.
  static const double minHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    return DaybreakButtonSkin(
      label: label,
      onPressed: onPressed,
      busy: busy,
      minHeight: minHeight,
      ink: colors.ink,
      textStyle: Theme.of(
        context,
      ).textTheme.titleMedium!.atWeight(FontWeight.w700),
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
    ).textTheme.titleMedium!.atWeight(FontWeight.w700),
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

  /// A destructive button whose confirmation lives somewhere ELSE.
  ///
  /// Two callers, both legitimate: the action inside a [ConfirmSheet] — the
  /// sheet IS the confirmation — and a button that opens an `ExportGuard`,
  /// which is three exits rather than two and therefore cannot be expressed
  /// as this widget's own [confirm]. A named constructor rather than a flag
  /// anyone could pass, because "destructive, no confirmation here" has to be
  /// a decision somebody wrote down.
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
      textStyle: Theme.of(
        context,
      ).textTheme.titleMedium!.atWeight(FontWeight.w800),
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
      // `.btn { font-size: var(--fs-body-lg) }` — 20, the same as every other
      // rung of the ladder. The HEIGHT is this button's deviation; the label
      // was never meant to be a second one, and at 24 it made the deviation
      // look twice as large as it is.
      textStyle: Theme.of(
        context,
      ).textTheme.bodyLarge!.atWeight(FontWeight.w800),
      fill: colors.surface,
      shadow: DaybreakElevation.of(context).level2,
      expand: true,
      // Frame 02 draws a check beside the word, and this is the one control
      // on the screen a reader looks for before they have read anything.
      // Decoration only — `DaybreakButtonSkin` excludes it from semantics, so
      // the button is still announced once.
      glyph: Icons.check,
    );
  }
}

/// The one inline spinner in the app.
///
/// Shared because a second copy is a second diameter and a second colour, on
/// two controls a reader sees in the same session. It scales with the text so
/// it does not shrink into a dot at the largest OS setting.
///
/// Carries **no semantics**: the control it sits in already says the working
/// word, and a progress node beside that label reads as a second, unnamed
/// thing.
class InlineSpinner extends StatelessWidget {
  /// Creates a spinner sized to [diameter] at 1.0 text scale.
  const InlineSpinner({required this.diameter, required this.color, super.key});

  /// The diameter at 1.0 text scale.
  final double diameter;

  /// The stroke's colour.
  final Color color;

  /// The stroke width, at every size.
  static const double strokeWidth = 2;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: MediaQuery.textScalerOf(context).scale(diameter),
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    ),
  );
}

/// What a screen reader announces for a control that can be busy.
///
/// **Both channels, always.** A spinner is pure animation, so it says nothing
/// at all to a screen reader; `Semantics(enabled:)` is invisible to a sighted
/// reader with low contrast vision. One helper so two controls cannot answer
/// this differently.
String busyAwareSemantics(
  String label, {
  required bool busy,
  required bool enabled,
  required AppLocalizations l10n,
}) => switch ((busy, enabled)) {
  (true, _) => '$label, ${l10n.stateWorking}',
  (false, false) => '$label, ${l10n.stateUnavailable}',
  (false, true) => label,
};
