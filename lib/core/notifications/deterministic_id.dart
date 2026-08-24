/// The one id a scheduled reminder is known by.
library;

import 'package:nearlystop/core/notifications/recurrence_rule.dart';

/// The daily reminder's rule identity. One reminder, so one constant.
const String kDailyReminderRuleId = 'daily-reminder';

/// A stable id for a reminder, folding RULE IDENTITY only.
///
/// `getPending()` gives back ids and nothing else — not the fire time, not the
/// body — so what this folds decides which edits re-arm an alarm and which
/// leave it alone. Both mistakes are silent:
///
/// * Fold too little (drop the hour) and moving 08:00 → 14:00 keeps the same
///   id. The reconcile's cancel loop and its schedule loop both skip it, and
///   the reminder goes on firing at the old hour for ever.
/// * Fold the RESOLVED instant and, under a repeating schedule, the id changes
///   every calendar day. Every reconcile becomes a cancel-and-reschedule of a
///   perfectly good alarm, and the pair is not atomic: a process death between
///   the two leaves nothing armed at all.
///
/// So: the rule id, the wall clock, and the words. A time change re-arms. A
/// locale change re-arms, because the armed notification is in the old
/// language until something does. A day passing does not.
int deterministicId({
  required String ruleId,
  required DailyReminderRule rule,
  required String title,
  required String body,
}) {
  // FNV-1a, 32-bit, masked into the non-negative half. Android notification
  // ids are Java `int`s: a value that overflowed would throw at the platform
  // channel, at 08:00, on somebody's phone rather than in CI.
  var hash = 0x811C9DC5;
  void fold(String value) {
    for (final unit in value.codeUnits) {
      hash = (hash ^ unit) & 0xFFFFFFFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    // A separator, so `('ab', 'c')` and `('a', 'bc')` are different inputs.
    hash = (hash ^ 0x1F) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  fold(ruleId);
  fold('${rule.hourLocal}:${rule.minuteLocal}');
  fold(title);
  fold(body);
  return hash & 0x7FFFFFFF;
}
