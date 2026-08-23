// The units the settings row is stored in, and the projection over it.
//
// EPIC-06 owns `SettingsController` and its write policy — the stream is the
// source of truth and nothing is mutated optimistically. What this file pins
// is the UNITS, because EPIC-06 and EPIC-12 both read them and a disagreement
// between the two is an alarm at the wrong hour.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/settings/application/settings_view_state.dart';

void main() {
  group('the text size reads as a WORD, not a multiplier', () {
    // "1" tells a 75-year-old nothing about what they are choosing, and "1.4×"
    // tells them less. The reference frame says "Large".
    const cases = <(double, TextSizeName)>[
      (1, TextSizeName.normal),
      (1.1, TextSizeName.normal),
      (1.2, TextSizeName.large),
      (1.4, TextSizeName.large),
      (1.5, TextSizeName.larger),
      (1.7, TextSizeName.larger),
      (1.8, TextSizeName.largest),
      (2, TextSizeName.largest),
    ];

    for (final (scale, expected) in cases) {
      test('$scale is ${expected.name}', () {
        expect(textSizeNameFor(scale), expected);
      });
    }

    test('every band is reachable from the slider', () {
      // A band no slider position can produce is a name nobody will ever see,
      // and the way that happens is a boundary written above the maximum.
      final reached = <TextSizeName>{
        for (var step = 0; step <= 10; step++)
          textSizeNameFor(quantiseTextScale(1 + step * 0.1)),
      };
      expect(reached, TextSizeName.values.toSet());
    });

    test('out of range still names something', () {
      expect(textSizeNameFor(0.5), TextSizeName.normal);
      expect(textSizeNameFor(9), TextSizeName.largest);
    });
  });

  test('a reminder time round-trips through every minute of the day', () {
    // Minutes since LOCAL midnight, never a `DateTime` and never a UTC
    // instant: EPIC-12 needs a wall clock and a rule, and a stored instant
    // drifts an hour across every DST boundary — twice a year, at the hour
    // somebody takes a steroid.
    for (var minute = 0; minute < 1440; minute++) {
      final time = minutesToTimeOfDay(minute);
      expect(timeOfDayToMinutes(time), minute, reason: '$minute');
    }
    expect(timeOfDayToMinutes(const TimeOfDay(hour: 8, minute: 0)), 480);
    expect(timeOfDayToMinutes(const TimeOfDay(hour: 0, minute: 0)), 0);
    expect(timeOfDayToMinutes(const TimeOfDay(hour: 23, minute: 59)), 1439);
  });

  test('the text scale quantises to tenths, at the boundaries', () {
    // A list of pairs, not a map: a `double` has no primitive equality and
    // cannot be a const map key.
    const cases = <(double, double)>[
      (1.04, 1),
      (1.05, 1.1),
      (1.15, 1.2),
      (0.9, 1),
      (2.5, 2),
    ];
    for (final (raw, expected) in cases) {
      expect(quantiseTextScale(raw), closeTo(expected, 1e-9), reason: '$raw');
    }
  });

  test('a seeded sweep never leaves the range or the grid', () {
    var seed = 11;
    int next() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;

    for (var run = 0; run < 500; run++) {
      final raw = -1 + (next() % 6000) / 1000;
      final quantised = quantiseTextScale(raw);

      expect(quantised, greaterThanOrEqualTo(1.0), reason: '$raw');
      expect(quantised, lessThanOrEqualTo(2.0), reason: '$raw');
      expect(
        (quantised * 10) - (quantised * 10).roundToDouble(),
        closeTo(0, 1e-9),
        reason: '$raw is not on the 0.1 grid',
      );
    }
  });

  test('a null locale tag is the System selection', () {
    expect(languageSelectionFor(null), LanguageSelection.system);
    expect(languageSelectionFor('fa'), LanguageSelection.fa);
    expect(languageSelectionFor('de'), LanguageSelection.de);
    // A tag the app does not ship falls back to System rather than throwing:
    // a settings row can outlive the build that wrote it.
    expect(languageSelectionFor('xx'), LanguageSelection.system);
  });

  test('every language option names itself in its own script', () {
    // Never transliterated: the person who needs this row is the one who
    // cannot read the English label for it.
    expect(LanguageSelection.fa.nativeName, 'فارسی');
    expect(LanguageSelection.ckb.nativeName, 'کوردیی ناوەندی');
    expect(LanguageSelection.de.nativeName, 'Deutsch');
    expect(LanguageSelection.en.nativeName, 'English');
    expect(LanguageSelection.system.nativeName, isNull);
  });
}
