/// The bridge between the domain's value objects and SQLite columns.
///
/// **Three storage shapes, and getting them mixed up is the most likely mistake
/// a future contributor will make here.**
///
/// * A **dose** is an INTEGER of hundredths of a milligram. Never a `REAL`.
///   Floating point in a dosing database is how 9.0 becomes 8.999999 and then
///   renders as 8.99 on someone's phone.
/// * A **calendar date** is a TEXT `yyyy-MM-dd`. `SPEC.md` §7: a dose belongs
///   to a date, not an instant. Stored as a timestamp, a user who flies to
///   Sydney or crosses a DST boundary gets their doses shifted by a day.
/// * An **instant** — `createdAt`, `takenAt`, `disclaimerAcceptedAt` — is
///   genuinely a moment in time, and is an INTEGER of milliseconds since the
///   epoch in **UTC**, read back with `isUtc: true`.
library;

import 'package:drift/drift.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// A dose, as an INTEGER of hundredths of a milligram.
class MilligramsConverter extends TypeConverter<Milligrams, int> {
  /// Creates the converter.
  const MilligramsConverter();

  @override
  Milligrams fromSql(int fromDb) => Milligrams.fromHundredths(fromDb);

  @override
  int toSql(Milligrams value) => value.hundredths;
}

/// A calendar date, as TEXT `yyyy-MM-dd`.
///
/// Throws [FormatException] on anything else, which the repository maps to
/// `StorageFailure.corrupt` rather than letting it crash the app.
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  /// Creates the converter.
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);

  @override
  String toSql(LocalDate value) => value.toIso8601();
}

/// The tablet strengths a patient holds, as a comma-joined list of hundredths.
///
/// SQLite has no list type. Written **sorted descending and deduplicated**, so
/// two plans holding the same strengths in a different order produce the same
/// bytes. An empty list is legal here and rejected at the repository — the
/// converter's job is the encoding, not the policy.
class StrengthListConverter extends TypeConverter<List<Milligrams>, String> {
  /// Creates the converter.
  const StrengthListConverter();

  @override
  List<Milligrams> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const <Milligrams>[];
    return <Milligrams>[
      for (final part in fromDb.split(','))
        Milligrams.fromHundredths(
          int.tryParse(part) ??
              (throw FormatException('not a strength list', fromDb)),
        ),
    ];
  }

  @override
  String toSql(List<Milligrams> value) {
    final unique = <int>{for (final mg in value) mg.hundredths}.toList()
      ..sort((a, b) => b.compareTo(a));
    return unique.join(',');
  }
}

/// The stored taper method, by enum name.
///
/// Maps **EPIC-04's** `TaperMethod` from `lib/core/dsns/facts.dart`. This layer
/// does not declare the enum (CONTRACTS.md §8): `TaperPlanFacts` names it and
/// the generator branches on it, so a declaration here would make the domain
/// import the data layer and trip the purity gate.
class TaperMethodConverter extends TypeConverter<TaperMethod, String> {
  /// Creates the converter.
  const TaperMethodConverter();

  @override
  TaperMethod fromSql(String fromDb) {
    for (final method in TaperMethod.values) {
      if (method.name == fromDb) return method;
    }
    throw FormatException('unknown taper method', fromDb);
  }

  @override
  String toSql(TaperMethod value) => value.name;
}

/// A step's stored status, by enum name.
class StepStatusConverter extends TypeConverter<StepStatus, String> {
  /// Creates the converter.
  const StepStatusConverter();

  @override
  StepStatus fromSql(String fromDb) {
    for (final status in StepStatus.values) {
      if (status.name == fromDb) return status;
    }
    throw FormatException('unknown step status', fromDb);
  }

  @override
  String toSql(StepStatus value) => value.name;
}

/// An instant, as INTEGER milliseconds since the epoch in **UTC**.
///
/// The counterpart to [LocalDateConverter], and the pair a future contributor
/// is most likely to confuse. `createdAt`, `takenAt` and `disclaimerAcceptedAt`
/// are genuinely moments in time; a dose's `date` is not. Reading back with
/// `isUtc: true` is what stops a local-zone `DateTime` leaking upward and
/// comparing unequal to the instant that was written.
class UtcInstantConverter extends TypeConverter<DateTime, int> {
  /// Creates the converter.
  const UtcInstantConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}
