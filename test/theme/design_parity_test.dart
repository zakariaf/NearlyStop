// Parity against the EXTERNAL design source, read at test time.
//
// `daybreak-visual-parity`'s top tier is "token values match **exactly**", and
// for a token epic that is the whole of parity — there is no screen to compare
// yet. So rather than transcribing `design/daybreak-system.html` into a second
// table that would drift, this file PARSES it and diffs every custom property
// against the Dart slot it feeds.
//
// If the reference is wrong, the HTML changes first and the PNGs are
// regenerated in their own commit. The implementation is never where a design
// decision gets made, and this test is what makes that structural rather than
// a habit.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/daybreak_type.dart';
import 'package:nearlystop/theme/gradients.dart';

/// The custom properties declared in one CSS block of the design source.
Map<String, String> _tokensIn(String css) {
  final tokens = <String, String>{};
  for (final match in RegExp(
    r'(--[a-z0-9-]+)\s*:\s*([^;]+);',
  ).allMatches(css)) {
    tokens[match.group(1)!] = match.group(2)!.trim();
  }
  return tokens;
}

Color _hex(String value) {
  final digits = value.replaceAll('#', '').trim();
  // CSS writes 8-digit hex as #RRGGBBAA; Dart wants 0xAARRGGBB. Needed since
  // `--border-current-block` is `primary` at 40% — a translucent token, which
  // is what lets the current block's outline composite over its own tint.
  if (digits.length == 8) {
    return Color(
      int.parse(digits.substring(6) + digits.substring(0, 6), radix: 16),
    );
  }
  return Color(int.parse('FF$digits', radix: 16));
}

double _px(String value) => double.parse(value.replaceAll(RegExp('[a-z]'), ''));

void main() {
  final source = File('design/daybreak-system.html').readAsStringSync();

  // The dark theme overrides ONLY the properties it restates, so the dark map
  // is the light map with the override block applied — exactly how the CSS
  // cascade resolves it, and exactly how `darkDaybreakColors` is authored.
  final rootBlock = source.substring(
    source.indexOf(':root{'),
    source.indexOf('}', source.indexOf(':root{')),
  );
  final darkStart = source.indexOf('data-theme="dark"');
  final darkBlock = source.substring(
    source.indexOf('{', darkStart),
    source.indexOf('}', darkStart),
  );
  final light = _tokensIn(rootBlock);
  final dark = <String, String>{...light, ..._tokensIn(darkBlock)};

  test('the design source parsed, so a silent zero-row run is impossible', () {
    expect(light, isNotEmpty);
    expect(light.length, greaterThan(40));
    expect(dark['--bg'], isNot(light['--bg']));
  });

  /// Every colour slot, by the CSS property that declares it.
  const slots = <String, Color Function(DaybreakColors)>{
    '--bg': _bg,
    '--surface': _surface,
    '--surface-raised': _surfaceRaised,
    '--surface-sunken': _surfaceSunken,
    '--ink': _ink,
    '--ink-muted': _inkMuted,
    '--ink-faint': _inkFaint,
    '--primary': _primary,
    '--primary-deep': _primaryDeep,
    '--secondary': _secondary,
    '--on-primary': _onPrimary,
    '--success': _success,
    '--success-fill': _successFill,
    '--warning': _warning,
    '--warning-fill': _warningFill,
    '--danger': _danger,
    '--danger-fill': _dangerFill,
    '--tint-primary': _tintPrimary,
    '--tint-success': _tintSuccess,
    '--tint-warning': _tintWarning,
    '--tint-danger': _tintDanger,
    '--border': _border,
    '--border-strong': _borderStrong,
    '--border-current-block': _borderCurrentBlock,
    '--state-taken': _stateTaken,
    '--state-missed': _stateMissed,
    '--state-today': _stateToday,
    '--state-newdose': _stateNewDose,
  };

  for (final (label, tokens, colors)
      in <(String, Map<String, String>, DaybreakColors)>[
        ('light', light, lightDaybreakColors),
        ('dark', dark, darkDaybreakColors),
      ]) {
    group('colour slots match the design source — $label', () {
      for (final MapEntry(key: property, value: read) in slots.entries) {
        test(property, () {
          expect(
            tokens[property],
            isNotNull,
            reason: '$property is not declared',
          );
          expect(
            read(colors),
            _hex(tokens[property]!),
            reason: '$property is ${tokens[property]} in the design source',
          );
        });
      }
    });
  }

  test('the sunrise gradient stops and angle match', () {
    for (final (label, tokens, gradient)
        in <(String, Map<String, String>, LinearGradient)>[
          ('light', light, DaybreakGradients.sunriseLight),
          ('dark', dark, DaybreakGradients.sunriseDark),
        ]) {
      final css = tokens['--grad-sunrise']!;
      expect(css, contains('138deg'), reason: label);
      final stops = RegExp('#([0-9A-Fa-f]{6}) ([0-9]+)%').allMatches(css);
      expect(stops, hasLength(4), reason: label);
      var index = 0;
      for (final stop in stops) {
        expect(
          gradient.colors[index],
          _hex(stop.group(1)!),
          reason: '$label stop $index',
        );
        expect(
          gradient.stops![index],
          closeTo(int.parse(stop.group(2)!) / 100, 1e-9),
          reason: '$label stop $index position',
        );
        index++;
      }
    }
  });

  test('the wash gradient endpoints match', () {
    for (final (label, tokens, gradient)
        in <(String, Map<String, String>, LinearGradient)>[
          ('light', light, DaybreakGradients.washLight),
          ('dark', dark, DaybreakGradients.washDark),
        ]) {
      final css = tokens['--grad-wash']!;
      final stops = RegExp('#([0-9A-Fa-f]{6})').allMatches(css).toList();
      expect(stops, hasLength(2), reason: label);
      expect(gradient.colors[0], _hex(stops[0].group(1)!), reason: label);
      expect(gradient.colors[1], _hex(stops[1].group(1)!), reason: label);
    }
  });

  test('the overlay scrim matches, alpha included', () {
    for (final (label, tokens, colors)
        in <(String, Map<String, String>, DaybreakColors)>[
          ('light', light, lightDaybreakColors),
          ('dark', dark, darkDaybreakColors),
        ]) {
      final css = RegExp(
        r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\)',
      ).firstMatch(tokens['--overlay']!)!;
      expect(
        colors.overlay.r * 255,
        closeTo(int.parse(css.group(1)!), 0.51),
        reason: '$label red',
      );
      expect(
        colors.overlay.g * 255,
        closeTo(int.parse(css.group(2)!), 0.51),
        reason: '$label green',
      );
      expect(
        colors.overlay.b * 255,
        closeTo(int.parse(css.group(3)!), 0.51),
        reason: '$label blue',
      );
      // 8-bit alpha cannot express every CSS decimal exactly: .55 is 140/255.
      expect(
        colors.overlay.a,
        closeTo(double.parse(css.group(4)!), 0.004),
        reason: '$label alpha',
      );
    }
  });

  test(
    'every shadow layer matches the design source, blur conversion and all',
    () {
      // CSS blur b maps to Flutter blurRadius r = 0.866 * (b - 1). This is
      // where the transcription in daybreak_elevation.dart is checked against
      // the source it was transcribed FROM, rather than against itself.
      //
      // `0 1px 2px rgba(140,84,56,.07)` — the x offset is a bare `0` and the
      // alpha has no leading digit.
      final layer = RegExp(
        r'(\d+)(?:px)?\s+(\d+)px\s+(\d+)px\s+'
        r'rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)',
      );
      for (final (label, tokens, elevation)
          in <(String, Map<String, String>, DaybreakElevation)>[
            ('light', light, lightDaybreakElevation),
            ('dark', dark, darkDaybreakElevation),
          ]) {
        for (final (property, level) in <(String, List<BoxShadow>)>[
          ('--shadow-1', elevation.level1),
          ('--shadow-2', elevation.level2),
          ('--shadow-3', elevation.level3),
          ('--shadow-glow', elevation.glow),
        ]) {
          final declared = layer.allMatches(tokens[property]!).toList();
          expect(
            declared,
            hasLength(level.length),
            reason: '$label $property layer count',
          );
          for (var i = 0; i < declared.length; i++) {
            final css = declared[i];
            final dy = double.parse(css.group(2)!);
            final blur = double.parse(css.group(3)!);
            expect(level[i].offset.dy, dy, reason: '$label $property $i dy');
            expect(
              level[i].blurRadius,
              closeTo(0.866 * (blur - 1), 0.05),
              reason: '$label $property $i blur (css ${blur.toInt()}px)',
            );
            expect(
              level[i].color.r * 255,
              closeTo(int.parse(css.group(4)!), 0.51),
              reason: '$label $property $i red',
            );
            expect(
              level[i].color.a,
              closeTo(double.parse(css.group(7)!), 0.004),
              reason: '$label $property $i alpha',
            );
          }
        }
        expect(tokens['--shadow-0'], 'none', reason: label);
        expect(elevation.level0, isEmpty, reason: label);
      }
    },
  );

  test('the radii match', () {
    expect(daybreakShapes.radiusXs, _px(light['--r-xs']!));
    expect(daybreakShapes.radiusSm, _px(light['--r-sm']!));
    expect(daybreakShapes.radiusMd, _px(light['--r-md']!));
    expect(daybreakShapes.radiusLg, _px(light['--r-lg']!));
    expect(daybreakShapes.radiusXl, _px(light['--r-xl']!));
    expect(daybreakShapes.radiusPill, _px(light['--r-pill']!));
  });

  test('the spacing ramp matches', () {
    final ramp = <double>[
      daybreakShapes.s1,
      daybreakShapes.s2,
      daybreakShapes.s3,
      daybreakShapes.s4,
      daybreakShapes.s5,
      daybreakShapes.s6,
      daybreakShapes.s7,
      daybreakShapes.s8,
      daybreakShapes.s9,
    ];
    for (var step = 1; step <= 9; step++) {
      expect(ramp[step - 1], _px(light['--s-$step']!), reason: '--s-$step');
    }
  });

  test('the type scale matches', () {
    final text = daybreakTextTheme(
      DaybreakScript.latin,
      colors: lightDaybreakColors,
    );
    expect(text.displayLarge!.fontSize, _px(light['--fs-display']!));
    expect(text.headlineLarge!.fontSize, _px(light['--fs-title']!));
    expect(text.titleLarge!.fontSize, _px(light['--fs-heading']!));
    expect(text.bodyLarge!.fontSize, _px(light['--fs-body-lg']!));
    expect(text.bodyMedium!.fontSize, _px(light['--fs-body']!));
    expect(text.labelMedium!.fontSize, _px(light['--fs-label']!));
    expect(text.labelSmall!.fontSize, _px(light['--fs-caption']!));
    expect(text.displayLarge!.height, _px(light['--lh-tight']!));
  });

  test("the Persian line-height bump is the design source's own number", () {
    final latin = daybreakTextTheme(
      DaybreakScript.latin,
      colors: lightDaybreakColors,
    );
    final perso = daybreakTextTheme(
      DaybreakScript.perso,
      colors: lightDaybreakColors,
    );
    final bump = double.parse(light['--lh-fa-bump']!);
    expect(bump, closeTo(0.14, 1e-9));
    expect(
      perso.bodyMedium!.height,
      closeTo(latin.bodyMedium!.height! + bump, 1e-9),
    );
  });

  test('the durations and easings match', () {
    expect(daybreakMotion.fast.inMilliseconds, _px(light['--dur-fast']!));
    expect(daybreakMotion.base.inMilliseconds, _px(light['--dur-base']!));
    expect(daybreakMotion.slow.inMilliseconds, _px(light['--dur-slow']!));
    expect(light['--ease-out'], 'cubic-bezier(.22,.85,.34,1)');
    expect(daybreakMotion.easeOut, const Cubic(0.22, 0.85, 0.34, 1));
    expect(light['--ease-in-out'], 'cubic-bezier(.65,0,.35,1)');
    expect(daybreakMotion.easeInOut, const Cubic(0.65, 0, 0.35, 1));
  });

  test('the families the CSS names first are the two we bundle', () {
    expect(light['--font-latin'], startsWith('"Nunito"'));
    expect(light['--font-fa'], startsWith('"Vazirmatn"'));
    expect(fontFamilyFor(DaybreakScript.latin), 'Nunito');
    expect(fontFamilyFor(DaybreakScript.perso), 'Vazirmatn');
  });
}

Color _bg(DaybreakColors c) => c.bg;
Color _surface(DaybreakColors c) => c.surface;
Color _surfaceRaised(DaybreakColors c) => c.surfaceRaised;
Color _surfaceSunken(DaybreakColors c) => c.surfaceSunken;
Color _ink(DaybreakColors c) => c.ink;
Color _inkMuted(DaybreakColors c) => c.inkMuted;
Color _inkFaint(DaybreakColors c) => c.inkFaint;
Color _primary(DaybreakColors c) => c.primary;
Color _primaryDeep(DaybreakColors c) => c.primaryDeep;
Color _secondary(DaybreakColors c) => c.secondary;
Color _onPrimary(DaybreakColors c) => c.onPrimary;
Color _success(DaybreakColors c) => c.success;
Color _successFill(DaybreakColors c) => c.successFill;
Color _warning(DaybreakColors c) => c.warning;
Color _warningFill(DaybreakColors c) => c.warningFill;
Color _danger(DaybreakColors c) => c.danger;
Color _dangerFill(DaybreakColors c) => c.dangerFill;
Color _tintPrimary(DaybreakColors c) => c.tintPrimary;
Color _tintSuccess(DaybreakColors c) => c.tintSuccess;
Color _tintWarning(DaybreakColors c) => c.tintWarning;
Color _tintDanger(DaybreakColors c) => c.tintDanger;
Color _border(DaybreakColors c) => c.border;
Color _borderStrong(DaybreakColors c) => c.borderStrong;
Color _borderCurrentBlock(DaybreakColors c) => c.borderCurrentBlock;
Color _stateTaken(DaybreakColors c) => c.stateTaken;
Color _stateMissed(DaybreakColors c) => c.stateMissed;
Color _stateToday(DaybreakColors c) => c.stateToday;
Color _stateNewDose(DaybreakColors c) => c.stateNewDose;
