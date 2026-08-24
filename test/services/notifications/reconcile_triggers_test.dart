// Every place the reconcile must run, and every place it must not.
//
// With no server there is no way to learn a reminder was dropped except the
// next foreground reconcile, so these triggers ARE the reliability story. The
// half that matters most is the negative: a `ref.listen` without a `select`
// fires on every settings write, so "changing high contrast reconciles zero
// times" is the assertion that separates a correct listener from one that
// happens to work.
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/services/notifications/fake_notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_providers.dart';
import 'package:nearlystop/services/notifications/reconcile_triggers.dart';
import 'package:nearlystop/services/notifications/sync_notifications.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../fixtures/seeded_plan.dart';
import '../../support/db_harness.dart';
import '../../support/harness.dart';

void main() {
  late tz.Location berlin;

  setUpAll(() {
    tzdata.initializeTimeZones();
    berlin = tz.getLocation('Europe/Berlin');
  });

  late FakeNotificationGateway gateway;
  late AppDatabaseHolder holder;
  late bool seeded;

  setUp(() {
    gateway = FakeNotificationGateway();
    holder = AppDatabaseHolder(openTestDatabase());
    seeded = false;
  });

  Future<ProviderContainer> makeContainer({
    Locale locale = const Locale('en'),
  }) async {
    final container = ProviderContainer(
      overrides: <Override>[
        ...launchOverrides(settings: AppSettings.defaults),
        databaseProvider.overrideWithValue(holder.database),
        notificationGatewayProvider.overrideWithValue(gateway),
        notificationZoneProvider.overrideWithValue(berlin),
        clockProvider.overrideWithValue(
          Clock.fixed(DateTime.utc(2025, 4, 16, 5)),
        ),
        resolvedLocaleProvider.overrideWithValue(locale),
      ],
    );
    addTearDown(container.dispose);
    // ONCE per test, however many containers a case builds: v1 holds one plan
    // and `savePlan` refuses a second.
    if (!seeded) {
      await seedTaperInto(container);
      seeded = true;
    }
    // The settings controller starts from the bootstrap snapshot and then
    // follows the repository's stream. Without this, a container built after
    // a write reconciles against the DEFAULTS — reminder off — and cancels
    // the entry the previous container armed.
    container.read(settingsControllerProvider);
    await pumpEventQueue();
    return container;
  }

  group('the settings listener fires on the reminder, and nothing else', () {
    test('changing the reminder time reconciles exactly once', () async {
      final container = await makeContainer();
      final trigger = container.read(reconcileTriggersProvider);
      await container
          .read(settingsControllerProvider.notifier)
          .setReminderEnabled(enabled: true);
      await pumpEventQueue();
      trigger.resetRunCount();

      await container
          .read(settingsControllerProvider.notifier)
          .setReminderMinuteOfDay(9 * 60);
      await pumpEventQueue();

      expect(trigger.runCount, 1);
    });

    test('changing high contrast reconciles ZERO times', () async {
      // The half that matters. A `ref.listen` on the whole `AppSettings`
      // passes the case above and fails this one, and the cost is a
      // cancel-and-rearm every time somebody drags the text-size slider.
      final container = await makeContainer();
      final trigger = container.read(reconcileTriggersProvider);
      await pumpEventQueue();
      trigger.resetRunCount();

      await container
          .read(settingsControllerProvider.notifier)
          .setHighContrast(enabled: true);
      await pumpEventQueue();

      expect(trigger.runCount, 0);
    });
  });

  test('a locale change reconciles, and produces a different id', () async {
    // The body is part of the id, so a language switch leaves an armed
    // notification in the old language until something re-arms it.
    final english = await makeContainer();
    await english
        .read(settingsControllerProvider.notifier)
        .setReminderEnabled(enabled: true);
    await english
        .read(settingsControllerProvider.notifier)
        .setReminderMinuteOfDay(8 * 60);
    // The controller follows the repository's STREAM, so the write has to
    // reach it before a reconcile can see it. In the app the trigger IS the
    // listener on that state, so this wait is the test standing in for a frame.
    await pumpEventQueue();
    await english.read(reconcileNotificationsProvider)();
    final englishId = (await gateway.pendingIds()).single;

    final persian = await makeContainer(locale: const Locale('fa'));
    await persian.read(reconcileNotificationsProvider)();

    final ids = await gateway.pendingIds();
    expect(ids, hasLength(1));
    expect(ids.single, isNot(englishId));
  });

  test('permission is CHECKED before the pending set is read', () async {
    // On resume, the authorization state decides what the Settings row says.
    // Reading the pending set first and checking afterwards means a revoked
    // grant is discovered one frame too late to render, which is exactly the
    // shape of "the row still reads On · 8:00 while nothing fires".
    final container = await makeContainer();
    final trigger = container.read(reconcileTriggersProvider);

    await trigger.onResume();

    expect(gateway.calls, isNotEmpty);
    expect(
      gateway.calls.indexOf('checkPermission'),
      lessThan(gateway.calls.indexOf('pendingIds')),
    );
  });

  test('two resumes in a row perform zero gateway writes', () async {
    final container = await makeContainer();
    await container
        .read(settingsControllerProvider.notifier)
        .setReminderEnabled(enabled: true);
    await container
        .read(settingsControllerProvider.notifier)
        .setReminderMinuteOfDay(8 * 60);
    await pumpEventQueue();
    final trigger = container.read(reconcileTriggersProvider);

    await trigger.onResume();
    gateway.resetCalls();
    await trigger.onResume();

    expect(gateway.scheduleCount, 0);
    expect(gateway.cancelCount, 0);
  });

  test('a revoked grant is reported, and the setting is KEPT', () async {
    // The user's intent has not changed. Clearing `reminderEnabled` here would
    // mean that re-allowing notifications in the OS silently does nothing,
    // because the app has forgotten they ever wanted one.
    final container = await makeContainer();
    await container
        .read(settingsControllerProvider.notifier)
        .setReminderEnabled(enabled: true);
    await container
        .read(settingsControllerProvider.notifier)
        .setReminderMinuteOfDay(8 * 60);
    await pumpEventQueue();
    final trigger = container.read(reconcileTriggersProvider);
    await trigger.onResume();

    gateway.permission = PermissionState.denied;
    await trigger.onResume();

    expect(container.read(notificationsBlockedProvider), isTrue);
    expect(
      container.read(settingsControllerProvider).reminderEnabled,
      isTrue,
      reason: 'the reader still wants a reminder; the OS is what changed',
    );
    expect(
      await gateway.pendingIds(),
      hasLength(1),
      reason: 'the entry stays armed — the OS simply will not post it',
    );
  });

  test('there is no boot_rearm_android.dart, and there cannot be', () async {
    // No Dart runs at boot: the plugin's own native receiver re-registers its
    // persisted alarms. A Dart file here would describe something the platform
    // does not offer, and reading it would suggest boot survival is covered by
    // code somebody could test.
    expect(
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('boot_rearm_android.dart')),
      isEmpty,
    );
  });
}
