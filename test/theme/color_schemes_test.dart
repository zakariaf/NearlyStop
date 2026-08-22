// Two mappings carry the whole epic, and each test name says which.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/color_schemes.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/primitives.dart';

import '../support/contrast.dart';

void main() {
  final light = daybreakColorScheme(Brightness.light, lightDaybreakColors);
  final dark = daybreakColorScheme(Brightness.dark, darkDaybreakColors);

  group('outline is the VISIBLE boundary, never the decorative hairline', () {
    // Material draws every TextField, Switch, Checkbox and OutlinedButton edge
    // from `outline`. The hairline there ships controls whose edges a
    // 78-year-old cannot see, and nothing in the app will report it.
    test('light', () {
      expect(light.outline, lightDaybreakColors.borderStrong);
      expect(light.outline, isNot(lightDaybreakColors.border));
      expect(light.outlineVariant, lightDaybreakColors.border);
    });

    test('dark', () {
      expect(dark.outline, darkDaybreakColors.borderStrong);
      expect(dark.outline, isNot(darkDaybreakColors.border));
      expect(dark.outlineVariant, darkDaybreakColors.border);
    });
  });

  test('ColorScheme.primary is the TEXT-safe coral, not the fill', () {
    // Material paints text and icons with the `primary` role, so the 2.76:1
    // fill must not reach a screen through a path no widget in this repo wrote.
    expect(light.primary, Primitives.coral43);
    expect(light.primary, isNot(lightDaybreakColors.primary));
    expect(light.primary, lightDaybreakColors.primaryDeep);
  });

  test('onPrimary on primary is measured, not trusted from a doc comment', () {
    expect(
      contrastRatio(light.onPrimary, light.primary),
      greaterThanOrEqualTo(4.5),
    );
    expect(contrastRatio(light.onPrimary, light.primary), closeTo(5.6, 0.15));
  });

  test('the two onPrimary roles are different colours ON PURPOSE', () {
    // ColorScheme.onPrimary sits on ColorScheme.primary (the deep coral).
    // DaybreakColors.onPrimary sits on the coral FILL and the sunrise gradient.
    expect(light.onPrimary, isNot(lightDaybreakColors.onPrimary));
    expect(
      contrastRatio(lightDaybreakColors.onPrimary, Primitives.coral64),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(lightDaybreakColors.onPrimary, Primitives.coral64),
      closeTo(6.04, 0.05),
    );
    // White on the coral fill is the exact mistake this pair exists to prevent.
    expect(
      contrastRatio(const Color(0xFFFFFFFF), Primitives.coral64),
      lessThan(3),
    );
  });

  test('dark is AUTHORED, not flipped', () {
    expect(darkDaybreakColors.bg, Primitives.plum11);
    expect(darkDaybreakColors.bg, isNot(const Color(0xFF000000)));
  });

  test('each scheme carries the brightness of the theme it is attached to', () {
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
  });

  test('every M3 role the app can render is stated, not defaulted', () {
    // A ColorScheme written by hand is a ColorScheme with a forgotten role, so
    // every slot the app touches is listed here explicitly.
    for (final (label, scheme) in <(String, ColorScheme)>[
      ('light', light),
      ('dark', dark),
    ]) {
      final roles = <String, Color>{
        'primary': scheme.primary,
        'onPrimary': scheme.onPrimary,
        'primaryContainer': scheme.primaryContainer,
        'onPrimaryContainer': scheme.onPrimaryContainer,
        'secondary': scheme.secondary,
        'onSecondary': scheme.onSecondary,
        'secondaryContainer': scheme.secondaryContainer,
        'onSecondaryContainer': scheme.onSecondaryContainer,
        'tertiary': scheme.tertiary,
        'onTertiary': scheme.onTertiary,
        'tertiaryContainer': scheme.tertiaryContainer,
        'onTertiaryContainer': scheme.onTertiaryContainer,
        'error': scheme.error,
        'onError': scheme.onError,
        'errorContainer': scheme.errorContainer,
        'onErrorContainer': scheme.onErrorContainer,
        'surface': scheme.surface,
        'onSurface': scheme.onSurface,
        'onSurfaceVariant': scheme.onSurfaceVariant,
        'surfaceDim': scheme.surfaceDim,
        'surfaceBright': scheme.surfaceBright,
        'surfaceContainerLowest': scheme.surfaceContainerLowest,
        'surfaceContainerLow': scheme.surfaceContainerLow,
        'surfaceContainer': scheme.surfaceContainer,
        'surfaceContainerHigh': scheme.surfaceContainerHigh,
        'surfaceContainerHighest': scheme.surfaceContainerHighest,
        'outline': scheme.outline,
        'outlineVariant': scheme.outlineVariant,
        'scrim': scheme.scrim,
        'shadow': scheme.shadow,
        'inverseSurface': scheme.inverseSurface,
        'onInverseSurface': scheme.onInverseSurface,
        'inversePrimary': scheme.inversePrimary,
      };
      for (final MapEntry(key: role, value: colour) in roles.entries) {
        expect(colour.a, greaterThan(0), reason: '$label.$role is transparent');
      }
    }
  });
}
