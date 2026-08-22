// The CSS-blur conversion is a rounding golden. Pasting the CSS number straight
// into blurRadius makes every shadow about 15% too tight, and nothing else in
// the suite notices.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/primitives.dart';

/// The CSS source beside each layer: (level, dy, cssBlur).
const List<(String, int, double, double)> cssSources =
    <(String, int, double, double)>[
      ('level1', 0, 1, 2),
      ('level1', 1, 2, 8),
      ('level2', 0, 2, 4),
      ('level2', 1, 10, 24),
      ('level3', 0, 6, 12),
      ('level3', 1, 22, 48),
    ];

void main() {
  final light = lightDaybreakElevation;
  final dark = darkDaybreakElevation;

  List<BoxShadow> levelOf(DaybreakElevation e, String name) => switch (name) {
    'level1' => e.level1,
    'level2' => e.level2,
    'level3' => e.level3,
    _ => throw ArgumentError(name),
  };

  test('every blurRadius is 0.866 * (cssBlur - 1)', () {
    for (final (level, index, dy, cssBlur) in cssSources) {
      for (final e in <DaybreakElevation>[light, dark]) {
        final layer = levelOf(e, level)[index];
        expect(
          layer.blurRadius,
          closeTo(0.866 * (cssBlur - 1), 0.05),
          reason: '$level layer $index (css blur $cssBlur)',
        );
        expect(layer.offset.dy, dy, reason: '$level layer $index dy');
      }
    }
    // The two named conversions, spelled out: css 4 -> 2.598, css 24 -> 19.918.
    expect(light.level2[0].blurRadius, closeTo(2.598, 0.001));
    expect(light.level2[1].blurRadius, closeTo(19.918, 0.001));
  });

  test('level0 is flat and every other level has at least two layers', () {
    for (final e in <DaybreakElevation>[light, dark]) {
      expect(e.level0, isEmpty);
      expect(e.level1.length, greaterThanOrEqualTo(2));
      expect(e.level2.length, greaterThanOrEqualTo(2));
      expect(e.level3.length, greaterThanOrEqualTo(2));
    }
  });

  test('shadows are WARM, never black', () {
    // A neutral shadow on a #FFF9F2 ground reads as grey dirt and drains the
    // warmth the whole emotional brief rests on.
    for (final level in <List<BoxShadow>>[
      light.level1,
      light.level2,
      light.level3,
    ]) {
      for (final layer in level) {
        expect(layer.color.withValues(alpha: 1), Primitives.clay42);
      }
    }
    for (final level in <List<BoxShadow>>[
      dark.level1,
      dark.level2,
      dark.level3,
    ]) {
      for (final layer in level) {
        expect(layer.color.withValues(alpha: 1), Primitives.plum01);
      }
    }
    for (final e in <DaybreakElevation>[light, dark]) {
      for (final level in <List<BoxShadow>>[
        e.level0,
        e.level1,
        e.level2,
        e.level3,
        e.glow,
      ]) {
        for (final layer in level) {
          expect(
            layer.color.withValues(alpha: 1),
            isNot(const Color(0xFF000000)),
          );
        }
      }
    }
  });

  test('glow is the primary at low alpha, one element per screen', () {
    for (final layer in light.glow) {
      expect(layer.color.withValues(alpha: 1), Primitives.coral64);
      expect(layer.color.a, lessThan(0.35));
    }
    for (final layer in dark.glow) {
      expect(layer.color.withValues(alpha: 1), Primitives.coral66);
      expect(layer.color.a, lessThan(0.35));
    }
  });

  test(
    'every offset is vertical only, so no level acquires a physical side',
    () {
      for (final e in <DaybreakElevation>[light, dark]) {
        for (final level in <List<BoxShadow>>[
          e.level1,
          e.level2,
          e.level3,
          e.glow,
        ]) {
          for (final layer in level) {
            expect(layer.offset.dx, 0);
          }
        }
      }
    },
  );

  test('high contrast does not change elevation', () {
    expect(daybreakElevationFor(Brightness.light), light);
    expect(daybreakElevationFor(Brightness.dark), dark);
  });
}
