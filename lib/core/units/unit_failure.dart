/// Failures produced by the unit value objects.
library;

import 'package:nearlystop/core/result.dart';

/// Why a dose string could not become a `Milligrams`, or why a dose could not
/// be halved.
///
/// Sealed, so a `switch` over it needs no `default:` and adding a case is a
/// compile error at every call site. Every subtype carries typed parameters and
/// **never** a user-facing string — EPIC-03 localizes from [Failure.code].
sealed class UnitFailure extends Failure {
  const UnitFailure();
}

/// The input was not a plain decimal number.
///
/// Carries [input] verbatim so the presentation layer can quote it back. The
/// input is expected to be ASCII-normalized already: `normalizeToAscii` runs at
/// the presentation edge, because `1٫5` is 1.5 and a digits-only normalizer
/// turns it into 15 — a ten-fold error on a dose field.
final class InvalidDoseFormat extends UnitFailure {
  /// Records that [input] could not be parsed.
  const InvalidDoseFormat(this.input);

  /// The rejected text, exactly as received.
  final String input;

  @override
  String get code => 'unit.invalid_dose_format';
}

/// The input carried more than two decimal places.
///
/// Doses are stored as integer hundredths, so `9.005` is not representable.
/// Rejecting is the only honest answer: silently rounding a dose is the one
/// unforgivable bug (SPEC §3.3).
final class DoseTooPrecise extends UnitFailure {
  /// Records that [input] is finer than 0.01 mg.
  const DoseTooPrecise(this.input);

  /// The rejected text, exactly as received.
  final String input;

  @override
  String get code => 'unit.dose_too_precise';
}

/// The input was negative. A dose below zero is not a quantity anyone can take.
final class NegativeDose extends UnitFailure {
  /// Records that [input] parsed as a negative amount.
  const NegativeDose(this.input);

  /// The rejected text, exactly as received.
  final String input;

  @override
  String get code => 'unit.negative_dose';
}

/// A dose with an odd number of hundredths cannot be halved exactly.
///
/// Carries the value that could not be halved, in hundredths, so the caller can
/// say which one. Never rounds to 12 or 13.
final class DoseNotHalvable extends UnitFailure {
  /// Records that [hundredths] is odd.
  const DoseNotHalvable(this.hundredths);

  /// The value that could not be halved, in hundredths of a milligram.
  final int hundredths;

  @override
  String get code => 'unit.dose_not_halvable';
}
