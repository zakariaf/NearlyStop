# EPIC-07 — Daybreak component library

**Branch:** `epic/07-component-library`
**Depends on:** EPIC-02 (the Daybreak token layer in `lib/theme/`: primitives, the five
`ThemeExtension`s, the hand-authored `ColorScheme`s including the high-contrast pair at the ≥7:1
floor, `resolveMotion`, the contrast-budget test),
EPIC-06 (the app shell, the `pumpApp` harness at `test/support/harness.dart`, and the placeholder tab
bar this epic replaces).

> **Contract:** `CONTRACTS.md` §9 — **EPIC-07 is authoritative for component token values.**
> EPIC-08/09/10 reference a component *by name* ("per EPIC-07's `DoseHeroCard`") and carry **no token
> values of their own**. Where this epic and a screen epic disagreed, the conflict was resolved
> against the reference PNGs and the winner written here; those five resolutions are marked
> **Resolved against the reference** in the tasks below. If a screen epic still states a token value
> for a component this epic owns, this file wins and the screen epic's line is a leftover.

## Where we are now

The app launches, routes between five placeholder screens, restores its theme before first paint and
speaks four languages. The Daybreak values all exist as slots. What does not exist is a single piece of
the app's actual visual vocabulary: there is no dose card, no day row, no block header, no Taken
button, no strength chip. `lib/features/*/presentation/widgets/` directories are empty, and the tab bar
is a stock Material `NavigationBar` that EPIC-06 explicitly labelled temporary.

## Why this epic exists

`daybreak-components` describes NearlyStop's UI as *a small closed set of recipes* — twelve of them.
Every one of the five screens is an arrangement of those twelve. Building them once, here, with their
own tests, means EPIC-08 through EPIC-11 are layout epics rather than invention epics, and it means the
accessibility properties this population depends on are proven in one place instead of re-argued five
times.

The properties in question are not decoration. Shape is the primary signal for day state because a
grayscale printout, a deuteranopic reader and a screen reader all have to answer *"did I take it?"* —
a filled dot, a hollow ring, a ring-with-core and a dashed circle answer it; four colours do not. The
Taken button is 88 points tall because it is pressed by a 74-year-old with a tremor, half-awake,
one-handed, 780 times. The dose numeral never shrinks because a `FittedBox` turns a loud layout failure
into a quietly wrong number on a phone. These are correctness properties with visual consequences, and
they belong to components, not to screens.

Doing it before any screen also settles the parity question at the right altitude: if the hero card's
radius, gradient and shadow match the reference, then every screen that contains a hero card matches on
that count for free — and the screen epics compare *arrangement* rather than re-litigating tokens.

## What we will have when it is done

Twelve named, `const`-constructible widget classes, each reading only Daybreak slots and taking
pre-formatted, pre-localized primitives — no `ref`, no drift row, no `DateTime`. A golden suite that
holds each of them still in light and dark, English and Persian, at 100% and 200% text scale. A real
Daybreak tab bar in the shell. And a raw-value gate in CI that fails the build the first time a hex,
radius, duration or `fontSize` appears outside `lib/theme/`.

## Skills to load

| Skill | What it governs here |
|---|---|
| `daybreak-components` | The twelve recipes, their thirteen non-negotiable rules, the degradation orders, the anti-pattern list — this epic is its implementation |
| `daybreak-tokens` | Which slot each part reads; the canonical extension and slot names |
| `daybreak-visual-parity` | The three-tier standard and the per-component crop comparison against the four reference PNGs |
| `widget-composition` | Class-not-method, `const` discipline, dumb views, `EdgeInsetsDirectional` everywhere |
| `custom-canvas-and-gestures` | `SunriseArcPainter` and the four day-state markers: token snapshot in fields, `shouldRepaint` over every field, no `BuildContext` in `paint()` |
| `adaptive-layout` | The `NavigationRail` swap, the segmented control's reflow to a vertical list above 1.5× scale, chips that wrap rather than scroll |
| `ui-states-and-feedback` | The empty state, the persistent (never `SnackBar`) backfill banner, and the confirm flow destructive buttons route through |
| `accessibility-as-code` | `Semantics` roles and containers, never-colour-alone, ≥44 targets, contrast against the composited background, no `textScaler` clamping |
| `widget-golden-and-a11y-testing` | The golden lanes, `loadAppFonts`, `debugDisableShadows`, and the a11y guideline assertions |
| `motion-and-haptics` | Press feedback = scale-to-0.98 over `motion.fast` **plus** `HapticFeedback.selectionClick()`, so it survives reduced motion |

## Tasks

### The twelve recipes, numbered

Everything in this epic — the task list, the parity table, the golden count and the definition of
done — refers to these twelve by number. A "recipe" is one golden-bearing unit, which is why the
button ladder counts once and a painter counts with the widget that owns it.

| # | Recipe | Class(es) | Task |
|---|---|---|---|
| 1 | Dose hero card | `DoseHeroCard`, `SunriseArcPainter` | 3 |
| 2 | Day-state row | `DayStateRow`, `DayStateMarker` | 4 |
| 3 | Block header | `BlockHeader`, `BlockHeaderDelegate` | 5 |
| 4 | Button ladder | `PrimaryPillButton`, `SecondaryButton`, `TertiaryButton`, `DestructiveButton`, `TakenButton` | 6 |
| 5 | Strength chip | `StrengthChip` | 7 |
| 6 | Method segmented control | `MethodSegmentedControl` | 7 |
| 7 | Tab bar | `DaybreakTabBar` (+ rail variant) | 7 |
| 8 | Backfill banner | `BackfillBanner` | 8 |
| 9 | Progress stat block | `ProgressStatBlock` | 8 |
| 10 | Disclaimer sheet | `DisclaimerSheet` | 8 |
| 11 | Empty state | `TaperEmptyState` | 8 |
| 12 | Confirm sheet + undo | `ConfirmSheet`, `UndoRow` | 8 |

### 1. Settle the slot names, and where shared widgets live

- **What** — Resolve two naming inconsistencies before writing 12 files against them, and fix the
  directory question.
- **Where** — `lib/theme/` (read only), `epics/EPIC-07-component-library.md` follow-up note in the PR,
  `lib/features/shared/presentation/widgets/`.
- **Details** — **RESOLVED before this epic starts — no decision needed here.** The slot names were
  reconciled across the skills on 2026-08-22: `daybreak-tokens` is the authority and the other two
  skills were corrected to match it. The API is `DaybreakColors`, `DaybreakShapes` (radii
  `radiusXs…radiusPill` **and** the spacing ramp `s1…s9`, plus `hairlineWidth`, `focusRingWidth` and
  the `cardShape()`/`heroShape()`/`pillShape()`/`sheetShape()` factories), `DaybreakElevation`
  (`level0…level3`, `glow`), and `DaybreakMotion`. The names `DaybreakRadii`, `DaybreakSpacing`,
  `shadow0…shadow3` and `shadowGlow` no longer appear anywhere and must not be reintroduced.
  `DaybreakScript` is an enum owned by `daybreak-bilingual-type`, not a `ThemeExtension` — leave it
  where it is. Read `lib/theme/` as EPIC-02 shipped it and use exactly that; do not add aliases.
  Placement: recipes owned by one screen live under that feature
  (`features/today/presentation/widgets/dose_hero_card.dart`). Recipes used by three or more screens —
  the button ladder, the empty state, the banner, the tab bar — live under
  `features/shared/presentation/widgets/`, which keeps `daybreak-components` rule 1's path shape
  intact without inventing a parallel `lib/ui/` tree.
  **Shorthand used in the tasks below:** `c.` = the resolved `DaybreakColors`, `r.` = `DaybreakShapes`
  radii, `s.` = `DaybreakShapes` spacing, `e.` = `DaybreakElevation`, `m.` = `DaybreakMotion`. The
  identifiers written here are the real ones — `r.radiusLg`, `s.s5`, `e.level1`, `e.glow` — so a task
  line can be copied into code unchanged.
- **Acceptance** — No component file imports a slot name that does not exist in `lib/theme/`; no alias
  or re-export layer was added.

### 2. The raw-value gate

- **What** — Extend the gate EPIC-02 already wired into CI. **Do not create a second script.**
- **Where** — `tool/check_raw_values.sh` (EPIC-02's, extended in place), `.github/workflows/ci.yml`
  (already wired — no new step).
- **Details** — `tool/` is the project's one script directory and `tool/check_bans.sh` its one
  entry point (EPIC-01's accumulate-and-fail-once model); a `scripts/check_raw_values.sh` with a
  second pattern list is how a rule tightened in one place goes silently missing in the other.
  This epic **adds four patterns** to the existing list: `BoxShadow\(`, `LinearGradient\(`,
  `Curves\.`, `EdgeInsets\.` (bare, non-directional). EPIC-02 already covers `Color\(0x`, `Colors\.`,
  `Duration\(`, `fontSize:` and `BorderRadius.circular\([0-9]`. Scope stays `lib/` excluding
  `lib/theme/` and generated files; print file:line and exit 1 on any hit. Two deliberate allowances,
  both commented in the script: `EdgeInsets.zero` and `Duration.zero`. **`// ignore:` is not an
  escape hatch** — a genuinely new aesthetic need is a new slot in `lib/theme/`.
  The `Curves\.` pattern is the one screens trip over: **every curve comes from `DaybreakMotion` via
  `resolveMotion`**, so a scroll animation is `m.easeOut`, never `Curves.easeOutCubic`. EPIC-09's
  jump-to-today control is the known offender — it is named here because this epic owns the gate that
  will fail it.
- **Acceptance** — One `check_raw_values.sh` exists in the repository, under `tool/`; it is green on
  `main` after this epic and red if a hex, a bare `EdgeInsets` or a `Curves.` is pasted into any
  component.

### 3. Dose hero card and `SunriseArcPainter`

- **What** — The Today screen's reason to exist: one gradient card, one number, one action.
- **Where** — `lib/features/today/presentation/widgets/dose_hero_card.dart`,
  `.../widgets/sunrise_arc_painter.dart`.

> **Resolved against the reference (1 of 5).** The card radius is **`r.radiusLg`**, not `r.radiusXl`:
> `design/daybreak-screens.html` `.hero` is `border-radius: var(--r-lg)`. EPIC-08 task 5 and its
> parity list already say `r.lg` and were right; this epic was wrong and is corrected here. The
> shadow slot is **`e.glow`** (`--shadow-glow`) — the name `shadowGlow` does not exist
> (`CONTRACTS.md` §9), so EPIC-08's `e.shadowGlow` is a sweep target, not a design difference.
> Padding is `s.s5` on all sides, matching `.hero`. EPIC-08 states none of these values itself; it
> says "per EPIC-07's `DoseHeroCard`".
- **Details** — `DecoratedBox` with `gradient: c.sunrise` (the **only** component allowed it, once per
  screen), `BorderRadius.all(r.radiusLg)`, `boxShadow: e.glow` (reserved for this card). Contents: date
  stamp, the day-kind badge (*"New dose day"* — glyph **and** word, never colour alone), the numeral in
  `displayLarge` `w800` with `FontFeature.tabularFigures()`, the `mg` unit in `titleLarge` `w600`
  baseline-aligned, the tablet line with the pill glyph, and the Taken action.
  Constructor takes primitives only: `doseText`, `unitText`, `tabletsText`, `dateText`, `dayKindLabel`,
  `isTaken`, `onTaken` — the Notifier formats; the widget paints.
  Semantics: **one** container — `Semantics(container: true, label: …)` with visual children under
  `ExcludeSemantics`, so VoiceOver reads *"Today, 9 milligrams: one 5 milligram tablet, four 1
  milligram tablets. Not yet taken."* as one sentence (`SPEC.md` §5.4), not four fragments. The Taken
  button keeps its own `Semantics(button: true)` and a `liveRegion` confirmation.
  Degradation order, implemented and commented (`daybreak-components` rule 6): arc drops above 1.6×
  scale → the horizontal `Row` becomes a `Column` → the caption's second line goes. **The numeral never
  shrinks**: no `FittedBox`, no computed `fontSize`, no `ellipsis`.
  `SunriseArcPainter` takes `Color arcColor, double strokeWidth, double sweep, double progress` as
  fields snapshotted at the widget layer; `paint()` never sees a `BuildContext`; `shouldRepaint`
  compares every field. It is `ExcludeSemantics` and decorative-only — it is the one place the 2.8:1
  pair is allowed, and it must never carry text or a meaningful outline.
- **Acceptance** — A widget test asserts `onPrimary` ≥ 4.5:1 against **both** sunrise endpoints in both
  themes; a 200% golden shows the arc gone, the column layout, and the numeral at full size with no
  overflow.

### 4. The four day-state rows

- **What** — `DayStateRow` with shape as the primary signal.
- **Where** — `lib/features/schedule/presentation/widgets/day_state_row.dart`,
  `.../widgets/day_state_marker.dart`.

> **Resolved against the reference (2 of 5).** The marker is **26 logical px**, not 28
> (`.srow .mark` is `26px` in `design/daybreak-screens.html`); EPIC-09 task 5 already said 26 and was
> right. The row itself is `c.surface`, 1px `c.border`, `r.radiusMd`, min height 64, padding
> `s.s3`/`s.s4` — also from `.srow`. The four **shapes** deliberately diverge from the reference,
> which distinguishes states partly by fill: shape-as-primary-signal is the grayscale/deuteranopia
> requirement argued above, and `daybreak-visual-parity` puts it in the "judged, not matched" tier.
> EPIC-09 states none of these values; it says "per EPIC-07's `DayStateRow`".

- **Details** — Four states, four shapes, each pairing a glyph **and** a localized text label with its
  colour. The `DayState` enum is EPIC-04's `{ taken, missed, today, upcoming }` — exactly four
  (`CONTRACTS.md` §1); `isNewDose` is a separate bool, never a fifth member:
  | State | Shape | Glyph | Colour slot |
  |---|---|---|---|
  | taken | filled disc | `Icons.check` | `c.stateTaken` |
  | missed | hollow ring, 3px stroke | `Icons.remove` | `c.stateMissed` |
  | today | ring + filled core | `Icons.circle` | `c.stateToday` |
  | upcoming | dashed circle, 2px, faint | none | `c.inkFaint` |
  **`missed` is `c.stateMissed` — the warm taupe `clay56` — everywhere it appears: the marker's ring,
  the row's dashed border, and the state *word* at the row's end. It is never `c.danger`, and the
  danger-tinted `dangerFill`/`tintDanger` slots are not used by this row at all.** This was argued
  and decided in EPIC-02 task 6 (`CONTRACTS.md` §9): red punishes a person for a bad week, on a
  screen they will open for 780 days, and `SPEC.md` §7 says a missed day does not block progress.
  Two known contradictions, both wrong, both resolved here: EPIC-09 task 5 and its parity list say
  the missed word is `danger` — **strike it**; and `design/daybreak-screens.html` itself still
  carries `.srow.missed .sstate{color:var(--danger)}`, which makes the reference PNG wrong on this
  one detail. Per the parity rule, the HTML is corrected first and all four PNGs are regenerated in
  their own commit; do that in this epic's branch rather than matching a mistake. EPIC-14 task 6
  ships the test that catches the drift if it ever returns.
  Marker is a `CustomPaint` at a fixed 26 logical px so the states scan as a column of glyphs down the
  list edge. Row content: weekday, date, dose, tablets, state (`SPEC.md` §4.2). `today` additionally
  carries **position and weight**: `w800` label, a 2px `c.stateToday` border and `e.level2` while
  other rows are flat on `c.surface` with a hairline `c.border`. A row whose dose differs from the
  previous day adds the `newDose`
  marker: `c.stateNewDose` + a direction glyph + the word — a dose change is exactly where this
  population makes mistakes.
  A row for an unachievable dose renders the flag text instead of a tablet breakdown (`SPEC.md` §3.3 /
  §7) — **never a rounded number**.
- **Acceptance** — A grayscale golden of all four states still answers "was this taken?"; a semantics
  test reads each row as a sentence including the state word.

### 5. Block header

- **What** — The component that replaces the forbidden month grid.
- **Where** — `lib/features/schedule/presentation/widgets/block_header.dart`.

> **Resolved against the reference (3 of 5).** EPIC-09's description is the correct one and is
> adopted here wholesale: `.blockhead` in `design/daybreak-screens.html` is `surface-raised` fill,
> 1px `border` **all round**, `--r-lg`, `--shadow-1`, `--s-4` padding, with a 36×36 `--r-sm` glyph
> tile (`surface` fill, `primaryDeep` glyph, 1px `border`) leading a two-line title/summary. The
> current block is `tint-primary` fill with a border mixed 40% from `primary`. This epic's earlier
> `surfaceSunken` / bottom-hairline-only / top-corners-`radiusMd` / no-glyph description is **wrong**
> and is replaced. EPIC-09 keeps the pinning, the grouping and the copy; it states no token values.

- **Details** — `const BlockHeader({required this.title, required this.doseSummary, required this.dayCount, required this.isCurrent, required this.isCompleted})`,
  all strings pre-localized. Fill `c.surfaceRaised`, 1px `c.border` on every edge, `r.radiusLg`,
  `e.level1`, padding `s.s4`, gap `s.s3`. Leading 36×36 glyph tile at `r.radiusSm`, `c.surface` fill,
  `c.primaryDeep` glyph, 1px `c.border`. Title `titleLarge` `w800`; summary `bodyMedium` `w700` in
  `c.ink` (not `inkMuted` — the reference sets `.bh-txt` to full `ink` and this is the teaching
  sentence). Current block: `c.tintPrimary` fill and a `c.primary`-derived border — expose it as a
  `c.borderCurrentBlock`-style slot rather than a `Color.lerp` at the call site, so the raw-value gate
  stays honest. Ships as a
  `SliverPersistentHeader` delegate (`BlockHeaderDelegate`) with `pinned: true` so the block a user is
  scrolling through is always identified. Completed blocks tint `c.tintSuccess` **and** prefix a check
  glyph **and** append the word.
  The header is the teaching device (`SPEC.md` §4.2): *"Block 3 of 11 — one day at 9mg, then 4 days at
  10mg"*. Its `maxExtent` is computed from the text's laid-out height so it grows at 200% scale rather
  than clipping — a fixed `maxExtent` is the classic bug here.
- **Acceptance** — At `TextScaler.linear(2.0)` in German the header wraps to three lines with no
  clipping; the sliver still pins.

### 6. Button ladder

- **What** — Five variants, one of them oversized.
- **Where** — `lib/features/shared/presentation/widgets/daybreak_buttons.dart`
  (`PrimaryPillButton`, `SecondaryButton`, `TertiaryButton`, `DestructiveButton`, `TakenButton`).

> **Resolved against the reference (4 of 5).** The Taken button is **`c.surface` fill with `c.ink`
> ink** — it is the reference's `.btn-onhero`, a light button *on* the sunrise card, not a second
> sunrise surface on top of the first. EPIC-08 task 5 and its parity list already say `surface` fill
> and `ink` label and were right; this epic's "as primary / `c.onPrimary`" is **wrong** and is
> replaced. Two deliberate deviations from the reference, both accessibility and both kept: the class
> is **`TakenButton`** (not "`PrimaryPillButton` variant `onHero`" — one named class, one golden, one
> semantics contract; EPIC-08 references it by that name), and its min height is **88**, not the
> reference's 56, because it is pressed one-handed by a 74-year-old with a tremor 780 times. Its
> shadow is `e.level2`; the `e.glow` slot stays reserved for the card beneath it.

- **Details** —
  | Variant | Fill | Ink | Border | Min height |
  |---|---|---|---|---|
  | Primary pill | `c.sunrise`, `r.radiusPill` | `c.onPrimary` | none | 56 |
  | Secondary | `c.surface`, `r.radiusPill` | `c.ink` | `c.borderStrong` 2px | 56 |
  | Tertiary | transparent | `c.primaryDeep` | none | 48 |
  | Destructive | `c.tintDanger`, `r.radiusPill` | `c.danger` | `c.dangerFill` 1px | 56 |
  | **Taken** (on hero) | `c.surface`, `r.radiusPill` | `c.ink` | none, `e.level2` | **88**, full width inside the hero's margins |
  Secondary is also corrected to the reference's `.btn-secondary` (`surface` fill, `ink` label, 2px
  `borderStrong`) — the previous `tintPrimary`/`primaryDeep` pair read as a weak primary and did not
  clear contrast comfortably in dark. No other epic states secondary's values, so nothing else moves.
  Every variant: `Semantics(button: true, label: …)`, `HitTestBehavior.opaque`, single tap, **no
  long-press-only path**. Press = scale to 0.98 over `motion.fast` via `resolveMotion` **plus**
  `HapticFeedback.selectionClick()`, so confirmation survives reduced motion where the scale collapses
  to `Duration.zero`. Disabled state changes fill *and* adds the word — never opacity alone.
  Destructive routes through **recipe 12's `ConfirmSheet`** (task 8) — the button itself never acts
  directly. That sheet is built in this epic precisely so the rule is enforced by a real widget with
  a real golden rather than by a sentence: it is what makes `SPEC.md` §5.3's "export before anything
  destructive" implementable in EPIC-11/13, and EPIC-08's Hold/Flare confirmations use it too.
  Labels are never `toUpperCase()`d: it no-ops in Persian and shouts in English.
- **Acceptance** — `androidTapTargetGuideline` and `iOSTapTargetGuideline` pass for every variant; the
  Taken button measures ≥88 logical px tall at 1.0 scale and grows, never shrinks, at 2.0.

### 7. Strength chip, method segmented control, tab bar

- **What** — The three selection components, all of which must signal selection without colour.
- **Where** — `lib/features/plan/presentation/widgets/strength_chip.dart`,
  `.../widgets/method_segmented_control.dart`,
  `lib/features/shared/presentation/widgets/daybreak_tab_bar.dart`.
- **Details** —
  - `StrengthChip`: `r.radiusPill`, min 44×44, `c.surfaceRaised` / `c.border`. Selected =
    `c.tintPrimary` + a 2px `c.borderStrong` ring + a check glyph + `w800`. Laid out in a `Wrap`,
    **never a horizontal scroller** — a strip hides options at 200% scale.
  - `MethodSegmentedControl`: a `Row` of equal segments on `c.surfaceSunken`, `r.radiusMd`; selected segment
    is a raised `c.surface` tile with `e.level1` and `w800`. `Semantics(inMutuallyExclusiveGroup: true,
    selected: …)` per segment. **Above 1.5× text scale it reflows to a vertical radio list** — an
    equal-width row of Persian or German method names cannot survive otherwise. Options are DSNS
    (default), percentage, fixed mg (`SPEC.md` §4.4).
  - `DaybreakTabBar`: five destinations, `c.surface` with a top hairline `c.border`, bar height 96
    including the 26pt bottom inset, each destination ≥44 wide and ≥52 tall at `r.radiusMd`.
    **Resolved against the reference (5 of 5):** active = **a `c.tintPrimary` pill behind the icon**
    (52×30, `r.radiusPill`) + filled icon variant + `w800` label in `c.primaryDeep`; inactive =
    outlined icon + `w600` + `c.inkMuted`. There is **no 3px indicator bar** — that was this epic's
    invention; `.tab[aria-current]` in the reference tints the icon capsule, and EPIC-08's parity
    list ("the active Today tab's `tintPrimary` icon pill and `primaryDeep` label") already described
    it correctly. **Labels always visible.** Replaces EPIC-06's placeholder `NavigationBar` inside
    `AppShell`; the `NavigationRail` variant for ≥600dp mirrors the same selection signals.
- **Acceptance** — A colour-blind simulation (grayscale golden) of each still identifies the selected
  item; the segmented control's vertical reflow is proven by a golden at 1.6× scale in German.

### 8. Banner, stat block, disclaimer sheet, empty state, confirm sheet

- **What** — The remaining five recipes (8–12).
- **Where** — `lib/features/shared/presentation/widgets/backfill_banner.dart`,
  `lib/features/progress/presentation/widgets/progress_stat_block.dart`,
  `lib/features/welcome/presentation/widgets/disclaimer_sheet.dart`,
  `lib/features/shared/presentation/widgets/taper_empty_state.dart`,
  `lib/features/shared/presentation/widgets/confirm_sheet.dart`,
  `lib/features/shared/presentation/widgets/undo_row.dart`.
- **Details** —
  - `BackfillBanner` — *"You haven't marked the last 3 days."* `c.tintWarning` fill, `r.radiusLg`, 1px
    `c.warningFill` border, a warning glyph, **body text in `c.ink`** (the semantic ink is for glyph
    and border only), two tertiary actions, `liveRegion: true`. **Never a `SnackBar`**: it must survive
    a scroll and a backgrounding, and this reader is slow. Copy is warm, not scolding — a missed day is
    not a failure (`SPEC.md` §4.1, §4.3).
  - `ProgressStatBlock` — `c.surfaceRaised`, `r.radiusLg`, `e.level1`; numeral `headlineLarge` `w800`
    tabular; overline `w600` with the tracking slot and **no `toUpperCase()`**. Every block states its
    unit in words: *"taken 341 of 350 days"*, *"12,480 mg cumulative"*, *"day 402 on steroids"*.
  - `DisclaimerSheet` — `c.surface`, `r.radiusXl` top corners only, scrim `c.overlay`, drag handle
    `c.border`. In gate mode (`SPEC.md` §4.0) `isDismissible: false`, `enableDrag: false`, and the
    single "I understand" action stays **disabled until the scroll controller reaches the end**. In
    re-read mode (from Settings) it is dismissible and the action says "Close".
  - `TaperEmptyState` — centred decorative illustration under `ExcludeSemantics`, a `titleLarge`
    heading, one `bodyLarge` sentence in `c.inkMuted`, exactly one primary action. Copy is warm:
    *"Your plan starts here"*, never *"No data"*.
  - `ConfirmSheet` — **recipe 12, and the widget that makes task 6's "destructive never acts
    directly" rule real.** Three consumers already exist, which is task 1's own threshold for
    `features/shared/`: EPIC-08's Hold and Flare confirmations, EPIC-11's delete-plan, EPIC-13's
    import merge policy. Shape: `c.surface`, `r.radiusXl` top corners, scrim `c.overlay`, drag
    handle, `isDismissible: true` and `enableDrag: true` (unlike the disclaimer gate — cancelling a
    destructive action must be the easy path). Contents: a `titleLarge` title; a `bodyLarge` body
    that **names exactly what will happen and what is kept** ("Your history and your total are
    kept"); an **optional pre-action** — a `SecondaryButton` that runs first and returns to the sheet
    rather than dismissing it, which is how `SPEC.md` §5.3's "Export first" is implementable; the
    confirm as a `DestructiveButton` or `PrimaryPillButton` depending on `isDestructive`; and a
    `TertiaryButton` cancel. Constructor takes pre-localized strings and callbacks only.
    Semantics: presented with `showModalBottomSheet(useRootNavigator: true)` so it reads as a modal
    route, `Semantics(scopesRoute: true, namesRoute: true, label: title)`, focus lands on the title.
    Returns `Future<ConfirmResult>` — `{confirmed, cancelled}` — never a bare `bool?`.
  - `UndoRow` — the app's **only** undo surface, named here so three epics stop inventing one. A
    persistent inline row (`c.tintPrimary` fill, `r.radiusLg`, a sentence plus one `TertiaryButton`
    "Undo"), rendered in the content flow directly under the thing that changed, `liveRegion: true`,
    dismissed by an explicit close or by the next mutation — **never a `SnackBar`**, for the same
    reason the banner is not one: it times out before this reader finishes it. EPIC-08's mark-taken
    undo and EPIC-09's row-tick undo both mount this.
- **Acceptance** — The disclaimer's action is provably disabled until scrolled to the end (widget
  test); the banner survives a `pumpAndSettle` of 30 s without disappearing; `ConfirmSheet`'s
  pre-action is proven to run and leave the sheet open, and dismissing by scrim returns `cancelled`
  without invoking the confirm callback; `UndoRow` is still present after a 30 s `pumpAndSettle`.

### 9. Golden and a11y suite

- **What** — The tests that hold all twelve recipes still, numbered as in the table above.
- **Where** — `test/golden/components/`, `test/support/golden_sheet.dart`,
  `test/support/load_app_fonts.dart` — beside EPIC-06's `test/support/harness.dart`, which supplies
  `pumpApp`. Golden output lives under `test/golden/` throughout the project (singular, per EPIC-06
  task 8); there is no `test/goldens/`.
- **Details** — One **scenario sheet** golden per recipe rather than 96 separate files: a
  `GoldenSheet` widget renders the recipe's states in a grid, and the test emits four files per
  recipe — `{light,dark} × {en,fa}` — each rendered twice, at `TextScaler.linear(1.0)` and `2.0`
  (so eight cells' worth of coverage in four images). Twelve recipes → 48 golden files, reviewable
  in a PR. The high-contrast palette (`CONTRACTS.md` §9) is **not** a fifth golden lane here —
  EPIC-14 covers it in the four-theme contrast loop.
  `loadAppFonts()` is hand-rolled in `test/support/` using `FontLoader` over the **bundled** Nunito and
  Vazirmatn TTFs from EPIC-02 — `golden_toolkit` is unmaintained and we are not adding `alchemist` for
  one helper. Without it every glyph is an Ahem box and the goldens are worthless.
  `debugDisableShadows = false` in `setUp` with a matching `addTearDown`, otherwise Daybreak's warm
  multi-layer shadows render as flat slabs and the goldens pin the wrong thing.
  Also per component: `meetsGuideline(textContrastGuideline)`, `meetsGuideline(androidTapTargetGuideline)`,
  and a semantics assertion that the state/selection is present in the semantics tree as **text**, not
  only as colour. Goldens run on a single CI platform (Linux) and are tagged so a mac/Windows run skips
  them — cross-platform font rasterisation makes any other arrangement permanently red.
- **Acceptance** — 48 golden files committed; `flutter test --tags golden` green in CI; deleting the
  `loadAppFonts` call makes them fail (proving they are actually rendering text).

## Visual parity

Reference: `design/reference/daybreak-screens-{light,dark}-{en,fa}.png` — the 2600×4760 contact sheet
whose six frames are, in reading order, **1 Welcome/disclaimer, 2 Today, 3 Schedule, 4 Progress,
5 Plan, 6 Settings** (3×2 grid at 1300 CSS px, `.phone` scale exactly 1). This epic compares
**components, cropped from their frames**, not whole screens — whole-screen parity belongs to
EPIC-08–11.

| # | Component | Frame | What must match exactly | What is measured (±2 px) |
|---|---|---|---|---|
| 1 | Dose hero card + arc | 2 | gradient token, `r.radiusLg`, `e.glow`, element order (date → badge → numeral → tablets → Taken), badge = glyph + word | card inset from the phone edge, card height, numeral baseline |
| 2 | Day-state rows | 3 | all four shapes, glyphs, labels; today's 2px `stateToday` border and `w800`; **missed in `stateMissed`, never `danger`** | marker diameter 26, row height 64, leading inset |
| 3 | Block header | 3 | `surfaceRaised` fill, 1px border all round, `r.radiusLg`, `e.level1`, 36pt glyph tile, current block's `tintPrimary` fill | header height at 1.0 scale |
| 4 | Button ladder | 1, 2, 5, 6 | fills, inks, borders, radii per variant; Taken = `surface` fill + `ink` label, ≥88 | heights 88 / 56 / 56 / 48 |
| 5 | Strength chips | 5 | pill radius, selected ring + check + weight | chip min 44×44, wrap gaps |
| 6 | Segmented control | 5 | raised selected tile, shadow token, weights | segment widths equal |
| 7 | Tab bar | all six | five labelled destinations, active = `tintPrimary` icon pill + `primaryDeep` label, filled vs outlined icons | bar height 96, icon pill 52×30 |
| 8 | Backfill banner | 2 | warning tint fill, `c.ink` body, glyph, two tertiary actions | banner inset and height |
| 9 | Stat blocks | 4 | surfaceRaised, `r.radiusLg`, tabular numerals, no uppercase overline | block height, grid gaps |
| 10 | Disclaimer sheet | 1 | top-corner radius only, scrim, handle, disabled primary | sheet height fraction |
| 11 | Empty state | — | no reference frame; judged against `daybreak-components` and `ui-states-and-feedback` | — |
| 12 | Confirm sheet + undo | — | no reference frame; judged against `ui-states-and-feedback` — dismissible sheet, optional pre-action, inline undo that never times out | — |

Rows 1, 2, 3, 4 and 7 are the five that EPIC-08/09 previously re-specified with different values.
They were resolved against the reference in the tasks above and the winners are written **here only**;
08/09/10 name the component and stop.

All four variants per component: **light × dark × LTR/en × RTL/fa**. RTL is an *exact* tier: the
gradient's `AlignmentDirectional` origin must mirror, chevrons must flip, and leading insets must move
to the right edge — assert it with a geometry check (`chevron.center.dx < width / 2` in RTL), not by
eye. `de` rides on the `en` cell as a longest-string overflow pass; `ckb` rides on `fa` as a
script/glyph and numeral pass; 200% scale is judged against each component's declared degradation
order, not against a PNG. Method and tolerances: `daybreak-visual-parity` — pixel identity is not the
standard, "pixels differ" is never a finding, and if the reference is wrong the HTML changes first and
all four PNGs are regenerated in their own commit. **This epic exercises that clause twice, both
deliberately:** `.srow.missed .sstate` moves from `--danger` to `--state-missed` (task 4), and the
Taken button's height goes from 56 to 88 (task 6, an accessibility floor the HTML follows rather than
leads). Both HTML edits and the PNG regeneration are one commit on this branch, made *before* the
component goldens are baselined.

## Definition of done

- [ ] All twelve recipes in the numbered table exist as named `const` widget classes under `features/*/presentation/widgets/`; no `_buildX()` method anywhere
- [ ] One `tool/check_raw_values.sh` (EPIC-02's, extended) green in CI — no hex, radius, duration, curve, bare `EdgeInsets` or `fontSize` outside `lib/theme/`; no second copy under `scripts/`
- [ ] All four day states carry shape + glyph + localized label; a grayscale golden still answers "was this taken?"
- [ ] `missed` renders in `c.stateMissed` in marker, border and word — `danger` appears nowhere in a day row, and the reference HTML/PNGs were corrected to match
- [ ] The five contested component values (hero radius, Taken fill, block header, day row, tab bar) are stated **only** here; EPIC-08/09/10 reference the components by name
- [ ] `ConfirmSheet` exists with its optional pre-action, and every `DestructiveButton` call site routes through it; `UndoRow` is the only undo surface in the app
- [ ] Dose numeral renders at 2.0 scale with no overflow, clamp or ellipsis; degradation order implemented and commented
- [ ] `onPrimary` verified ≥4.5:1 against both sunrise endpoints, light and dark
- [ ] `SunriseArcPainter` snapshots tokens; `shouldRepaint` compares every field; no `BuildContext` in `paint()`
- [ ] Taken ≥88 tall; every other target ≥44×44, single-tap, `Semantics(button: true)`
- [ ] Chips, segments and tabs signal selection with glyph + weight + shape; tab labels always visible
- [ ] Every animation resolves through `resolveMotion` and collapses to zero under reduced motion
- [ ] `DaybreakTabBar` replaces the placeholder `NavigationBar` in `AppShell`, rail variant included
- [ ] 48 golden sheets committed; a11y guideline assertions per component
- [ ] Component parity contact sheet attached to the PR, light + dark, LTR + RTL
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, parity evidence, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
