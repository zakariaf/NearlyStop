// The chrome: five destinations, the breakpoint, and the error banner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/app.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/routing/app_router.dart';
import 'package:nearlystop/routing/routes.dart';

import '../../support/harness.dart';

void main() {
  final openContainers = <ProviderContainer>[];

  tearDown(() {
    for (final container in openContainers) {
      container.dispose();
    }
    openContainers.clear();
  });

  /// The app past the gate, so the shell is what renders.
  Future<ProviderContainer> pumpShell(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Size size = const Size(400, 800),
    StorageFailure? bootstrapFailure,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: launchOverrides(
        settings: acceptedSettings(localeTag: locale.languageCode),
        bootstrapFailure: bootstrapFailure,
      ),
    );
    // Tracked, not torn down here. Two tests below pump twice — the
    // breakpoint pair and the two-locale a11y sweep — and registering a
    // teardown per pump nests one `runAsync` inside another, which
    // `flutter_test` refuses. One disposal per test, at the end.
    openContainers.add(container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NearlyStopApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('each destination navigates to its branch', (tester) async {
    final container = await pumpShell(tester);
    final router = container.read(routerProvider);

    for (var index = 0; index < Routes.branches.length; index++) {
      await tester.tap(find.byIcon(_icons[index]));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        Routes.branches[index],
        reason: 'destination $index',
      );
    }
  });

  testWidgets('below the breakpoint it is a bar, above it a rail', (
    tester,
  ) async {
    await pumpShell(tester, size: const Size(599, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await pumpShell(tester, size: const Size(600, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('labels are always shown, and survive German at 360dp', (
    tester,
  ) async {
    // German is the longest-string locale; 360dp is the narrowest phone this
    // audience is likely to hold. Icon-only is not an acceptable fallback for
    // a reader who is unsure what a glyph means.
    await pumpShell(
      tester,
      locale: const Locale('de'),
      size: const Size(360, 800),
    );

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
    for (final label in <String>[
      'Heute',
      'Plan',
      'Verlauf',
      'Therapie',
      'Optionen',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the error banner is persistent, and is not a SnackBar', (
    tester,
  ) async {
    await pumpShell(tester, bootstrapFailure: const Io('disk on fire'));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    // Thirty seconds of timed pumps: a SnackBar would be long gone, and this
    // audience does not finish reading a message that removes itself.
    await tester.pump(const Duration(seconds: 30));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no banner when the launch was clean', (tester) async {
    await pumpShell(tester);

    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('exactly one destination is selected at a time', (tester) async {
    final container = await pumpShell(tester);
    container.read(routerProvider).go(Routes.progress);
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(bar.selectedIndex, Routes.branches.indexOf(Routes.progress));
  });

  testWidgets('the shell meets the tap-target and contrast guidelines', (
    tester,
  ) async {
    // Checked in both directions: `fa` mirrors, and a mirrored layout is where
    // a hand-rolled inset turns a 48pt target into a 20pt one.
    for (final locale in <Locale>[const Locale('en'), const Locale('fa')]) {
      await pumpShell(tester, locale: locale);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    }
  });
}

const _icons = <IconData>[
  Icons.wb_sunny_outlined,
  Icons.view_agenda_outlined,
  Icons.trending_down,
  Icons.medication_outlined,
  Icons.settings_outlined,
];
