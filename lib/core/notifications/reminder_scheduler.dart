/// What the app WANTS scheduled, computed from facts and nothing else.
library;

import 'package:clock/clock.dart';
import 'package:nearlystop/core/notifications/deterministic_id.dart';
import 'package:nearlystop/core/notifications/recurrence_rule.dart';
import 'package:nearlystop/core/notifications/scheduled_notification.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:timezone/timezone.dart' as tz;

export 'package:nearlystop/core/notifications/deterministic_id.dart';
export 'package:nearlystop/core/notifications/recurrence_rule.dart';
export 'package:nearlystop/core/notifications/scheduled_notification.dart';

/// The desired notification set, as a pure function of the facts.
///
/// No plugin, no database, no `DateTime.now()`. Everything this needs arrives
/// as an argument, which is what makes the whole engine verifiable off-device
/// — including the two DST boundaries a year that no CI run will ever cross on
/// its own.
abstract final class ReminderScheduler {
  /// What SHOULD be armed right now.
  ///
  /// Empty in three separate cases, and they are separate on purpose: the
  /// reminder being off, there being no taper to remind anybody about, and no
  /// time having been chosen. Collapsing them into one condition is how two of
  /// the three end up unimplemented behind the one that works.
  static Set<ScheduledNotification> compute({
    required AppSettings settings,
    required bool taperActive,
    required tz.Location zone,
    required Clock clock,
    required NotificationCopy copy,
  }) {
    if (!settings.reminderEnabled) return const <ScheduledNotification>{};
    if (!taperActive) return const <ScheduledNotification>{};
    final minute = settings.reminderMinuteOfDay;
    if (minute == null) return const <ScheduledNotification>{};

    final rule = DailyReminderRule.fromMinuteOfDay(minute);
    return <ScheduledNotification>{
      ScheduledNotification(
        id: deterministicId(
          ruleId: kDailyReminderRuleId,
          rule: rule,
          title: copy.title,
          body: copy.body,
        ),
        fireAt: nextDailyAt(rule, zone: zone, clock: clock),
        title: copy.title,
        body: copy.body,
        payload: kTodayPayload,
        channelId: kDailyReminderChannelId,
      ),
    };
  }
}
