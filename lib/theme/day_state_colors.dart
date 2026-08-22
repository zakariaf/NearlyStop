/// The day-state quartet: colour derived LAST from the day's value object.
library;

import 'dart:ui';

import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

/// The colour for [state], and for the separate new-dose signal.
///
/// Colour is **never the state's only channel**. Every state also carries a
/// glyph, a word and a shape — a filled dot and a check for taken, a hollow
/// ring and a dashed row for missed, a 2px row border and a sunrise mark for
/// today, a badge for new-dose. Those are `daybreak-components` (EPIC-07); the
/// floor they clear is `accessibility-as-code`'s. This function guarantees only
/// that the colour is a slot read, and the greyscale golden guarantees the
/// shapes still answer "which one is which".
///
/// **[isNewDose] is a separate channel, not a fifth [DayState] member**
/// (CONTRACTS.md §1). A day is routinely `today`, a new-dose day, and not yet
/// taken all at once, so one enum value could never describe a real day. When
/// it is set it takes the colour, because "which dose is this" is the question
/// the colour answers; whether the day was ticked is carried by the check
/// glyph, which is why colour is never the only channel.
///
/// `missed` is `stateMissed` — warm taupe — and deliberately **not** `danger`.
/// This app is opened every morning for roughly 780 days by someone who is
/// already frightened; red punishes a person for a bad morning. That was argued
/// once, in EPIC-02, and `day_state_colors_test.dart` fails if it is quietly
/// "fixed" back to red.
Color dayStateColor(
  DayState state,
  DaybreakColors colors, {
  bool isNewDose = false,
}) {
  if (isNewDose) return colors.stateNewDose;
  return switch (state) {
    DayState.taken => colors.stateTaken,
    DayState.missed => colors.stateMissed,
    DayState.today => colors.stateToday,
    // `upcoming` is the ABSENCE state, so it takes the decorative
    // `inkFaint` — the same tone as a disabled glyph, and deliberately below
    // the 3:1 state-mark floor. It carries no information the other three do
    // not already carry; its dashed circle is the signal, and the greyscale
    // golden is what proves that reads.
    DayState.upcoming => colors.inkFaint,
  };
}
