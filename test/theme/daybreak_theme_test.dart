// A ThemeData is f(args) -> data, so this is a value test with no pump.
//
// The table below is eight cases — {light, dark} x {latin, perso} x
// {default, high contrast} — so a new extension cannot be attached to one
// ThemeData and forgotten in seven.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

import '../support/contrast.dart';

const List<(Brightness, DaybreakScript, bool)> matrix =
    <(Brightness, DaybreakScript, bool)>[
      (Brightness.light, DaybreakScript.latin, false),
      (Brightness.light, DaybreakScript.latin, true),
      (Brightness.light, DaybreakScript.perso, false),
      (Brightness.light, DaybreakScript.perso, true),
      (Brightness.dark, DaybreakScript.latin, false),
      (Brightness.dark, DaybreakScript.latin, true),
      (Brightness.dark, DaybreakScript.perso, false),
      (Brightness.dark, DaybreakScript.perso, true),
    ];

void main() {
  test('all five extensions are attached to every ThemeData it can return', () {
    for (final (brightness, script, highContrast) in matrix) {
      final theme = buildDaybreakTheme(
        brightness,
        script,
        highContrast: highContrast,
      );
      final label = '$brightness/$script/hc=$highContrast';
      expect(theme.extension<DaybreakColors>(), isNotNull, reason: label);
      expect(theme.extension<DaybreakShapes>(), isNotNull, reason: label);
      expect(theme.extension<DaybreakElevation>(), isNotNull, reason: label);
      expect(theme.extension<DaybreakMotion>(), isNotNull, reason: label);
      expect(theme.extension<DaybreakTypography>(), isNotNull, reason: label);
      expect(theme.useMaterial3, isTrue, reason: label);
      expect(theme.brightness, brightness, reason: label);
      expect(
        theme.scaffoldBackgroundColor,
        theme.extension<DaybreakColors>()!.bg,
        reason: label,
      );
    }
  });

  test('the script argument REACHES the text theme', () {
    // This is the entire mechanism by which EPIC-03's Persian transform gets to
    // a screen, so a builder that quietly ignores it fails here and nowhere
    // else in the suite.
    final latin = buildDaybreakTheme(Brightness.light, DaybreakScript.latin);
    final perso = buildDaybreakTheme(Brightness.light, DaybreakScript.perso);

    // ThemeData folds fontFamily/fontFamilyFallback into every TextTheme slot.
    expect(latin.textTheme.bodyMedium!.fontFamily, 'Nunito');
    expect(latin.textTheme.bodyMedium!.fontFamilyFallback, <String>[
      'Vazirmatn',
    ]);
    expect(perso.textTheme.bodyMedium!.fontFamily, 'Vazirmatn');
    expect(perso.textTheme.bodyMedium!.fontFamilyFallback, <String>['Nunito']);
    expect(perso.textTheme.displayLarge!.fontSize, 58);
    expect(latin.textTheme.displayLarge!.fontSize, 72);
    expect(perso.textTheme.bodyMedium!.letterSpacing, 0);
    expect(latin.textTheme.bodyMedium!.letterSpacing, isNot(0));
  });

  test('the highContrast argument REACHES the palette', () {
    // A `true` that silently falls through to the default palette must be red,
    // not invisible.
    for (final brightness in Brightness.values) {
      final base = buildDaybreakTheme(
        brightness,
        DaybreakScript.latin,
      ).extension<DaybreakColors>()!;
      final hc = buildDaybreakTheme(
        brightness,
        DaybreakScript.latin,
        highContrast: true,
      ).extension<DaybreakColors>()!;
      expect(hc, isNot(base), reason: '$brightness');
      expect(hc.border, hc.borderStrong, reason: '$brightness');
      expect(hc.inkMuted, hc.ink, reason: '$brightness');
      // An override OVER the base: an untouched slot is identical.
      expect(hc.sunrise, base.sunrise, reason: '$brightness');
      expect(hc.wash, base.wash, reason: '$brightness');
    }
  });

  test('high contrast changes LUMINANCE, never the emotional register', () {
    for (final brightness in Brightness.values) {
      final base = buildDaybreakTheme(
        brightness,
        DaybreakScript.latin,
      ).extension<DaybreakColors>()!;
      final hc = buildDaybreakTheme(
        brightness,
        DaybreakScript.latin,
        highContrast: true,
      ).extension<DaybreakColors>()!;

      // Still warm taupe, still not danger.
      expect(hc.stateMissed, isNot(hc.danger), reason: '$brightness');
      expect(
        hueDegrees(hc.stateMissed),
        closeTo(hueDegrees(base.stateMissed), 10),
        reason: '$brightness hue moved',
      );
      // Further from the surface than the base was — darker on a light ground,
      // lighter on a dark one.
      expect(
        contrastRatio(hc.stateMissed, hc.surface),
        greaterThan(contrastRatio(base.stateMissed, base.surface)),
        reason: '$brightness',
      );
    }
  });

  test('the high-contrast tints are solid fills, not washes', () {
    // A 6% wash over cream is invisible to the eye this mode exists for, and it
    // is the background half of every pair it participates in.
    for (final brightness in Brightness.values) {
      final hc = buildDaybreakTheme(
        brightness,
        DaybreakScript.latin,
        highContrast: true,
      ).extension<DaybreakColors>()!;
      for (final tint in <Color>[
        hc.tintPrimary,
        hc.tintSuccess,
        hc.tintWarning,
        hc.tintDanger,
      ]) {
        expect(tint.a, 1.0, reason: '$brightness tint is translucent');
        expect(tint, isNot(hc.surface), reason: '$brightness');
      }
    }
  });

  test('dark high contrast is authored, not pushed to black', () {
    final hc = buildDaybreakTheme(
      Brightness.dark,
      DaybreakScript.latin,
      highContrast: true,
    ).extension<DaybreakColors>()!;
    expect(
      hc.bg,
      buildDaybreakTheme(
        Brightness.dark,
        DaybreakScript.latin,
      ).extension<DaybreakColors>()!.bg,
    );
    expect(hc.bg, isNot(const Color(0xFF000000)));
  });

  test('every button holds the 48dp floor and has NO fixed height', () {
    // At 200% text scale the label must grow the button, not be clipped by it.
    final theme = buildDaybreakTheme(Brightness.light, DaybreakScript.latin);
    final styles = <String, ButtonStyle?>{
      'filled': theme.filledButtonTheme.style,
      'outlined': theme.outlinedButtonTheme.style,
      'text': theme.textButtonTheme.style,
    };
    for (final MapEntry(key: name, value: style) in styles.entries) {
      expect(style, isNotNull, reason: name);
      expect(
        style!.minimumSize!.resolve(<WidgetState>{})!.height,
        greaterThanOrEqualTo(48),
        reason: name,
      );
      expect(style.fixedSize?.resolve(<WidgetState>{}), isNull, reason: name);
    }
    // The tab bar deliberately states NO height: Flutter's default (80)
    // already clears the floor and leaves room a 15px label needs at the 1.3x
    // NavigationBar clamps to, and the German destination names are the app's
    // longest strings. A pinned height is the same clipping risk the buttons
    // refuse two assertions above.
    expect(theme.navigationBarTheme.height, isNull);
  });

  test('EVERY component-theme style carries the bundled family', () {
    // ThemeData folds fontFamily into `textTheme` ONLY. A style handed straight
    // to a component theme keeps a null family and renders in the platform
    // default face — in fa/ckb a system Perso-Arabic face or tofu, on every
    // screen, silently breaking the bundled-and-licensed promise.
    for (final (script, family, fallback) in <(DaybreakScript, String, String)>[
      (DaybreakScript.latin, 'Nunito', 'Vazirmatn'),
      (DaybreakScript.perso, 'Vazirmatn', 'Nunito'),
    ]) {
      final theme = buildDaybreakTheme(Brightness.light, script);
      final styles = <String, TextStyle?>{
        'filled': theme.filledButtonTheme.style!.textStyle!.resolve(
          <WidgetState>{},
        ),
        'outlined': theme.outlinedButtonTheme.style!.textStyle!.resolve(
          <WidgetState>{},
        ),
        'text': theme.textButtonTheme.style!.textStyle!.resolve(
          <WidgetState>{},
        ),
        'navigationBar': theme.navigationBarTheme.labelTextStyle!.resolve(
          <WidgetState>{},
        ),
        'inputLabel': theme.inputDecorationTheme.labelStyle,
        'doseNumeral': theme.extension<DaybreakTypography>()!.doseNumeral,
        'overline': theme.extension<DaybreakTypography>()!.overline,
        'dayStateChip': theme.extension<DaybreakTypography>()!.dayStateChip,
      };
      for (final MapEntry(key: name, value: style) in styles.entries) {
        expect(style?.fontFamily, family, reason: '$script $name family');
        expect(
          style?.fontFamilyFallback,
          <String>[fallback],
          reason: '$script $name fallback',
        );
      }
    }
  });

  test(
    'surfaceTint is STATED, so no coral wash reaches an elevated surface',
    () {
      for (final (brightness, script, highContrast) in matrix) {
        final theme = buildDaybreakTheme(
          brightness,
          script,
          highContrast: highContrast,
        );
        final colors = theme.extension<DaybreakColors>()!;
        expect(theme.colorScheme.surfaceTint, colors.surface);
        expect(
          theme.colorScheme.surfaceTint,
          isNot(theme.colorScheme.primary),
          reason: 'left unset it defaults to primary',
        );
      }
    },
  );

  test('boldText reaches the theme', () {
    final normal = buildDaybreakTheme(Brightness.light, DaybreakScript.latin);
    final bold = buildDaybreakTheme(
      Brightness.light,
      DaybreakScript.latin,
      boldText: true,
    );
    expect(normal.textTheme.bodyMedium!.fontWeight, FontWeight.w400);
    expect(bold.textTheme.bodyMedium!.fontWeight, FontWeight.w600);
  });

  test('lib/theme declares no day-state enum of its own', () {
    // DayState is EPIC-04's, in lib/core/day_state.dart, and has exactly four
    // members. A second one here would drift from the palette's switch.
    expect(
      Directory('lib/theme')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .where((s) => RegExp(r'enum\s+\w*[Dd]ay\w*State').hasMatch(s)),
      isEmpty,
    );
  });
}
