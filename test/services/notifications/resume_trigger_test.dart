// Something has to CALL the resume trigger.
//
// Every other test in this stack calls `onResume()` by hand, which proves the
// method works and proves nothing about whether anything invokes it. A trigger
// nobody calls is the whole engine quietly not running — and with no server
// there is no other way to discover that the OS dropped a reminder or that the
// reader revoked the grant in system settings.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/app_lifecycle.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/services/notifications/fake_notification_gateway.dart';
import 'package:nearlystop/services/notifications/notification_providers.dart';
import 'package:nearlystop/services/notifications/reconcile_triggers.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../fixtures/seeded_plan.dart';
import '../../support/harness.dart';
import '../../support/notification_harness.dart';

void main() {
  setUpAll(initializeTestTimeZones);

  late FakeNotificationGateway gateway;

  setUp(() => gateway = FakeNotificationGateway());

  ProviderContainer pumpContainer(WidgetTester tester) {
    final container = ProviderContainer(
      overrides: <Override>[
        ...launchOverrides(settings: AppSettings.defaults),
        ...notificationOverrides(gateway: gateway),
        taperFactsReaderProvider.overrideWithValue(
          () async => seededSnapshot(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('a real resume reaches the reconcile', (tester) async {
    final container = pumpContainer(tester);
    final observer = container.read(notificationLifecycleProvider);
    addTearDown(observer.dispose);
    final trigger = container.read(reconcileTriggersProvider)..resetRunCount();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(trigger.runCount, greaterThan(0));
  });

  testWidgets('nothing runs while the app is merely backgrounded', (
    tester,
  ) async {
    // Pausing is not resuming. A reconcile on the way OUT reads a database the
    // OS is about to suspend, for an answer nobody will act on until the next
    // launch.
    final container = pumpContainer(tester);
    final observer = container.read(notificationLifecycleProvider);
    addTearDown(observer.dispose);
    final trigger = container.read(reconcileTriggersProvider)..resetRunCount();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(trigger.runCount, 0);
  });

  testWidgets('disposing it stops the observing', (tester) async {
    // A leaked `AppLifecycleListener` keeps a disposed container's providers
    // reachable, and the next test's resume runs against it.
    final container = pumpContainer(tester);
    container.read(notificationLifecycleProvider).dispose();
    final trigger = container.read(reconcileTriggersProvider)..resetRunCount();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(trigger.runCount, 0);
  });
}
