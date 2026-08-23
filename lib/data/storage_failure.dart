/// Why a storage operation could not be completed.
library;

import 'package:drift/drift.dart' show DriftWrappedException;
// The shipping connection runs the engine on a background isolate, and its
// errors arrive wrapped in `DriftRemoteException` rather than
// `DriftWrappedException`. The library is marked experimental, but the
// exception type it publishes is what `NativeDatabase.createInBackground` —
// the connection this app ships — throws on every engine error, so
// classifying it is not optional.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:nearlystop/core/result.dart';
import 'package:sqlite3/common.dart' show SqliteException;

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

/// Classifies an engine, converter or filesystem error.
///
/// **The only place a drift or sqlite exception is named.** Everything above
/// this line sees a [StorageFailure].
///
/// Public rather than `@visibleForTesting` because both repositories call it,
/// and because an error mapper is exactly the code that never runs until the
/// day it matters — it earns its own tests.
StorageFailure storageFailureFrom(Object error) {
  // Drift wraps whatever the engine or a converter threw, and it wraps it in
  // TWO different classes: `DriftWrappedException` in-process, and
  // `DriftRemoteException` across the isolate boundary that
  // `NativeDatabase.createInBackground` puts the shipping app behind. Missing
  // the remote one means every constraint violation ON A REAL PHONE reads as a
  // generic Io failure, while every test — all in-process — says otherwise.
  var cause = error;
  while (true) {
    final inner = switch (cause) {
      DriftWrappedException(:final cause?) => cause,
      DriftRemoteException(:final remoteCause) => remoteCause,
      _ => null,
    };
    if (inner == null || identical(inner, cause)) break;
    cause = inner;
  }
  if (cause is FormatException) return Corrupt(cause.message);
  if (cause is SqliteException) {
    // The low byte of an extended result code is the primary code, and 19 is
    // SQLITE_CONSTRAINT — covering UNIQUE (2067), CHECK (275), FOREIGN KEY
    // (787), NOT NULL (1299) and PRIMARY KEY (1555) in one test. Matching the
    // message text instead breaks the day SQLite rewords it.
    if (cause.extendedResultCode & 0xFF == 19) {
      return ConstraintViolation(cause.message);
    }
  }
  return Io(cause);
}
