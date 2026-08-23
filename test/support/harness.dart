/// The shared widget-test entry point, from EPIC-06 onward.
///
/// Every later epic pumps its screens through [pumpApp]. A harness that
/// silently drops one of its arguments makes every one of those tests vacuous
/// — a golden captured at `textScaler` 2.0 that was really rendered at 1.0
/// proves nothing and looks fine — so the harness has its own tests, in
/// `test/support/harness_test.dart`, written before it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/app.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/providers.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';
import 'package:riverpod/misc.dart' show Override;

/// Pumps [child] inside the app's real theme, locale and delegates.
///
/// Returns after **one** frame and deliberately does not settle, so a
/// frame-one assertion is expressible through it. Call `tester.pumpAndSettle()`
/// yourself when a test genuinely needs the animations finished.
///
/// The defaults are pinned by test: `en`, `Brightness.light`, `TextScaler`
/// 1.0. Every later epic's unspecified test is therefore deterministic rather
/// than dependent on the host.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    // `tester.view`, not `setSurfaceSize`: the latter does not take effect
    // until a later pump, so a breakpoint test would lay out at the default
    // 800×600 and pass for the wrong reason.
    tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        // The SAME builder the app uses, with the same three arguments. A
        // harness that built a default `ThemeData` would let a screen pass here
        // and look wrong in the app.
        theme: buildDaybreakTheme(brightness, scriptFor(locale)),
        // `copyWith` on the MediaQuery `MaterialApp` already provides, not a
        // bare `MediaQueryData`: replacing it wholesale zeroes the viewport
        // size, and a screen laid out at 0×0 passes any test that does not
        // look at geometry.
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// The overrides a launched app needs, in one place.
///
/// `bootstrapSettingsProvider` throws by default — deliberately, so no screen
/// can render the wrong theme and never notice. That makes it required in
/// every test that pumps the app, and five files were each spelling the same
/// override out. A sixth spelling is a sixth chance to seed something subtly
/// different from what the launch actually produces.
List<Override> launchOverrides({
  AppSettings? settings,
  Object? bootstrapFailure,
}) => <Override>[
  bootstrapSettingsProvider.overrideWithValue(settings ?? AppSettings.defaults),
  bootstrapErrorProvider.overrideWithValue(bootstrapFailure),
];

/// Settings past the disclaimer gate, so the shell is what renders.
///
/// Without an acceptance timestamp every route redirects to `/welcome`, and a
/// test that meant to exercise a screen silently exercises the gate instead.
AppSettings acceptedSettings({String? localeTag, bool highContrast = false}) =>
    AppSettings.defaults.copyWith(
      disclaimerAcceptedAt: DateTime.utc(2026),
      localeTag: localeTag,
      highContrast: highContrast,
    );

/// Pumps the real [NearlyStopApp] and hands back its container.
///
/// The container is **not** torn down here. Two suites pump twice in one test,
/// and registering a teardown per pump nests one `runAsync` inside another,
/// which `flutter_test` refuses — so disposal is the caller's, once per test.
Future<ProviderContainer> pumpNearlyStopApp(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
  }
  final container = ProviderContainer(overrides: overrides);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const NearlyStopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
