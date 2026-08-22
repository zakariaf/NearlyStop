// The mechanics every ThemeExtension has to get right: copyWith touches one
// field, lerp moves every interpolable one, non-interpolables snap, and of()
// ASSERTS rather than handing back a palette nothing measured.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/daybreak_type.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';
import 'package:nearlystop/theme/primitives.dart';

void main() {
  final lightTypography = daybreakTypography(
    text: daybreakTextTheme(DaybreakScript.latin, colors: lightDaybreakColors),
    script: DaybreakScript.latin,
    colors: lightDaybreakColors,
  );
  final darkTypography = daybreakTypography(
    text: daybreakTextTheme(DaybreakScript.perso, colors: darkDaybreakColors),
    script: DaybreakScript.perso,
    colors: darkDaybreakColors,
  );

  group('identity endpoints', () {
    // A lerp that ignores `t` passes nothing else in this file.
    test('DaybreakColors', () {
      expect(
        lightDaybreakColors.lerp(darkDaybreakColors, 0),
        lightDaybreakColors,
      );
      expect(
        lightDaybreakColors.lerp(darkDaybreakColors, 1),
        darkDaybreakColors,
      );
      expect(lightDaybreakColors.lerp(null, 0.5), lightDaybreakColors);
    });

    test('DaybreakShapes', () {
      final other = daybreakShapes.copyWith(radiusLg: 40);
      expect(daybreakShapes.lerp(other, 0), daybreakShapes);
      expect(daybreakShapes.lerp(other, 1), other);
    });

    test('DaybreakElevation', () {
      expect(
        lightDaybreakElevation.lerp(darkDaybreakElevation, 0),
        lightDaybreakElevation,
      );
      expect(
        lightDaybreakElevation.lerp(darkDaybreakElevation, 1),
        darkDaybreakElevation,
      );
    });

    test('DaybreakMotion', () {
      final other = daybreakMotion.copyWith(base: const Duration(seconds: 1));
      expect(daybreakMotion.lerp(other, 0), daybreakMotion);
      expect(daybreakMotion.lerp(other, 1), other);
    });

    test('DaybreakTypography', () {
      expect(lightTypography.lerp(darkTypography, 0), lightTypography);
      expect(lightTypography.lerp(darkTypography, 1), darkTypography);
    });
  });

  test('copyWith changes one field and leaves every other one alone', () {
    const replacement = Primitives.clay11;
    final copy = lightDaybreakColors.copyWith(ink: replacement);
    expect(copy.ink, replacement);
    // Enumerated, not spot-checked: a field missing from copyWith would
    // silently reset on every call.
    expect(copy.bg, lightDaybreakColors.bg);
    expect(copy.surface, lightDaybreakColors.surface);
    expect(copy.surfaceRaised, lightDaybreakColors.surfaceRaised);
    expect(copy.surfaceSunken, lightDaybreakColors.surfaceSunken);
    expect(copy.inkMuted, lightDaybreakColors.inkMuted);
    expect(copy.inkFaint, lightDaybreakColors.inkFaint);
    expect(copy.primary, lightDaybreakColors.primary);
    expect(copy.primaryDeep, lightDaybreakColors.primaryDeep);
    expect(copy.secondary, lightDaybreakColors.secondary);
    expect(copy.onPrimary, lightDaybreakColors.onPrimary);
    expect(copy.success, lightDaybreakColors.success);
    expect(copy.successFill, lightDaybreakColors.successFill);
    expect(copy.warning, lightDaybreakColors.warning);
    expect(copy.warningFill, lightDaybreakColors.warningFill);
    expect(copy.danger, lightDaybreakColors.danger);
    expect(copy.dangerFill, lightDaybreakColors.dangerFill);
    expect(copy.tintPrimary, lightDaybreakColors.tintPrimary);
    expect(copy.tintSuccess, lightDaybreakColors.tintSuccess);
    expect(copy.tintWarning, lightDaybreakColors.tintWarning);
    expect(copy.tintDanger, lightDaybreakColors.tintDanger);
    expect(copy.border, lightDaybreakColors.border);
    expect(copy.borderStrong, lightDaybreakColors.borderStrong);
    expect(copy.overlay, lightDaybreakColors.overlay);
    expect(copy.stateTaken, lightDaybreakColors.stateTaken);
    expect(copy.stateMissed, lightDaybreakColors.stateMissed);
    expect(copy.stateToday, lightDaybreakColors.stateToday);
    expect(copy.stateNewDose, lightDaybreakColors.stateNewDose);
    expect(copy.sunrise, lightDaybreakColors.sunrise);
    expect(copy.wash, lightDaybreakColors.wash);
  });

  test('shadow lists go through BoxShadow.lerpList, and stay warm', () {
    final mid = lightDaybreakElevation.lerp(darkDaybreakElevation, 0.5);
    expect(mid.level3, hasLength(lightDaybreakElevation.level3.length));
    for (final shadow in mid.level3) {
      expect(shadow.color, isNot(const Color(0xFF000000)));
    }
  });

  test('gradients go through LinearGradient.lerp', () {
    final mid = lightDaybreakColors.lerp(darkDaybreakColors, 0.5);
    // The two sunrises declare different stop lists, so LinearGradient.lerp
    // returns their UNION — six stops, not four. That is the interpolation
    // doing its job; what matters is that the result is a real gradient
    // between the two and is neither endpoint.
    expect(mid.sunrise, isA<LinearGradient>());
    expect(mid.sunrise.colors.length, greaterThanOrEqualTo(4));
    expect(mid.sunrise, isNot(lightDaybreakColors.sunrise));
    expect(mid.sunrise, isNot(darkDaybreakColors.sunrise));
    expect(mid.wash.colors, hasLength(2));
    expect(mid.wash, isNot(lightDaybreakColors.wash));
  });

  test('a non-interpolable field snaps at the midpoint', () {
    final other = daybreakMotion.copyWith(easeOut: Curves.linear);
    expect(daybreakMotion.lerp(other, 0.49).easeOut, daybreakMotion.easeOut);
    expect(daybreakMotion.lerp(other, 0.51).easeOut, Curves.linear);
  });

  group('of(context) ASSERTS rather than falling back', () {
    // A fallback ships a palette no contrast row ever measured, and
    // loud-in-debug beats unreadable-on-a-bedside-table.
    Future<void> expectAssert(
      WidgetTester tester,
      void Function(BuildContext) read,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              read(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    }

    testWidgets('DaybreakColors', (tester) async {
      await expectAssert(tester, DaybreakColors.of);
    });
    testWidgets('DaybreakShapes', (tester) async {
      await expectAssert(tester, DaybreakShapes.of);
    });
    testWidgets('DaybreakElevation', (tester) async {
      await expectAssert(tester, DaybreakElevation.of);
    });
    testWidgets('DaybreakMotion', (tester) async {
      await expectAssert(tester, DaybreakMotion.of);
    });
    testWidgets('DaybreakTypography', (tester) async {
      await expectAssert(tester, DaybreakTypography.of);
    });
  });

  group('the declared ladders', () {
    test('spacing is 4 8 12 16 20 24 32 40 48', () {
      expect(
        <double>[
          daybreakShapes.s1,
          daybreakShapes.s2,
          daybreakShapes.s3,
          daybreakShapes.s4,
          daybreakShapes.s5,
          daybreakShapes.s6,
          daybreakShapes.s7,
          daybreakShapes.s8,
          daybreakShapes.s9,
        ],
        <double>[4, 8, 12, 16, 20, 24, 32, 40, 48],
      );
    });

    test('radii are 8 12 16 24 32 999', () {
      expect(
        <double>[
          daybreakShapes.radiusXs,
          daybreakShapes.radiusSm,
          daybreakShapes.radiusMd,
          daybreakShapes.radiusLg,
          daybreakShapes.radiusXl,
          daybreakShapes.radiusPill,
        ],
        <double>[8, 12, 16, 24, 32, 999],
      );
    });

    test('motion is 120 / 220 / 420 with the two named cubics', () {
      expect(daybreakMotion.fast, const Duration(milliseconds: 120));
      expect(daybreakMotion.base, const Duration(milliseconds: 220));
      expect(daybreakMotion.slow, const Duration(milliseconds: 420));
      expect(daybreakMotion.easeOut, const Cubic(0.22, 0.85, 0.34, 1));
      expect(daybreakMotion.easeInOut, const Cubic(0.65, 0, 0.35, 1));
    });
  });

  group('the silhouette factories map to the right radii', () {
    // The MAPPING is the thing that can be wrong, not the radius constant.
    test('cardShape is radiusLg (24)', () {
      final shape = daybreakShapes.cardShape();
      expect(shape.borderRadius, BorderRadius.circular(24));
    });

    test('heroShape is radiusXl (32)', () {
      expect(
        daybreakShapes.heroShape().borderRadius,
        BorderRadius.circular(32),
      );
    });

    test('sheetShape rounds only the top, at radiusXl', () {
      expect(
        daybreakShapes.sheetShape().borderRadius,
        const BorderRadius.vertical(top: Radius.circular(32)),
      );
    });

    test('pillShape is a stadium', () {
      expect(daybreakShapes.pillShape(), isA<StadiumBorder>());
    });
  });
}
