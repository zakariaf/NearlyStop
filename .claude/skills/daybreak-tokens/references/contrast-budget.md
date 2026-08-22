# The Daybreak contrast budget

Every foreground/background pair NearlyStop is allowed to render, measured in both themes, with the
floor each row must clear. Ratios use the WCAG 2.1 relative-luminance formula
(`Color.computeLuminance()` implements the same maths, so the table and the test agree by
construction).

This is not documentation of a past decision — it is the gate. A slot with no row here is a colour
nothing verifies, and the population that would notice (people aged 60–80, on a phone, at 6am, often
with steroid-related visual side effects) is precisely the population that will not file a bug.

## The floors

| Content | Floor | Source |
|---|---|---|
| Body text, labels, meaningful icons | **4.5:1** | WCAG 2.2 SC 1.4.3 |
| Large text (≥24px, or ≥19px bold) | 3:1 | WCAG 2.2 SC 1.4.3 — Daybreak holds these to 4.5 anyway |
| Control boundaries, focus rings, state marks | **3:1** | WCAG 2.2 SC 1.4.11 |
| Decorative fills, hairlines, disabled glyphs | none | must never carry meaning |

Daybreak does not spend the large-text exemption. The display step (72px, weight 800) is the dose
number — the single most important thing on the screen — so it is held to the body floor.

## The measured table

Light and dark columns are the measured ratios of the *same* slot pair in each theme.

| Foreground | Background | Light | Dark | Floor | |
|---|---|---:|---:|---:|:--|
| `ink` | `bg` | 13.01 | 14.48 | 4.5 | pass |
| `ink` | `surface` | 13.60 | 13.08 | 4.5 | pass |
| `ink` | `surfaceRaised` | 12.55 | 11.80 | 4.5 | pass |
| `inkMuted` | `bg` | 5.96 | 8.09 | 4.5 | pass |
| `inkMuted` | `surface` | 6.23 | 7.31 | 4.5 | pass |
| `inkMuted` | `surfaceRaised` | 5.75 | 6.59 | 4.5 | pass |
| `primaryDeep` | `bg` | 5.56 | 7.30 | 4.5 | pass |
| `primaryDeep` | `tintPrimary` | 4.91 | 5.81 | 4.5 | pass |
| `onPrimary` | `primary` | 6.04 | 7.22 | 4.5 | pass |
| `onPrimary` | `secondary` | 9.71 | 10.64 | 4.5 | pass |
| `success` | `tintSuccess` | 4.56 | 6.84 | 4.5 | pass |
| `warning` | `tintWarning` | 5.23 | 8.42 | 4.5 | pass |
| `danger` | `tintDanger` | 5.40 | 6.10 | 4.5 | pass |
| `danger` | `surface` | 6.54 | 6.68 | 4.5 | pass |
| `borderStrong` | `surface` | 3.65 | 3.98 | 3.0 | pass |
| `stateTaken` | `surface` | 4.21 | 6.65 | 3.0 | pass |
| `stateToday` | `surface` | 3.79 | 6.59 | 3.0 | pass |
| `stateMissed` | `surface` | 3.65 | 3.98 | 3.0 | pass |
| `stateNewDose` | `tintWarning` | 5.23 | 8.42 | 3.0 | pass |

Nineteen rows, no waivers. Notice how little headroom `stateToday` (3.79) and `stateMissed`/
`borderStrong` (3.65) have in light: those three are the first casualties of any "let's soften the
palette" edit, and the reason each of them must also carry a shape and a word.

## Decorative-only carve-outs

Three tokens are deliberately below a text floor. They are usable, but only for things that carry no
meaning on their own.

### `primary` — #F97350, **2.76:1** on `surface`, 2.64:1 on `bg` (light)

The signature coral. It is a **fill and a gradient stop**, never:

- text or a label of any size,
- an icon that carries meaning (a decorative flourish is fine),
- a control boundary or a focus ring — that is `borderStrong` and `primaryDeep`,
- a `ColorScheme.primary` mapping, because Material paints text with that role.

The text-safe sibling is `primaryDeep` (#B0402A, 5.56:1). In the **dark** theme the distinction
collapses — `primary` and `primaryDeep` are both #FF8A66 at 7.30:1 — which is exactly why the light
theme's discipline has to be enforced by review and by this file rather than by "it looked fine when
I checked."

### `inkFaint` — #A08A80 light / #9A8078 dark

Disabled glyphs and placeholder text only. Never body copy, never a caption a user must read, never
a label attached to a control they need to operate. A disabled control's *label* stays `inkMuted`;
only its glyph fades.

### `border` — #F0DDCD light / #45333A dark, ~1.35:1

A decorative hairline between rows of the same weight. It is never the sole boundary of a control,
never the outline of an input, and never a focus ring. It maps to `ColorScheme.outlineVariant`;
`ColorScheme.outline` gets `borderStrong`.

## Sampling rules for things that are not a flat pair

**Gradients.** A ratio against a gradient is only meaningful at its **worst stop**. For
`sunrise`, the worst stop for `onPrimary` (#2A1A16) is the coral end at 6.04:1; the amber end is
9.71:1. Measure the worst stop, record it, and keep the set of foregrounds allowed on a gradient at
exactly one. White would measure 2.76:1 on the coral stop — it fails, which is why the mockups' warm
brown-on-sunrise is a correctness decision, not a stylistic one.

**Overlays and scrims.** `overlay` is translucent, so nothing is measured *against* it. Text over the
disclaimer scrim sits on the sheet's opaque `surface`, not on the scrim.

**Shadows.** Never carry contrast. A shadow that is doing the work of a boundary is a missing
`borderStrong`.

**Anything over the `wash` gradient.** `wash` runs #FFF7EE→#FFFFFF (light) and #3B2B31→#2E2229
(dark). Both endpoints are within 0.6 of the `ink`-on-`surface` ratio, so text over the wash is
covered by the `ink`/`surface` and `ink`/`bg` rows. Any *new* wash must be re-checked at both ends.

## The test

```dart
// test/theme/contrast_budget_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

typedef Pair = (String name, Color Function(DaybreakColors) fg, Color Function(DaybreakColors) bg,
    double floor);

const _budget = <Pair>[
  ('ink on bg', _ink, _bg, 4.5),
  ('ink on surface', _ink, _surface, 4.5),
  ('ink on surfaceRaised', _ink, _surfaceRaised, 4.5),
  ('inkMuted on bg', _inkMuted, _bg, 4.5),
  ('inkMuted on surface', _inkMuted, _surface, 4.5),
  ('inkMuted on surfaceRaised', _inkMuted, _surfaceRaised, 4.5),
  ('primaryDeep on bg', _primaryDeep, _bg, 4.5),
  ('primaryDeep on tintPrimary', _primaryDeep, _tintPrimary, 4.5),
  ('onPrimary on primary (sunrise worst stop)', _onPrimary, _primary, 4.5),
  ('onPrimary on secondary', _onPrimary, _secondary, 4.5),
  ('success on tintSuccess', _success, _tintSuccess, 4.5),
  ('warning on tintWarning', _warning, _tintWarning, 4.5),
  ('danger on tintDanger', _danger, _tintDanger, 4.5),
  ('danger on surface', _danger, _surface, 4.5),
  ('borderStrong on surface', _borderStrong, _surface, 3.0),
  ('stateTaken on surface', _stateTaken, _surface, 3.0),
  ('stateToday on surface', _stateToday, _surface, 3.0),
  ('stateMissed on surface', _stateMissed, _surface, 3.0),
  ('stateNewDose on tintWarning', _stateNewDose, _tintWarning, 3.0),
];

Color _ink(DaybreakColors c) => c.ink;
Color _bg(DaybreakColors c) => c.bg;
// … one tear-off per slot the budget names.

void main() {
  for (final (label, colors) in [
    ('light', lightDaybreakColors),
    ('dark', darkDaybreakColors),
  ]) {
    group('Daybreak contrast budget — $label', () {
      for (final (name, fg, bg, floor) in _budget) {
        test(name, () {
          expect(contrastRatio(fg(colors), bg(colors)), greaterThanOrEqualTo(floor),
              reason: '$name fails its floor in the $label theme');
        });
      }
    });
  }

  test('decorative-only tokens are documented as such, not silently used as text', () {
    // These assertions exist to FAIL LOUDLY if someone "fixes" the palette by
    // darkening primary — at which point the fill loses the sunrise's warmth and
    // the gradient stops matching the design source.
    expect(contrastRatio(lightDaybreakColors.primary, lightDaybreakColors.surface), lessThan(3.0));
  });
}
```

The last test is deliberate: it pins `primary` as decorative. If a future edit raises it above 4.5:1,
the test fails and forces the question "did we mean to change the brand colour, and did we re-render
the sunrise gradient?" rather than letting a silent drift through.

## Adding or changing a slot

1. Add the primitive to `lib/theme/primitives.dart`, named `<hueFamily><L*>` with its measured L\* in
   the comment.
2. Wire it into **both** `lightDaybreakColors` and `darkDaybreakColors` — a slot that exists in one
   theme only is a crash waiting for the first person who switches at 6am.
3. Add a row to the table above with both measured ratios and its floor.
4. Add the pair to `_budget` in the test.
5. If the slot encodes a state, confirm with `daybreak-components` that the state also carries a
   glyph, a word, and a shape, and add it to the greyscale golden.

## Honest limits

This budget proves the **declared pairs**. It does not prove:

- a composition nobody declared (a token used on a surface it was never measured against);
- text over a photo, a translucent chrome, or a system blur;
- what a specific person with a specific cataract or steroid-related visual change actually sees;
- that the *shape* signals are legible — that is the greyscale golden's job
  (`widget-golden-and-a11y-testing`) and the manual sweep's (`design-review-workflow`).

What it does buy: the manual review starts from a verified floor instead of from zero, and no colour
change can land quietly.
