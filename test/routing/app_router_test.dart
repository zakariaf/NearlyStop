// The gate, the branches, and the unknown route.
//
// Redirects are asserted HEADLESSLY where they can be: build the router from a
// container, `go(...)`, and read the resulting location. No widget pumped means
// no frame timing to reason about, and the redirect is the whole claim.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/app.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/routing/app_router.dart';
import 'package:nearlystop/routing/routes.dart';
import 'package:riverpod/misc.dart' show Override;

import '../support/db_harness.dart';
import '../support/harness.dart';

/// Every location a user or a deep link can name.
const allLocations = <String>[
  Routes.today,
  Routes.schedule,
  Routes.progress,
  Routes.plan,
  Routes.settings,
  Routes.disclaimerReread,
];

void main() {
  ProviderContainer containerWith({required bool accepted}) {
    final container = ProviderContainer(
      overrides: launchOverrides(
        settings: accepted ? acceptedSettings() : AppSettings.defaults,
      ),
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Pumps the real app, navigates, and reads where it ended up.
  ///
  /// Not headless. A `GoRouter` that has never been attached to a
  /// `Router` widget has not performed its initial navigation, so
  /// `currentConfiguration.uri.path` is the empty string and every redirect
  /// assertion passes or fails for the wrong reason.
  Future<String> locationAfter(
    WidgetTester tester,
    ProviderContainer container,
    String target,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NearlyStopApp(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(target);
    await tester.pumpAndSettle();
    final path = container
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    await tester.pumpWidget(const SizedBox.shrink());
    return path;
  }

  group('the gate, while the disclaimer is unaccepted', () {
    for (final location in allLocations) {
      testWidgets('$location lands on /welcome', (tester) async {
        final container = containerWith(accepted: false);

        expect(
          await locationAfter(tester, container, location),
          Routes.welcome,
        );
      });
    }
  });

  group('once accepted', () {
    for (final location in allLocations) {
      testWidgets('$location stays where it was sent', (tester) async {
        final container = containerWith(accepted: true);

        expect(
          await locationAfter(tester, container, location),
          location,
        );
      });
    }

    testWidgets('the gate itself is no longer a place to be', (tester) async {
      // A deep link or a restored location pointing at /welcome after
      // acceptance must not re-arm it.
      final container = containerWith(accepted: true);

      expect(
        await locationAfter(tester, container, Routes.welcome),
        Routes.today,
      );
    });

    testWidgets('the initial location is Today', (tester) async {
      final container = containerWith(accepted: true);

      expect(
        await locationAfter(tester, container, Routes.today),
        Routes.today,
      );
    });
  });

  test('the router is built ONCE and survives a settings change', () async {
    // A `ref.watch` inside `routerProvider` would recreate the GoRouter and
    // reset every branch's navigation stack — a user who scrolled the Schedule
    // back three months would lose that place by toggling high contrast.
    final container = containerWith(accepted: true);
    final first = container.read(routerProvider);

    container.read(settingsControllerProvider.notifier);
    final second = container.read(routerProvider);

    expect(identical(first, second), isTrue);
  });

  testWidgets('an unknown route renders the localized page, not ErrorWidget', (
    tester,
  ) async {
    final container = containerWith(accepted: true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NearlyStopApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(routerProvider).go('/nope');
    await tester.pumpAndSettle();

    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('That page does not exist'), findsOneWidget);
    expect(find.text('Go to Today'), findsOneWidget);
  });

  testWidgets('the gate cannot be left by the system back button', (
    tester,
  ) async {
    final container = containerWith(accepted: false);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NearlyStopApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(routerProvider);
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.welcome);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.welcome);
  });

  testWidgets('the gate can be PASSED — there is an accept action', (
    tester,
  ) async {
    // The bug this exists for shipped: `_WelcomeGate` rendered the disclaimer
    // and nothing else. On a fresh install the app opened on a screen with no
    // action, and `PopScope(canPop: false)` meant the reader could not even
    // back out of it — the app was unusable and no test noticed, because every
    // test asserted where the redirect LANDS and none asked whether it can be
    // left.
    //
    // Found by launching on a simulator, which is the only place "install it
    // fresh and try to use it" happens.
    // A REAL in-memory database, not just the bootstrap override: accepting
    // writes a row, and the redirect is driven by the repository stream
    // emitting it back. Without one the write fails, nothing emits, and the
    // test asserts against a path that cannot succeed in the harness — which
    // proves nothing about the app.
    final database = openTestDatabase();
    final container = ProviderContainer(
      overrides: <Override>[
        ...launchOverrides(settings: AppSettings.defaults),
        databaseProvider.overrideWithValue(database),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => database.settingsDao.ensureRowExists('settings-0'),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NearlyStopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      Routes.welcome,
    );

    final accept = find.widgetWithText(
      PrimaryPillButton,
      'I understand',
    );
    expect(accept, findsOneWidget, reason: 'the gate has no way out');
    expect(
      tester.widget<PrimaryPillButton>(accept).onPressed,
      isNotNull,
      reason: 'the accept action is disabled with nothing left to scroll',
    );

    // And it WORKS end to end: accepting writes `disclaimerAcceptedAt`, the
    // router's `refreshListenable` fires, and the redirect sends the reader to
    // Today. A button that exists but leaves them where they were is the same
    // bug wearing a hat.
    // The TAP does it, and nothing else. Calling `acceptDisclaimer()` beside
    // the tap would let a button wired to nothing pass this.
    //
    // Inside `runAsync` because the button's own callback awaits a real
    // database write, and real asynchronous I/O never completes in the
    // fake-async zone `testWidgets` runs its body in.
    await tester.runAsync(() async {
      await tester.tap(accept);
      // The write and the stream emission back are real I/O. Give them real
      // time, then let the router rebuild.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      Routes.today,
      reason: 'accepting the disclaimer did not open the app',
    );
  });
}
