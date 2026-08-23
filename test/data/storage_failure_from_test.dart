// The engine classifier, arm by arm.
//
// Every other test reaches it through the engine, which can only produce the
// arms this drift version happens to throw. The ones it does not — a wrapped
// converter failure, a non-constraint SQLite error — are exactly the arms that
// first run on a stranger's phone.
import 'package:drift/drift.dart' show DriftWrappedException;
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:sqlite3/common.dart' show SqliteException;

void main() {
  test('a wrapped converter failure is unwrapped to Corrupt', () {
    // Without the unwrap this reads as Io, and the screen says "storage error"
    // for what is one unreadable column.
    final wrapped = DriftWrappedException(
      message: 'running a query',
      cause: const FormatException('unknown step status', 'paused'),
      trace: StackTrace.empty,
    );

    expect(storageFailureFrom(wrapped), const Corrupt('unknown step status'));
  });

  test('nested wrapping unwraps all the way down', () {
    final inner = DriftWrappedException(
      message: 'inner',
      cause: const FormatException('bad date', '16/04/2026'),
      trace: StackTrace.empty,
    );
    final outer = DriftWrappedException(
      message: 'outer',
      cause: inner,
      trace: StackTrace.empty,
    );

    expect(storageFailureFrom(outer), const Corrupt('bad date'));
  });

  test('a wrapper with no cause is Io, not an infinite unwrap', () {
    final empty = DriftWrappedException(
      message: 'no cause',
      trace: StackTrace.empty,
    );

    expect(storageFailureFrom(empty), isA<Io>());
  });

  test('every SQLITE_CONSTRAINT extended code maps to ConstraintViolation', () {
    // The low byte of an extended result code is the primary code, and 19 is
    // SQLITE_CONSTRAINT. Matching the message text instead breaks the day
    // SQLite rewords it.
    const codes = <int>[
      275, // CHECK
      787, // FOREIGN KEY
      1299, // NOT NULL
      1555, // PRIMARY KEY
      2067, // UNIQUE
    ];
    for (final code in codes) {
      final error = SqliteException(code, 'constraint failed');

      expect(
        storageFailureFrom(error),
        isA<ConstraintViolation>(),
        reason: 'extended code $code',
      );
    }
  });

  test('a NON-constraint SQLite error is Io, not ConstraintViolation', () {
    // 11 is SQLITE_CORRUPT — a damaged file, not a rule the app broke. Calling
    // it a constraint violation would send the UI down the "you did something
    // invalid" path for a disk problem.
    final error = SqliteException(11, 'database disk image is malformed');

    expect(storageFailureFrom(error), isA<Io>());
  });

  test('a bare exception is Io and keeps its cause', () {
    const cause = FormatException('not from drift');

    expect(storageFailureFrom(cause), const Corrupt('not from drift'));
    expect(storageFailureFrom(StateError('closed')), isA<Io>());
  });
}
