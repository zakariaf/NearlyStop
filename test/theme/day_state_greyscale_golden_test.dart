@Tags(<String>['golden'])
library;

// The greyscale gate for the day-state quartet.
//
// Its job is to answer "which one is which" with the colour taken away. It
// cannot, and that is the finding: in the light palette the four marks measure
// L* 52 (taken), 55 (today), 56 (missed) and 59 (upcoming) — within four points
// of each other. Colour is therefore NOT a channel this quartet can lean on,
// and EPIC-07 owes it a shape, a glyph and a word per state, with EPIC-14's
// sweep as the check. Better to learn that here than in EPIC-14.
//
// The swatches carry no text on purpose: glyph rasterisation differs between a
// macOS author machine and a Linux CI runner, and a golden that drifts on the
// host is a golden nobody keeps.
//
// Even so this file is TAGGED `golden` and CI excludes it. Cross-OS raster
// differences are real, these images were authored on macOS, and a gate that
// goes red for the host rather than for the code is a gate that gets switched
// off. The claim CI actually needs — that colour alone cannot separate the
// quartet — is the measured, layout-invariant test at the bottom of this file,
// and it is NOT tagged. EPIC-14 owns the pinned-runner sweep.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/theme/day_state_colors.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../support/contrast.dart';

/// Saturation zero — the standard greyscale matrix.
const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

Widget _quartet(DaybreakColors colors) => ColorFiltered(
  colorFilter: _greyscale,
  child: ColoredBox(
    color: colors.surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final state in DayState.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ColoredBox(
                color: dayStateColor(state, colors),
                child: const SizedBox(width: 48, height: 48),
              ),
            ),
          // The new-dose signal is a SEPARATE channel, so it gets its own
          // swatch rather than a fifth enum member.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ColoredBox(
              color: dayStateColor(
                DayState.today,
                colors,
                isNewDose: true,
              ),
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  for (final (label, colors) in <(String, DaybreakColors)>[
    ('default', lightDaybreakColors),
    ('high-contrast', lightHighContrastDaybreakColors),
  ]) {
    testWidgets('the quartet renders in greyscale — $label', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: _quartet(colors)),
        ),
      );
      await expectLater(
        find.byType(ColorFiltered),
        matchesGoldenFile('goldens/day_state_greyscale_$label.png'),
      );
    });
  }

  test(
    'colour ALONE does not separate the quartet — shape is load-bearing',
    () {
      // Measured, not eyeballed. If a future palette change ever made colour
      // sufficient this fails, and that is a conversation worth having rather
      // than a silent loosening of EPIC-07's obligation.
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
      expect(
        closest,
        lessThan(10),
        reason: 'greyscale L* separations: $marks',
      );
    },
  );
}
