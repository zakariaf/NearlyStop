// The quartet, and the one decision that must never be quietly reverted.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/theme/day_state_colors.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

void main() {
  const palettes = <(String, Brightness, bool)>[
    ('light', Brightness.light, false),
    ('dark', Brightness.dark, false),
    ('light high-contrast', Brightness.light, true),
    ('dark high-contrast', Brightness.dark, true),
  ];

  for (final (label, brightness, highContrast) in palettes) {
    final colors = daybreakColorsFor(brightness, highContrast: highContrast);

    test('the mapping is total over all four members — $label', () {
      expect(dayStateColor(DayState.taken, colors), colors.stateTaken);
      expect(dayStateColor(DayState.missed, colors), colors.stateMissed);
      expect(dayStateColor(DayState.today, colors), colors.stateToday);
      expect(dayStateColor(DayState.upcoming, colors), colors.inkFaint);
    });

    test('a MISSED dose is warm taupe, never danger — $label', () {
      // Argued once, in EPIC-02. This app is opened every morning for ~780 days
      // by someone already frightened, and red punishes a person for a bad
      // morning. A change back to red is a product decision, not a tidy-up.
      expect(dayStateColor(DayState.missed, colors), colors.stateMissed);
      expect(dayStateColor(DayState.missed, colors), isNot(colors.danger));
      expect(dayStateColor(DayState.missed, colors), isNot(colors.dangerFill));
    });

    test('isNewDose is a SEPARATE channel, not a fifth member — $label', () {
      expect(
        dayStateColor(DayState.today, colors, isNewDose: true),
        colors.stateNewDose,
      );
      expect(
        dayStateColor(DayState.today, colors),
        colors.stateToday,
      );
      // A day is routinely today AND a new-dose day AND not yet taken.
      expect(
        dayStateColor(DayState.upcoming, colors, isNewDose: true),
        colors.stateNewDose,
      );
    });
  }

  test('DayState has exactly four members, so the switch stays exhaustive', () {
    expect(DayState.values, hasLength(4));
  });
}
