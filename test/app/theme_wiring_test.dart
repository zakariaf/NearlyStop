// The palettes and the weight ladder have to be REACHABLE, not merely built.
//
// `buildDaybreakTheme`'s `highContrast` and `boldText` arguments are described
// as load-bearing; a build in which nothing ever passes a non-default value is
// a build where the OS accessibility switches do nothing. For this audience
// that is a defect, not a deferral (CLAUDE.md rule 4).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/app/app.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/providers.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:riverpod/misc.dart' show Override;

void main() {
  Future<DaybreakColors> paletteUnder(
    WidgetTester tester,
    MediaQueryData query,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: query,
        child: Builder(
          builder: (_) => ProviderScope(
            overrides: <Override>[
              bootstrapSettingsProvider.overrideWithValue(AppSettings.defaults),
            ],
            child: const NearlyStopApp(),
          ),
        ),
      ),
    );
    return DaybreakColors.of(tester.element(find.byType(Scaffold)));
  }

  testWidgets('the OS high-contrast switch reaches the palette', (
    tester,
  ) async {
    final normal = await paletteUnder(tester, const MediaQueryData());
    final high = await paletteUnder(
      tester,
      const MediaQueryData(highContrast: true),
    );
    expect(high, isNot(normal));
    // The structural moves the high-contrast palette is defined by.
    expect(high.border, high.borderStrong);
    expect(high.inkMuted, high.ink);
  });

  testWidgets('the OS bold-text switch reaches the weight ladder', (
    tester,
  ) async {
    Future<FontWeight?> bodyWeight({required bool boldText}) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(boldText: boldText),
          child: ProviderScope(
            overrides: <Override>[
              bootstrapSettingsProvider.overrideWithValue(AppSettings.defaults),
            ],
            child: const NearlyStopApp(),
          ),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      return Theme.of(context).textTheme.bodyMedium?.fontWeight;
    }

    expect(await bodyWeight(boldText: false), FontWeight.w400);
    expect(await bodyWeight(boldText: true), FontWeight.w600);
  });

  testWidgets('high contrast and bold text compose', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(highContrast: true, boldText: true),
        child: ProviderScope(
          overrides: <Override>[
            bootstrapSettingsProvider.overrideWithValue(AppSettings.defaults),
          ],
          child: const NearlyStopApp(),
        ),
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);
    expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w600);
    expect(DaybreakColors.of(context).inkMuted, DaybreakColors.of(context).ink);
  });

  // The stored text-scale setting is read at bootstrap, persisted, and carried
  // through `AppSettings` — none of which does anything unless the widget tree
  // is told. Before this suite existed the setting was silently inert: the
  // slider EPIC-11 puts on the Settings screen would have moved and changed
  // nothing.
  Future<double> scaledTen(
    WidgetTester tester, {
    required double stored,
    TextScaler platform = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: platform),
        child: ProviderScope(
          overrides: <Override>[
            bootstrapSettingsProvider.overrideWithValue(
              AppSettings.defaults.copyWith(textScale: stored),
            ),
          ],
          child: const NearlyStopApp(),
        ),
      ),
    );
    return MediaQuery.textScalerOf(
      tester.element(find.byType(Scaffold)),
    ).scale(10);
  }

  testWidgets('the stored text scale reaches the tree', (tester) async {
    expect(await scaledTen(tester, stored: 1.4), closeTo(14, 0.001));
  });

  testWidgets('it MULTIPLIES the OS scaler, it does not replace it', (
    tester,
  ) async {
    // `TextScaler.clamp(minScaleFactor: 1.5)` would leave this at 20 — the user
    // asked their phone for 2.0 AND this app for 1.5, and gets both.
    expect(
      await scaledTen(
        tester,
        stored: 1.5,
        platform: const TextScaler.linear(2),
      ),
      closeTo(30, 0.001),
    );
  });

  testWidgets('the app multiplier is bounded, the OS scaler is not', (
    tester,
  ) async {
    // Ours is bounded because it is OUR control. A stored 4.0 — from a corrupt
    // row or a future slider with a wider range — is capped at 1.5. The OS half
    // is never touched: 3.0 from the phone stays 3.0.
    expect(await scaledTen(tester, stored: 4), closeTo(15, 0.001));
    expect(await scaledTen(tester, stored: 0.1), closeTo(9, 0.001));
    expect(
      await scaledTen(
        tester,
        stored: 1,
        platform: const TextScaler.linear(3),
      ),
      closeTo(30, 0.001),
    );
  });
}
