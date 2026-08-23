/// Formatting and parsing a dose, per locale.
///
/// **Format at the edge, normalize before every parse.** The domain is integer
/// hundredths (`Milligrams`, EPIC-04) specifically so it cannot round; this
/// file is the only place that turns one into text a person reads, and the only
/// place that turns text a person typed back into one.
///
/// The failure this exists to prevent: a Persian soft keyboard produces `1٫5`.
/// Fold the digits but not the separator and it becomes `15` — a ten-fold error
/// on a dose field, in an app whose entire purpose is getting a steroid dose
/// right.
library;

import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/unit_failure.dart';

/// The `NumberFormat` whose symbol data a locale reads its digits from.
///
/// `intl` emits native digits from the locale's **symbol data**, not from a
/// `-u-nu-` extension — it drops the unicode `-u` extension during fallback, so
/// tagging the locale achieves nothing. A locale `intl` has no symbols for
/// falls back to Latin **silently**, which is why `ckb` is pinned to `fa`: same
/// digit block (U+06Fx), same separators, and a test asserts the emitted block
/// rather than trusting this mapping.
NumberFormat numberFormatFor(Locale locale) => switch (locale.languageCode) {
  // ۰۱۲۳۴۵۶۷۸۹ — U+06Fx, decimal U+066B, grouping U+066C.
  'fa' => NumberFormat.decimalPattern('fa'),
  'ckb' => NumberFormat.decimalPattern('fa'),
  // 1.234,5 — comma decimal.
  'de' => NumberFormat.decimalPattern('de'),
  _ => NumberFormat.decimalPattern('en'),
};

/// The dose formatter: at most two fraction digits, at least none.
///
/// **`maximumFractionDigits: 2`, not 1.** One rounds 0.25 to `0.3` and 1.25 to
/// `1.3`, and both are reachable — half a 0.5mg tablet and half a 2.5mg tablet
/// (CONTRACTS §10). `minimumFractionDigits: 0` so 9mg renders `9`, not `9.00`:
/// the 72px numeral is the most-read pixel in the product.
NumberFormat doseFormat(Locale locale) => numberFormatFor(locale)
  ..maximumFractionDigits = 2
  ..minimumFractionDigits = 0;

/// Renders [dose] for [locale].
String formatDose(Milligrams dose, Locale locale) =>
    doseFormat(locale).format(dose.hundredths / 100);

/// Renders a plain count — days, a percentage — in [locale]'s digits.
///
/// Grouping OFF: a hold period is a count of days, and `1,000` in a field the
/// user then re-types is a separator they have to delete before it parses.
String formatWholeNumber(int value, Locale locale) =>
    (numberFormatFor(locale)..turnOffGrouping()).format(value);

/// Reads a plain count typed in any of the app's digit blocks.
///
/// No separators, so no locale needed past the digit fold — which is why this
/// is not [parseDose] with a flag: a count has no decimal point to get wrong.
int? parseWholeNumber(String raw) {
  final ascii = normalizeToAscii(raw.trim());
  if (ascii.isEmpty) return null;
  return int.tryParse(ascii);
}

/// Folds Perso-Arabic digits to ASCII. **Digits only.**
///
/// Folds U+0660–0669 (Arabic-Indic) and U+06F0–06F9 (extended Arabic-Indic) to
/// ASCII, maps `٫` U+066B to `.`, and drops `٬` U+066C.
///
/// It does **nothing** with ASCII `,` or `.`, so `double.parse` on its output
/// throws for German `7,5` — which is precisely why [parseDose] goes through
/// `NumberFormat.parse` afterwards rather than `double.parse`. A normalizer
/// that also rewrote separators could not tell a German decimal comma from an
/// English thousands comma, and would have to guess on a dose field.
String normalizeToAscii(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + (rune - 0x0660));
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + (rune - 0x06F0));
    } else if (rune == 0x066B) {
      buffer.write('.');
    } else if (rune == 0x066C) {
      // The Perso-Arabic thousands separator carries no value.
      continue;
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Rewrites [ascii] from [locale]'s notation into plain `1234.5` form.
///
/// Returns `null` when the grouping separators are not where this locale puts
/// them — which is what keeps English `7,5` a rejection rather than 75. The
/// rule is the ordinary one: a group separator has one to three digits before
/// it, exactly three after it, and never appears past the decimal point.
String? _toPlainDecimal(String ascii, Locale locale) {
  final symbols = numberFormatFor(locale).symbols;
  final decimal = symbols.DECIMAL_SEP;
  final group = symbols.GROUP_SEP;

  final parts = ascii.split(decimal);
  if (parts.length > 2) return null;
  final whole = parts.first;
  final fraction = parts.length == 2 ? parts[1] : '';
  if (fraction.contains(group)) return null;

  if (whole.contains(group)) {
    final groups = whole.split(group);
    if (groups.first.isEmpty || groups.first.length > 3) return null;
    for (final chunk in groups.skip(1)) {
      if (chunk.length != 3) return null;
    }
  }
  final digitsOnly = whole.replaceAll(group, '');
  return fraction.isEmpty ? digitsOnly : '$digitsOnly.$fraction';
}

/// Parses user text as a dose, in [locale]'s own number conventions.
///
/// Digits first (Perso-Arabic → ASCII), separators second (`intl`'s symbol
/// data). **Never `double.parse` on user text, never `int.parse`, and never
/// strip-non-digits** — on `1.234,5` that last one is a thousand-fold error.
///
/// A value finer than a hundredth is **flagged, never rounded**. EPIC-03's own
/// task text asks for half-up rounding here (`0.255` → `0.26`); CONTRACTS and
/// `CLAUDE.md` rule 5 both say an unrepresentable dose is flagged and that
/// silently rounding one is the single unforgivable bug, so the contract wins
/// and EPIC-04's [DoseTooPrecise] is the answer.
///
/// The shape is deliberately **fold, then delegate** — not parse-and-validate.
/// An earlier version re-rendered the parsed value and compared it against the
/// input, which rejected `10.0`, `9.50`, `.5` and `09` as malformed: every one
/// of those is how a real person writes a dose, and `10.0` is how the pack is
/// printed.
Result<Milligrams, UnitFailure> parseDose(
  String raw,
  Locale locale, {
  Milligrams? ceiling,
}) {
  final ascii = normalizeToAscii(raw.trim());
  final plain = _toPlainDecimal(ascii, locale);
  if (plain == null) return Err(InvalidDoseFormat(raw));

  // `Milligrams.parse` is the domain's parser and the ONLY one. It is integer
  // arithmetic end to end — no `double` in a dose path — it caps the whole part
  // so an unbounded digit run returns a failure instead of throwing, and it
  // already distinguishes `DoseTooPrecise` from `NegativeDose` from
  // `InvalidDoseFormat`. Re-deriving any of that here is how the Plan screen
  // ends up able to store a value it cannot read back.
  final parsed = Milligrams.parse(plain);
  return switch (parsed) {
    Err<Milligrams, UnitFailure>() => Err(_reword(parsed, raw)),
    Ok<Milligrams, UnitFailure>(:final value) =>
      ceiling != null && value > ceiling
          ? Err(DoseAboveCeiling(raw, ceiling.hundredths))
          : Ok(value),
  };
}

/// Re-labels a domain failure with the text the USER typed.
///
/// `Milligrams.parse` saw the ASCII-folded form; quoting that back at someone
/// who typed `۹٫۵` would be quoting a string they never wrote.
UnitFailure _reword(Err<Milligrams, UnitFailure> failure, String raw) =>
    switch (failure.failure) {
      InvalidDoseFormat() => InvalidDoseFormat(raw),
      DoseTooPrecise() => DoseTooPrecise(raw),
      NegativeDose() => NegativeDose(raw),
      final UnitFailure other => other,
    };
