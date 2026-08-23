// The loop EPIC-02 left open.
//
// EPIC-02 shipped the entire Persian transform — height + 0.14, tracking
// clamped to 0, the display slot hand-set — behind a `DaybreakScript`
// argument, and then nothing decided which script to pass. Every build got
// Latin. These are the tests that make the Persian half reachable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';
import 'package:nearlystop/theme/daybreak_type.dart';

const _fa = Locale('fa');
const _en = Locale('en');
const _de = Locale('de');

void main() {
  group('scriptFor', () {
    test('the two Perso-Arabic locales, and everything else', () {
      expect(scriptFor(_fa), DaybreakScript.perso);
      expect(scriptFor(kurdishSorani), DaybreakScript.perso);
      expect(scriptFor(_en), DaybreakScript.latin);
      expect(scriptFor(_de), DaybreakScript.latin);
      // Unknown falls to Latin and never throws: an unsupported locale that
      // slipped past resolution must render something.
      expect(scriptFor(const Locale('ja')), DaybreakScript.latin);
    });

    test('it reads languageCode only', () {
      // Switching on the full tag is how `fa-AF` quietly gets the Latin scale.
      expect(scriptFor(const Locale('fa', 'AF')), DaybreakScript.perso);
      expect(
        scriptFor(
          const Locale.fromSubtags(
            languageCode: 'ckb',
            scriptCode: 'Arab',
            countryCode: 'IQ',
          ),
        ),
        DaybreakScript.perso,
      );
    });
  });

  group('the cascade ends in the other BUNDLED face', () {
    // Nunito has no Perso-Arabic coverage. Persian falling through it tofus, or
    // lands on whatever the OS happens to have — and the mockup's
    // `system-ui, Tahoma` tail was a browser affordance that does not carry
    // over to a bundled-fonts app.
    test('fa is Vazirmatn falling back to Nunito', () {
      final style = buildDaybreakTheme(
        Brightness.light,
        scriptFor(_fa),
      ).textTheme.bodyLarge!;

      expect(style.fontFamily, 'Vazirmatn');
      expect(style.fontFamilyFallback, <String>['Nunito']);
    });

    test('en is Nunito falling back to Vazirmatn', () {
      final style = buildDaybreakTheme(
        Brightness.light,
        scriptFor(_en),
      ).textTheme.bodyLarge!;

      expect(style.fontFamily, 'Nunito');
      expect(style.fontFamilyFallback, <String>['Vazirmatn']);
    });

    test('no slot in any locale falls to a system font', () {
      for (final locale in <Locale>[_en, _de, _fa, kurdishSorani]) {
        final text = buildDaybreakTheme(
          Brightness.light,
          scriptFor(locale),
        ).textTheme;

        for (final style in <TextStyle?>[
          text.displayLarge,
          text.displayMedium,
          text.displaySmall,
          text.headlineLarge,
          text.headlineMedium,
          text.headlineSmall,
          text.titleLarge,
          text.titleMedium,
          text.titleSmall,
          text.bodyLarge,
          text.bodyMedium,
          text.bodySmall,
          text.labelLarge,
          text.labelMedium,
          text.labelSmall,
        ]) {
          expect(
            style!.fontFamily,
            anyOf('Nunito', 'Vazirmatn'),
            reason: locale.toLanguageTag(),
          );
          expect(style.fontFamily, isNot('system-ui'));
          expect(style.fontFamily, isNot('Tahoma'));
          expect(style.fontFamilyFallback, isNotEmpty);
        }
      }
    });
  });

  test('per locale, the theme carries exactly the script transform', () {
    for (final locale in <Locale>[_en, _de, _fa, kurdishSorani]) {
      final script = scriptFor(locale);
      final fromTheme = buildDaybreakTheme(
        Brightness.light,
        script,
      ).textTheme.bodyLarge!;
      final fromType = daybreakTextTheme(
        script,
        colors: daybreakColorsFor(Brightness.light, highContrast: false),
      ).bodyLarge!;

      expect(
        fromTheme.height,
        closeTo(fromType.height!, 1e-9),
        reason: locale.toLanguageTag(),
      );
    }
  });

  test('the Persian lift is exactly +0.14 over the Latin value', () {
    final latin = buildDaybreakTheme(
      Brightness.light,
      DaybreakScript.latin,
    ).textTheme.bodyLarge!.height!;
    final perso = buildDaybreakTheme(
      Brightness.light,
      DaybreakScript.perso,
    ).textTheme.bodyLarge!.height!;

    expect(perso, closeTo(latin + 0.14, 1e-9));
    // German takes the Latin value exactly — it is a longer language, not a
    // different script.
    expect(
      buildDaybreakTheme(
        Brightness.light,
        scriptFor(_de),
      ).textTheme.bodyLarge!.height,
      closeTo(latin, 1e-9),
    );
  });

  test('ckb takes the identical transform as fa, slot for slot', () {
    // Same script, same joining, same ascenders and diacritics. It still needs
    // its own visual pass — vocabulary and word length differ — but not its own
    // type scale.
    final faTheme = buildDaybreakTheme(
      Brightness.light,
      scriptFor(_fa),
    ).textTheme;
    final ckbTheme = buildDaybreakTheme(
      Brightness.light,
      scriptFor(kurdishSorani),
    ).textTheme;

    expect(ckbTheme, faTheme);
  });

  test('Perso-Arabic is never letter-spaced', () {
    // Tracking on a joining script breaks the joins. EPIC-02 clamps it to zero
    // under `perso`; this is what holds that true through the locale seam.
    final text = buildDaybreakTheme(
      Brightness.light,
      scriptFor(_fa),
    ).textTheme;

    for (final style in <TextStyle?>[
      text.displayLarge,
      text.headlineLarge,
      text.titleLarge,
      text.bodyLarge,
      text.labelLarge,
      text.labelMedium,
      text.labelSmall,
    ]) {
      expect(style!.letterSpacing, 0, reason: '${style.fontSize}');
    }
  });
}
