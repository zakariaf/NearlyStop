/// The typed-error spine: a recoverable failure is a value, not an exception.
///
/// Every boundary that can fail for a runtime reason the caller must handle
/// returns a [Result]. Only genuine bugs throw, and those are caught once by
/// the global error net installed in `bootstrap()`.
///
/// The void arm is spelled `Result<void, F>` — `const Ok<void, F>(null)`.
/// There is deliberately no `Unit` type in this codebase; a test under
/// `test/core/result_test.dart` fails the build if one appears.
library;

import 'package:meta/meta.dart';

/// A recoverable failure, identified by a stable [code].
///
/// Not `sealed`: each boundary owns its own sealed family in its own file
/// (`sealed class StorageFailure extends Failure`), and a sealed base would
/// force every one of them into this library. The families are what callers
/// switch on exhaustively; this base only fixes the shared vocabulary.
///
/// A subtype carries typed parameters and never a user-facing string — a baked
/// message breaks translation, RTL mirroring and Persian numerals. Localize
/// from [code] at the presentation edge.
@immutable
abstract class Failure {
  /// Const base constructor so subtypes can be `const`.
  const Failure();

  /// Stable, localization-key-like identifier, e.g. `'storage.write_failed'`.
  String get code;
}

/// The outcome of an operation that can fail: either [Ok] or [Err].
///
/// Sealed, so a `switch` covering both arms needs no `default:` and a third
/// arm could never be added without breaking every call site on purpose.
@immutable
sealed class Result<T, F extends Failure> {
  /// Const base constructor so both arms can be `const`.
  const Result();
}

/// A successful [Result] carrying [value].
@immutable
final class Ok<T, F extends Failure> extends Result<T, F> {
  /// Wraps [value] as a success. For the void arm, pass `null`.
  const Ok(this.value);

  /// The produced value; `void` when the operation produces nothing.
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, F> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T, F>, value);
}

/// A failed [Result] carrying [failure].
@immutable
final class Err<T, F extends Failure> extends Result<T, F> {
  /// Wraps [failure] as the failed arm.
  const Err(this.failure);

  /// Why the operation failed. Switch it exhaustively; never render it raw.
  final F failure;

  @override
  bool operator ==(Object other) =>
      other is Err<T, F> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err<T, F>, failure);
}
