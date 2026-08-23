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
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/routing/app_router.dart';
import 'package:nearlystop/routing/routes.dart';

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
}
