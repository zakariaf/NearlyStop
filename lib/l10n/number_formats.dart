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

/// The format that reads text **after** [normalizeToAscii] has run.
///
/// Not the same as [numberFormatFor], and the difference is load-bearing:
/// `NumberFormat.decimalPattern('fa').parse('1.5')` **throws**, because the
/// Persian format expects `٫` (U+066B) as its decimal separator and an ASCII
/// point is not it. Normalization has already turned every Perso-Arabic digit
/// into ASCII, `٫` into `.` and dropped `٬` — so what reaches the parser for
/// `fa` and `ckb` is plain English notation, and the English format is what
/// reads it.
///
/// German is untouched by normalization (it uses ASCII separators already), so
/// it keeps its own format and its comma decimal.
NumberFormat _parseFormatFor(Locale locale) => switch (locale.languageCode) {
  'fa' || 'ckb' => NumberFormat.decimalPattern('en'),
  _ => numberFormatFor(locale),
};

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
Result<Milligrams, UnitFailure> parseDose(
  String raw,
  Locale locale, {
  Milligrams? ceiling,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return Err(InvalidDoseFormat(raw));

  final ascii = normalizeToAscii(trimmed);
  final num value;
  try {
    value = _parseFormatFor(locale).parse(ascii);
  } on FormatException {
    return Err(InvalidDoseFormat(raw));
  }

  // Ordered deliberately. A non-finite value has no meaningful rendering, so
  // it cannot survive to the round-trip check below and be reported as a
  // formatting problem; and a negative one is a clearer failure than "this is
  // not how your locale writes a number".
  if (value.isNaN || value.isInfinite) return Err(NonFiniteDose(raw));
  if (value < 0) return Err(NegativeDose(raw));

  // `NumberFormat.parse` is lenient about a grouping separator sitting where a
  // decimal belongs — `7,5` in `en` parses to **75**. Re-rendering the parsed
  // value and comparing catches it: a string this locale would never have
  // produced is not a dose in this locale.
  //
  // The comparison is at FULL precision, not the two-digit display precision,
  // and on both sides normalized to ASCII digits. Comparing the display
  // rendering would reject `0.255` here as a malformed number, when the honest
  // answer is that it is a well-formed number too fine to represent — and the
  // two failures send the user to different fixes.
  final canonical = numberFormatFor(locale)
    ..maximumFractionDigits = 10
    ..minimumFractionDigits = 0;
  if (normalizeToAscii(canonical.format(value)) != normalizeToAscii(trimmed)) {
    return Err(InvalidDoseFormat(raw));
  }

  final scaled = value * 100;
  final hundredths = scaled.round();
  // Two decimal places exactly. `9.005` is not representable in hundredths, and
  // the honest answer is to say so.
  if ((scaled - hundredths).abs() > 1e-9) return Err(DoseTooPrecise(raw));

  if (ceiling != null && hundredths > ceiling.hundredths) {
    return Err(DoseAboveCeiling(raw, ceiling.hundredths));
  }
  return Ok(Milligrams.fromHundredths(hundredths));
}
