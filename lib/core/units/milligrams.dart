/// The one dose type in this codebase.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/unit_failure.dart';

/// A dose, stored as integer **hundredths** of a milligram.
///
/// **No `double` appears anywhere in a dose path.** Halves of a 0.5 mg tablet
/// give 0.25 mg, so tenths are not enough, and `0.1 + 0.2 != 0.3` is not
/// acceptable in an app whose output someone swallows. Every operation below is
/// integer arithmetic, so `10mg - 9.9mg` is exactly 10 hundredths.
///
/// Formatting is deliberately **not** here: [toDisplayString] emits canonical
/// ASCII with no locale separators and no thousands group, and EPIC-03's
/// `formatDose(Milligrams, Locale)` projects it for the screen.
@immutable
final class Milligrams implements Comparable<Milligrams> {
  /// Creates a dose from an exact count of hundredths of a milligram.
  const Milligrams.fromHundredths(this.hundredths);

  /// Zero milligrams — the target dose of a completed taper.
  static const Milligrams zero = Milligrams.fromHundredths(0);

  /// Hundredths of a milligram. 950 is 9.5 mg; 25 is 0.25 mg.
  final int hundredths;

  /// At most six whole digits: 999999 mg is already three orders of magnitude
  /// above the highest realistic starting dose, and an unbounded digit run is
  /// what makes `int.parse` throw instead of returning a failure.
  static final RegExp _decimal = RegExp(r'^(\d{0,6})(?:\.(\d{1,2}))?$');
  static final RegExp _tooPrecise = RegExp(r'^\d*\.\d{3,}$');

  /// Parses canonical ASCII decimal text such as `'9'`, `'9.5'`, `'.5'`.
  ///
  /// Returns [InvalidDoseFormat] for anything that is not a plain decimal
  /// (`''`, `'abc'`, `'9,5'`, `'9.'`, or more than six whole digits),
  /// [DoseTooPrecise] for more than two decimal places, and [NegativeDose] for
  /// a leading minus. **Never rounds** — `'9.005'` is a failure, not 9.00 or
  /// 9.01.
  ///
  /// **Total: it never throws.** This is the Plan screen's dose field, so a
  /// user holding a key must produce a typed failure, not a crash.
  ///
  /// The caller must have normalized digits and separators to ASCII first
  /// (`i18n-rtl-l10n`'s `normalizeToAscii`); this function does not know about
  /// `۹` or `٫`.
  static Result<Milligrams, UnitFailure> parse(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('-')) return Err(NegativeDose(text));
    if (_tooPrecise.hasMatch(trimmed)) return Err(DoseTooPrecise(text));

    final match = _decimal.firstMatch(trimmed);
    if (match == null) return Err(InvalidDoseFormat(text));

    final whole = match.group(1) ?? '';
    final fraction = match.group(2);
    if (whole.isEmpty && fraction == null) return Err(InvalidDoseFormat(text));

    final wholeHundredths = (whole.isEmpty ? 0 : int.parse(whole)) * 100;
    final fractionHundredths = fraction == null
        ? 0
        : int.parse(fraction.padRight(2, '0'));
    return Ok(Milligrams.fromHundredths(wholeHundredths + fractionHundredths));
  }

  /// Whether this dose is exactly zero.
  bool get isZero => hundredths == 0;

  /// The sum of two doses.
  Milligrams operator +(Milligrams other) =>
      Milligrams.fromHundredths(hundredths + other.hundredths);

  /// The difference of two doses. May be negative; callers that must not go
  /// below a target clamp with `nextDose`.
  Milligrams operator -(Milligrams other) =>
      Milligrams.fromHundredths(hundredths - other.hundredths);

  /// This dose repeated [factor] times — the tablet-composition primitive.
  Milligrams operator *(int factor) =>
      Milligrams.fromHundredths(hundredths * factor);

  /// Whether this dose is strictly less than [other].
  bool operator <(Milligrams other) => hundredths < other.hundredths;

  /// Whether this dose is less than or equal to [other].
  bool operator <=(Milligrams other) => hundredths <= other.hundredths;

  /// Whether this dose is strictly greater than [other].
  bool operator >(Milligrams other) => hundredths > other.hundredths;

  /// Whether this dose is greater than or equal to [other].
  bool operator >=(Milligrams other) => hundredths >= other.hundredths;

  /// Half of this dose, or [DoseNotHalvable] when [hundredths] is odd.
  ///
  /// A half tablet is a real physical act, so the result must be a dose the
  /// patient can actually hold. 0.5 mg halves to 0.25 mg; 0.25 mg does not
  /// halve, and returning a rounded 0.12 or 0.13 would be a silent dose change.
  Result<Milligrams, UnitFailure> half() => hundredths.isEven
      ? Ok(Milligrams.fromHundredths(hundredths ~/ 2))
      : Err(DoseNotHalvable(hundredths));

  /// Canonical ASCII text: `9`, `9.5`, `0.25`, `10`.
  ///
  /// Trailing zeros are trimmed and there is no locale separator and no
  /// thousands group — this is the storage and test representation, not the
  /// screen one.
  String toDisplayString() {
    final sign = hundredths < 0 ? '-' : '';
    final magnitude = hundredths.abs();
    final whole = magnitude ~/ 100;
    final fraction = magnitude % 100;
    if (fraction == 0) return '$sign$whole';
    final padded = fraction.toString().padLeft(2, '0');
    final trimmed = padded.endsWith('0')
        ? padded.substring(0, padded.length - 1)
        : padded;
    return '$sign$whole.$trimmed';
  }

  @override
  int compareTo(Milligrams other) => hundredths.compareTo(other.hundredths);

  @override
  bool operator ==(Object other) =>
      other is Milligrams && other.hundredths == hundredths;

  @override
  int get hashCode => hundredths.hashCode;

  @override
  String toString() => '${toDisplayString()}mg';
}
