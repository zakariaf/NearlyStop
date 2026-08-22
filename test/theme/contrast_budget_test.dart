// The palette is a CORRECTNESS artifact, and this is the gate.
//
// The audience is 60-80 years old, opening this app at 6am for roughly 780
// consecutive mornings, often with steroid-related visual side effects. For
// them contrast is not a design preference, it is whether they can read the
// number they are about to swallow — and it is precisely the population that
// will not file a bug.
//
// Every declared foreground/background pair, run against all FOUR palettes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/color_schemes.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/gradients.dart';
import 'package:nearlystop/theme/primitives.dart';

import '../support/contrast.dart';

typedef Slot = Color Function(DaybreakColors c);

/// One row of `daybreak-tokens/references/contrast-budget.md`.
typedef BudgetRow = (String name, Slot fg, Slot bg, double baseFloor);

const double _text = 4.5;
const double _mark = 3;
const double _hcText = 7;
const double _hcMark = 4.5;

const List<BudgetRow> budget = <BudgetRow>[
  ('ink on bg', _ink, _bg, _text),
  ('ink on surface', _ink, _surface, _text),
  ('ink on surfaceRaised', _ink, _surfaceRaised, _text),
  ('inkMuted on bg', _inkMuted, _bg, _text),
  ('inkMuted on surface', _inkMuted, _surface, _text),
  ('inkMuted on surfaceRaised', _inkMuted, _surfaceRaised, _text),
  ('primaryDeep on bg', _primaryDeep, _bg, _text),
  ('primaryDeep on tintPrimary', _primaryDeep, _tintPrimary, _text),
  (
    'onPrimary on primary (the sunrise worst stop)',
    _onPrimary,
    _primary,
    _text,
  ),
  ('onPrimary on secondary', _onPrimary, _secondary, _text),
  ('success on tintSuccess', _success, _tintSuccess, _text),
  ('warning on tintWarning', _warning, _tintWarning, _text),
  ('danger on tintDanger', _danger, _tintDanger, _text),
  ('danger on surface', _danger, _surface, _text),
  ('borderStrong on surface', _borderStrong, _surface, _mark),
  // The two *Fill slots that are legitimately marks in their own right. The
  // third, warningFill, is a decorative fill in the light theme and is asserted
  // NEGATIVELY in the carve-out group below, exactly like `primary`.
  ('successFill on surface', _successFill, _surface, _mark),
  ('dangerFill on surface', _dangerFill, _surface, _mark),
  // There is deliberately no `onPrimary on successFill` / `on dangerFill` row:
  // nothing in the design puts text on those two. They are MARKS — a dot, a
  // bar — measured against `surface` above. `warningFill` is the one fill that
  // is a text ground, and it is asserted in the carve-out group below because
  // in light it is decorative on its own.
  ('stateTaken on surface', _stateTaken, _surface, _mark),
  ('stateToday on surface', _stateToday, _surface, _mark),
  ('stateMissed on surface', _stateMissed, _surface, _mark),
  ('stateNewDose on tintWarning', _stateNewDose, _tintWarning, _mark),
];

Color _ink(DaybreakColors c) => c.ink;
Color _inkMuted(DaybreakColors c) => c.inkMuted;
Color _bg(DaybreakColors c) => c.bg;
Color _surface(DaybreakColors c) => c.surface;
Color _surfaceRaised(DaybreakColors c) => c.surfaceRaised;
Color _primary(DaybreakColors c) => c.primary;
Color _primaryDeep(DaybreakColors c) => c.primaryDeep;
Color _secondary(DaybreakColors c) => c.secondary;
Color _onPrimary(DaybreakColors c) => c.onPrimary;
Color _success(DaybreakColors c) => c.success;
Color _warning(DaybreakColors c) => c.warning;
Color _danger(DaybreakColors c) => c.danger;
Color _tintPrimary(DaybreakColors c) => c.tintPrimary;
Color _tintSuccess(DaybreakColors c) => c.tintSuccess;
Color _tintWarning(DaybreakColors c) => c.tintWarning;
Color _tintDanger(DaybreakColors c) => c.tintDanger;
Color _successFill(DaybreakColors c) => c.successFill;
Color _dangerFill(DaybreakColors c) => c.dangerFill;
Color _borderStrong(DaybreakColors c) => c.borderStrong;
Color _stateTaken(DaybreakColors c) => c.stateTaken;
Color _stateToday(DaybreakColors c) => c.stateToday;
Color _stateMissed(DaybreakColors c) => c.stateMissed;
Color _stateNewDose(DaybreakColors c) => c.stateNewDose;

void main() {
  group('the contrast oracle itself', () {
    // Pin it before trusting it with seventy-six rows: a linearisation bug in
    // the helper turns the whole budget green.
    test('white on black is 21, and any colour on itself is 1', () {
      expect(
        contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        closeTo(21, 1e-9),
      );
      for (final c in const <Color>[
        Primitives.clay19,
        Primitives.coral64,
        Primitives.plum11,
      ]) {
        expect(contrastRatio(c, c), closeTo(1, 1e-9));
      }
    });

    test('the published pair #767676 on #FFFFFF is 4.54', () {
      expect(
        contrastRatio(const Color(0xFF767676), const Color(0xFFFFFFFF)),
        closeTo(4.54, 0.01),
      );
    });
  });

  const palettes = <(String, Brightness, bool)>[
    ('light', Brightness.light, false),
    ('dark', Brightness.dark, false),
    ('light high-contrast', Brightness.light, true),
    ('dark high-contrast', Brightness.dark, true),
  ];

  for (final (label, brightness, isHighContrast) in palettes) {
    final colors = daybreakColorsFor(brightness, highContrast: isHighContrast);
    group('budget — $label', () {
      for (final (name, fg, bg, baseFloor) in budget) {
        final floor = isHighContrast
            ? (baseFloor >= _text ? _hcText : _hcMark)
            : baseFloor;
        test('$name >= $floor', () {
          final measured = contrastRatio(fg(colors), bg(colors));
          expect(
            measured,
            greaterThanOrEqualTo(floor),
            reason: '$name measures ${measured.toStringAsFixed(2)} in $label',
          );
        });
      }

      test('ColorScheme.onPrimary on ColorScheme.primary', () {
        // The SCHEME's pair, not DaybreakColors' — they are different colours
        // on different grounds, on purpose.
        final scheme = daybreakColorScheme(brightness, colors);
        expect(
          contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(isHighContrast ? _hcText : _text),
        );
      });

      test('onPrimary on the sunrise gradient WORST stop', () {
        // A ratio against a gradient is only meaningful at its worst stop, and
        // which stop that is depends on the foreground — so it is DERIVED, not
        // a named index. Naming one was the bug: stop 0 is the darkest in both
        // sunrises, and measuring stop 1 reported an easier ground than ships.
        //
        // The floor here stays 4.5 EVEN IN HIGH CONTRAST, and that is a stated
        // exception rather than an oversight: against the darkest sunrise stop
        // even pure black reaches only 6.88:1 (light) and 6.21:1 (dark), so 7:1
        // is unreachable on this ground with any foreground. The gradient
        // carries decoration only — daybreak-tokens rule 9 — and the number
        // that matters sits on an opaque `surface` chip at 13.6:1. If a future
        // palette raises this floor, the gradient's stops have to change first,
        // in the design source.
        final worst = DaybreakGradients.worstStopFor(
          colors.onPrimary,
          colors.sunrise,
        );
        expect(
          contrastRatio(colors.onPrimary, worst),
          greaterThanOrEqualTo(_text),
          reason: 'worst stop $worst in $label',
        );
      });
    });
  }

  group('the decorative-only carve-outs, asserted NEGATIVELY', () {
    // These exist to fail loudly if someone "fixes" the palette by darkening
    // the coral — at which point the fill loses the sunrise's warmth and the
    // gradient stops matching the design source. A test that goes green when
    // someone changes the brand colour is a test that lost.
    test('light primary is below the text floor, and that is the point', () {
      final measured = contrastRatio(
        lightDaybreakColors.primary,
        lightDaybreakColors.surface,
      );
      expect(measured, lessThan(3));
      expect(measured, closeTo(2.76, 0.02));
    });

    test('the high-contrast toggle does NOT raise the coral', () {
      expect(
        lightHighContrastDaybreakColors.primary,
        lightDaybreakColors.primary,
      );
      expect(
        contrastRatio(
          lightHighContrastDaybreakColors.primary,
          lightHighContrastDaybreakColors.surface,
        ),
        lessThan(4.5),
      );
    });

    test(
      'white on the sunrise worst stop FAILS, which is why it is banned',
      () {
        const white = Color(0xFFFFFFFF);
        expect(
          contrastRatio(
            white,
            DaybreakGradients.worstStopFor(
              white,
              DaybreakGradients.sunriseLight,
            ),
          ),
          lessThan(3),
        );
      },
    );

    test('7:1 on the sunrise is UNREACHABLE, so the exception is real', () {
      // Pinned so nobody raises the high-contrast gradient floor without
      // changing the gradient's stops in the design source first.
      const black = Color(0xFF000000);
      for (final gradient in <LinearGradient>[
        DaybreakGradients.sunriseLight,
        DaybreakGradients.sunriseDark,
      ]) {
        final worst = DaybreakGradients.worstStopFor(black, gradient);
        expect(contrastRatio(black, worst), lessThan(7));
        expect(contrastRatio(black, worst), greaterThanOrEqualTo(4.5));
      }
    });

    test('warningFill is a FILL in light, never a mark on its own', () {
      // amber80 measures 1.72:1 on white — invisible to the eye this palette
      // exists for. The same carve-out as `primary`: a background that carries
      // meaning only with `onPrimary` on it (9.71:1). In DARK it clears 7.17:1
      // and is covered by the budget rows above.
      expect(
        contrastRatio(
          lightDaybreakColors.warningFill,
          lightDaybreakColors.surface,
        ),
        lessThan(3),
      );
      expect(lightDaybreakColors.secondary, lightDaybreakColors.warningFill);
      expect(
        contrastRatio(
          lightDaybreakColors.onPrimary,
          lightDaybreakColors.warningFill,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
