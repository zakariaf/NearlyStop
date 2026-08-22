/// The one date type in this codebase.
library;

import 'package:meta/meta.dart';

/// A calendar date: a year, a month and a day, with **no time and no zone**.
///
/// `SPEC.md` §7 opens with "dates, not durations": a taper runs ~780 days and
/// crosses DST twice a year, so a day index computed from elapsed seconds will
/// eventually shift someone's dose onto the wrong calendar day. Every
/// arithmetic operation here goes through `DateTime.utc`, which has no DST at
/// all.
///
/// There is deliberately **no** `toDateTime()` returning a local instant. The
/// single bridge is [toUtcMidnight], and its dartdoc says what it is for.
@immutable
final class LocalDate implements Comparable<LocalDate> {
  /// Creates the date [year]-[month]-[day].
  ///
  /// Out-of-range components normalize the way `DateTime.utc` does — month 13
  /// is January of the next year — so construct from validated input or use
  /// [tryParse].
  const LocalDate(this.year, this.month, this.day);

  /// Takes the **local** Y/M/D fields of [instant].
  ///
  /// This is how "what day is it for this user right now" is answered: read the
  /// instant from the injected `Clock`, then project it here.
  factory LocalDate.fromDateTime(DateTime instant) =>
      LocalDate(instant.year, instant.month, instant.day);

  /// Parses `yyyy-MM-dd`, throwing [FormatException] on anything else.
  ///
  /// For text this app produced — a stored ISO date, a golden vector row. Use
  /// [tryParse] for anything a user or a file could have written.
  factory LocalDate.parse(String iso) {
    final parsed = tryParse(iso);
    if (parsed == null) throw FormatException('not an ISO calendar date', iso);
    return parsed;
  }

  /// Parses `yyyy-MM-dd`, or returns `null`.
  ///
  /// Rejects a syntactically valid but non-existent date: `2026-13-01` and
  /// `2026-02-30` are both `null`, because `DateTime.utc` would silently
  /// normalize them into a different day.
  static LocalDate? tryParse(String iso) {
    final match = _iso.firstMatch(iso);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      return null;
    }
    return LocalDate(year, month, day);
  }

  static final RegExp _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// The calendar year.
  final int year;

  /// The calendar month, 1–12.
  final int month;

  /// The day of the month, 1–31.
  final int day;

  /// The date [days] later, as a calendar operation.
  ///
  /// Computed in UTC on purpose: a local `DateTime.add` on a DST boundary
  /// returns the same calendar day at 23:00, and the taper would silently lose
  /// or repeat a day twice a year.
  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(toUtcMidnight().add(Duration(days: days)));

  /// Calendar days from [other] to this date; negative when this is earlier.
  int difference(LocalDate other) =>
      toUtcMidnight().difference(other.toUtcMidnight()).inDays;

  /// The ISO weekday, `DateTime.monday` (1) through `DateTime.sunday` (7).
  int get weekday => toUtcMidnight().weekday;

  /// `yyyy-MM-dd`, zero-padded.
  String toIso8601() =>
      '${year.toString().padLeft(4, '0')}'
      '-${month.toString().padLeft(2, '0')}'
      '-${day.toString().padLeft(2, '0')}';

  /// This date at midnight **UTC**.
  ///
  /// Exists solely so `intl`'s `DateFormat` and `shamsi_date`'s
  /// `Jalali.fromDateTime` can read the Y/M/D fields. Constructing a **local**
  /// instant from a [LocalDate] is banned — it is how a Persian date or an
  /// `MMMEd` label ends up one day off east of UTC.
  DateTime toUtcMidnight() => DateTime.utc(year, month, day);

  /// Whether this date is strictly before [other].
  bool operator <(LocalDate other) => compareTo(other) < 0;

  /// Whether this date is on or before [other].
  bool operator <=(LocalDate other) => compareTo(other) <= 0;

  /// Whether this date is strictly after [other].
  bool operator >(LocalDate other) => compareTo(other) > 0;

  /// Whether this date is on or after [other].
  bool operator >=(LocalDate other) => compareTo(other) >= 0;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso8601();
}
