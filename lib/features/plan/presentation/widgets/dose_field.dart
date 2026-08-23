/// One numeric field, spelled once.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/unit_failure.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:nearlystop/l10n/numeric_input.dart';

/// A dose or a count, with the app's one character set and one keyboard.
///
/// **Stateless, and it does not own its controller.** Every controller and
/// focus node on this screen is created and disposed by the `State` that owns
/// the form, so there is a single place to get disposal right rather than one
/// per field. What this widget owns is the pairing that must never drift: the
/// formatter, the keyboard type and the parser all agreeing on which
/// characters exist.
class NumericField extends StatelessWidget {
  /// Creates the field.
  const NumericField({
    required this.controller,
    required this.label,
    required this.validator,
    required this.onChanged,
    this.focusNode,
    this.suffix,
    this.helperText,
    this.decimal = true,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  /// The text, owned by the caller.
  final TextEditingController controller;

  /// Owned by the caller, when the caller wants traversal control.
  final FocusNode? focusNode;

  /// The localized label.
  final String label;

  /// The localized unit shown after the number, if any.
  final String? suffix;

  /// A note under the field. A WARNING lives here; an error does not.
  final String? helperText;

  /// Whether a decimal separator may be typed.
  final bool decimal;

  /// What the keyboard's action key does.
  final TextInputAction textInputAction;

  /// The localized reason this text cannot be read, or null.
  final FormFieldValidator<String> validator;

  /// Called with the raw text on every keystroke.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focusNode,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: <TextInputFormatter>[
      if (decimal) kDoseInputFormatter else kWholeNumberInputFormatter,
    ],
    textInputAction: textInputAction,
    // On INTERACTION, not from the first frame: a form that is red before the
    // reader has typed anything reads as a telling-off on a screen they have
    // not filled in yet. Per field rather than via an ancestor `Form`, so a
    // field is correct wherever it is placed.
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      helperText: helperText,
      // A warning must not be swallowed by a one-line helper slot at the
      // largest OS text size — this audience runs at 200% routinely.
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    validator: validator,
    onChanged: onChanged,
  );
}

/// The localized reason [raw] cannot be read as a dose, or null.
///
/// Shared by every dose field in the feature — the plan's two, the fixed step
/// and the strength editor — because a second copy is a second answer, and the
/// two disagree the first time somebody changes the example in one of them.
String? doseFieldError(
  String raw,
  Locale locale,
  AppLocalizations l10n, {
  bool required = true,
}) {
  if (raw.trim().isEmpty) {
    return required ? l10n.planErrorDoseRequired : null;
  }
  return switch (parseDose(raw, locale)) {
    Ok<Milligrams, UnitFailure>() => null,
    // A value finer than a hundredth is FLAGGED, never rounded (CLAUDE.md
    // rule 5), and it gets its own message: telling somebody who typed
    // `0.255` to "use one decimal separator" is telling them the wrong thing.
    Err<Milligrams, UnitFailure>(failure: DoseTooPrecise()) =>
      l10n.planErrorDoseTooPrecise(
        formatDose(const Milligrams.fromHundredths(925), locale),
      ),
    Err<Milligrams, UnitFailure>() => l10n.planErrorDoseUnreadable(
      formatDose(const Milligrams.fromHundredths(950), locale),
    ),
  };
}

/// [raw] as a dose, or null when it cannot be read.
Milligrams? readDose(String raw, Locale locale) =>
    switch (parseDose(raw, locale)) {
      Ok<Milligrams, UnitFailure>(:final value) => value,
      Err<Milligrams, UnitFailure>() => null,
    };
