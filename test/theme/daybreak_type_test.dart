// Typography, where two conversions are silently wrong if you paste the CSS.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_type.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

/// The seven authored roles, and the M3 slot each is read back through.
const Map<String, TextStyle? Function(TextTheme)> roleSlots =
    <String, TextStyle? Function(TextTheme)>{
      'display': _displayLarge,
      'title': _headlineLarge,
      'heading': _titleLarge,
      'body-lg': _bodyLarge,
      'body': _bodyMedium,
      'label': _labelMedium,
      'caption': _labelSmall,
    };

TextStyle? _displayLarge(TextTheme t) => t.displayLarge;
TextStyle? _headlineLarge(TextTheme t) => t.headlineLarge;
TextStyle? _titleLarge(TextTheme t) => t.titleLarge;
TextStyle? _bodyLarge(TextTheme t) => t.bodyLarge;
TextStyle? _bodyMedium(TextTheme t) => t.bodyMedium;
TextStyle? _labelMedium(TextTheme t) => t.labelMedium;
TextStyle? _labelSmall(TextTheme t) => t.labelSmall;

const Map<String, double> declaredSizes = <String, double>{
  'display': 72,
  'title': 34,
  'heading': 24,
  'body-lg': 20,
  'body': 17,
  'label': 15,
  'caption': 14,
};

void main() {
  final latin = daybreakTextTheme(
    DaybreakScript.latin,
    colors: lightDaybreakColors,
  );
  final perso = daybreakTextTheme(
    DaybreakScript.perso,
    colors: lightDaybreakColors,
  );

  List<TextStyle?> allSlots(TextTheme t) => <TextStyle?>[
    t.displayLarge,
    t.displayMedium,
    t.displaySmall,
    t.headlineLarge,
    t.headlineMedium,
    t.headlineSmall,
    t.titleLarge,
    t.titleMedium,
    t.titleSmall,
    t.bodyLarge,
    t.bodyMedium,
    t.bodySmall,
    t.labelLarge,
    t.labelMedium,
    t.labelSmall,
  ];

  test('all FIFTEEN M3 slots are assigned, and none is below 14', () {
    // An unassigned labelSmall defaults to 11px, and a Chip or NavigationBar
    // will smuggle it onto a screen that never declared it.
    for (final (label, theme) in <(String, TextTheme)>[
      ('latin', latin),
      ('perso', perso),
    ]) {
      final slots = allSlots(theme);
      expect(slots, hasLength(15), reason: label);
      for (var i = 0; i < slots.length; i++) {
        expect(slots[i], isNotNull, reason: '$label slot $i');
        expect(slots[i]!.fontSize, isNotNull, reason: '$label slot $i');
        expect(
          slots[i]!.fontSize,
          greaterThanOrEqualTo(14),
          reason: '$label slot $i is ${slots[i]!.fontSize}px',
        );
      }
    }
  });

  test('the seven roles carry their declared sizes', () {
    for (final MapEntry(key: role, value: slot) in roleSlots.entries) {
      expect(slot(latin)!.fontSize, declaredSizes[role], reason: role);
    }
  });

  test('tracking is LOGICAL PIXELS, not em', () {
    // -0.045em at 72 is -3.24, not -0.045. The em value passes any "is it
    // negative" check and is 72x wrong; this is the only case that catches it.
    expect(latin.displayLarge!.letterSpacing, closeTo(-3.24, 1e-9));
    expect(latin.headlineLarge!.letterSpacing, closeTo(-1.02, 1e-9));
    expect(latin.titleLarge!.letterSpacing, closeTo(-0.48, 1e-9));
    expect(latin.bodyLarge!.letterSpacing, closeTo(-0.20, 1e-9));
    expect(latin.bodyMedium!.letterSpacing, closeTo(-0.17, 1e-9));
    expect(latin.labelMedium!.letterSpacing, closeTo(0.15, 1e-9));
    expect(latin.labelSmall!.letterSpacing, closeTo(0.28, 1e-9));
  });

  test('the Persian transform lifts every height by 0.14, except display', () {
    for (final MapEntry(key: role, value: slot) in roleSlots.entries) {
      if (role == 'display') continue;
      expect(
        slot(perso)!.height,
        closeTo(slot(latin)!.height! + 0.14, 1e-9),
        reason: role,
      );
    }
    // Display is the one hand-set exception: 1.05 + 0.14 is loose for a
    // single-line numeral, and Vazirmatn's digits carry more ink at the same
    // point size, so it steps down to 58 / 1.15.
    expect(perso.displayLarge!.fontSize, 58);
    expect(perso.displayLarge!.height, closeTo(1.15, 1e-9));
  });

  test('every Persian slot has tracking ZERO', () {
    // Perso-Arabic is a joined script: positive tracking snaps the joins and
    // negative tracking collides diacritics. A clamp applied only to display
    // fails here.
    for (final slot in allSlots(perso)) {
      expect(slot!.letterSpacing, 0);
    }
  });

  test('the boldText ladder is 400 -> 600 -> 700 -> 800 -> 900, clamped', () {
    expect(boldTextStep(FontWeight.w400), FontWeight.w600);
    expect(boldTextStep(FontWeight.w600), FontWeight.w700);
    expect(boldTextStep(FontWeight.w700), FontWeight.w800);
    expect(boldTextStep(FontWeight.w800), FontWeight.w900);
    expect(boldTextStep(FontWeight.w900), FontWeight.w900);
  });

  test('boldText reaches the theme, in one transform', () {
    final bold = daybreakTextTheme(
      DaybreakScript.latin,
      colors: lightDaybreakColors,
      boldText: true,
    );
    expect(latin.bodyMedium!.fontWeight, FontWeight.w400);
    expect(bold.bodyMedium!.fontWeight, FontWeight.w600);
    expect(latin.displayLarge!.fontWeight, FontWeight.w800);
    expect(bold.displayLarge!.fontWeight, FontWeight.w900);
  });

  test('every slot carries a matching wght fontVariation', () {
    // fontWeight alone does NOT move a variable face declared as one asset.
    // Nunito's default instance is wght 200, so without this every heading
    // renders ExtraLight and a golden baselined against that passes forever.
    for (final theme in <TextTheme>[latin, perso]) {
      for (final slot in allSlots(theme)) {
        expect(
          slot!.fontVariations,
          contains(
            FontVariation('wght', slot.fontWeight!.value.toDouble()),
          ),
        );
      }
    }
  });

  test('the app-specific roles carry their font features', () {
    final typography = daybreakTypography(
      DaybreakScript.latin,
      colors: lightDaybreakColors,
    );
    // 9 -> 10 must not shift the number the user reads every morning.
    expect(
      typography.doseNumeral.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(
      typography.dayStateChip.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    // The overline is caption at weight 800 with POSITIVE tracking, en/de only.
    expect(typography.overline.fontWeight, FontWeight.w800);
    expect(typography.overline.letterSpacing, greaterThan(0));

    final perso = daybreakTypography(
      DaybreakScript.perso,
      colors: lightDaybreakColors,
    );
    expect(perso.overline.letterSpacing, 0);
  });

  test(
    'the family cascade ends in the OTHER bundled face, never a system one',
    () {
      expect(fontFamilyFor(DaybreakScript.latin), 'Nunito');
      expect(fontFamilyFallbackFor(DaybreakScript.latin), <String>[
        'Vazirmatn',
      ]);
      expect(fontFamilyFor(DaybreakScript.perso), 'Vazirmatn');
      expect(fontFamilyFallbackFor(DaybreakScript.perso), <String>['Nunito']);
    },
  );
}
