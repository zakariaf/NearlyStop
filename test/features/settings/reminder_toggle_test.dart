// The reminder row: asking at the right moment, and degrading honestly.
//
// This is EPIC-12's acceptance gate. Everything else in the epic is asserted
// in pieces; this is the one test that says the pieces compose — toggle on,
// pick a time, and exactly one repeating notification is armed at that minute.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/services/notifications/fake_notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_providers.dart';
import 'package:nearlystop/services/notifications/reconcile_triggers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:timezone/timezone.dart' as tz;

import '../../fixtures/seeded_plan.dart';
import '../../support/harness.dart';
import '../../support/notification_harness.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    initializeTestTimeZones();
  });

  late FakeNotificationGateway gateway;

  setUp(() {
    gateway = FakeNotificationGateway();
  });

  /// Pumps Settings with the reminder engine wired to a fake gateway.
  Future<AppLocalizations> pumpSettings(
    WidgetTester tester, {
    PermissionState permission = PermissionState.granted,
  }) async {
    gateway.permission = permission;
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: <Override>[
        ...launchOverrides(settings: AppSettings.defaults),
        settingsControllerProvider.overrideWith(_InMemorySettings.new),
        // The FACTS, not a database. Driving real drift I/O from inside
        // `testWidgets`' fake-async zone means pumping every await by hand,
        // and this gate is about the reminder, not about storage — which the
        // reconcile suite covers over a real engine.
        taperFactsReaderProvider.overrideWithValue(
          () async => seededSnapshot(),
        ),
        ...notificationOverrides(gateway: gateway),
      ],
      surfaceSize: const Size(390, 1400),
    );
    // Reading it is what registers the listeners.
    ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    ).read(reconcileTriggersProvider);
    await tester.pumpAndSettle();
    return l10n;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));

  testWidgets('toggling on with permission arms exactly one, at the minute', (
    tester,
  ) async {
    // The acceptance gate. One realistic scenario, asserted to the exact
    // expected value: that the pieces compose is the only thing it proves, and
    // nothing else in this epic proves it.
    final l10n = await pumpSettings(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // REQUESTED, not merely checked. `checkPermission` never shows the OS
    // prompt, so an app that only checks can never be granted anything on a
    // fresh install — and the fake answers both calls identically, so nothing
    // else here separates them.
    expect(gateway.calls.first, 'requestPermission');

    expect(gateway.pending, hasLength(1));
    final armed = gateway.pending.single;
    expect(armed.fireAt, tz.TZDateTime(testZone, 2025, 4, 16, 8));
    expect(armed.repeatsDaily, isTrue);
    expect(armed.title, l10n.reminderTitle);
    expect(armed.body, l10n.reminderBody);

    // And back off again: the round trip, not just the arm.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(await gateway.pendingIds(), isEmpty);
  });

  testWidgets('toggling on with permission DENIED arms nothing and says why', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester, permission: PermissionState.denied);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(gateway.calls, contains('requestPermission'));
    expect(gateway.scheduleCount, 0);
    expect(
      containerOf(tester).read(settingsControllerProvider).reminderEnabled,
      isFalse,
      reason: 'the setting could not take effect, so it did not take',
    );
    // Inline, never a SnackBar: information the reader has to act on does not
    // time out.
    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.textContaining(l10n.reminderBlocked),
      findsWidgets,
      reason: 'nothing on screen explains why the switch snapped back',
    );
  });

  testWidgets('the app never asks for permission on its own', (tester) async {
    // Never on launch. The request happens when the reader turns the reminder
    // on, which is the one moment it explains itself — a prompt on first run
    // is a prompt somebody denies before they know what it is for.
    await pumpSettings(tester);

    expect(gateway.calls, isNot(contains('requestPermission')));
  });

  testWidgets('a grant revoked later marks the row, and keeps the setting', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    gateway.permission = PermissionState.denied;
    await containerOf(tester).read(reconcileTriggersProvider).onResume();
    await tester.pumpAndSettle();

    expect(find.textContaining(l10n.reminderBlocked), findsWidgets);
    expect(
      containerOf(tester).read(settingsControllerProvider).reminderEnabled,
      isTrue,
      reason: 'the reader still wants a reminder; the OS is what changed',
    );
    expect(await gateway.pendingIds(), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

/// A `SettingsController` that keeps state in memory and actually changes it.
///
/// Not the fixed one from the harness: this gate is about the SEQUENCE — the
/// switch writes, the listener sees the write, the reconcile arms — and a
/// controller whose writes do nothing would make the whole thing vacuous.
/// Not the real one either: it reads through drift, and driving drift from
/// inside `testWidgets`' fake-async zone means pumping every await by hand.
final class _InMemorySettings extends SettingsController {
  @override
  AppSettings build() => AppSettings.defaults;

  @override
  Future<Result<void, StorageFailure>> setReminderEnabled({
    required bool enabled,
  }) async {
    state = state.copyWith(reminderEnabled: enabled);
    return const Ok(null);
  }

  @override
  Future<Result<void, StorageFailure>> setReminderMinuteOfDay(
    int? minute,
  ) async {
    state = state.copyWith(reminderMinuteOfDay: minute);
    return const Ok(null);
  }
}
