// The harness's own tests.
//
// Every later epic pumps through `pumpApp`. If it silently ignored an
// argument, each of those tests would still pass while asserting nothing —
// a golden "at 200% text scale" rendered at 100% looks perfectly fine.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:riverpod/misc.dart' show Override;

import 'harness.dart';

final Provider<int> probeProvider = Provider<int>((ref) => 0);

void main() {
  testWidgets('overrides reach the tree', (tester) async {
    // The argument a broken harness drops most quietly.
    late int seen;

    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, child) {
          seen = ref.watch(probeProvider);
          return const SizedBox.shrink();
        },
      ),
      overrides: <Override>[probeProvider.overrideWithValue(42)],
    );

    expect(seen, 42);
  });

  testWidgets('locale reaches Localizations AND Directionality', (
    tester,
  ) async {
    for (final (locale, direction) in <(Locale, TextDirection)>[
      (const Locale('en'), TextDirection.ltr),
      (const Locale('de'), TextDirection.ltr),
      (const Locale('fa'), TextDirection.rtl),
    ]) {
      late BuildContext context;

      await pumpApp(
        tester,
        Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.shrink();
          },
        ),
        locale: locale,
      );

      expect(Localizations.localeOf(context), locale);
      expect(Directionality.of(context), direction, reason: '$locale');
    }
  });

  testWidgets('brightness reaches the theme', (tester) async {
    late Brightness seen;

    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          seen = Theme.of(context).brightness;
          return const SizedBox.shrink();
        },
      ),
      brightness: Brightness.dark,
    );

    expect(seen, Brightness.dark);
  });

  testWidgets('textScaler reaches MediaQuery', (tester) async {
    late double scaled;

    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          scaled = MediaQuery.textScalerOf(context).scale(10);
          return const SizedBox.shrink();
        },
      ),
      textScaler: const TextScaler.linear(2),
    );

    expect(scaled, 20);
  });

  testWidgets('the defaults are pinned, so an unspecified test is stable', (
    tester,
  ) async {
    late Locale locale;
    late Brightness brightness;
    late double scaled;

    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          locale = Localizations.localeOf(context);
          brightness = Theme.of(context).brightness;
          scaled = MediaQuery.textScalerOf(context).scale(10);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(locale, const Locale('en'));
    expect(brightness, Brightness.light);
    expect(scaled, 10);
  });

  testWidgets('it returns after ONE frame, without settling', (tester) async {
    // A harness that settles cannot express a frame-one assertion, and
    // frame one is where the no-flash promise lives.
    var builds = 0;

    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          builds++;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(builds, 1);
  });

  testWidgets('surfaceSize reaches the viewport and is restored', (
    tester,
  ) async {
    late Size seen;

    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          seen = MediaQuery.sizeOf(context);
          return const SizedBox.shrink();
        },
      ),
      surfaceSize: const Size(599, 800),
    );

    expect(seen, const Size(599, 800));
  });

  testWidgets('the theme is the APP theme, not a Material default', (
    tester,
  ) async {
    // The whole point of a shared harness: a screen that passes here has been
    // rendered in the same tokens it will ship in.
    late TextStyle body;

    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          body = Theme.of(context).textTheme.bodyLarge!;
          return const SizedBox.shrink();
        },
      ),
      locale: const Locale('fa'),
    );

    expect(body.fontFamily, 'Vazirmatn');
  });

  // Three arguments were added when `/code-review` found that `pumpApp` built
  // a `MaterialApp` materially different from the app's while its doc claimed
  // they were the same. Each is asserted here for the reason at the top of
  // `harness.dart`: an argument the harness silently drops makes every later
  // epic's test that passes it vacuous.
  testWidgets('highContrast reaches the palette', (tester) async {
    late DaybreakColors palette;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          palette = DaybreakColors.of(context);
          return const SizedBox.shrink();
        },
      ),
      highContrast: true,
    );

    // The structural moves that define the high-contrast palette.
    expect(palette.border, palette.borderStrong);
    expect(palette.inkMuted, palette.ink);
  });

  testWidgets('boldText reaches the weight ladder', (tester) async {
    Future<FontWeight?> weightWith({required bool boldText}) async {
      late FontWeight? weight;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            weight = Theme.of(context).textTheme.bodyMedium?.fontWeight;
            return const SizedBox.shrink();
          },
        ),
        boldText: boldText,
      );
      return weight;
    }

    expect(await weightWith(boldText: false), FontWeight.w400);
    expect(await weightWith(boldText: true), FontWeight.w600);
  });

  testWidgets('userTextScale composes with textScaler, as the app does', (
    tester,
  ) async {
    late double scaled;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          scaled = MediaQuery.textScalerOf(context).scale(10);
          return const SizedBox.shrink();
        },
      ),
      textScaler: const TextScaler.linear(2),
      userTextScale: 1.5,
    );

    // 2.0 from the "OS", 1.5 from the app: the product, not either one.
    expect(scaled, closeTo(30, 0.001));
  });
}
