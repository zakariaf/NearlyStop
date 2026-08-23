// The purest TDD in the epic, and the one where a defect is a ten-fold dosing
// error.
//
// A Persian soft keyboard produces `1٫5`. A normalizer that folds digits but
// not separators turns that into `15`. On a dose field in a steroid-tapering
// app that is the single worst bug this codebase could contain, so it is
// asserted as an ABSENCE — negative assertions beside every positive one, and
// seeded fuzz aimed at the failure class rather than at examples.
import 'dart:math';
import 'dart:ui';

import 'package:characters/characters.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/unit_failure.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/number_formats.dart';

const _en = Locale('en');
const _de = Locale('de');
const _fa = Locale('fa');

Milligrams mg(int hundredths) => Milligrams.fromHundredths(hundredths);

Milligrams okOf(Result<Milligrams, UnitFailure> result) {
  expect(result, isA<Ok<Milligrams, UnitFailure>>(), reason: '$result');
  return (result as Ok<Milligrams, UnitFailure>).value;
}

F errOf<F extends UnitFailure>(Result<Milligrams, UnitFailure> result) {
  expect(result, isA<Err<Milligrams, UnitFailure>>(), reason: '$result');
  return (result as Err<Milligrams, UnitFailure>).failure as F;
}

void main() {
  group('formatDose', () {
    test('two fraction digits, because 0.25mg and 1.25mg are reachable', () {
      // Under `maximumFractionDigits: 1` these render '0.3' and '1.3'. Half a
      // 0.5mg tablet and half a 2.5mg tablet are both real doses this app
      // produces (CONTRACTS §10).
      expect(formatDose(mg(25), _en), '0.25');
      expect(formatDose(mg(125), _en), '1.25');
    });

    test('minimumFractionDigits 0, so a whole dose is not 9.00', () {
      expect(formatDose(mg(900), _en), '9');
      expect(formatDose(Milligrams.zero, _en), '0');
    });

    test('German takes its comma from intl, not a hand-rolled rule', () {
      expect(formatDose(mg(1050), _de), '10,5');
      expect(formatDose(mg(25), _de), '0,25');
    });

    test(
      'fa renders U+06Fx and U+066B — never ASCII, never the Arabic block',
      () {
        final rendered = formatDose(mg(125), _fa);

        expect(rendered, '۱٫۲۵');
        expect(rendered.characters.length, 4);
        for (final code in rendered.runes) {
          final isPersianDigit = code >= 0x06F0 && code <= 0x06F9;
          final isPersianDecimal = code == 0x066B;
          expect(
            isPersianDigit || isPersianDecimal,
            isTrue,
            reason: 'U+${code.toRadixString(16)} in "$rendered"',
          );
          // The Arabic-Indic block is a DIFFERENT set of characters, and is
          // wrong for Persian and Kurdish.
          expect(code, isNot(inInclusiveRange(0x0660, 0x0669)));
          expect(code, isNot(inInclusiveRange(0x0030, 0x0039)));
        }
      },
    );

    test('ckb matches fa exactly — intl has no ckb symbols and falls back '
        'to Latin SILENTLY', () {
      // This case is the only thing standing between a Kurdish user and ASCII
      // digits.
      for (final hundredths in <int>[25, 100, 125, 900, 1050, 6000]) {
        expect(
          formatDose(mg(hundredths), kurdishSorani),
          formatDose(mg(hundredths), _fa),
          reason: '$hundredths',
        );
      }
      expect(formatDose(mg(125), kurdishSorani), '۱٫۲۵');
    });
  });

  group('parseDose — the hostile inputs, each with its negative assertion', () {
    test('a Persian decimal separator is a decimal, not a digit', () {
      final parsed = okOf(parseDose('1٫5', _fa));

      expect(parsed, mg(150));
      expect(parsed, isNot(mg(1500)));
    });

    test('a German decimal comma is a decimal, not a thousands group', () {
      final parsed = okOf(parseDose('7,5', _de));

      expect(parsed, mg(750));
      expect(parsed, isNot(mg(7500)));
    });

    test('grouping separators survive both ways round', () {
      // Strip-non-digits is a THOUSAND-fold error on these two.
      expect(okOf(parseDose('1.234,5', _de)), mg(123450));
      expect(okOf(parseDose('1,234.5', _en)), mg(123450));
    });

    test('a grouping comma in the decimal position is NOT a dose', () {
      // `NumberFormat('en').parse('7,5')` quietly returns 75. Deciding this
      // here is what stops that reaching a dose field.
      errOf<InvalidDoseFormat>(parseDose('7,5', _en));
      expect(
        parseDose('7,5', _en),
        isNot(Ok<Milligrams, UnitFailure>(mg(750))),
      );
      expect(
        parseDose('7,5', _en),
        isNot(Ok<Milligrams, UnitFailure>(mg(7500))),
      );
    });
  });

  group('normalizeToAscii is a DIGIT normalizer, not a separator one', () {
    test('it folds both Perso-Arabic blocks and their separators', () {
      expect(normalizeToAscii('۱٫۵'), '1.5');
      expect(normalizeToAscii('١٢٣'), '123', reason: 'the Arabic block too');
      expect(normalizeToAscii('۱٬۲۳۴'), '1234', reason: 'U+066C is dropped');
    });

    test('it leaves ASCII separators ALONE, which is why parsing is locale '
        'aware', () {
      expect(normalizeToAscii('7,5'), '7,5');
      expect(
        () => double.parse(normalizeToAscii('7,5')),
        throwsFormatException,
        reason: 'exactly why parseDose goes through NumberFormat.parse',
      );
    });
  });

  group('parseDose rejections', () {
    test('negative', () => errOf<NegativeDose>(parseDose('-1', _en)));

    test('not a number at all', () {
      errOf<InvalidDoseFormat>(parseDose('', _en));
      errOf<InvalidDoseFormat>(parseDose('abc', _en));
      errOf<InvalidDoseFormat>(parseDose('١٢abc', kurdishSorani));
    });

    test('non-finite', () {
      // A digit string too large for a double. `1e400` is NOT the case to use:
      // `NumberFormat` has no exponent in `decimalPattern`, so it is rejected
      // as malformed — correctly — long before it can be infinite.
      errOf<InvalidDoseFormat>(parseDose('1e400', _en));
      errOf<NonFiniteDose>(parseDose('1${'0' * 400}', _en));
    });

    test('above the plan ceiling', () {
      expect(okOf(parseDose('60', _en, ceiling: mg(6000))), mg(6000));
      errOf<DoseAboveCeiling>(parseDose('60.01', _en, ceiling: mg(6000)));
    });

    test('finer than a hundredth is FLAGGED, never rounded', () {
      // CONTRACTS line 123 and CLAUDE.md rule 5: an unrepresentable dose is
      // flagged, never silently rounded. The epic's own task text asks for
      // half-up rounding here — `0.255 -> 26` — which is the one unforgivable
      // bug written down as a requirement, so the contract wins and EPIC-04's
      // `DoseTooPrecise` is the answer.
      errOf<DoseTooPrecise>(parseDose('0.255', _en));
      errOf<DoseTooPrecise>(parseDose('0.254', _en));
      errOf<DoseTooPrecise>(parseDose('0.005', _en));
      // The boundary that IS representable still parses.
      expect(okOf(parseDose('0.25', _en)), mg(25));
      expect(okOf(parseDose('0.01', _en)), mg(1));
    });
  });

  test('round trip in 0.25mg steps, every locale', () {
    // 0.25 and not 0.5: a half-step range never generates a quarter-milligram,
    // which is exactly how a rounding bug survives a test suite.
    for (final locale in kSupportedLocales) {
      for (var h = 25; h <= 6000; h += 25) {
        final dose = mg(h);

        expect(
          parseDose(formatDose(dose, locale), locale),
          Ok<Milligrams, UnitFailure>(dose),
          reason: 'locale=${locale.toLanguageTag()} hundredths=$h',
        );
      }
    }
  });

  test('the same round trip against an INDEPENDENT oracle', () {
    // A second path that never calls NumberFormat.parse, so format and parse
    // cannot be jointly wrong.
    for (final locale in kSupportedLocales) {
      final symbols = numberFormatFor(locale).symbols;
      for (var h = 25; h <= 6000; h += 25) {
        final ascii = normalizeToAscii(formatDose(mg(h), locale))
            .replaceAll(symbols.GROUP_SEP, '')
            .replaceAll(symbols.DECIMAL_SEP, '.');

        expect(
          double.parse(ascii),
          closeTo(h / 100, 1e-9),
          reason: 'locale=${locale.toLanguageTag()} hundredths=$h',
        );
      }
    }
  });

  test('seeded fuzz: the round trip is never 10x or 1/10th', () {
    // The ten-fold error asserted as an absence rather than hoped away by
    // examples.
    final rng = Random(0x5EED);
    for (var i = 0; i < 500; i++) {
      final h = 25 + rng.nextInt(240) * 25;
      for (final locale in kSupportedLocales) {
        final back = okOf(parseDose(formatDose(mg(h), locale), locale));

        expect(back.hundredths, h, reason: 'locale=$locale h=$h');
        expect(back.hundredths, isNot(h * 10), reason: 'ten-fold, h=$h');
        expect(back.hundredths, isNot(h ~/ 10), reason: 'tenth, h=$h');
      }
    }
  });
}
