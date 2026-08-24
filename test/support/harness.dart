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
import 'package:nearlystop/app/user_preferences_layer.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
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
  bool highContrast = false,
  bool boldText = false,
  bool disableAnimations = false,
  double userTextScale = 1,
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
        // OFF, like the app's own `MaterialApp`. It was on by default here,
        // so every parity capture and contact sheet carried a red diagonal
        // stripe across the top-right corner that the reference does not —
        // a difference a reviewer has to learn to ignore, which is the worst
        // kind of difference to have in a comparison sheet.
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        // The SAME builder the app uses, with the same three arguments. A
        // harness that built a default `ThemeData` would let a screen pass here
        // and look wrong in the app.
        theme: buildDaybreakTheme(
          brightness,
          scriptFor(locale),
          highContrast: highContrast,
        ),
        // The app suppresses the theme cross-fade; without this a harness pump
        // that changes theme would need an extra settle to reach the colours
        // the app shows immediately.
        themeAnimationStyle: AnimationStyle.noAnimation,
        // `copyWith` on the MediaQuery `MaterialApp` already provides, not a
        // bare `MediaQueryData`: replacing it wholesale zeroes the viewport
        // size, and a screen laid out at 0×0 passes any test that does not
        // look at geometry.
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler,
              boldText: boldText,
              highContrast: highContrast,
              disableAnimations: disableAnimations,
            ),
            // The app's OWN layer, not a re-implementation of it: `pumpApp`
            // renders a screen under exactly the preferences wrapper
            // `MaterialApp.builder` gives it in production.
            child: UserPreferencesLayer(
              script: scriptFor(locale),
              highContrast: highContrast,
              userTextScale: userTextScale,
              child: child,
            ),
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
  StorageFailure? bootstrapFailure,
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

/// A widget test that tears its provider scope down INSIDE the body.
///
/// Drift schedules a zero-duration timer when a query stream is cancelled, and
/// `testWidgets` asserts no timer is pending — an assertion that runs BEFORE
/// `addTearDown` callbacks, so unmounting there is too late. The symptom is a
/// whole file that hangs with no output at all, which is why this is shared
/// rather than re-derived: the second person to hit it loses an hour.
void widgetTestWithDatabase(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

/// Fails if anything on screen scrolls sideways.
///
/// Excludes the `Scrollable` a single-line text field builds for itself:
/// `EditableText` scrolls its own content horizontally, which is how a long
/// medicine name stays typeable, and has nothing to do with the PAGE scrolling
/// sideways.
void expectNoHorizontalScroll(WidgetTester tester) {
  final inFields = tester
      .widgetList<Scrollable>(
        find.descendant(
          of: find.byType(EditableText),
          matching: find.byType(Scrollable),
        ),
      )
      .toSet();
  for (final scrollable in tester.widgetList<Scrollable>(
    find.byType(Scrollable),
  )) {
    if (inFields.contains(scrollable)) continue;
    expect(
      scrollable.axisDirection,
      anyOf(AxisDirection.down, AxisDirection.up),
      reason: 'a horizontal scroller hides content off the edge',
    );
  }
  expect(tester.takeException(), isNull);
}

/// A `SettingsController` that reports fixed settings and swallows writes.
///
/// Five suites were each declaring their own. A sixth spelling is a sixth
/// chance to seed something subtly different from what the app produces.
final class FixedSettingsController extends SettingsController {
  /// Reports the defaults.
  FixedSettingsController() : _settings = AppSettings.defaults;

  /// Reports [settings].
  FixedSettingsController.of(AppSettings settings) : _settings = settings;

  /// A plan-less install past the disclaimer, with the reminder on — so the
  /// rows are not all sitting at their defaults in a golden.
  factory FixedSettingsController.seeded() => FixedSettingsController.of(
    AppSettings.defaults.copyWith(
      reminderEnabled: true,
      reminderMinuteOfDay: 8 * 60,
      disclaimerAcceptedAt: DateTime.utc(2026, 4),
    ),
  );

  final AppSettings _settings;

  @override
  AppSettings build() => _settings;

  @override
  Future<Result<void, StorageFailure>> setLocaleTag(String? tag) async =>
      const Ok(null);
}
