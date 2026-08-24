// The reconcile: one idempotent function every scheduling change flows
// through, driven headlessly with a fake gateway and a frozen clock.
//
// Idempotence is asserted by COUNTING GATEWAY WRITES, never by comparing end
// states — the end state is identical whether the second run did nothing or
// cancelled and re-armed everything, and the difference is a window in which a
// process death leaves the reader with no alarm at all.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/notifications/reminder_scheduler.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/services/notifications/fake_notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_providers.dart';
import 'package:nearlystop/services/notifications/sync_notifications.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:timezone/timezone.dart' as tz;

import '../../fixtures/seeded_plan.dart';
import '../../support/db_harness.dart';
import '../../support/harness.dart';
import '../../support/notification_harness.dart';

void main() {
  setUpAll(initializeTestTimeZones);

  late FakeNotificationGateway gateway;

  late AppDatabaseHolder holder;
  late bool seeded;

  setUp(() {
    gateway = FakeNotificationGateway();
    holder = AppDatabaseHolder(openTestDatabase());
    seeded = false;
  });

  /// A container over a REAL in-memory database.
  ///
  /// Not a stubbed `taperSnapshotProvider`: the reconcile reads the
  /// repository's own stream, because that is the only read that works at
  /// bootstrap when no widget is listening — so a test that stubbed the
  /// provider would be exercising a path the app never takes.
  Future<ProviderContainer> containerAt({
    bool reminderEnabled = true,
    int? reminderMinuteOfDay = 8 * 60,
    bool taperActive = true,
    DateTime? now,
    Locale locale = const Locale('en'),
  }) async {
    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(holder.database),
        ...notificationOverrides(
          gateway: gateway,
          now: now,
          locale: locale,
        ),
        settingsControllerProvider.overrideWith(
          () => FixedSettingsController.of(
            AppSettings.defaults.copyWith(
              reminderEnabled: reminderEnabled,
              reminderMinuteOfDay: reminderMinuteOfDay,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // ONCE per test, however many containers a case builds. Seeding again
    // would insert a SECOND plan — `savePlan` creates, it does not upsert —
    // and the taper the reconcile then reads is not the one the first
    // reconcile armed for.
    if (taperActive && !seeded) {
      await seedTaperInto(container);
      seeded = true;
    }
    return container;
  }

  /// The invariant every case ends on: the OS holds exactly what was wanted.
  ///
  /// Recomputed from the same pure function the reconcile uses, so it cannot
  /// agree with a reconcile that computed the wrong thing — it can only agree
  /// with one that ARMED the wrong thing.
  Future<void> expectConverged(ProviderContainer container) async {
    final snapshot = await container
        .read(taperRepositoryProvider)
        .watchSnapshot()
        .first;
    final facts = (snapshot as Ok<TaperSnapshot, StorageFailure>).value;
    final desired = ReminderScheduler.compute(
      settings: container.read(settingsControllerProvider),
      taperActive: taperActive(facts),
      zone: testZone,
      clock: container.read(clockProvider),
      copy: container.read(notificationCopyProvider),
    );
    expect(
      await gateway.pendingIds(),
      desired.map((n) => n.id).toSet(),
      reason: 'the pending set is not the desired set',
    );
  }

  test('an empty gateway arms exactly one, and cancels nothing', () async {
    final container = await containerAt();

    final result = await container.read(reconcileNotificationsProvider)();

    expect(result, isA<Ok<void, ReminderFailure>>());
    expect(gateway.scheduleCount, 1);
    expect(gateway.cancelCount, 0);
    expect(
      gateway.pending.single.fireAt,
      tz.TZDateTime(testZone, 2025, 4, 16, 8),
    );
    expect(gateway.pending.single.repeatsDaily, isTrue);
    await expectConverged(container);
  });

  test('running it again with nothing changed writes NOTHING', () async {
    final container = await containerAt();
    await container.read(reconcileNotificationsProvider)();
    gateway.resetCalls();

    await container.read(reconcileNotificationsProvider)();

    expect(gateway.scheduleCount, 0);
    expect(gateway.cancelCount, 0);
    await expectConverged(container);
  });

  test('a day passing writes nothing either', () async {
    // The whole point of folding rule identity only. A repeating alarm that is
    // cancelled and re-armed every morning is the bug the id design prevents,
    // and the end state looks identical either way.
    await (await containerAt()).read(reconcileNotificationsProvider)();
    gateway.resetCalls();

    // Past the fire time, three days later.
    await (await containerAt(
      now: DateTime.utc(2025, 4, 19, 9),
    )).read(reconcileNotificationsProvider)();

    expect(gateway.scheduleCount, 0);
    expect(gateway.cancelCount, 0);
  });

  test('moving the time is one cancel and one schedule', () async {
    await (await containerAt()).read(reconcileNotificationsProvider)();
    final oldId = gateway.pending.single.id;
    gateway.resetCalls();

    final container = await containerAt(reminderMinuteOfDay: 14 * 60);
    await container.read(reconcileNotificationsProvider)();

    expect(gateway.cancelCount, 1);
    expect(gateway.scheduleCount, 1);
    expect(await gateway.pendingIds(), isNot(contains(oldId)));
    // CANCEL FIRST. Arming before disarming leaves a window with two entries
    // for the same reminder — and iOS silently drops everything past ~64
    // pending, so the order is the difference between a moved reminder and no
    // reminder at all on a phone near the cap.
    expect(
      gateway.calls.indexOf('cancel'),
      lessThan(gateway.calls.indexOf('schedule')),
    );
    await expectConverged(container);
  });

  test('a locale change re-arms, because the words changed', () async {
    await (await containerAt()).read(reconcileNotificationsProvider)();
    gateway.resetCalls();

    final container = await containerAt(locale: const Locale('fa'));
    await container.read(reconcileNotificationsProvider)();

    expect(gateway.cancelCount, 1);
    expect(gateway.scheduleCount, 1);
    await expectConverged(container);
  });

  test('turning the reminder off cancels, and arms nothing', () async {
    await (await containerAt()).read(reconcileNotificationsProvider)();
    gateway.resetCalls();

    final container = await containerAt(reminderEnabled: false);
    await container.read(reconcileNotificationsProvider)();

    expect(gateway.cancelCount, 1);
    expect(gateway.scheduleCount, 0);
    expect(await gateway.pendingIds(), isEmpty);
    await expectConverged(container);
  });

  test('deleting the plan cancels too — asserted separately', () async {
    // Separately from the case above on purpose: one of the two conditions
    // being unimplemented is invisible while the other one works.
    final container = await containerAt();
    await container.read(reconcileNotificationsProvider)();
    gateway.resetCalls();

    await container.read(taperRepositoryProvider).deletePlan();
    await container.read(reconcileNotificationsProvider)();

    expect(gateway.cancelCount, 1);
    expect(gateway.scheduleCount, 0);
    expect(await gateway.pendingIds(), isEmpty);
    await expectConverged(container);
  });

  test('the FINAL step still gets its reminder', () async {
    // 6mg down to 5mg: the last step runs FROM above the target down TO it,
    // and somebody in the middle of it takes a dose every morning for 52 days.
    // Reading `toDose` here instead of `fromDose` cuts their reminder off the
    // day the final step starts — 52 mornings early, silently.
    final container = await containerAt(taperActive: false);
    await container
        .read(taperRepositoryProvider)
        .savePlan(
          const TaperPlanDraft(
            drugName: 'Prednisolone',
            startDate: LocalDate(2025, 4, 1),
            currentDose: Milligrams.fromHundredths(600),
            targetDose: Milligrams.fromHundredths(500),
            strengths: <Milligrams>[Milligrams.fromHundredths(100)],
            allowHalves: true,
            method: TaperMethod.dsns,
            stepSize: Milligrams.fromHundredths(100),
          ),
        );

    await container.read(reconcileNotificationsProvider)();

    expect(gateway.scheduleCount, 1);
    await expectConverged(container);
  });

  test('a taper already AT its target arms nothing', () async {
    // A plan whose starting dose is its target has no reduction left to make.
    // A daily nudge to open an app with nothing to show is the fastest way to
    // have notifications turned off for good — and then they are off for the
    // next taper too.
    final container = await containerAt(taperActive: false);
    await container
        .read(taperRepositoryProvider)
        .savePlan(
          const TaperPlanDraft(
            drugName: 'Prednisolone',
            startDate: LocalDate(2025, 4, 1),
            currentDose: Milligrams.fromHundredths(500),
            targetDose: Milligrams.fromHundredths(500),
            strengths: <Milligrams>[Milligrams.fromHundredths(100)],
            allowHalves: true,
            method: TaperMethod.dsns,
            stepSize: Milligrams.fromHundredths(100),
          ),
        );

    await container.read(reconcileNotificationsProvider)();

    expect(gateway.scheduleCount, 0);
    expect(await gateway.pendingIds(), isEmpty);
    await expectConverged(container);
  });

  test('a foreign id from a restore is cancelled', () async {
    // Restored pending ids came from another device and mean nothing here.
    final container = await containerAt();
    await gateway.schedule(
      ScheduledNotification(
        id: 424242,
        fireAt: tz.TZDateTime(testZone, 2025, 4, 16, 9),
        title: 'from another phone',
        body: 'b',
        payload: kTodayPayload,
        channelId: kDailyReminderChannelId,
      ),
    );
    gateway.resetCalls();

    await container.read(reconcileNotificationsProvider)();

    expect(await gateway.pendingIds(), isNot(contains(424242)));
    await expectConverged(container);
  });

  test('a refusal is typed, and the NEXT run repairs it', () async {
    final container = await containerAt();
    gateway.failNextSchedule = true;

    final result = await container.read(reconcileNotificationsProvider)();

    expect(result, isA<Err<void, ReminderFailure>>());
    expect(
      (result as Err<void, ReminderFailure>).failure,
      isA<SchedulingRefused>(),
    );
    expect(await gateway.pendingIds(), isEmpty);

    // Converges on the next run rather than needing a reinstall. This is the
    // only assertion that distinguishes "left in a repairable state" from
    // "left in a state that looks fine and never fires".
    final second = await container.read(reconcileNotificationsProvider)();
    expect(second, isA<Ok<void, ReminderFailure>>());
    await expectConverged(container);
  });
}
