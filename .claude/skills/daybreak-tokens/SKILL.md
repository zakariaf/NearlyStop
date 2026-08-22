---
name: daybreak-tokens
description: >-
  Pins NearlyStop's Daybreak design values into lib/theme/ — warm #FFF9F2 / #241A20 surfaces, coral
  #F97350 / #FF8A66 brand, the 138° sunrise gradient, warm-brown rgba(140,84,56) multi-layer shadows,
  8/12/16/24/32/pill radii, the 4→48 spacing ramp, 120/220/420ms motion, and the
  taken/missed/today/new-dose day-state quartet — as a Primitives pool (the only file holding a raw
  Color(0x…), named by hue family + measured CIE L*) plus DaybreakColors, DaybreakShapes,
  DaybreakElevation and DaybreakMotion ThemeExtensions with copyWith, honest lerp and an asserting
  of(context); hand-authors light AND dark ColorScheme (never fromSeed, never dynamic_color, never
  google_fonts), maps outline to border-strong not the decorative hairline, keeps #F97350's 2.76:1
  fill-only, and gates every slot with a contrast-budget unit test. Use when editing lib/theme/,
  adding or renaming a Daybreak token, choosing a colour, radius, shadow, gradient or duration for a
  NearlyStop screen, building ThemeData/ColorScheme, wiring DaybreakColors.of(context), or reviewing
  a widget that renders a hex, BoxShadow, LinearGradient or Duration.
---

# daybreak-tokens

Daybreak is the *values* half of NearlyStop's design system: every colour, radius, shadow, gradient
and duration the app can render, declared once in `lib/theme/` and read back through named slots.
`design-system-structure` owns the *mechanism* — two tiers, `ThemeExtension`, the asserting `of()`,
hand-authored `ColorScheme`, the no-raw-values gate — and this skill does not re-teach it; it plugs
in and supplies the numbers. Applies to every file under `lib/theme/` and to any widget that would
otherwise reach for a hex, a `BoxShadow`, a `LinearGradient`, or a `Duration`.

- `references/contrast-budget.md` — every measured pair in both themes, the floor per row, the
  decorative-only carve-out, and the test that gates a new slot.
- `examples/daybreak_theme.dart` — the full build: primitive pool, all four extensions, both
  `ColorScheme`s, `buildDaybreakTheme(Brightness)`.

## Non-negotiable rules

1. **`lib/theme/primitives.dart` is the only file in the repo that may hold a Daybreak hex** — every
   other file, the rest of `lib/theme/` included, composes from `Primitives.*`. WHY: a reskin, a
   contrast re-measure, or a dark re-tune must be a one-file diff; a second file with hexes means
   `references/contrast-budget.md` is measuring a palette the app no longer renders.
2. **Widgets read Tier-2 slots only — `DaybreakColors.of(context).ink`, never `Primitives.clay19`.**
   WHY: a primitive is a value with no theme; a widget holding one hardcodes light mode and renders
   brown-on-brown at 1.1:1 the first time someone switches to dark at 6am.
3. **Primitives are named `<hueFamily><L*>`: `clay19`, `coral64`, `moss52`, `plum15`** — family = the
   measured hue/chroma band, number = CIE L\* rounded. Never `brown700`, `darkBrown`, `brandCoral`.
   WHY (`design-system-structure` rule 2): rank scales have no room to insert, appearance names
   invert catastrophically in dark, brand names die with the brand — and L\* makes "are these two far
   enough apart?" answerable by reading the names.
4. **A colour that appears only inside a gradient stays inline in that gradient constant; it never
   gets a primitive name.** `#FF9A4D` and `#FFC46A` live inside `Primitives.sunriseLight` and
   nowhere else. WHY: a named stop invites a widget to use it as a flat fill, and no row of the
   contrast budget ever measured it as one.
5. **Both `ColorScheme`s are hand-authored with a fixed role map; never `ColorScheme.fromSeed`, never
   `dynamic_color`.** WHY: Daybreak's light `primary` is 2.76:1 and its `border` is ~1.35:1 — a seed
   hands Material a palette whose every derived role is unmeasured, and wallpaper-derived colour is
   untestable at build time.
6. **`ColorScheme.outline` maps to `borderStrong` (3.65:1), never to `border`** — `border` is
   `outlineVariant` only. WHY: Material draws `TextField`, `Switch`, `Checkbox` and `OutlinedButton`
   boundaries from `outline`, so the decorative hairline there ships controls whose edges a
   78-year-old cannot see, and nothing in the app will report it.
7. **`primary` (#F97350) is a FILL in light mode and never carries or is used as text.** Accent text,
   links, the active tab label and the focus ring use `primaryDeep` (#B0402A, 5.56:1). WHY: #F97350
   measures **2.76:1** on `surface` — the one Daybreak token that is decorative-only, and it looks
   confident enough to be adopted as a text colour by accident.
8. **Shadows are warm, multi-layer, and never `Colors.black` or `elevation:`.** Every level is a
   `List<BoxShadow>` tinted `clay42` (#8C5438) in light and `plum01` (#080406) in dark. WHY: a neutral
   black shadow on a #FFF9F2 ground reads as grey dirt and drains the warmth the whole emotional
   brief rests on; Material's `elevation:` paints exactly that neutral shadow and ignores the token.
9. **The sunrise gradient is one token, used at most once per screen, and only `onPrimary` (#2A1A16)
   sits on it** — never white, never a small label, never a number that matters. WHY: #2A1A16
   measures 6.04:1 on the coral stop and 9.71:1 on the amber stop; white fails at both ends, and text
   on a gradient can only be verified at its worst stop, so keep worst stops known and few.
10. **Gradient `begin`/`end` are `AlignmentDirectional`, never `Alignment`.** WHY: `Alignment` does
    not mirror, so in Persian the light would fall from the wrong corner while every other element
    mirrored — a physical-side bug that no LTR golden can catch (`i18n-rtl-l10n` rule 5).
11. **Every duration and curve is a `DaybreakMotion` slot resolved through `resolveMotion`, which
    returns `Duration.zero` under `MediaQuery.disableAnimationsOf`.** WHY: the mechanism is
    `design-system-structure`'s and the values are ours — and a user who turned animations off asked
    for stop, not for 120ms instead of 420ms.
12. **The day-state quartet (`stateTaken`/`stateMissed`/`stateToday`/`stateNewDose`) is a derived
    slot computed last from the day's value object — never the state's only channel — and
    `stateMissed` is `clay56` (warm taupe), deliberately not `danger`.** WHY: the ≥3-non-colour-signal
    floor is `accessibility-as-code`'s and the shapes are `daybreak-components`'; the token
    contribution is that a missed dose is never red — this app is opened every morning for ~780 days
    by someone already frightened, and red punishes a person for a bad morning.
13. **Dark is authored, not flipped, and stays warm.** `bg` is `plum11` (#241A20), never `#000000`;
    dark shadows keep a plum-black tint. WHY: dark mode here is a 6am bedside screen, and an
    OLED-true-black void is exactly the cold clinical register the brief rules out.
14. **A new or changed slot lands in `references/contrast-budget.md` with its test in the same
    commit.** WHY: an ungated colour is an unverified colour, and the failure mode — unreadable text
    for the exact population that will not file a bug — is silent.
15. **Fonts are bundled: `Nunito` (Latin) and `Vazirmatn` (Persian), license-registered, never
    `google_fonts`.** WHY: the HTML mockups linked the Google Fonts CDN; NearlyStop is offline and
    `google_fonts` ships an HTTP path by default. Per-script sizing is `daybreak-bilingual-type`'s.

## Tier 1 — the primitive pool

Families are measured bands, not moods: **clay** (warm brown/cream, hue 15–35, chroma > 12),
**taupe** (same hue, low chroma), **plum** (dark mauve neutral, hue 300–350), **coral** (hue 5–20,
high chroma), **amber** (hue 25–45), **moss** (hue 140–165), **rose** (hue 0–8).

```dart
// lib/theme/primitives.dart — the ONLY file allowed a raw Color(0x…). The number is
// CIE L* rounded, so clay19 vs clay89 reads as a 70-point separation on sight.
abstract final class Primitives {
  static const clay98  = Color(0xFFFFF9F2); // bg, light
  static const clay19  = Color(0xFF3B2A25); // ink, light — also the light overlay ink
  static const clay42  = Color(0xFF8C5438); // shadow ink, light — warm, never black
  static const clay56  = Color(0xFFA67D68); // borderStrong AND stateMissed, light
  static const plum11  = Color(0xFF241A20); // bg, dark — warm, never #000
  static const coral64 = Color(0xFFF97350); // primary, light — FILL ONLY (2.76:1)
  static const coral43 = Color(0xFFB0402A); // primaryDeep, light — accent TEXT (5.56:1)
  static const moss52  = Color(0xFF2E8B63); // stateTaken, light
  // …full pool in examples/daybreak_theme.dart
}
```

`borderStrong` and `stateMissed` sharing `clay56` is deliberate: an unticked day carries the weight
of a control boundary — present, legible at 3.65:1, emotionally neutral.

## Tier 2 — the slots widgets read

Four extensions, each with `copyWith`, an honest `lerp`, and an `of()` that **asserts**, never falls back:

| Extension | Holds |
|---|---|
| `DaybreakColors` | `bg surface surfaceRaised surfaceSunken · ink inkMuted inkFaint · primary primaryDeep secondary onPrimary · success successFill warning warningFill danger dangerFill · tintPrimary tintSuccess tintWarning tintDanger · border borderStrong overlay · stateTaken stateMissed stateToday stateNewDose · sunrise wash` |
| `DaybreakShapes` | radii `xs 8 · sm 12 · md 16 · lg 24 · xl 32 · pill 999`; spacing `s1 4 · s2 8 · s3 12 · s4 16 · s5 20 · s6 24 · s7 32 · s8 40 · s9 48`; `hairlineWidth`, `focusRingWidth`; `cardShape()/sheetShape()/pillShape()/heroShape()` factories |
| `DaybreakElevation` | `level0 level1 level2 level3 glow` — each a `List<BoxShadow>` |
| `DaybreakMotion` | `fast 120ms · base 220ms · slow 420ms`; `easeOut Cubic(.22,.85,.34,1)`; `easeInOut Cubic(.65,0,.35,1)` |

```dart
final c = DaybreakColors.of(context);
final s = DaybreakShapes.of(context);
Container(
  padding: EdgeInsetsDirectional.all(s.s4),          // 16, a token — not a literal
  decoration: BoxDecoration(
    color: c.surfaceRaised,
    borderRadius: BorderRadius.circular(s.radiusLg), // 24
    boxShadow: DaybreakElevation.of(context).level1,
  ),
  child: Text('9 mg', style: TextStyle(color: c.ink)),
);
```

## The sunrise gradient — 138° in Flutter, mirrored in RTL

CSS measures the angle clockwise from "to top"; Flutter's `Alignment` box is `-1..1` with **+y
downward**. The direction vector for a CSS angle θ is `(sin θ, −cos θ)` in maths coordinates, which
in Flutter's y-down box is `(sin θ, cos(180° − θ))` — for 138° that is `(0.669, 0.743)`:

```dart
// AlignmentDirectional, so the light falls from the leading top corner in BOTH scripts.
static const sunriseLight = LinearGradient(
  begin: AlignmentDirectional(-0.669, -0.743), // 138° from "to top", leading-top
  end:   AlignmentDirectional(0.669, 0.743),
  colors: [Color(0xFFF9633F), coral64, Color(0xFFFF9A4D), Color(0xFFFFC46A)],
  stops: [0.0, 0.32, 0.68, 1.0],
);
```

Honest limit: `Alignment` components are fractions of each axis independently, so the rendered angle
is 138° only on a square box — on a wide hero card it flattens. For a true geometric angle use
`topCenter`→`bottomCenter` with `transform: GradientRotation((138 - 180) * math.pi / 180)` and
**negate the radians under `TextDirection.rtl`**: `GradientRotation` has no direction resolution,
which is exactly why the Alignment form is the default token.

## Warm elevation — CSS blur is not Flutter `blurRadius`

Flutter has no multi-layer shadow token, so each level is a `List<BoxShadow>` on the extension. CSS
blur `b` means σ = `b/2`; Flutter's `blurRadius` r means σ = `0.57735·r + 0.5`, so **r ≈ 0.866·(b−1)**.
Writing the CSS number straight into `blurRadius` makes every shadow ~15% too tight — a hard edge
where the system wants a warm lift.

```dart
// shadow-2: 0 2px 4px rgba(140,84,56,.07), 0 10px 24px rgba(140,84,56,.10)
static final _level2Light = <BoxShadow>[
  BoxShadow(color: Primitives.clay42.withValues(alpha: 0.07),
      offset: const Offset(0, 2), blurRadius: 2.6),   // css 4  -> 0.866*3
  BoxShadow(color: Primitives.clay42.withValues(alpha: 0.10),
      offset: const Offset(0, 10), blurRadius: 19.9), // css 24 -> 0.866*23
];
```

`glow` is the primary at low alpha (`coral64` light, `coral66` dark), spent on exactly one element
per screen — the sunrise hero or the primary action. `lerp` uses `BoxShadow.lerpList`.

## Motion

```dart
Duration resolveMotion(BuildContext context, Duration full) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : full;

AnimatedContainer(
  duration: resolveMotion(context, DaybreakMotion.of(context).base), // 220ms
  curve: DaybreakMotion.of(context).easeOut,                          // Cubic(.22,.85,.34,1)
  ...
);
```

`fast` is a tap's own feedback, `base` a state change the user caused, `slow` the one celebratory
moment (a taper step completing). The moment catalogue and the haptic that must survive reduced
motion are `motion-and-haptics`.

## The day-state quartet

```dart
// lib/theme/day_state_colors.dart — colour derived LAST from the value object.
extension DayStatePalette on DayState {
  Color color(DaybreakColors c) => switch (this) {
        DayState.taken   => c.stateTaken,    // moss52 / moss70 — 4.21:1 on surface
        DayState.missed  => c.stateMissed,   // clay56 / plum54 — 3.65:1, NOT danger
        DayState.today   => c.stateToday,    // coral55 / coral70 — 3.79:1 boundary
        DayState.newDose => c.stateNewDose,  // amber42 / amber83
      };
}
```

Each state also carries a glyph, a word and a shape — filled dot + check for taken, hollow 3px ring +
dashed row for missed, 2px row border + sunrise mark for today, badge for new-dose. Those shapes are
`daybreak-components`, the floor is `accessibility-as-code`; this file only guarantees the colour is
a slot read and that a greyscale golden still answers the question.

## The contrast budget

Nineteen declared pairs, all passing, measured with the WCAG 2.1 relative-luminance formula. Text
rows require 4.5:1; boundary and state-mark rows require 3.0:1. Two carve-outs, both load-bearing:

- **`primary` #F97350 — 2.76:1 on `surface`. Decorative only:** fill and gradient stop; never text,
  never a meaningful icon, never a boundary.
- **`inkFaint` — disabled glyphs and placeholder text only.** Never body copy, never a label a user
  must read to act.

```dart
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

test('Daybreak pairs clear their floor in both themes', () {
  for (final c in [lightDaybreakColors, darkDaybreakColors]) {
    expect(contrastRatio(c.ink, c.bg), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(c.primaryDeep, c.tintPrimary), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5)); // gradient worst stop
    expect(contrastRatio(c.borderStrong, c.surface), greaterThanOrEqualTo(3.0));
    expect(contrastRatio(c.stateTaken, c.surface), greaterThanOrEqualTo(3.0));
  }
});
```

Full table, both themes' measured numbers, the gradient worst-stop sampling rule and the add-a-slot
checklist: `references/contrast-budget.md`.

## Anti-patterns

- **`Color(0xFFF97350)` outside `primitives.dart`, or `Primitives.clay19` inside a widget** — the
  first fails the gate (add a slot, never an `// ignore`); the second hardcodes light mode.
- **`#F97350` as text, an icon colour, or a focus ring** — 2.76:1; use `primaryDeep`.
- **`ColorScheme.outline: c.border`** — the decorative hairline as a control boundary; every input
  and switch loses its visible edge.
- **`ColorScheme.fromSeed(seedColor: Primitives.coral64)`, or adding `dynamic_color`** — derived
  roles are unmeasured and the per-role overrides do not propagate.
- **`Material(elevation: 2)`, `BoxShadow(color: Colors.black26)`, or the CSS blur number written
  straight into `blurRadius`** — a neutral shadow on a cream ground reads as dirt, and the unconverted
  blur lands ~15% tight; use `DaybreakElevation.level2` and `r ≈ 0.866·(b−1)`.
- **White text on the sunrise gradient, or a dose number on it** — fails at both stops; the hero's
  action sits on an opaque `surface` chip with `ink` (13.6:1).
- **`Alignment(-0.669, -0.743)` for the gradient, or more than one gradient per screen** — the first
  does not mirror in Persian; the second retires the signature.
- **`danger` for a missed day, or `success` as a plain "good" wash** — red shames, and a semantic
  colour spent on decoration cannot be trusted when something is actually wrong.
- **`google_fonts`, or `#000000`/`Colors.black87` in the dark theme** — a runtime font fetch in an
  offline app, and a cold void in a system whose whole point is warmth.
- **A slot merged without a contrast-budget row** — an unverified colour nobody will report.

## Definition of done

- [ ] Every Daybreak hex lives in `lib/theme/primitives.dart`; `design-system-structure`'s
      `check_raw_values.sh` is clean over `lib/` and `check_font_bundling.sh` shows no `google_fonts`.
- [ ] Primitives are named `<hueFamily><L*>`; no widget reads one; gradient-only stops stay inline.
- [ ] All four extensions implement `copyWith` + a `lerp` covering every field, and an asserting
      `of(context)`; both are attached to **both** `ThemeData`s.
- [ ] Both `ColorScheme`s are hand-authored with `outline` = `borderStrong`, `outlineVariant` =
      `border`; light `primary` is fill-only and `primaryDeep` carries accent text and focus rings.
- [ ] Every shadow is a warm-tinted `List<BoxShadow>` from `DaybreakElevation`; no `elevation:`, no
      `Colors.black`. The sunrise gradient uses `AlignmentDirectional`, appears at most once per
      screen, carries only `onPrimary`, and an RTL golden shows it falling from the leading corner.
- [ ] Every animation reads a `DaybreakMotion` slot through `resolveMotion`; a reduced-motion test
      asserts `Duration.zero`.
- [ ] Day-state colour is derived from the day's value object through a slot; a greyscale golden of
      Schedule still answers "which day is which".
- [ ] `references/contrast-budget.md` lists every declared pair, the AA test passes for both themes,
      and `primary` + `inkFaint` sit in the decorative-only carve-out.

## Related skills

- See `design-system-structure` for the mechanism this skill supplies values to: two-tier tokens, the
  `ThemeExtension` contract, the asserting `of()`, the no-raw-values gate, and `resolveMotion`.
- See `daybreak-components` for the NearlyStop component recipes — dose hero, block header, day row,
  taper-step card — that consume these slots.
- See `daybreak-bilingual-type` for the Nunito/Vazirmatn cascade, the Persian line-height bump and
  display step-down, and the per-script `TextTheme` projection built on this scale.
- See `accessibility-as-code` for the ≥3-non-colour-signal floor, target sizes, and a11y flags from
  `MediaQuery` — the floor this palette is built to clear.
- See `motion-and-haptics` for what the 120/220/420 tokens are spent on, and
  `custom-canvas-and-gestures` for the Progress taper curve's painter, which takes a token snapshot
  instead of reading `Theme.of(context)` in `paint()`.
- See `i18n-rtl-l10n` for the directional geometry the gradient mirroring rides on, and
  `widget-golden-and-a11y-testing` for the greyscale, RTL, and largest-text golden lanes.

## References

- Flutter API — `ThemeExtension`: https://api.flutter.dev/flutter/material/ThemeExtension-class.html
- Flutter API — `ColorScheme` (M3 roles, `fromSeed` caveats): https://api.flutter.dev/flutter/material/ColorScheme-class.html
- Flutter API — `BoxShadow` (`blurRadius`, `lerpList`, `convertRadiusToSigma`): https://api.flutter.dev/flutter/painting/BoxShadow-class.html
- Flutter API — `LinearGradient` (`begin`/`end`, `transform`, `GradientRotation`): https://api.flutter.dev/flutter/painting/LinearGradient-class.html
- Flutter API — `AlignmentDirectional`: https://api.flutter.dev/flutter/painting/AlignmentDirectional-class.html
- Flutter API — `Color.computeLuminance`: https://api.flutter.dev/flutter/dart-ui/Color/computeLuminance.html
- Flutter cookbook — Use a custom font (bundling, `fontFamilyFallback`): https://docs.flutter.dev/cookbook/design/fonts
- Material Design 3 — colour roles: https://m3.material.io/styles/color/roles
- MDN — `linear-gradient()` angle definition: https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient
- W3C WAI — WCAG 2.2 SC 1.4.3 Contrast (Minimum) and SC 1.4.11 Non-text Contrast: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
