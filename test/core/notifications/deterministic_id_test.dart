// The id is what the reconcile diffs on, and `getPending()` returns nothing
// else — not the fire time, not the body. So what the id folds decides which
// edits re-arm an alarm and which leave it alone, and getting it wrong is
// silent both ways: fold too little and a moved reminder keeps firing at the
// old hour; fold too much and a perfectly good repeating alarm is cancelled
// and re-armed every single morning, with a window in between where a process
// death leaves nothing armed at all.
import 'package:clock/clock.dart';
import 'package:nearlystop/core/notifications/deterministic_id.dart';
import 'package:nearlystop/core/notifications/recurrence_rule.dart';
import 'package:test/test.dart';

void main() {
  const rule = DailyReminderRule(hourLocal: 8, minuteLocal: 0);
  const title = 'Your plan for today';
  const body = "Open NearlyStop to see today's dose.";

  int idFor({
    DailyReminderRule rule = rule,
    String title = title,
    String body = body,
    String ruleId = kDailyReminderRuleId,
  }) => deterministicId(
    ruleId: ruleId,
    rule: rule,
    title: title,
    body: body,
  );

  test('a day passing does not change it', () {
    // The whole reason the resolved instant is NOT folded in. Under a
    // repeating schedule the instant moves every calendar day; an id that
    // followed it would make every reconcile a cancel-and-reschedule.
    final monday = withClock(Clock.fixed(DateTime.utc(2025, 4, 16, 7)), idFor);
    final thursday = withClock(
      Clock.fixed(DateTime.utc(2025, 4, 19, 9)),
      idFor,
    );

    expect(monday, thursday);
  });

  test('moving the time changes it', () {
    expect(
      idFor(rule: const DailyReminderRule(hourLocal: 14, minuteLocal: 0)),
      isNot(idFor()),
    );
    expect(
      idFor(rule: const DailyReminderRule(hourLocal: 8, minuteLocal: 1)),
      isNot(idFor()),
    );
  });

  test('changing the words changes it', () {
    // A locale switch changes the body, and the armed notification is in the
    // old language until something re-arms it.
    expect(idFor(title: 'برنامه امروز شما'), isNot(idFor()));
    expect(idFor(body: 'Another sentence.'), isNot(idFor()));
  });

  test('a different rule id is a different notification', () {
    expect(idFor(ruleId: 'something-else'), isNot(idFor()));
  });

  test('the fields are separated, not concatenated', () {
    // A running hash over a byte stream cannot tell ("ab", "c") from
    // ("a", "bc"). Here that means a title ending in the first letter of the
    // body would collide with the pair that splits one letter earlier — two
    // notifications the reconcile cannot tell apart, where the second
    // silently replaces the first.
    expect(idFor(title: 'ab', body: 'c'), isNot(idFor(title: 'a', body: 'bc')));
    expect(
      idFor(ruleId: 'daily', body: 'x'),
      isNot(idFor(ruleId: 'dailyx')),
    );
  });

  test('it fits in the 32-bit signed range Android requires', () {
    // Android notification ids are Java ints. A hash that overflowed would
    // throw at the platform channel, at 08:00, on somebody's phone.
    for (var minute = 0; minute < 1440; minute++) {
      final id = idFor(rule: DailyReminderRule.fromMinuteOfDay(minute));
      expect(id, greaterThanOrEqualTo(0), reason: 'minute $minute');
      expect(id, lessThan(1 << 31), reason: 'minute $minute');
    }
  });

  test('every minute of the day gets its own id', () {
    // 1440 rules, 1440 ids. A collision means two reminders the reconcile
    // cannot tell apart, and the second silently replaces the first.
    final ids = <int>{
      for (var minute = 0; minute < 1440; minute++)
        idFor(rule: DailyReminderRule.fromMinuteOfDay(minute)),
    };

    expect(ids, hasLength(1440));
  });
}
