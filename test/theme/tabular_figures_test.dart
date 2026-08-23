// EPIC-02 declared `FontFeature.tabularFigures()` on `doseNumeral` because the
// 72px number the user reads every morning must not shift between 9mg and
// 10mg. **That declaration is only true if the shipped file has the feature.**
//
// The invariant is the test and the font's feature table only chooses which
// implementation satisfies it, so this was written before the answer was known.
// `tool/verify_tnum.sh` is the evidence for which branch was taken.
//
// Never Ahem: its uniform metrics make every case here vacuously green.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

const _latinDigits = <String>['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
const _persianDigits = <String>[
  '۰',
  '۱',
  '۲',
  '۳',
  '۴',
  '۵',
  '۶',
  '۷',
  '۸',
  '۹',
];

double _advanceOf(String text, TextStyle style, TextDirection direction) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

TextStyle _doseNumeralFor(Locale locale) => buildDaybreakTheme(
  Brightness.light,
  scriptFor(locale),
).extension<DaybreakTypography>()!.doseNumeral;

void main() {
  test('the declaration EPIC-02 made is still there', () {
    // This task is what makes that declaration true; if the slot loses the
    // feature the rest of this file is measuring something else.
    for (final locale in <Locale>[const Locale('en'), const Locale('fa')]) {
      expect(
        _doseNumeralFor(locale).fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: locale.toLanguageTag(),
      );
    }
  });

  test('Latin digits 0-9 all advance the same width', () {
    final style = _doseNumeralFor(const Locale('en'));
    final widths = <String, double>{
      for (final digit in _latinDigits)
        digit: _advanceOf(digit, style, TextDirection.ltr),
    };

    final first = widths.values.first;
    for (final entry in widths.entries) {
      expect(
        entry.value,
        closeTo(first, 0.01),
        reason: 'digit ${entry.key} of $widths',
      );
    }
  });

  test('Persian digits ۰-۹ all advance the same width', () {
    // The case that may LEGITIMATELY fail: Vazirmatn's Perso-Arabic digits are
    // not guaranteed to sit in the same feature record as its Latin ones. Its
    // result chooses the implementation below.
    final style = _doseNumeralFor(const Locale('fa'));
    final widths = <String, double>{
      for (final digit in _persianDigits)
        digit: _advanceOf(digit, style, TextDirection.rtl),
    };

    final first = widths.values.first;
    for (final entry in widths.entries) {
      expect(
        entry.value,
        closeTo(first, 0.01),
        reason: 'digit ${entry.key} of $widths',
      );
    }
  });

  test('the invariant that must hold either way: 9 to 10 in Latin', () {
    // Read the START edge, not the width — the number grows by a digit, so the
    // width must change. What must not move is where the numeral begins.
    final style = _doseNumeralFor(const Locale('en'));

    final nine = _advanceOf('9', style, TextDirection.ltr);
    final ten = _advanceOf('10', style, TextDirection.ltr);

    // In LTR the start edge is at 0 by construction, so the meaningful
    // statement is that the extra digit costs exactly one digit advance.
    expect(ten - nine, closeTo(nine, 0.01));
  });

  test('the same invariant in Persian, read directionally', () {
    // In `fa` the LEFT edge is the TRAILING one, so a width comparison read
    // left-to-right would assert the wrong edge.
    final style = _doseNumeralFor(const Locale('fa'));

    final nine = _advanceOf('۹', style, TextDirection.rtl);
    final ten = _advanceOf('۱۰', style, TextDirection.rtl);

    expect(ten - nine, closeTo(nine, 0.01));
  });
}
