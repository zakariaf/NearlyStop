// The three screens EPIC-11 owns, against the platform guidelines.
//
// `a11y_sweep_test.dart` sweeps the COMPONENTS. A component that clears 48pt
// on its own can still be pushed under it by a neighbour on a real screen, and
// contrast is measured against what was actually composited underneath — which
// on a screen is a card on a tint on the page ground, not a nominal surface.
//
// Run at 1.0 and 2.0 in both directions, because every failure this catches is
// a failure at one of the four corners and at none of the middle.
//
// **What `textContrastGuideline` does NOT see.** It resolves each semantics
// node's label back to a single `RenderParagraph`, so any text merged into a
// larger node — which on these screens is most of it — is skipped silently. A
// planted `primary` label inside a card passes it. So the paragraph walk below
// runs alongside it: every `RenderParagraph` in the tree, checked against the
// one rule the palette states outright — `primary` #F97350 measures 2.76:1 and
// is decorative-only, never a label.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/derived_schedule_provider.dart';
import 'package:nearlystop/app/locale_providers.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/plan/presentation/plan_screen.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/disclaimer_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:riverpod/misc.dart' show Override;

import '../fixtures/seeded_plan.dart';
import '../support/contrast.dart';
import '../support/harness.dart';

/// One screen under sweep: how to build it, and what it needs overridden.
typedef _Screen = ({
  Widget Function(AppLocalizations) build,
  List<Override> Function(Locale) overrides,
});

/// Fails if any painted paragraph misses WCAG AA against the page.
///
/// Walks the RENDER tree, not the semantics tree: that is the whole point —
/// merged text has no node of its own, and merged text is where this mistake
/// hides.
///
/// **Measured, not banned by name.** The obvious rule — "never use `primary`
/// for text" — is a LIGHT-theme rule: #F97350 on cream is 2.76:1, but the dark
/// palette's coral70 on plum11 is 7.30:1 and perfectly legible. Comparing the
/// colour by identity would forbid the readable one and teach nothing.
///
/// The ground is taken as the better of `surface` and `bg`, which is an
/// approximation: text painted on a TINT is measured against the card instead.
/// In this palette the tints sit within a few percent of the surface they
/// cover, so the approximation is conservative rather than blind — and the
/// component suites measure the tinted recipes against their own fills.
void expectTextMeetsAA(WidgetTester tester, Brightness brightness) {
  final colors = brightness == Brightness.light
      ? lightDaybreakColors
      : darkDaybreakColors;
  final scaler = tester.platformDispatcher.textScaleFactor;

  for (final element in find.byType(Text).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph) continue;
    final style = render.text.style;
    final color = style?.color;
    if (color == null) continue;
    final text = render.text.toPlainText();
    if (text.trim().isEmpty) continue;
    // `onPrimary` is the token that MEANS "painted on a filled accent, not on
    // the page" — a pill button's label sits on the sunrise gradient, and
    // measuring it against the card behind the button says 1.09:1 about text
    // that is perfectly legible. Those recipes are measured against their own
    // fills in `daybreak_buttons_test.dart`.
    if (color == colors.onPrimary) continue;

    final points = (style?.fontSize ?? 14) * scaler;
    final bold = (style?.fontWeight?.value ?? 0) >= FontWeight.w700.value;
    // WCAG's own large-text carve-out: 18pt, or 14pt when bold.
    final large = points >= 18 || (bold && points >= 14);
    final required = large ? 3.0 : 4.5;

    final ratio = <double>[
      contrastRatio(color, colors.surface),
      contrastRatio(color, colors.bg),
    ].reduce((a, b) => a > b ? a : b);

    expect(
      ratio,
      greaterThanOrEqualTo(required),
      reason:
          '"$text" measures ${ratio.toStringAsFixed(2)}:1 at '
          '${points.toStringAsFixed(0)}pt, and needs $required',
    );
  }
}

void main() {
  setUpAll(initializeDateFormatting);

  List<Override> planOverrides(Locale locale) => <Override>[
    taperSnapshotProvider.overrideWith(
      (ref) => Stream<Result<TaperSnapshot, StorageFailure>>.value(
        Ok<TaperSnapshot, StorageFailure>(seededSnapshot()),
      ),
    ),
    todayDateProvider.overrideWithValue(seededToday),
    clockProvider.overrideWithValue(Clock.fixed(seededNow)),
    resolvedLocaleProvider.overrideWithValue(locale),
  ];

  final screens =
      <
        String,
        ({
          Widget Function(AppLocalizations) build,
          List<Override> Function(Locale) overrides,
        })
      >{
        'Plan': (
          build: (_) => const PlanScreen(),
          overrides: planOverrides,
        ),
        'Settings': (
          build: (_) => const SettingsScreen(),
          overrides: (locale) => <Override>[
            settingsControllerProvider.overrideWith(_Seeded.new),
          ],
        ),
        'Welcome': (
          build: (l10n) => Scaffold(
            body: SafeArea(
              child: DisclaimerSheet(
                title: l10n.welcomeTitle,
                body: '${l10n.welcomeDisclaimer}\n\n${l10n.welcomeOffline}',
                actionLabel: l10n.welcomeAccept,
                isGate: true,
                onAccept: () {},
                onClose: () {},
              ),
            ),
          ),
          overrides: (_) => const <Override>[],
        ),
      };

  for (final MapEntry<String, _Screen>(key: name, value: screen)
      in screens.entries) {
    for (final brightness in Brightness.values) {
      for (final locale in <Locale>[const Locale('en'), const Locale('fa')]) {
        for (final scale in <double>[1, 2]) {
          final label =
              '$name — ${brightness.name} ${locale.languageCode} at $scale';
          testWidgets(label, (tester) async {
            final handle = tester.ensureSemantics();
            final l10n = await AppLocalizations.delegate.load(locale);
            await pumpApp(
              tester,
              screen.build(l10n),
              overrides: screen.overrides(locale),
              locale: locale,
              brightness: brightness,
              textScaler: TextScaler.linear(scale),
              // Tall enough that a `ListView` BUILDS the whole screen: an
              // off-screen row is a row no guideline is measured against, so a
              // 844pt surface would sweep the top third and report green.
              surfaceSize: Size(390, scale == 1 ? 1600 : 3600),
            );
            await tester.pumpAndSettle();

            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            expectTextMeetsAA(tester, brightness);
            expect(tester.takeException(), isNull);

            handle.dispose();
            // Drift-free, but the Plan screen still holds a stream
            // subscription whose cancellation schedules a zero-duration timer.
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          });
        }
      }
    }
  }
}

final class _Seeded extends SettingsController {
  @override
  AppSettings build() => AppSettings.defaults.copyWith(
    reminderEnabled: true,
    reminderMinuteOfDay: 8 * 60,
    disclaimerAcceptedAt: DateTime.utc(2026, 4),
  );

  @override
  Future<Result<void, StorageFailure>> setLocaleTag(String? tag) async =>
      const Ok(null);
}
