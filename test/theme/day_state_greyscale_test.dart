// The claim CI actually needs from the greyscale quartet, as a MEASUREMENT.
//
// Deliberately in its own file and deliberately untagged. `@Tags` is a
// LIBRARY-level annotation: leaving this test beside the golden meant
// `--exclude-tags golden` dropped it too, so the assertion CI was told it still
// ran had not run since the day it was written.
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../support/contrast.dart';

void main() {
  test('colour ALONE does not separate the quartet', () {
    // In the light palette the four marks measure L* 52 (taken), 55 (today),
    // 56 (missed) and 59 (upcoming) — within four points of each other. So
    // EPIC-07 owes the quartet a shape, a glyph and a word per state, and
    // EPIC-14's sweep is the check. Better to learn that here than there.
    //
    // If a future palette change ever made colour sufficient this goes red, and
    // that is a conversation worth having rather than a silent loosening of
    // EPIC-07's obligation.
    final marks = <String, double>{
      'taken': lStar(lightDaybreakColors.stateTaken),
      'today': lStar(lightDaybreakColors.stateToday),
      'missed': lStar(lightDaybreakColors.stateMissed),
      'upcoming': lStar(lightDaybreakColors.inkFaint),
    };
    var closest = 100.0;
    for (final a in marks.entries) {
      for (final b in marks.entries) {
        if (a.key == b.key) continue;
        final gap = (a.value - b.value).abs();
        if (gap < closest) closest = gap;
      }
    }
    expect(closest, lessThan(10), reason: 'greyscale L* separations: $marks');
  });
}
