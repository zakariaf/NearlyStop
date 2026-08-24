/// When a reminder repeats, as a wall clock rather than an instant.
library;

import 'package:clock/clock.dart';
import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart' as tz;

/// Every day, at one local time.
///
/// **A wall clock plus a rule, never a UTC instant.** An instant computed on
/// 29 March fires at 07:00 on 30 March, because Berlin moved an hour under it.
/// The reader set 08:00 and means 08:00 on every one of the ~780 mornings this
/// runs, including the two a year when the day is 23 or 25 hours long.
@immutable
class DailyReminderRule {
  /// Creates the rule.
  const DailyReminderRule({required this.hourLocal, required this.minuteLocal})
    : assert(
        hourLocal >= 0 && hourLocal < 24,
        'hourLocal is a wall-clock hour, 0..23',
      ),
      assert(
        minuteLocal >= 0 && minuteLocal < 60,
        'minuteLocal is a wall-clock minute, 0..59',
      );

  /// The rule stored as minutes since local midnight — the column's shape.
  factory DailyReminderRule.fromMinuteOfDay(int minute) => DailyReminderRule(
    hourLocal: minute ~/ 60,
    minuteLocal: minute % 60,
  );

  /// The local hour, 0..23.
  final int hourLocal;

  /// The local minute, 0..59.
  final int minuteLocal;

  /// Minutes since local midnight — how `AppSettings` stores it.
  int get minuteOfDay => hourLocal * 60 + minuteLocal;

  @override
  bool operator ==(Object other) =>
      other is DailyReminderRule &&
      other.hourLocal == hourLocal &&
      other.minuteLocal == minuteLocal;

  @override
  int get hashCode => Object.hash(hourLocal, minuteLocal);

  @override
  String toString() =>
      'DailyReminderRule($hourLocal:${minuteLocal.toString().padLeft(2, '0')})';
}

/// The next instant [rule] names in [zone], at or after the clock's now.
///
/// **At or after.** A reader whose phone is awake at exactly 08:00:00 must get
/// today's reminder, not tomorrow's — and the version that gets this wrong is
/// unreproducible for whoever they report it to.
///
/// The zone is an argument rather than `tz.local` so a test can pin one; the
/// app passes `tz.local`, which `bootstrap()` sets from the device. Reading
/// `tz.local` here instead would make every test depend on the machine.
tz.TZDateTime nextDailyAt(
  DailyReminderRule rule, {
  required tz.Location zone,
  required Clock clock,
}) {
  final now = tz.TZDateTime.from(clock.now(), zone);
  final today = tz.TZDateTime(
    zone,
    now.year,
    now.month,
    now.day,
    rule.hourLocal,
    rule.minuteLocal,
  );
  if (!today.isBefore(now)) return today;
  // Built from the NEXT day's components, never `today + 24h`: a 23-hour day
  // would land the sum at 09:00 and a 25-hour day at 07:00.
  final tomorrow = now.add(const Duration(days: 1));
  return tz.TZDateTime(
    zone,
    tomorrow.year,
    tomorrow.month,
    tomorrow.day,
    rule.hourLocal,
    rule.minuteLocal,
  );
}
