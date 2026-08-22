# EPIC-02 — Daybreak theme & tokens

**Branch:** `epic/02-daybreak-theme`
**Depends on:** EPIC-01

## Where we are now

EPIC-01 left a Flutter app that builds and a CI run that blocks on format, analyze, a static ban
grep and a randomized test suite. `lib/theme/` exists and is empty. `lib/app.dart` holds a plain
`MaterialApp` with a placeholder `Scaffold` and no `theme:` argument at all, so every pixel it draws
is Material's default purple on white — the exact opposite of the design.

The design itself is fully specified and lives outside the code: `design/daybreak-system.html` is the
authored system, `design/daybreak-screens.html` renders all six screens from it, and
`design/reference/daybreak-screens-{light,dark}-{en,fa}.png` are the 2600px captures. The
`daybreak-tokens` skill has already extracted the values — the primitive pool, both `ColorScheme`s,
the four extensions and the full build are in
`.claude/skills/daybreak-tokens/examples/daybreak_theme.dart`, and every measured contrast pair is in
`references/contrast-budget.md`. Nothing has been ported into Dart.

No fonts are bundled. `assets/` does not exist.

## Why this epic exists

The audience is 60–80 years old, opening this app at 6am for roughly 780 consecutive mornings, often
with steroid-related visual side effects. For them contrast is not a design preference, it is whether
they can read the number they are about to swallow. That makes the palette a **correctness artifact**,
and correctness artifacts need a test. Nineteen foreground/background pairs have been measured; this
epic turns that table into a unit test that fails a build.

It exists second, before localization and before any screen, because a token system retrofitted is a
token system that lost. If two screens ship with `Color(0xFFF97350)` inline, the reskin, the
dark-mode re-tune and the contrast re-measure all become multi-file archaeology instead of a one-file
diff — and the no-raw-values gate can never be switched on because it would be red on arrival.

And there is one specific trap this epic exists to disarm. Daybreak's signature coral, `#F97350`,
measures **2.76:1** on surface. It fails AA by a wide margin. It also looks confident and warm enough
that any developer, at any point in the next fourteen epics, will reach for it as a text colour or a
focus ring and it will look fine on their desk monitor. The token system has to make that mistake
structurally awkward and the test has to make it loud.

## What we will have when it is done

Every colour, radius, spacing step, shadow, gradient and duration the app can render is declared once
and read back through a named slot. The app launches in the warm cream light theme and the warm plum
dark theme, switching with the OS, and a third high-contrast pair exists behind
`buildDaybreakTheme(..., highContrast: true)` for EPIC-11's toggle to select. A contrast test pins all
nineteen measured pairs across all four palettes.
Animations collapse to `Duration.zero` when the OS says reduce motion. Nunito and Vazirmatn ship
inside the binary with their OFL text registered, so the app's own licenses page is honest and no
glyph is ever fetched over a network. `tool/check_raw_values.sh` is green and wired into CI, so the
first inline hex in a feature widget is a red build.

## Skills to load

| Skill | What it governs for this epic |
|---|---|
| `daybreak-tokens` | The values: the full primitive pool, both hand-authored `ColorScheme`s, the four extensions, the gradient maths, the warm shadow stack, the day-state quartet |
| `design-system-structure` | The mechanism: two tiers, `ThemeExtension` with `copyWith`/`lerp`/asserting `of()`, no-raw-values gate, `resolveMotion`, painters snapshot tokens |
| `daybreak-bilingual-type` | The seven-role scale, `em`→logical-px tracking conversion, all fifteen M3 slots assigned, font bundling + `LicenseRegistry`, the `boldText` weight ladder |
| `motion-and-haptics` | What 120/220/420 are spent on, and which haptic must survive reduced motion |
| `accessibility-as-code` | The AA floors this palette is built to clear, the ≥3-non-colour-signal rule the day-state quartet must not violate, reading a11y flags from `MediaQuery` |
| `widget-golden-and-a11y-testing` | The greyscale and reduced-motion golden lanes, loading real fonts in tests |
| `custom-canvas-and-gestures` | Why the Progress painter (EPIC-10) takes a token snapshot rather than reading `Theme.of(context)` in `paint()` — the extension shape must support it |
| `lint-and-style-config` | Appending the raw-values gate to the existing ban script without weakening it |

## Tasks

### 1. Tier 1 — the primitive pool

- **What** — Port the full measured primitive pool into the one file in the repo allowed a raw hex.
- **Where** — `lib/theme/primitives.dart`.
- **Details** — Source of truth is `.claude/skills/daybreak-tokens/examples/daybreak_theme.dart`
  lines 29–87. `abstract final class Primitives`, all `static const Color`. Names are
  `<hueFamily><L*>` — the family is the measured hue/chroma band, the number is CIE L\* rounded:
  `clay100 clay98 clay97 clay95 clay94 clay89 clay73 clay59 clay56 clay42 clay41 clay19 clay11`,
  `taupe56`, `plum01 plum03 plum08 plum11 plum15 plum19 plum24 plum54`,
  `coral93 coral70 coral66 coral64 coral55 coral43 coral19`,
  `amber95 amber83 amber80 amber72 amber42 amber20`,
  `moss94 moss78 moss70 moss52 moss46 moss22`,
  `rose92 rose70 rose58 rose47 rose40 rose18`.
  Never `brown700`, `darkBrown` or `brandCoral`: rank scales have no room to insert, appearance names
  invert catastrophically in dark, brand names die with the brand, and L\* makes "are these two far
  enough apart?" answerable by reading the names.
  **A colour that appears only inside a gradient does not get a primitive name.** `#F9633F`,
  `#FF9A4D`, `#FFC46A`, `#FFF7EE` stay inline inside their gradient constants — a named stop invites a
  widget to use it as a flat fill, and no row of the contrast budget ever measured it as one.
  Every constant carries a one-line comment naming the slot(s) it feeds, so a future reader can find
  the consumer without grepping.
- **Acceptance** — Every hex in `lib/` lives in this file. `clay56` is commented as feeding both
  `borderStrong` and `stateMissed`, and that sharing is called out as deliberate.

### 2. Tier 2 — the four `ThemeExtension`s

- **What** — The slots widgets read, each with `copyWith`, an honest `lerp` and an asserting `of()`.
- **Where** — `lib/theme/daybreak_colors.dart`, `daybreak_shapes.dart`, `daybreak_elevation.dart`,
  `daybreak_motion.dart`.
- **Details** —
  - `DaybreakColors` — `bg surface surfaceRaised surfaceSunken · ink inkMuted inkFaint · primary
    primaryDeep secondary onPrimary · success successFill warning warningFill danger dangerFill ·
    tintPrimary tintSuccess tintWarning tintDanger · border borderStrong overlay · stateTaken
    stateMissed stateToday stateNewDose · sunrise wash`. `sunrise` and `wash` are `LinearGradient`,
    the rest are `Color`.
  - `DaybreakShapes` — radii `radiusXs 8 · radiusSm 12 · radiusMd 16 · radiusLg 24 · radiusXl 32 ·
    radiusPill 999`; spacing
    `s1 4 · s2 8 · s3 12 · s4 16 · s5 20 · s6 24 · s7 32 · s8 40 · s9 48`; `hairlineWidth`,
    `focusRingWidth`; and the silhouette factories `cardShape() sheetShape() pillShape() heroShape()`
    so a component asks for a shape, not a radius.
  - `DaybreakElevation` — `level0 level1 level2 level3 glow`, each a `List<BoxShadow>`.
  - `DaybreakMotion` — `fast 120ms · base 220ms · slow 420ms`, `easeOut Cubic(.22,.85,.34,1)`,
    `easeInOut Cubic(.65,0,.35,1)`.
  > **Contract:** CONTRACTS.md §9 and §15 fix these names once: radii are `radiusXs…radiusPill`,
  > spacing is `s1…s9`, elevation is `level0…level3` + `glow`. **`DaybreakRadii`, `DaybreakSpacing`,
  > `shadow0…shadow3` and `shadowGlow` do not exist and must not be reintroduced** — EPIC-08/09/10
  > still contain them and are being swept in their own epics. This task is where the names become
  > real, so getting them right here is what makes that sweep mechanical.
  `of(context)` **asserts** on a missing extension and returns non-null; it never `?? fallback`. A
  fallback silently ships a theme no test verified, and loud-in-debug beats wrong-in-field.
  `lerp` interpolates every `Color` and `double`; `List<BoxShadow>` uses `BoxShadow.lerpList`;
  `Gradient` uses `Gradient.lerp`; non-interpolables snap at `t < 0.5`. A field forgotten in `lerp` is
  the classic design-system rot, so the test in task 7 walks the fields.
- **Acceptance** — All four extensions are attached to **both** `ThemeData`s. A widget test that
  builds a bare `MaterialApp` without the extensions hits the assert.

### 3. Both `ColorScheme`s, hand-authored — and the `primary` trap

- **What** — Light and dark `ColorScheme`s written by hand with a fixed role map.
- **Where** — `lib/theme/color_schemes.dart`.
- **Details** — Never `ColorScheme.fromSeed`, never `dynamic_color`. A seed hands Material a palette
  whose every derived role is unmeasured, per-role overrides do not propagate, and wallpaper-derived
  colour is untestable at build time.
  Two mappings carry the whole epic:
  - **`ColorScheme.outline` = `borderStrong` (3.65:1), never `border` (~1.35:1).** `border` is
    `outlineVariant` only. Material draws `TextField`, `Switch`, `Checkbox` and `OutlinedButton`
    boundaries from `outline`; the decorative hairline there ships controls whose edges a 78-year-old
    cannot see, and nothing in the app will report it.
  - **`ColorScheme.primary` = `Primitives.coral43` (primaryDeep), NOT `coral64`.** Material paints
    text and icons with the `primary` role — `TextButton` labels, `FilledButton.tonal` foregrounds,
    the `TextField` focus label. Mapping the 2.76:1 decorative coral there would put failing text on
    screen through a path no widget in this repo wrote. The decorative `coral64` reaches pixels only
    through `DaybreakColors.primary` and the `sunrise` gradient.
  Name the resulting collision explicitly in a doc comment, because it will confuse the next reader:
  **`ColorScheme.onPrimary` and `DaybreakColors.onPrimary` are different colours on purpose.**
  `ColorScheme.onPrimary` is `clay98` sitting on `coral43` (≈5.6:1, measured by the test, not trusted
  from this line). `DaybreakColors.onPrimary` is `clay11` (#2A1A16), the *only* foreground allowed on
  the coral fill and the sunrise gradient — 6.04:1 at the gradient's worst stop, where white would
  measure 2.76:1 and fail.
  Dark is **authored, not flipped**: `bg` is `plum11` (#241A20), never `#000000`. This is a 6am
  bedside screen; an OLED-true-black void is the cold clinical register the brief rules out.
- **Acceptance** — `grep -n 'fromSeed\|dynamic_color' lib/` is empty. A test asserts
  `scheme.outline == c.borderStrong` and `scheme.primary != c.primary` in the light theme, with the
  reason in the test name.

### 4. Gradients and the warm shadow stack

- **What** — The sunrise and wash gradients as directional tokens; five elevation levels as warm
  multi-layer shadow lists.
- **Where** — `lib/theme/gradients.dart`, `lib/theme/elevation.dart`.
- **Details** —
  **Gradients.** `begin`/`end` are `AlignmentDirectional`, never `Alignment`. `Alignment` does not
  mirror, so in Persian and Kurdish the light would fall from the wrong corner while every other
  element mirrored — a physical-side bug no LTR golden can catch. CSS measures the angle clockwise
  from "to top"; Flutter's box is `-1..1` with **+y downward**, so 138° resolves to `(0.669, 0.743)`:
  ```dart
  static const sunriseLight = LinearGradient(
    begin: AlignmentDirectional(-0.669, -0.743),
    end:   AlignmentDirectional(0.669, 0.743),
    colors: [Color(0xFFF9633F), Primitives.coral64, Color(0xFFFF9A4D), Color(0xFFFFC46A)],
    stops: [0.0, 0.32, 0.68, 1.0],
  );
  ```
  Honest limit, and it must go in the doc comment: `Alignment` components are independent axis
  fractions, so the rendered angle is exactly 138° only on a square box and flattens on a wide hero
  card. The geometric alternative is `topCenter`→`bottomCenter` with
  `transform: GradientRotation((138 - 180) * math.pi / 180)`, **negating the radians under
  `TextDirection.rtl`** because `GradientRotation` has no direction resolution — which is precisely
  why the `AlignmentDirectional` form is the shipped default.
  One gradient per screen, maximum. Two retires the signature.
  **Shadows.** Never `Colors.black`, never Material's `elevation:` — a neutral shadow on a #FFF9F2
  ground reads as grey dirt and drains the warmth the whole emotional brief rests on. Every level is a
  `List<BoxShadow>` tinted `clay42` in light and `plum01` in dark.
  **CSS blur is not Flutter `blurRadius`.** CSS blur `b` means σ = `b/2`; Flutter's `blurRadius` r
  means σ = `0.57735·r + 0.5`, so **r ≈ 0.866·(b−1)**. Writing the CSS number straight in makes every
  shadow ~15% too tight — a hard edge where the system wants a warm lift. Put the conversion in a
  comment beside each layer:
  ```dart
  // shadow-2: 0 2px 4px rgba(140,84,56,.07), 0 10px 24px rgba(140,84,56,.10)
  BoxShadow(color: Primitives.clay42.withValues(alpha: 0.07),
      offset: Offset(0, 2), blurRadius: 2.6),   // css 4  -> 0.866*3
  BoxShadow(color: Primitives.clay42.withValues(alpha: 0.10),
      offset: Offset(0, 10), blurRadius: 19.9), // css 24 -> 0.866*23
  ```
  `glow` is the primary at low alpha (`coral64` light, `coral66` dark), spent on exactly one element
  per screen — the sunrise hero or the primary action.
- **Acceptance** — Every `blurRadius` in the file carries its CSS source and the conversion. No
  `Colors.black` anywhere. An RTL widget test shows the sunrise gradient's warm end at the leading
  corner.

### 5. Typography: the scale, both scripts, and bundled fonts

- **What** — The seven-role scale as a fully-assigned M3 `TextTheme` parameterised by script, the
  app-specific type slots, and Nunito + Vazirmatn bundled with their licences registered.
- **Where** — `lib/theme/daybreak_type.dart`, `lib/theme/daybreak_typography.dart`,
  `assets/fonts/`, `pubspec.yaml`, `lib/bootstrap.dart`.
- **Details** — Values are authoritative in
  `.claude/skills/daybreak-bilingual-type/references/type-scale.md`; a number that disagrees is a bug,
  not a variant. display 72 · title 34 · heading 24 · body-lg 20 · body 17 · label 15 · caption 14.
  **`letterSpacing` is logical pixels; CSS tracking is `em`. Multiply at authoring time.** `-0.045em`
  at 72 is `-3.24`, not `-0.045` — pasting the `em` value gives a result 72× too small that looks like
  it worked.
  **All fifteen `TextTheme` slots assigned.** An unassigned `labelSmall` is 11px, and a `Chip` or
  `NavigationBar` will smuggle it into a screen that never declared it — a 17px-floor violation nobody
  wrote.
  `daybreakTextTheme(DaybreakScript script)` takes `latin` or `perso` and applies the Persian
  transform in one place: `height += 0.14`, every negative tracking clamped to `0` (Perso-Arabic is a
  joined script — tracking snaps the joins), and display hand-set to **58 / 1.15** rather than the
  uniform lift. **This epic ships the function; EPIC-03 supplies the locale that selects the script.**
  The `boldText` weight ladder (400→600→700→800→900, clamped to the shipped font's `wght` maximum)
  lives in the same theme-level transform, never at a call site.
  **`fontWeight` alone does not move a variable font.** Both faces ship as a single variable TTF
  declared with no `weight:` entries, which is *one* declared asset — `fontWeight` selects among
  declared assets and otherwise leaves the default instance (or lets the engine synthesise), so
  every `w600`/`w700`/`w800` in this epic and in EPIC-07–11 can render identically. The weight axis is
  reached through `TextStyle.fontVariations`. In the same one theme-level transform that carries the
  Persian delta and the `boldText` ladder, derive
  `fontVariations: [FontVariation('wght', weight.value.toDouble())]` alongside every `fontWeight` —
  never at a call site. (The alternative is shipping static instances declared with explicit `weight:`
  entries per face; pick one and say which in the file's doc comment.)
  This matters beyond decoration: weight is one of the two non-colour channels carrying selection
  state on chips, segments and tabs, and it is the whole of the `boldText` accessibility response. A
  golden baselined against the defect passes forever, so the test must be a measurement, not a
  picture: **assert that the same string at `w400` and at `w800` lays out to different widths, in
  both faces.**
  `DaybreakTypography` is a fifth `ThemeExtension` for the roles M3 has no slot for: `doseNumeral`
  (display + `FontFeature.tabularFigures()` — 9→10 must not shift the number the user reads every
  morning), `overline` (caption 800, +0.06em…+0.12em tracking, **en/de only**), `dayStateChip`.
  **Fonts.** Download `Nunito-VariableFont_wght.ttf` and `Vazirmatn-VariableFont_wght.ttf` once,
  locally, and commit them with their `OFL-*.txt`. Both are SIL OFL 1.1 — verify from the shipped file,
  not from memory.
  ```yaml
  flutter:
    fonts:
      - family: Nunito
        fonts: [{ asset: assets/fonts/Nunito-VariableFont_wght.ttf }]
      - family: Vazirmatn
        fonts: [{ asset: assets/fonts/Vazirmatn-VariableFont_wght.ttf }]
    assets: [assets/fonts/OFL-Nunito.txt, assets/fonts/OFL-Vazirmatn.txt]
  ```
  Register in `bootstrap()` before `runApp` — an unregistered OFL font makes the licenses page a lie:
  ```dart
  LicenseRegistry.addLicense(() async* {
    for (final f in const ['Nunito', 'Vazirmatn']) {
      yield LicenseEntryWithLineBreaks([f], await rootBundle.loadString('assets/fonts/OFL-$f.txt'));
    }
  });
  ```
  If you subset, keep `--layout-features='*'` (dropping `GSUB`/`GPOS` destroys Perso-Arabic joining)
  and never let the subsetter *instance* the font — a frozen `wght` axis kills the `boldText` ladder.
  `google_fonts` is banned and already refused by `tool/check_bans.sh`.
- **Acceptance** — `flutter run` in airplane mode from a clean install renders Nunito. Pushing
  `showLicensePage` from the placeholder screen lists both faces with their OFL text — **there is no
  Settings → About entry point yet; EPIC-11 builds it (CONTRACTS.md §13) and inherits this evidence.**
  A widget test asserts the same string at `w400` and `w800` measures different widths in Nunito and
  in Vazirmatn. No `fontSize:` or `fontFamily:` outside `lib/theme/`.

### 6. `buildDaybreakTheme` and the day-state quartet

- **What** — The single theme builder, wired into `lib/app.dart`, plus the derived day-state colour.
- **Where** — `lib/theme/daybreak_theme.dart`, `lib/theme/day_state_colors.dart`, `lib/app.dart`.
- **Details** — `ThemeData buildDaybreakTheme(Brightness b, DaybreakScript script,
  {bool highContrast = false})` returns
  `useMaterial3: true`, the hand-authored `ColorScheme`, `daybreakTextTheme(script)`, the resolved
  `fontFamily`/`fontFamilyFallback` pair, all five extensions, `scaffoldBackgroundColor: bg`, and the
  component themes that hold the ≥48dp target floor: `FilledButtonThemeData`,
  `OutlinedButtonThemeData`, `TextButtonThemeData`, `CardThemeData`, `NavigationBarThemeData`,
  `SwitchThemeData`, `InputDecorationTheme`. Buttons get a `minimumSize` floor and **no fixed height**
  — the label at 200% text scale must grow the button, not clip it.
  Both callers pass all three arguments: `buildDaybreakTheme(brightness, scriptFor(locale),
  highContrast: settings.highContrast)`. EPIC-06 and EPIC-14 currently call a one-argument form; the
  script argument is the entire mechanism by which EPIC-03's Persian transform reaches the screen, and
  the `highContrast` flag is how EPIC-11's toggle reaches a palette rather than nothing.
  `lib/app.dart` passes `theme:` and `darkTheme:` and leaves `themeMode: ThemeMode.system` — EPIC-06
  makes it a setting.
  **`DayState` is not declared here.** `enum DayState { taken, missed, today, upcoming }` lives in
  `lib/core/day_state.dart` and is **owned by EPIC-04**, which builds `DayPlan` around it. EPIC-02
  owns only the *mapping* to colour, in `day_state_colors.dart`, and writes it against that
  four-member enum. Until EPIC-04 lands, declare the enum in the test fixture, not in `lib/core/`.
  > **Contract:** CONTRACTS.md §1 — `DayState` has **exactly four** members and EPIC-04 owns the file.
  > The earlier fifth idea, `newDose`, is not a day state: a day is simultaneously `today`, a new-dose
  > day and not yet taken, so one enum value cannot express a real day. **`isNewDose` is a separate
  > `bool` on `DayPlan`.** The `stateNewDose` colour slot is therefore selected by that bool, not by an
  > enum arm, and the `switch` over `DayState` in the palette extension stays exhaustive over four
  > cases. This replaces EPIC-02's earlier "decided here, do not duplicate in the domain layer"
  > instruction, which EPIC-04 and EPIC-09 could not both honour.
  Colour is computed **last** from the value object and is never the state's only channel:
  `stateMissed` is `clay56` (warm taupe), deliberately **not** `danger`. This app is opened every
  morning for 780 days by someone already frightened; red punishes a person for a bad morning. The
  glyph, word and shape that carry the state alongside the colour belong to `daybreak-components` in
  EPIC-07.
- **Acceptance** — The placeholder screen renders warm cream in light and warm plum in dark, switching
  with the OS. The palette extension `switch`es exhaustively over `DayState`'s four members and
  resolves `stateNewDose` from a separate `isNewDose` bool; `lib/theme/` declares no day-state enum of
  its own.

### 7. The high-contrast palette — the third pair

- **What** — A third `ColorScheme` / `DaybreakColors` pair per brightness, selected by
  `buildDaybreakTheme(..., highContrast: true)`, measured to a higher floor than the default palette.
- **Where** — `lib/theme/color_schemes.dart`, `lib/theme/daybreak_colors.dart`,
  `lib/theme/daybreak_theme.dart`, `test/theme/contrast_budget_test.dart`.
- **Details** —
  > **Contract:** CONTRACTS.md §9 — **high contrast is v1.** SPEC §4.5 and §5.4 require the toggle and
  > EPIC-05 stores the `highContrast` column, but no epic built the palette: EPIC-06 task 3 and
  > EPIC-11 task 8 both say "the high-contrast variant selected by EPIC-02's API", and until now that
  > API did not exist. **EPIC-02 owns it.** EPIC-11 wires the switch and owns no colour values;
  > EPIC-14 task 3 then loops **four** themes (light, dark, light-HC, dark-HC), not two.
  This is a *derivation with a measured result*, not a second design. Author it as an override set
  over the base `DaybreakColors` so the two palettes cannot drift apart structurally:
  - `border` → `borderStrong` everywhere (the decorative hairline disappears as a concept).
  - `inkMuted` → `ink`; `inkFaint` → `inkMuted`. Secondary text stops being secondary — for this
    population a caption they cannot read is a caption that is not there.
  - The four tints (`tintPrimary tintSuccess tintWarning tintDanger`) drop to **solid fills** on
    `surface`; a 6% wash over cream is invisible to the eye this mode exists for, and it is the
    background half of every pair it participates in.
  - `stateMissed` stays warm taupe, darkened until it clears the floor. **It does not become
    `danger`** — high contrast changes the luminance, never the emotional register (§9).
  - `primary` stays decorative-only, exactly as in the base palette. Raising the coral to clear 7:1
    would destroy the signature and is not what the toggle promises; the high-contrast path reaches
    text through `primaryDeep`, which is already `ColorScheme.primary`.
  - Gradients keep their stops. `DaybreakColors.onPrimary` (`clay11`) is already the only foreground
    allowed on them, and it is measured at the worst stop.
  Dark high-contrast is authored, not inverted: `bg` stays `plum11`, and the lift comes from the
  foregrounds, not from pushing the ground to `#000000`.
  **The floor is ≥7:1 (WCAG AAA body text) for every text row, and ≥4.5:1 for boundary and state-mark
  rows** — one step up from the base palette's 4.5/3.0. Add the high-contrast lane to the same
  table-driven test as a third and fourth `DaybreakColors` instance, so a new slot cannot be added to
  one palette and forgotten in the other. A row that cannot reach its floor is a slot that needs a new
  primitive, not a lowered floor: add it to `primitives.dart` with its `<hueFamily><L*>` name, and to
  the contrast-budget table in the same commit (`daybreak-tokens` rule 14).
  Honest limit, stated in the doc comment: high contrast is a **palette** swap. It does not change
  type size, spacing or hit targets — those are the text-scale and 48dp floors, which are always on.
- **Acceptance** — `buildDaybreakTheme(b, script, highContrast: true)` returns a `ThemeData` carrying
  all five extensions with the high-contrast values, for both brightnesses. The contrast test runs
  every row against all four palettes and every high-contrast text row measures ≥7:1. A test asserts
  `hc.border == hc.borderStrong` and `hc.inkMuted == hc.ink`, naming the reason. A greyscale golden of
  the day-state quartet in high contrast still answers "which one is which".

### 8. The tests that make the palette a contract

- **What** — Contrast budget, `lerp` completeness, reduced motion, and a greyscale golden.
- **Where** — `test/theme/contrast_budget_test.dart`, `test/theme/theme_extension_test.dart`,
  `test/theme/motion_test.dart`, `test/theme/goldens/`.
- **Details** —
  - **Contrast.** All nineteen rows from `daybreak-tokens/references/contrast-budget.md`, run against
    **all four** `DaybreakColors` instances (light, dark, light-HC, dark-HC — task 7), as a
    table-driven test where each row names its pair, its palette and its
    floor. Text rows require 4.5:1 and high-contrast text rows 7:1; boundary and state-mark rows
    require 3.0:1, and 4.5:1 in high contrast. Daybreak deliberately
    does **not** spend the large-text 3:1 exemption — the 72px dose numeral is the most important
    thing on the screen and is held to the body floor. Add the two rows this epic introduces:
    `ColorScheme.onPrimary` on `ColorScheme.primary`, and `DaybreakColors.onPrimary` on the sunrise
    gradient's **worst stop** (the coral end), since a ratio against a gradient is only meaningful
    there.
    Also assert the carve-outs **negatively**, so the intent survives a refactor:
    `contrastRatio(c.primary, c.surface) < 4.5` in light, with a comment saying this is why `primary`
    is fill-only. A test that goes green when someone "fixes" the coral is a test that lost.
  - **`lerp` completeness.** For each extension, `lerp(a, b, 0.5)` must differ from both endpoints in
    every field that is interpolable. Enumerate the fields explicitly — the failure mode is a field
    added later and forgotten.
  - **Reduced motion.** `resolveMotion(context, DaybreakMotion.of(context).base)` returns
    `Duration.zero` under `MediaQuery(data: MediaQueryData(disableAnimations: true), …)`. Not a
    shorter duration, not a softer curve: a user who asked the OS to stop animations asked for stop.
  - **Greyscale golden.** Render `DayState`'s four members — `taken`, `missed`, `today`, `upcoming` —
    side by side, plus a `today` sample with `isNewDose: true` so the new-dose mark is exercised as
    the separate channel it is, all under a `ColorFilter.matrix` saturation-zero wrapper. If the
    golden cannot answer "which one is which", the quartet is leaning
    on colour alone and the component work in EPIC-07 has a problem to solve now, not in EPIC-14.
- **Acceptance** — All four test files pass. Changing `coral43` to `coral64` in the light
  `primaryDeep` slot turns the contrast test red with a message naming the pair.

### 9. Wire the no-raw-values gate into CI

- **What** — Add `check_raw_values.sh` and `check_font_bundling.sh` to the ban gate from EPIC-01.
- **Where** — `tool/check_raw_values.sh`, `tool/check_font_bundling.sh`, `tool/check_bans.sh`,
  `.github/workflows/ci.yml`.
- **Details** — Copy both from `.claude/skills/design-system-structure/scripts/` **into `tool/`**, and
  call them from the single `tool/check_bans.sh` entry point EPIC-01 established. This file is the
  one raw-values gate in the repo: EPIC-07 task 2 **extends** it with its component patterns
  (`BoxShadow(`, `LinearGradient(`, bare `EdgeInsets.`) rather than creating a second
  `scripts/check_raw_values.sh` with a different rule set, and EPIC-14 appends its a11y patterns the
  same way. Two scripts with the same name in two directories is how a rule tightened in one goes
  silently missing from the other. The raw-values gate
  rejects, **outside `lib/theme/**`**: `Color(0x…)`, `Colors.*` (except `transparent`), `Curves.*`,
  `Duration(milliseconds:|seconds:` (except `Duration.zero`), a literal `BorderRadius.circular(n)`,
  and `fontSize: n`. Strip comments before matching, accumulate every offender, fail once with the
  full list.
  A legitimate new need is **a new token slot, never an `// ignore`** — one place to diff is the whole
  point, and an ignore here is how the palette starts having two sources of truth. And per
  `daybreak-tokens` rule 14, a new or changed slot lands in the contrast-budget table with its test in
  the same commit; an ungated colour is an unverified colour, and the failure mode is silent for
  exactly the population that will not file a bug.
- **Acceptance** — The gate is green on the tree and fails on a planted `Color(0xFF123456)` in
  `lib/features/`, naming the file and line. `check_font_bundling.sh` shows no `google_fonts` in
  `pubspec.lock`.

## Definition of done

- [ ] Every Daybreak hex lives in `lib/theme/primitives.dart`, named `<hueFamily><L*>`; gradient-only
      stops stay inline; no widget reads a primitive
- [ ] All five extensions implement `copyWith` + a field-complete `lerp` + an asserting `of()`, and
      are attached to **every** `ThemeData` the builder can return
- [ ] Slot names are `radiusXs…radiusPill`, `s1…s9`, `level0…level3` + `glow`; `DaybreakRadii`,
      `DaybreakSpacing`, `shadow0…shadow3` and `shadowGlow` appear nowhere
- [ ] Both `ColorScheme`s hand-authored; `outline` = `borderStrong`, `outlineVariant` = `border`,
      `ColorScheme.primary` = `primaryDeep`; no `fromSeed`, no `dynamic_color`
- [ ] Sunrise + wash gradients use `AlignmentDirectional`; the 138° derivation and its square-box
      limit are documented; an RTL test proves the light falls from the leading corner
- [ ] Every shadow is a warm multi-layer `List<BoxShadow>` with its CSS blur conversion
      (`r ≈ 0.866·(b−1)`) in a comment; no `elevation:`, no `Colors.black`
- [ ] All fifteen `TextTheme` slots assigned; tracking authored in `em` and multiplied by size;
      `DaybreakTypography` carries `doseNumeral` with `tabularFigures`
- [ ] Weight reaches the variable faces through `fontVariations('wght')` derived in the one
      theme-level transform, proven by a width-differs test at `w400` vs `w800` in both faces
- [ ] Nunito + Vazirmatn bundled, OFL text shipped and `LicenseRegistry`-registered; `showLicensePage`
      lists both; no `google_fonts` in the lockfile
- [ ] `buildDaybreakTheme(Brightness, DaybreakScript, {bool highContrast})` ships all three arguments;
      a high-contrast `ColorScheme`/`DaybreakColors` pair exists per brightness at a ≥7:1 text floor
- [ ] EPIC-02 declares **no** `DayState`; `lib/theme/day_state_colors.dart` maps EPIC-04's four-member
      enum plus a separate `isNewDose` bool; `stateMissed` is `clay56`, not `danger`, in every palette
- [ ] Contrast test covers all nineteen measured pairs plus the two new ones across all four palettes,
      and asserts the `primary` carve-out negatively
- [ ] Reduced-motion test asserts `Duration.zero`; greyscale day-state golden still answers "which is
      which" in both the default and the high-contrast palette
- [ ] `check_raw_values.sh` + `check_font_bundling.sh` wired into CI and green
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, parity evidence, tests added,
      deferrals
- [ ] CI green
- [ ] Merged to `main`
