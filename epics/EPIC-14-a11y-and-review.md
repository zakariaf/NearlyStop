# EPIC-14 — Accessibility, performance & design review

**Branch:** `epic/14-a11y-and-review`
**Depends on:** EPIC-08, EPIC-09, EPIC-10, EPIC-11, EPIC-12, EPIC-13

## Where we are now

The app is feature-complete. All six surfaces exist under `lib/features/` — `welcome/`, `today/`,
`schedule/`, `progress/`, `plan/`, `settings/`, each with `presentation/<name>_screen.dart` and a
`presentation/widgets/` folder of `const` Daybreak components. `lib/theme/` holds the primitive pool
and the five `ThemeExtension`s (`DaybreakColors`, `DaybreakShapes`, `DaybreakElevation`,
`DaybreakMotion`, `DaybreakTypography`), in **three** colour pairs — light, dark and the high-contrast
variant EPIC-02 ships. `lib/l10n/arb/` carries `app_en.arb`, `app_de.arb`, `app_fa.arb`,
`app_ckb.arb` plus the hand-written `CkbMaterialLocalizations` delegate. Notifications (EPIC-12) and
backup/export (EPIC-13) are wired.

> **Contract:** `epics/CONTRACTS.md` is the arbiter for every cross-epic name used here — the token
> slots (`DaybreakElevation.level0…level3`/`glow`, `DaybreakShapes.radiusXs…radiusPill`), the theme
> builder signature, `LocalDate`/`Milligrams`, and the decision that high contrast is v1. Where this
> epic and an earlier one disagree, CONTRACTS.md wins.

What each previous epic proved was **local to itself**: EPIC-08 through EPIC-11 each ran
`daybreak-visual-parity` over their own screens, each added an overflow matrix for their own widgets,
each asserted their own semantics. Nothing has yet been checked **across the whole app at once**, and
three things have never been checked at all:

- the **largest OS text size on the smallest supported device**, screen by screen, in all four locales;
- the **contrast budget as it actually composites** — EPIC-02's budget test measures token pairs in
  isolation, not the pairs the built screens really put on top of each other;
- **Schedule scroll performance** with a real ~780-day taper behind it, in profile mode, on a floor
  device.

There is also no `docs/design-review/` directory and no sign-off artifact. A ban gate does exist —
`tool/check_bans.sh`, created in EPIC-01 and extended by EPIC-02 and EPIC-07 — and it already covers
physical `EdgeInsets.only(left:)`, `Icons.arrow_back`/`arrow_forward`, raw `Color(0x` outside
`lib/theme/primitives.dart`, and the raw-value patterns. What it does not yet cover is the
a11y-specific set (`withClampedTextScaling`, `FittedBox`, `ellipsis` on a real label, orientation
locks, swallowed overflow exceptions in tests). CI runs format, analyze, codegen-freshness, tests,
ARB parity and the ban gate, and nothing else.

## Why this epic exists

For this audience accessibility is not a quality bar, it is whether the app functions. A 78-year-old
with cataracts running iOS at the largest Dynamic Type setting is not an edge case here — they are the
median user, and the app is opened by them roughly 780 times. A layout that clips the dose numeral at
200% is the same defect class as computing the wrong dose: the person cannot answer *what do I swallow
this morning*. Every previous epic authored accessibility into its own widgets; this epic proves the
composition of them holds, in the combinations no single epic owned — largest scale × smallest device ×
German string length × Sorani script × dark mode × RTL.

It also exists because the per-epic parity checks were, by design, narrow. `daybreak-visual-parity`
runs once per UI epic on that epic's screens; nobody has yet laid all six screens side by side and
asked whether they read as one app. Drift accumulates between epics — a spacing step that got rounded,
a state pill that grew a different radius on Progress than on Schedule — and it is invisible one screen
at a time.

Finally, this is the pass where `design-review-workflow` legitimately runs. That skill is emphatic
that a design review happens **once, at the end, on the release build** — never per task. The build
tasks are done, so its trigger condition is met, and its dated sign-off artifact becomes the
precondition EPIC-15 depends on. Without that artifact there is nothing gating the release except
someone's memory of having looked at the app.

## What we will have when it is done

Every screen survives the largest OS text size with bold text on a 320×640 surface without clipping,
in all four locales — and survives the composed ceiling, where the in-app text-size factor multiplies
an already-maxed OS scaler. Every colour pair the app actually renders is asserted in a pure-Dart test
against WCAG AA in the two normal themes and against a 7:1 floor in the two high-contrast themes —
**four** theme loops, because the high-contrast toggle is a v1 requirement and an unmeasured palette
behind it is a dead setting. VoiceOver and TalkBack read the Today screen as one natural sentence, verified
on real hardware. Every state in the app is legible in a grayscale screenshot. Reduced motion collapses
every animation to its end state. The Schedule list scrolls without a dropped frame on a floor device
with a full 780-day taper loaded, backed by a recorded profile trace. All 24 parity pairs (6 screens ×
{light, dark} × {en, fa}) exist as side-by-side sheets in the PR. And `docs/design-review/` holds a
dated, tracked sign-off naming the commit, the build, the findings, their resolutions and a verdict —
the file EPIC-15 cannot start without.

## Skills to load

| Skill | What it governs here |
|---|---|
| `accessibility-as-code` | The authoring floor being audited: Semantics on every node, never clamp the scaler, never colour alone, ≥44px targets, `boldText`, traversal by `sortKey`. |
| `widget-golden-and-a11y-testing` | The harness (`useDevice`/`pumpApp`), the one-testWidgets-per-tuple overflow matrix, `isSemantics`, the explicit `getSize` tap-target loop, pure-Dart contrast, and the honest limits of `meetsGuideline`. |
| `daybreak-visual-parity` | The full 24-pair matrix, the three-tier standard, and the `de`/`ckb`/200% passes that have no reference image. |
| `run-goldens-rebaseline` | The only sanctioned ritual for re-blessing golden images that an accepted visual FIX moved. |
| `design-review-workflow` | The end-of-build sweep matrix, BLOCKER/FIX/NOTE grading, the single fix round, the on-device pass ordering, and the dated sign-off. |
| `flutter-performance` | Profile-mode measurement on a floor device, `.select` rebuild scoping, sliver laziness, surgical `RepaintBoundary`, no work in `build()`. |
| `adaptive-layout` | Landscape and tablet widths (SPEC §5.4 — people prop tablets on a kitchen table), size-class breakpoints, no orientation lock, `NavigationRail` swap. |
| `motion-and-haptics` | The declared moment catalog whose reduced-motion fallbacks this epic verifies, and the haptic map that must survive motion collapse. |
| `i18n-rtl-l10n` | Directional geometry, numeral systems, bidi isolation, and the German-length / Sorani-script failure modes. |
| `daybreak-components` | The declared degradation order every component must hold at 200%, and the shape-first day-state signals grayscale must still read. |

## Tasks

### 1. A11y and directionality rules added to the ban gate

- **What** — Add the a11y and RTL rule group to the **existing** ban gate, and resolve every hit.
- **Where** — `tool/check_bans.sh` (extended, **not** a new script), `.github/workflows/ci.yml`
  (the ban-gate step already exists — no new job).

  > **Contract:** one script directory (`tool/`) and one entry point (`tool/check_bans.sh`), per
  > `epics/README.md` → *Repo conventions*. EPIC-01 created the accumulate-and-fail-once script,
  > EPIC-02 added the raw-value rules, EPIC-07 added the component rules. This epic appends a rule
  > group; it does not create `tool/check_a11y_gates.sh` or anything under `scripts/`.

- **Details** — **Do not re-add rules EPIC-01 already ships**: `EdgeInsets.only(` with `left:`/`right:`,
  `Alignment.center(Left|Right)`, `Positioned(` with `left:`/`right:`, `TextAlign.(left|right)`,
  `Icons.arrow_(back|forward)`, `Colors.black`/`Colors.white`, and `Color(0x` outside
  `lib/theme/primitives.dart` are already hits there. The **new** a11y group is:
  `withClampedTextScaling`, `FittedBox`, `TextOverflow.ellipsis`,
  `SystemChrome.setPreferredOrientations` (`adaptive-layout` rule 6), and
  `ignoreOverflowErrors`/`takeException()` inside a `tearDown` in `test/`.

  Two rules must be **written narrowly in the script**, because the blunt form bans code EPIC-11 was
  told to write:
  - `textScaleFactor` — `TextScaler.textScaleFactor` is an abstract (deprecated) getter, so
    EPIC-11's `UserTextScaler` **must** implement it and cannot be restructured out of it. Ban the
    *reads and passes* only: `MediaQuery\.textScaleFactorOf`, `\.textScaleFactor\b` as a property
    read, and `textScaleFactor:` as a named argument — with `lib/theme/user_text_scaler.dart` excluded
    by path, since that file is where the override is legally declared. Put a one-line comment at the
    declaration saying the member is required and deprecated, so the next reader does not delete it.
  - `MediaQuery.of(context)` — ban the aspect-getter misuse only:
    `MediaQuery\.of\(context\)\.(size|padding|textScaler|viewInsets|orientation)`. Allow
    `MediaQuery.of(context).copyWith`, which is the only way to build the `MediaQueryData` EPIC-11
    task 8 wraps the app in.

  **A path- or pattern-scoped rule baked into the script is not the forbidden allowlist file.** The
  forbidden thing is a side-car list of files that opt out of a rule that still applies to them; a
  rule that is written to say what it actually means is just a correct rule. Everything else stands:
  per `design-review-workflow`, **a hit is a place a decision must exist**, not automatically a
  defect — resolve each, and where the code is genuinely right, restructure rather than suppress.
  Keep the script POSIX `sh` with `grep -rnE`, accumulate all hits, exit 1 once at the end, and print
  the rule name next to each.
- **Acceptance** — `tool/check_bans.sh` exits 0 on the branch with the new group active; a
  deliberately reintroduced `FittedBox` turns it red; EPIC-11's `UserTextScaler` and its
  `MediaQuery.of(context).copyWith` call site are **green without any allowlist entry**, and a test
  asserts that (add a fixture pair to the script's own self-test: one file that must pass, one that
  must fail).

### 2. Whole-app overflow + fit matrix

- **What** — One overflow/fit matrix per screen, sized so it stays runnable, that proves nothing clips
  at the largest scale on the smallest surface.
- **Where** — `test/a11y/overflow_matrix_test.dart` (new), extending `test/support/harness.dart`.
- **Details** — `setUpAll(loadAppFonts)` is mandatory or the bold axis is inert under Ahem. Loop
  **around** `testWidgets`, never inside — overflow is reported once per `RenderObject`, so a loop
  inside one test silently under-reports every tuple after the first. Axes, deliberately pruned so the
  suite stays under a few hundred cases:
  - `en`: `Device.all` (compact_320, small_360, medium_412) × scale `[1.0, 1.3, 1.5, 2.0, 3.0]` × bold
    `[false, true]`, all six screens.
  - `de`: compact_320 only, scale `[1.0, 2.0]`, bold `[true]` — German is the longest-string locale and
    compact+bold is where it breaks.
  - `fa` and `ckb`: compact_320, scale `[1.0, 2.0]`, bold `[false]` — script height and joining, not
    length.
  - **Composed ceiling** (its own axis, all six screens, `en` + `de`): compact_320 × OS scale `3.0`
    × EPIC-11's in-app text-size factor `2.0` × bold. EPIC-11's `UserTextScaler` **multiplies** the OS
    scaler, so the field worst case is OS-max × app-max, not OS-max — and the audience that maxes the
    OS setting is exactly the audience that then reaches for the in-app slider. This axis is the only
    place the composed number is ever rendered; use whatever composition cap EPIC-11 task 8 declares
    and assert against it rather than against `3.0`.

  Every cell asserts `expect(tester.takeException(), isNull)` **and** a fit assertion: the dose numeral,
  the block header title and the day-row label each `getRect` inside their computed parent rect. A
  clipped `Text` reports no overflow, so the exception check alone is not sufficient (rule 7 of
  `widget-golden-and-a11y-testing`).

  **The fixture is pinned and shared.** Every pump here, every parity capture in task 9, and every
  sweep cell in task 12 uses the same seeded plan and the same clock, defined once in
  `test/fixtures/seeded_taper.dart`: *Prednisolone, current 10mg, target 0mg, strengths 5mg + 1mg,
  halves on, DSNS, active step 10mg → 9.5mg, day 14 of 52, clock pinned to 2025-04-16.* The step is
  10 → 9.5 and not 10 → 9 because CONTRACTS.md §6 takes the largest achievable increment ≤ 10% of the
  current dose. If EPIC-11's parity fixture ever disagrees, this file is the one both read.
- **Acceptance** — Matrix green including the composed-ceiling axis; temporarily hardcoding a
  `SizedBox(height: 48)` on a day row turns at least one `2.0`-scale cell red with a readable message.

### 3. Composited contrast test over the whole token table

- **What** — Replace/extend EPIC-02's isolated budget test with one that measures the pairs the built
  screens actually composite, in all four themes.
- **Where** — `test/a11y/contrast_test.dart` (new), `docs/a11y/contrast-budget.md` (regenerated table).
- **Details** — Pure Dart over colour **values**, never `meetsGuideline(textContrastGuideline)` — that
  matcher screenshots and histograms the layer and false-passes white on `#FAFAFA`. Implement `wcag(a,b)`
  from relative luminance and an APCA `Lc` helper.

  > **Contract:** the builder is
  > `buildDaybreakTheme(Brightness b, DaybreakScript script, {bool highContrast = false})`
  > (CONTRACTS.md §9). Loop **four** themes, not two:
  > `(light, false)`, `(dark, false)`, `(light, true)`, `(dark, true)`.
  > High contrast is v1 — SPEC §4.5/§5.4 require the toggle, EPIC-05 stores the column, and EPIC-02
  > ships the third `ColorScheme`/`DaybreakColors` pair. A four-theme loop is what turns that from a
  > toggle into a verified one. The `script` argument is required and is what reaches EPIC-03's
  > Persian type transform — run the loop for both `DaybreakScript` values so a script-specific
  > `onSurface` override cannot slip past unmeasured.

  The floor depends on the theme: **≥4.5:1** for body ink and meaningful icons in the two normal
  themes, and **≥7:1** for the same pairs in the two high-contrast themes — that is the budget EPIC-02
  authored the palette against, and a high-contrast theme that only clears AA is a dead setting.
  Assert ≥4.5:1 for body ink and meaningful icons on their real surface (`ink`/`inkMuted` on
  `bg`, `surface`, `surfaceRaised`, `surfaceSunken`, and on every `tint*` fill), ≥3:1 for the dose
  display numeral and `borderStrong`. Special cases that only exist because a screen composites them:
  `onPrimary` against **both** endpoint stops of `sunrise` (per `daybreak-components` rule 7 — a
  gradient is not one background); banner body ink on `warningTint`; block-header summary on
  `surfaceSunken`; each of the day-state quartet against the surface its row sits on; and the Progress
  staircase **stroke** against the card fill at both gradient endpoints at ≥3:1 (WCAG SC 1.4.11 — it is
  a graphical object that carries information, and it is the only mark on that screen with no text
  fallback; EPIC-10 paints it in `primaryDeep`, keeping `primary`→`secondary` for the decorative area
  fill underneath). Assert the chroma-only pairs directly (`wcag(stateTaken, surface)`,
  `wcag(stateMissed, surface)`) — that luminance gap is exactly what a grayscale user perceives.
  Finally assert `primary` (#F97350, 2.76:1) is **fill-only** with a source grep: no `TextStyle`/`Icon`
  colour in `lib/` resolves `c.primary`.
- **Acceptance** — Every rendered pair has a row in `docs/a11y/contrast-budget.md` with its measured
  ratio and its floor, **for each of the four themes**; the test fails if a token is nudged past its
  floor, and fails separately if a high-contrast pair drops below 7:1.

### 4. Semantics and traversal audit, screen by screen

- **What** — Assert every screen's semantic tree: roles, labels, live regions, and traversal order.
- **Where** — `test/a11y/semantics_test.dart` (new), fixes across `lib/features/*/presentation/`.
- **Details** — Use `isSemantics(...)` (never the deprecated `containsSemantics`). Per screen:
  - **Today** — the hero card is **one** container node whose label is the SPEC §5.4 sentence,
    e.g. for the pinned fixture *"Today, 10 milligrams: two 5 milligram tablets. Not yet taken."* —
    composed in the notifier from ARB ICU strings, with the visual children under `ExcludeSemantics`.
    The Taken button is `isButton`, `hasTapAction`, and its success announcement is a `liveRegion`.
    The backfill banner is a `liveRegion` and is reachable before the secondary actions.
  - **Schedule** — each day row is one container labelled `weekday, date, dose, tablets, state`; block
    headers are `header: true`; the jump-to-today control is a labelled button.
  - **Progress** — the staircase chart carries one summary `label` describing the trend (the mockup
    already models this in its `aria-label`); stat blocks state their unit in words.
  - **Plan / Settings / Welcome** — every control labelled; the disclaimer sheet's "I understand" is a
    button, and the sheet is not dismissible by an unlabelled scrim tap alone. Settings now has four
    cards, not three (CONTRACTS.md §13): the **Language picker** — whose options are rendered each in
    its own script, so assert each option's semantic label is the *localized language name*, not a tag
    like `ckb`, and that the selected option announces its selected state — and the **About card**,
    whose version row reads as one node (`"NearlyStop, version 1.0.0, build 1"`, not four fragments)
    and whose "View licenses" is a labelled button. `showLicensePage` is Flutter's own screen: assert
    only that it opens and inherits the Daybreak theme, and record anything it does badly as a NOTE.
  Assert traversal with `sortKey`: use `tester.semantics.simulatedAccessibilityTraversal()` and check
  the resulting order equals the **priority** order the screen declared, not the layout order. On Today
  that means dose → state → Taken → backfill → secondary actions.
- **Acceptance** — Every interactive node in all six screens has an asserted role and label; traversal
  order tests pass; no unlabelled `Icon` survives (each is labelled or `ExcludeSemantics`).

### 5. Tap-target measurement pass

- **What** — Measure every interactive target explicitly instead of trusting the built-in guideline.
- **Where** — `test/a11y/tap_targets_test.dart` (new).
- **Details** — `meetsGuideline(androidTapTargetGuideline)` skips every node flush with the view edge,
  so it is advisory only and must be `await expectLater`-ed if used at all. The gate is an explicit
  loop: for each screen, find every node with `hasTapAction`, `getSize` it, assert
  `width >= 44 && height >= 44`. Assert the **Taken** action separately at `height >= 88`
  (`daybreak-components` rule 10). Run the loop at scale 1.0 and 2.0 — a target that is 44 at 1.0 can
  still be 44 at 2.0 if its parent clamps it, which is the bug. Add a semantic assertion that no action
  is long-press-only.
- **Acceptance** — Test green at both scales; shrinking any button min-height below its ladder floor
  turns it red naming the widget.

### 6. Never-colour-alone verification in grayscale

- **What** — Prove every state signal survives desaturation and colour-vision deficiency.
- **Where** — `test/a11y/state_signals_test.dart` (new), `docs/design-review/grayscale/` (sweep output).
- **Details** — Two halves. **Automated:** for each of `taken`/`missed`/`today`/`upcoming`, assert the
  row renders its declared shape (`find.byType(DayStateMarkerPainter)`'s `shape` field, or the painter's
  public value object), its glyph, and its localized label together — shape first, colour derived last.
  Same for chips (selected = fill + 2px `borderStrong` ring + check glyph + w800), the segmented control,
  and the tab bar (active = filled icon variant + w800 + 3px indicator). Add the luminance-gap assertions
  from task 3 so a chroma-only pair cannot slip through. **Manual:** during the sweep (task 12),
  desaturate one screenshot per screen and confirm every state is still identifiable; also run a
  deuteranopia/protanopia/tritanopia simulation pass. Confirm `stateMissed` is still the warm taupe
  `clay56` and has not drifted to `danger` — a missed dose is never red in this app.
- **Acceptance** — Automated assertions green; a reviewer can name every state from the grayscale
  screenshots without seeing the colour versions.

### 7. Reduced motion collapses to zero

- **What** — Verify every declared motion moment has a reduced-motion path that lands on the end state.
- **Where** — `test/a11y/reduced_motion_test.dart` (new), fixes in components that animate.
- **Details** — Pump with `MediaQuery.copyWith(disableAnimations: true)` layered above `MaterialApp`
  (harness already supports the flag pattern). Assert `resolveMotion(context, motion.base)` returns
  `Duration.zero`; assert that after a single `pump()` following an interaction, the widget is already
  in its end state (`SchedulerBinding.instance.hasScheduledFrame` is false and no `Timer` is pending).
  Cover the declared moments: Taken press-scale, the Taken success confirmation, the tab indicator
  slide, the Schedule jump-to-today scroll, the Progress chart draw-in, sheet presentation. Every one of
  these must still **acknowledge** — motion collapsing to zero must not remove the feedback, so assert
  the haptic slot still fires (`HapticFeedback` call recorded through the injected haptic gateway) and
  the `liveRegion` announcement still happens. Also confirm no ambient/repeating animation exists
  without a stop condition (`motion-and-haptics` rule 11) — grep for `repeat(` in `lib/`.
- **Acceptance** — All moments verified; with animations disabled the app has zero scheduled frames at
  rest, and every commit is still acknowledged by haptic + semantics.

### 8. Screen-reader pass on real hardware

- **What** — Hear the app, on both platforms, with the real assistive services.
- **Where** — `docs/design-review/on-device-pass.md` (new, part of the sign-off bundle).
- **Details** — Automation cannot do this: Flutter ships four machine-checkable guidelines (one
  known-broken) and no Switch Access simulation exists at all. Run VoiceOver on a real iPhone and
  TalkBack on a real low-end Android, on the **release** build, in `en` and `fa`. Script the pass:
  swipe through Today top to bottom and write down verbatim what is spoken; confirm it matches the
  SPEC §5.4 sentence and does not fragment into four announcements. Then: tap Taken and confirm the
  success is announced; navigate all five tabs by swipe and confirm each destination announces its
  name and selected state; enter the Plan form, edit the current dose, and confirm the field is
  exitable using only the reader; confirm no focus trap in the disclaimer sheet or any bottom sheet.
  Repeat the traversal with Switch Access / Switch Control on one screen and record honestly whether
  it works. Record device, OS version, date at the top of the file.
- **Acceptance** — The file contains the transcribed Today sentence per platform per locale, a pass/fail
  per checked item, and any failure is filed as a BLOCKER into task 13's findings table.

### 9. Full visual parity matrix — 6 screens × {light, dark} × {LTR, RTL}

- **What** — The complete 24-pair comparison against the committed reference PNGs.
- **Where** — `parity/ref/`, `parity/app/`, `parity/sheets/` (side-by-side HTML + rendered sheets),
  `test/parity/*_parity_test.dart` (extended).
- **Details** — Follow `daybreak-visual-parity` exactly. Crop each frame from
  `design/reference/daybreak-screens-{light,dark}-{en,fa}.png` using the documented rect dump — the
  sheets are 2600×4760, 3 columns × 2 rows, frames in order `01 welcome`, `02 today`, `03 schedule`,
  `04 progress`, `05 plan`, `06 settings`. Crop **out** the mockup's HTML furniture: the 54px drawn
  status bar, the 46px bezel radius, the two shell rings, the drawn home indicator. Capture the app at
  **390×844 logical, DPR 2** with `loadAppFonts()`, `debugDisableShadows = false`, and the shared
  `test/fixtures/seeded_taper.dart` fixture from task 2 (same plan, same pinned clock — a parity sheet
  shot against a different fixture than the sweep is not comparable to it). Basenames match between
  `parity/ref/` and `parity/app/`. Back every claim with
  assertions, not eyeballs: resolved token colours, radii, type sizes and element order at tier
  *exact*; `getRect` measurements at ±2 logical px; a sampled flat fill at ΔE00 ≤ 2. Never sample a text
  pixel. **Fix the implementation, never the reference** — if the reference is wrong, that is a separate
  commit that edits `design/daybreak-screens.html` and regenerates all four PNGs.
- **Acceptance** — 24 pairs exist, the side-by-side contact sheet is pasted into the PR, every
  exact-tier miss is fixed, every tolerance-tier miss is re-measured, and every differs-tier
  observation is recorded once and dismissed.

### 10. German longest-string pass and Kurdish Sorani script pass

- **What** — The two locales the mockup never showed, checked against rules rather than pixels.
- **Where** — `test/parity/de_length_test.dart`, `test/parity/ckb_script_test.dart`,
  `test/golden/ckb_script_golden_test.dart` (real-font lane).
- **Details** — **de** rides the `en` cell: assert the longest ARB value per screen renders without
  overflow at compact_320 × 2.0 × bold, and that no label ellipsizes or shrinks. Identify the longest
  strings programmatically from `app_de.arb` so the test does not rot. **ckb** rides the `fa` cell:
  a real-font golden (`@Tags(['golden'])`, `loadAppFonts`, pinned OS) is the only way to catch tofu —
  Ahem squares would render "fine". Assert Vazirmatn (or the declared Sorani-covering face) is the
  resolved family, that joining forms render (compare a joined form against an isolated one in width),
  and that numerals follow the locale's declared numeral system while **stored** values stay ASCII
  (`i18n-rtl-l10n` rule 6). Confirm the ckb `LocalizationsDelegate` from EPIC-03 is supplying framework
  strings and that no Material control falls back to English.
- **Acceptance** — Both passes green; the ckb golden shows real Sorani glyphs, not boxes.

### 11. Schedule performance pass

- **What** — Find and fix jank on the one list that will hold ~780 days.
- **Where** — `lib/features/schedule/presentation/`, `lib/features/schedule/application/`,
  `docs/perf/schedule-profile.md` (before/after).
- **Details** — Measure first, in **profile** mode on a real floor device (a cheap Android), with a
  seeded full-length taper (10mg → 0 at the SPEC §3.4 step sizes ≈ 780 days, 15 steps × 11 blocks).
  DevTools → Performance, record a fast fling from today back to day one and forward to the end.
  For each over-budget frame decide Build / Layout / Raster. Expected fixes, applied only where the
  trace justifies them: the day list must be a `SliverList` with block headers as
  `SliverPersistentHeader` (never a materialized `ListView(children: [...])`); `generateSchedule` must
  run **once, in EPIC-06's `derivedScheduleProvider`** (CONTRACTS.md §4) with
  `scheduleViewProvider(stepIndex)` selecting from its output — never in `build()`, and never a second
  time per screen; row widgets watch `provider.select(...)` on their own day, not the whole
  schedule; the day-state marker
  `CustomPaint` gets a surgical `RepaintBoundary` and a `shouldRepaint` that is one value compare with
  zero allocation in `paint()`; every row constructor is `const`-able. Record UI **and** raster thread
  numbers before and after; the budget is no frame over 16 ms during the fling. Add a regression guard:
  a widget test asserting only a bounded number of day rows are built for a full-length taper (proving
  laziness), since a frame-time assertion in CI would be a flake.
- **Acceptance** — `docs/perf/schedule-profile.md` holds before/after traces with numbers; the
  laziness regression test is green; no claim of performance is made that was not measured.

### 12. The end-of-build screenshot sweep

- **What** — Shoot the full `design-review-workflow` matrix on the release build.
- **Where** — `docs/design-review/sweep/` (one PNG per cell), `tool/sweep_screenshots.sh`.
- **Details** — Preconditions per the skill: last build task done, CI green, **release** build (a debug
  banner or debug-mode jank wastes the sweep), status bar standardized (`xcrun simctl status_bar …
  override` / an emulator demo-mode equivalent) so shots differ only where the UI differs. Cells:
  every screen (× each meaningful state: empty plan, mid-taper, taper complete, missed-days banner
  showing, export in progress) × {light, dark} × {LTR/en, RTL/fa}, all seeded from
  `test/fixtures/seeded_taper.dart`. **Largest text scale + bold is
  applied to every still**, not a separate axis, and the largest-scale reflow is re-shot on the smallest
  device. Two axes the earlier epics never covered:
  - **High contrast** — one still per screen with the toggle on, light and dark, `en` only. The palette
    is new in EPIC-02 and this is the first time all six screens are looked at in it.
  - **Expanded width** — every screen at 1024×768 landscape and at a 13″ iPad size class, light + dark,
    `en` + `fa`. SPEC §5.4 makes landscape a v1 requirement and EPIC-15 ships
    `TARGETED_DEVICE_FAMILY = "1,2"` on the strength of it, so the `NavigationRail` swap and the
    landscape reflow have to be looked at *here*, not discovered at the iPad screenshot upload.

  Motion moments are captured as short **video**, with reduce-motion off and on — skippability
  and the reduced-motion end state are not judgeable from a still. Filenames
  `NN--<screen>[-<state>]--<theme>[-hc]--<dir>[--expanded].png`, machine-sortable.
- **Acceptance** — Every matrix cell has a file, including the high-contrast and expanded-width axes;
  the inventory is listed in the sign-off, and the grayscale/CVD derivatives from task 6 sit alongside.

### 13. Graded findings, one fix round, dated sign-off

- **What** — Turn the sweep and on-device pass into graded findings, fix them once, and sign off.
- **Where** — `docs/design-review/YYYY-MM-DD-signoff.md` (new, tracked).
- **Details** — Consolidate every observation into one deduped table graded **BLOCKER / FIX / NOTE**.
  Every accessibility-floor violation is a mandatory BLOCKER regardless of how good the screen looks —
  contrast, tap size, text-scale reflow, colour-alone, RTL correctness, reduce-motion safety. Judge each
  screen through the four lenses: floor compliance, identity fidelity (does it deliver Daybreak, not a
  Material default), parity-or-better against the reference, and motion moments. Then **exactly one fix
  round**: fix all BLOCKERs and FIXes as one scoped unit, re-run gates and tests, re-shoot only the
  affected cells (overwriting — the folder stays one truth), and verify each finding against its new
  shot. Open no new critique during verification; new observations become NOTEs on the backlog. A
  surviving BLOCKER means no sign-off and an escalation, not a second round. Do the destructive
  on-device steps **last**:
  - **rotate every screen**, including mid-form on Plan and mid-scroll on Schedule, and confirm no
    state loss, no crash and no lost keyboard focus (this is the on-device half of the expanded-width
    axis in task 12);
  - **export → wipe → import**, on device, and confirm the taper comes back whole. Include picking the
    backup file out of Files / Drive on **both** platforms — a custom extension is not selectable on
    iOS without the document-type declaration EPIC-13/EPIC-15 own, and a greyed-out file in the picker
    is a BLOCKER, not a NOTE;
  - feed import a **truncated** and a **hand-corrupted** backup and confirm a visible error and an
    intact store;
  - trigger a known crash and confirm the log symbolizes and carries no user content.

  > **Contract:** the "install the previous release and upgrade in place" step is **deferred to the
  > v1.1 gate**, and this is deliberate, not an omission. Per CONTRACTS.md §11 the app ships **schema
  > v1 at v1.0.0** — the artificial v2-with-a-dead-column is gone — so there is no earlier artifact
  > whose upgrade would exercise anything, and a same-schema install-over would record a false pass on
  > the highest-consequence line in the release gate. What replaces it here is **verifying the
  > fixture-based migration evidence exists and is green**, not re-running it by hand:
  > EPIC-05's `stepByStep` harness against the generated v2 fixture, and EPIC-13's `upgradePayload`
  > ladder against a v1-header backup payload. Both are pure tests, both run in CI, and the sign-off
  > cites them **by test name and file** on the SPEC §7 "app update must migrate" line, with the words
  > *"no on-device upgrade path exists at v1.0.0; first exercised at v1.1"* written out so nobody
  > later reads a tick as an on-device pass. From v1.0.1 onward the previous **store** build is the
  > artifact to install over, and that step returns to this list.

  The sign-off records date, reviewer, commit sha, build flavour, the matrix inventory, the findings
  table with resolutions, and a verdict line.
- **Acceptance** — The sign-off file exists, is committed, says SIGNED OFF, and every BLOCKER/FIX in it
  is marked resolved with the commit that resolved it. The migration line names the two fixture tests
  and carries the v1.1 deferral sentence verbatim; EPIC-15 task 12 cites this record rather than
  re-running it.

### 14. Re-baseline the goldens an accepted FIX moved

- **What** — Bless only the golden images that the fix round legitimately changed.
- **Where** — `test/**/goldens/*.png`, `test/parity/**`.
- **Details** — Follow `run-goldens-rebaseline` literally. Green the real assertions (geometry,
  overflow, contrast, semantics) **first** — a golden asserts nothing and will happily bless clipped
  text. Re-baseline only in the pinned blessing environment with `loadAppFonts()` in effect, scoped
  `flutter test --update-goldens --tags golden`. Open **every** changed PNG by eye; an image you did not
  expect is a regression — revert and fix the code. Delete orphan PNGs left by renamed tests. Remove
  `failures/` artifacts. Prove it by re-running without the flag, twice. Commit the images **alone**
  with a message naming the cause, e.g. `test(goldens): rebaseline schedule rows — marker 24→28px
  (design review FIX-07)`.
- **Acceptance** — `flutter test --tags golden` green without the flag twice in a row; no orphans; no
  `--update-goldens` anywhere in `.github/workflows/`; images in their own commit.

## Visual parity

**Reference:** `design/reference/daybreak-screens-{light,dark}-{en,fa}.png` — all four sheets, all six
frames each. **Frames:** `01 welcome`, `02 today`, `03 schedule`, `04 progress`, `05 plan`,
`06 settings`, in the grid's own order (3 columns × 2 rows at the documented 1300×2380 CSS capture).
**Variants:** the complete 24-pair matrix — every frame × {light, dark} × {LTR/en, RTL/fa} — plus the
**five** no-reference passes: `de` longest-string (rides the `en` cells), `ckb` script/numerals (rides
the `fa` cells), 200% text scale judged against each component's **declared degradation order**,
**high contrast** (EPIC-02's third palette — the mockup has no high-contrast sheet, so this is judged
against the ≥7:1 budget and the degradation order, never against a PNG), and **expanded width**
(landscape / 13″ iPad — judged against `adaptive-layout`'s breakpoint rules).

**What must match exactly:** token values (hexes; the `DaybreakShapes` radii `radiusXs…radiusPill` =
`8/12/16/24/32/pill` and the spacing ramp `s1…s9` = `4→48`; `DaybreakElevation.level0…level3`/`glow`;
type sizes and weights), element order and nesting, state signals as shape + glyph + label together
(`missed` is `stateMissed` warm taupe, **never** `danger` — CONTRACTS.md §9),
every localized string against the ARB, and RTL mirroring of chrome, chevrons, directional insets and
the sunrise gradient's `AlignmentDirectional` origin. **What is measured within tolerance:** spacing and
component dimensions at ±2 logical px, sampled flat fills at ΔE00 ≤ 2, gradient midpoints at ΔE00 ≤ 3.
**What is not compared:** glyph rasterisation, antialiasing, gradient banding, shadow falloff, and every
piece of the mockup's phone chrome. Method, capture geometry and the mismatch decision tree are
`daybreak-visual-parity`'s; this epic runs it at full width and pastes the contact sheet into the PR.

## Definition of done

- [ ] The a11y rule group added to the **existing** `tool/check_bans.sh` (no second script, nothing under `scripts/`); green with EPIC-11's `UserTextScaler` in the tree and no allowlist file
- [ ] Overflow + fit matrix covers all six screens at compact_320 × 200% × bold in `en`, `de`, `fa`, `ckb`, plus the composed OS-3.0 × app-2.0 ceiling axis in `en` + `de`
- [ ] Composited contrast test loops **four** themes — light, dark, light-high-contrast, dark-high-contrast — at ≥4.5:1 normal / ≥7:1 high contrast; `docs/a11y/contrast-budget.md` regenerated with a row per pair per theme
- [ ] `primary` proved fill-only; no text or icon in `lib/` resolves it; the Progress staircase stroke measured ≥3:1 against the card fill at both gradient endpoints
- [ ] Semantics asserted per screen with `isSemantics`; Today reads as the SPEC §5.4 sentence; traversal asserted against priority order; Settings' four cards covered, language options labelled by localized name and About's version row read as one node
- [ ] Every tap target measured ≥44×44 at scale 1.0 and 2.0; Taken ≥88
- [ ] Every state legible in grayscale and under CVD simulation; `stateMissed` still warm taupe, never red
- [ ] Reduced motion collapses every declared moment to its end state, with haptic and live-region feedback intact
- [ ] VoiceOver and TalkBack passes recorded on real hardware, in `en` and `fa`, with transcribed output
- [ ] All 24 parity pairs captured, asserted and pasted into the PR; `de` and `ckb` passes green
- [ ] Schedule profiled on a floor device with a 780-day taper; before/after recorded; no frame over 16 ms; laziness regression test added
- [ ] Full sweep matrix shot on the release build, including states, high contrast, expanded width (landscape + 13″ iPad), videos of motion moments, and largest-scale reflow on the smallest device
- [ ] Findings graded, one fix round completed, destructive on-device steps run last, dated sign-off committed with a SIGNED OFF verdict
- [ ] Migration evidence cited by test name (EPIC-05's v2-fixture `stepByStep` test + EPIC-13's `upgradePayload` ladder test); the on-device install-over-previous-release step recorded as **deferred to the v1.1 gate**, with the reason written out
- [ ] Goldens re-baselined only where a FIX moved them, in their own commit
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, parity evidence, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
