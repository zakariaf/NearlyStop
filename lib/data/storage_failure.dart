/// Why a storage operation could not be completed.
library;

import 'package:nearlystop/core/result.dart';

/// The data layer's sealed failure family.
///
/// **No drift type appears here or in any repository signature.** A
/// `SqliteException`, a `DriftWrappedException` or a generated row class never
/// leaves `lib/data/db/` — the domain and the UI never learn that drift exists.
/// Every subtype carries a stable [Failure.code] and typed detail, never a
/// user-facing string; the presentation layer localizes from the code.
sealed class StorageFailure extends Failure {
  const StorageFailure();
}

/// The row the caller asked for is not there.
final class NotFound extends StorageFailure {
  /// Records that [what] could not be found.
  const NotFound(this.what);

  /// What was being looked for, e.g. `'plan'`.
  final String what;

  @override
  List<Object?> get props => <Object?>[what];

  @override
  String get code => 'storage.not_found';
}

/// A UNIQUE, CHECK or FOREIGN KEY constraint refused the write.
///
/// The invariants are in the schema on purpose: a corrupt row is
/// unrepresentable at the storage layer rather than merely policed in Dart.
final class ConstraintViolation extends StorageFailure {
  /// Records the constraint that refused, in [detail].
  const ConstraintViolation(this.detail);

  /// Which constraint, for the log — never shown to a user.
  final String detail;

  @override
  List<Object?> get props => <Object?>[detail];

  @override
  String get code => 'storage.constraint_violation';
}

/// A stored value could not be read back as the type it claims to be.
///
/// A `method` column holding `'weekly'`, a date column holding `'16/04/2026'`.
/// Surfaced rather than thrown, so a single bad row cannot crash the app on a
/// 400-day taper the user cannot re-enter.
final class Corrupt extends StorageFailure {
  /// Records the unreadable value, in [detail].
  const Corrupt(this.detail);

  /// What could not be read.
  final String detail;

  @override
  List<Object?> get props => <Object?>[detail];

  @override
  String get code => 'storage.corrupt';
}

/// The filesystem or the engine refused.
final class Io extends StorageFailure {
  /// Records the underlying [cause], already logged with its stack.
  const Io(this.cause);

  /// The original error. Logged at the boundary, never rendered.
  final Object cause;

  @override
  List<Object?> get props => <Object?>[cause];

  @override
  String get code => 'storage.io';
}

/// The operation is refused because the app's own rules forbid it.
///
/// A second plan when v1 holds one, an empty strength list, starting the next
/// step before this one is complete.
final class Invariant extends StorageFailure {
  /// Records which rule refused, in [detail].
  const Invariant(this.detail);

  /// Which rule. Stable enough for the presentation layer to switch on.
  final String detail;

  @override
  List<Object?> get props => <Object?>[detail];

  @override
  String get code => 'storage.invariant';
}
