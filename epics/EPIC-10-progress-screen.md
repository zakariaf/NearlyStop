# EPIC-10 — Progress screen & chart

**Branch:** `epic/10-progress-screen`
**Depends on:** EPIC-06 (app shell, routing), EPIC-07 (component library)

## Where we are now

Today and Schedule may or may not be merged — this epic depends only on the shell and the components,
so it can run in parallel with 08/09. What exists:

- the five-branch `StatefulShellRoute` with a placeholder at `/progress`;
- **one** repository (EPIC-05), `TaperRepository` at `lib/data/taper_repository.dart`, exposing a
  single read — `Stream<Result<TaperSnapshot, StorageFailure>> watchSnapshot()`, carrying the plan,
  every `Step`, every `DoseLog`, every `FlareEvent` and every `HoldEvent` — plus the mutations
  `markTaken`/`undoTaken`/`setNote`/`recordFlare`/`recordHold`/`startNextStep`. **There is no
  `watchHistory()` and no `HistorySnapshot`**;
- EPIC-06's `derivedScheduleProvider` (`generateSchedule` run once, in the app layer),
  `todayDateProvider` (`Provider<LocalDate>`) and `appLocalizationsProvider`;
- the pure engine (EPIC-04) including `generateSchedule`, the block table, and
  **`lib/core/dsns/cumulative.dart` — `cumulativeTakenMg`, `daysOnSteroids`, `adherence`, already
  written and already tested**;
- EPIC-07's `ProgressStatBlock`, `SecondaryButton`, and `TaperEmptyState`.

> **Contract:** CONTRACTS §3 and §4 — one repository returning facts, derivation in providers. This
> screen's own provider is `progressViewProvider`.

There is no chart, no stats derivation, and no export entry point. Export itself — the PDF/CSV and
the OS share sheet — is **EPIC-13**; this epic builds only the button and the route it will fill.

## Why this epic exists

Progress is why someone keeps going on day 400 and what the rheumatologist actually wants to see at
the six-month appointment. The Today screen answers "what do I swallow"; this screen answers "am I
doing this right, and how far have I come" (SPEC §4.3). Two years is a long time to take a tablet
every morning with no visible evidence that anything is happening — the staircase is the evidence.

It is also the screen most likely to be built badly. A dose-over-time chart invites a charting
package, a `BuildContext` read inside `paint()`, a colour-only flare marker, and an adherence number
phrased as a streak. Every one of those is wrong here: the app makes zero network calls and carries
no dependency it does not need; a painter that touches `BuildContext` cannot be tested or kept
allocation-free; a flare mark that is only red disappears in grayscale and for a colour-blind reader;
and a breakable streak is cruel to a 74-year-old who missed three mornings during a flare. SPEC §4.3
is explicit — *stated gently and never as a streak to break*.

And a painted chart is, to a screen reader, a blank rectangle. The population that needs this app
most is the one most likely to be running VoiceOver at 200% text. So the chart ships with a
non-visual equivalent that carries the same information in words — not a fallback nobody tests, but
the thing the layout degrades *to* at large text scale.

## What we will have when it is done

A Progress screen showing the dose staircase from the starting dose to today, with **flare and hold**
markers and a today dot, drawn by a `CustomPainter` that never sees a `BuildContext`; the "Started 12 September
2024 at 15mg" line; three stat blocks (days on the drug, cumulative mg, days ticked, each stated in
words with its unit); an encouraging line that says how much lower the dose is than at the start; and
an "Export for my doctor" button that routes to the export flow. A screen-reader user gets a real
summary of the chart and can open a dose-history list that says the same thing in sentences. It
matches frame 4 of the Daybreak reference in light and dark, LTR and RTL.

## Skills to load

| Skill | What it governs here |
|---|---|
| `daybreak-visual-parity` | Frame-4 capture/compare, the 4-cell matrix, PR evidence. |
| `custom-canvas-and-gestures` | The painter contract: token snapshot at the widget layer, `shouldRepaint` over every field. |
| `daybreak-components` | `ProgressStatBlock`, card recipes, the never-colour-alone rule for flare marks. |
| `daybreak-tokens` | Chart stroke (`primaryDeep`, ≥3:1) and fill gradient stops, `border` gridlines, `danger` flare ring, hold bracket, `stateToday` dot. |
| `flutter-performance` | Segment reduction (780 days → ~20 segments), `RepaintBoundary`, no layout in `paint()`. |
| `accessibility-as-code` | The chart's semantic equivalent, contrast, gentle adherence phrasing. |
| `state-management-riverpod` | `ProgressNotifier` over `watchSnapshot` + `derivedScheduleProvider`, pure projection, memoised series. |
| `widget-golden-and-a11y-testing` | Goldens incl. a grayscale lane; a painter unit test over the emitted path. |
| `i18n-rtl-l10n` | Locale numerals and date formats, RTL time-axis direction, plural stat labels. |
| `adaptive-layout` | Stat grid reflow, chart height on landscape/tablet. |

## Tasks

### 1. Scaffold the Progress feature module

- **What** — Create the feature under the standard layout.
- **Where** — `lib/features/progress/application/progress_view_provider.dart` (notifier + provider,
  per CONTRACTS §4), `lib/features/progress/presentation/progress_screen.dart`,
  `progress_view_state.dart`, and `presentation/widgets/`
  (`dose_staircase_chart.dart`, `dose_staircase_painter.dart`, `progress_stat_grid.dart`,
  `encouragement_card.dart`, `taper_start_line.dart`, `dose_history_list.dart`).
- **Details** — Painter lives beside its widget, not in `lib/core/`; it is specific to this chart.
  No widget in `widgets/` imports drift, the repository, or `WidgetRef`.
- **Acceptance** — Module compiles with a stub state; `scaffold-feature-module`'s checklist satisfied.

### 2. `ProgressViewState` and the series model

- **What** — Model the chart as segments, not per-day points.
- **Where** — `lib/features/progress/presentation/progress_view_state.dart`.
- **Details** —
  ```dart
  final class DoseSegment {          // one horizontal tread of the staircase
    final int startDayIndex;         // days since plan start
    final int endDayIndex;
    final Milligrams dose;           // never a double — see the note below
  }
  final class FlareMark {
    final int dayIndex;
    final Milligrams dose;
    final String label;              // localized, for the semantic list
  }
  final class HoldMark {
    final int dayIndex;              // the hold's first day
    final int days;                  // extraDays
    final Milligrams dose;
    final String label;              // "held at 9mg for 5 days, from 3 March"
  }
  final class ProgressStats {
    final String daysOnDrug;         // "581"
    final String cumulativeMg;       // "6,842" (locale-formatted)
    final String adherence;          // "574 of 581"
    final String adherenceCaption;   // "days ticked so far — a few gaps change nothing"
  }
  ```
  `ProgressLoaded` carries `segments`, `flares`, **`holds`**, `todayPoint`, `axis` (min/max dose,
  first/last date label), `stats`, `startLine`, `encouragement`, and `eventCountLabel`. Plus
  `ProgressNoPlan` for the empty state.
  > **Contract:** CONTRACTS §1 — `Milligrams` (integer hundredths) is the only dose type. Doses are
  > **never** stored as `double` in the view state; the conversion to a `double` happens once, at
  > the last moment, inside the painter's y-axis mapping, which is genuinely geometric.
  **Holds are modelled because SPEC §4.3 says "flares *and* holds marked on the timeline".** They
  are stored (EPIC-05), honoured by the generator (EPIC-04) and recordable from Today (EPIC-08); a
  rheumatologist looking at a stalled staircase needs to see *why* it stalled.

  **Segment reduction is the performance story, and the tread rule is stated exactly so nobody has
  to guess.** A DSNS step has no single "nominal dose" — it is 26 days at `fromDose` and 26 at
  `toDose` (SPEC §3.1) — so the rule is **two treads per step**: `fromDose` for the first half of
  the step and `toDose` for the second, with the boundary at the day-27 crossover. Alternating days
  are *not* drawn as 1-day treads; the day-level alternation lives on Schedule and Progress shows
  the trend a doctor asks about. This is documented in a dartdoc comment on `DoseSegment`.
  The arithmetic, corrected: **15mg → 9mg at the 1mg steps SPEC §3.2 mandates above 10mg is six
  steps** (15→14→13→12→11→10→9), and six steps × two treads = the reference's **twelve** segments.
  The earlier "one tread per step … matching the reference's twelve treads" could not close.
  Adjacent segments at the same dose (a step's `toDose` and the next step's `fromDose`) are **not**
  merged — the boundary is kept so the acceptance test can check it, and the painter draws them as
  one continuous tread because their y is identical.
  Steady-state days after the final step extend the last tread at the target dose rather than
  ending the series.
- **Acceptance** — A 780-day fixture produces ≤ 32 segments; a unit test asserts a **6-step 15→9
  fixture produces exactly 12 segments whose boundaries are the step start dates and the day-27
  crossovers**, and that flare dates open a new segment. A fixture stepping 5 → 0 in 0.5mg
  increments produces treads whose `dose` values compare equal to the `Milligrams` values that
  generated them — no rounding at the seam.

### 3. `ProgressNotifier`

- **What** — Derive the whole screen from facts.
- **Where** — `lib/features/progress/application/progress_view_provider.dart` (per CONTRACTS §4 the
  notifier and its provider live under `application/`; the widgets stay in `presentation/`).
- **Details** —
  ```dart
  final progressViewProvider =
      StreamNotifierProvider<ProgressNotifier, ProgressViewState>(ProgressNotifier.new);
  ```
  `build()` watches `todayDateProvider`, `derivedScheduleProvider` and `appLocalizationsProvider`,
  and maps `repo.watchSnapshot()` through a pure static
  `_project(snapshot, schedule, today, l10n)`.

  **The three numbers are not computed here.** EPIC-04 task 7 already ships them, pure and tested,
  in `lib/core/dsns/cumulative.dart`, and this epic *consumes* them:
  - **days on the drug** = `daysOnSteroids(plan.startDate, today)` — inclusive whole calendar days
    on `LocalDate`, never elapsed seconds (SPEC §7, DST). Note `LocalDate.difference(LocalDate)`
    returns an `int` of days; there is no `Duration` and therefore no `.inDays`.
  - **cumulative mg** = `cumulativeTakenMg(logs)` — `Σ actualMg` over logs with `taken == true`.
    `actualMg`, not `plannedMg`: a backfilled day at a reverted dose must total honestly, and days
    never ticked contribute nothing. Keep this cross-reference in the dartdoc; it is the reason the
    number matches EPIC-13's CSV export, which calls the same function.
  - **adherence** = `adherence(logs, dayPlans) → Adherence(takenCount, plannedCount)`, phrased with
    `l10n.daysTickedSoFar`. Never a streak, never a percentage with a red colour, never a "broken"
    state.
  `_project`'s only job for these three is **localized formatting** — `NumberFormat` on the values
  the domain returns. Re-deriving the arithmetic in the presentation layer would put it outside
  EPIC-04's purity gate and let it drift from the exported number.
  Encouragement = `l10n.lowerThanStart(delta)` where `delta = startingDose − currentDose`, and when
  `delta == 0` it falls back to a warm neutral line rather than "0mg lower".
- **Acceptance** — Unit tests for the *formatting* of each number in all four locales, plus a taper
  with untick gaps and day one (581 → 1, no divide-by-zero in the adherence string). **The
  flare-preserves-cumulative test is EPIC-04's** (`cumulative.dart` already carries a test named for
  that sentence); this epic references it rather than duplicating it.

### 4. `DoseStaircasePainter`

- **What** — The chart, painted with no `BuildContext`.
- **Where** — `widgets/dose_staircase_painter.dart`.
- **Details** — Constructor takes a **snapshot**: `List<DoseSegment> segments`,
  `List<FlareMark> flares`, `List<HoldMark> holds`, `Offset todayPoint`-worth of data,
  `Color gridline`, `Gradient lineGrad`,
  `Gradient fillGrad`, `Color flareRing`, `Color flareGlyph`, `Color holdBracket`,
  `Color markerFill`, `Color todayRing`,
  `double strokeWidth`, `TextDirection direction`, and a small record of **pre-laid-out**
  `TextPainter`s for the axis labels (built in the widget's `build` from
  `Theme.of(context).textTheme` and `MediaQuery.textScalerOf`). `paint()` allocates no `Paint` per
  frame beyond the four it needs, calls no `Theme.of`, and lays out no text.
  Geometry mirrors the reference SVG's `viewBox 0 0 320 176`: four horizontal gridlines at 1px in
  `c.border`; the staircase as a single `Path` of `H`/`V` moves; a closed copy of that path filled
  with a vertical gradient (`primary` @30% → `secondary` @4%) — that area is decoration and carries
  no information, so the 2.76:1 `primary` is legitimate there.
  **The stroke is different: it is the only mark carrying the screen's primary information, and it
  has no text fallback of its own, so it must clear WCAG 2.1 SC 1.4.11's 3:1 for graphical
  objects.** `primary` at 2.76:1 against the card's `wash` fill does not. Draw the stroke as a
  horizontal gradient in `primaryDeep` (or whichever slot clears 3:1 against `wash` at **both**
  gradient endpoints in light and dark) at 3px with round joins and caps, and keep
  `primary` → `secondary` for the fill underneath. The audience is 60–80 with declining contrast
  sensitivity; EPIC-14's `textContrastGuideline` does not look at painted geometry, so this is
  pinned by the unit test below instead.
  Flare marks: a 9px circle filled `surface`, stroked `danger` at 2.5px, with the flare glyph path
  drawn inside — **shape + glyph, never colour alone**.
  **Hold marks** (SPEC §4.3): a bracketed tread segment — a square bracket spanning the held days
  drawn in `holdBracket` above the tread, with a small tick at each end — **a distinct shape, not a
  second ring and not a colour variant of the flare mark**, so the two never have to be told apart
  by colour. Both counts are also stated in words below the chart:
  `l10n.flaresAndHoldsRecorded(flares, holds)` → *"2 flares and 1 hold recorded"* (ICU plurals; when
  either count is zero the phrase drops that clause rather than saying "0 holds").
  Today: a 6px `surface` circle with a 3px `stateToday` ring.
  RTL: time flows from the reading start edge, so in RTL the painter mirrors x
  (`canvas.save(); canvas.translate(size.width, 0); canvas.scale(-1, 1);`) for the path work and
  paints the (already correctly shaped) `TextPainter`s **unmirrored** at mirrored positions. This is a
  stated design decision: the earliest date sits at the start edge in both directions.
  `shouldRepaint` compares every field, including list identity *and* length, and the text direction.
- **Acceptance** — A painter unit test drives it through a recording canvas and asserts the emitted
  path's first and last vertices for a known series, in both text directions, and that a `HoldMark`
  emits its bracket. A unit test asserts **the stroke colour is ≥ 3:1 against the card fill at both
  gradient endpoints, in light and dark**. A `grep` shows no `BuildContext`, `Theme`, or
  `MediaQuery` in the painter file.

### 5. `DoseStaircaseChart` widget

- **What** — The card that owns the painter.
- **Where** — `widgets/dose_staircase_chart.dart`.
- **Details** — `card raised` recipe: `wash` gradient fill, `shapes.radiusLg`, `border` hairline,
  `elevation.level2`, padding `shapes.s4`, with an overline heading ("Your dose over time" — `caption`/w800/`+.09em` tracking in
  Latin, **no uppercase and no tracking in `fa`/`ckb`**). `AspectRatio` or a fixed 176 logical px
  height at 1.0 scale, wrapped in a `RepaintBoundary`. The chart is under
  `ExcludeSemantics` and paired with a sibling `Semantics(label: …)` node — see task 6.
  Interaction is deliberately **none** in v1: no tooltip, no crosshair, no pan. A tap target that
  does nothing is worse than no tap target, and `custom-canvas-and-gestures`' hit-testing machinery
  is unnecessary weight for a read-only trend line. Stated as a deferral in the PR.
- **Acceptance** — Golden of the card at light/dark × en/fa; a rebuild-count test proves the painter
  does not repaint when an unrelated part of the screen rebuilds.

### 6. The non-visual equivalent

- **What** — Give the chart a real screen-reader form, and make it the 200%-scale degradation target.
- **Where** — `widgets/dose_staircase_chart.dart`, `widgets/dose_history_list.dart`.
- **Details** — The chart's semantic sibling carries a composed summary:
  *"Chart: your dose fell from 15 milligrams in September 2024 to 9 milligrams in April 2026, with 2
  flares and 1 hold recorded."* Below it, a disclosure ("Dose history as a list") expanding to
  `DoseHistoryList` — one row per segment: *"15 milligrams from 12 September 2024 for 52 days"* —
  with **flare rows and hold rows** interleaved in date order (*"Flare on 3 March 2025, back to
  10 milligrams"*, *"Held at 9 milligrams for 5 days from 12 June 2025"*). Holds are as much a
  timeline event as flares (SPEC §4.3) and this list is the only place a screen-reader user can
  find either. The list is real UI, focusable and readable, not a hidden `Semantics`
  string, because a low-vision sighted user needs it as much as a screen-reader user does.
  **Above 1.5× text scale the chart is replaced by the list automatically** — a 176px canvas cannot
  carry legible axis labels at 200%, and shrinking labels is the defect `accessibility-as-code` bans.
  That is the declared degradation order for this screen: chart → list; stat grid 2-col → 1-col;
  encouragement icon dropped last.
- **Acceptance** — `SemanticsTester` asserts the summary sentence in `en` and `fa`, including the
  flare-and-hold clause; a test over a fixture with one hold asserts its row appears in
  `DoseHistoryList` in date order; a test at `TextScaler.linear(2.0)` finds `DoseHistoryList` and no
  `CustomPaint` for the chart.

### 7. Start line, stat grid and encouragement

- **What** — The three blocks under the chart.
- **Where** — `widgets/taper_start_line.dart`, `widgets/progress_stat_grid.dart`,
  `widgets/encouragement_card.dart`.
- **Details** — Start line: sunrise glyph in `primaryDeep` + body/w700 `inkMuted` text, padding
  `shapes.s4 shapes.s1 0`.
  Stat grid: `GridView` is banned here too — use a `Row` of two `Expanded` `ProgressStatBlock`s plus
  a full-width third, or a `Wrap`; at >1.3× scale it becomes a `Column`. Each block's fill, radius,
  hairline and elevation are EPIC-07's `ProgressStatBlock` (CONTRACTS §9) and are not restated here;
  this task specifies the content: value at `title`/w800 with tabular figures and
  `letterSpacing` −0.02em converted to px; the unit as a smaller inline span ("6,842 **mg**"); the
  label at `label`/w600 `inkMuted`, two lines allowed, never truncated. **Every stat states its unit
  in words** (`daybreak-components`).
  Encouragement: `tintSuccess` fill, `success`-mixed border, `shapes.radiusLg`, 28pt sun glyph in `success`,
  body/w700 ink. Wording is warm and never comparative to other patients.
- **Acceptance** — Longest-string (`de`) pass shows no truncation in any stat label; at 2.0 scale the
  grid is a single column with all three blocks intact.

### 8. Export entry point

- **What** — The button, its route, and an honest placeholder.
- **Where** — `progress_screen.dart`, `lib/routing/` (a `/progress/export` route).
- **Details** — EPIC-07's `SecondaryButton` (its fill, border and elevation are EPIC-07's —
  CONTRACTS §9), 56 tall, download glyph + "Export for my doctor". It pushes `/progress/export`. Until
  EPIC-13 lands, that route renders a `ui-states-and-feedback` "coming next" panel — **not** a
  disabled button and **not** a dead tap. The route, its name and its go_router entry are created
  here so EPIC-13 only fills the screen.
  Do not implement PDF/CSV generation, file writing, or `share_plus` in this epic; adding the
  dependency here would put an unused package in `pubspec.yaml` through a merge, which
  `dependency-hygiene` forbids.
- **Acceptance** — Tapping the button navigates; the deferral is stated in the PR description.

### 9. Screen assembly, empty state and adaptive layout

- **What** — `ProgressScreen` and its non-happy states.
- **Where** — `lib/features/progress/presentation/progress_screen.dart`.
- **Details** — `ConsumerWidget` over `progressViewProvider`; loading → a skeleton reserving the chart
  card's height; error → the standard error panel with retry; `ProgressNoPlan` → `TaperEmptyState`
  routing to `/plan`. Body scrolls (unlike Today, this screen is expected to). Above 840 logical px,
  the chart card and the stat column sit side by side; the chart keeps its aspect ratio rather than
  stretching to a letterbox.
- **Acceptance** — Goldens for empty, loading and loaded; tablet golden at 1024×768.

### 10. Tests

- **What** — The set that holds this screen.
- **Where** — `test/features/progress/`, `test/golden/progress/`.
- **Details** — `_project` unit tests for the *formatting* of the three numbers (the arithmetic is
  EPIC-04's and is tested there) and for the segment reduction, including the six-step 15→9 → 12
  segments case; the painter path and stroke-contrast tests from task 4; a `shouldRepaint` test
  asserting `true` on each changed field and `false` when nothing changed; widget tests for the 1.5×
  chart→list swap; a11y guideline tests; goldens across light/dark × en/fa × 1.0/2.0 plus a
  grayscale lane proving the **flare and hold** marks are still identifiable by shape alone. All
  against a pinned clock and the seeded 581-day fixture that reproduces the reference's numbers
  (581 days, 6,842 mg, 574 of 581, 2 flares, 1 hold, 15mg → 9mg in six 1mg steps).
- **Acceptance** — `flutter test` green; the seeded fixture is shared with the parity capture so the
  numbers on screen match the reference exactly.

### 11. Visual parity pass

- **What** — Prove the screen against frame 4.
- **Where** — `parity/ref/04--progress--{light,dark}--{en,fa}.png`, `parity/app/…`,
  `parity/sheet.html`.
- **Details** — Crop frame 4 at CSS rect `[27, 1494, 390, 844]` (PNG `+54+2988`, 780×1688),
  content-box adjusted for the 54px status bar; capture at 390×844 DPR 2 with the seeded fixture.
  Sample the chart's fill gradient at its midpoint (tolerance ΔE00 ≤ 3) and the stat card fill at its
  centre (ΔE00 ≤ 2); assert the gridline colour by token rather than by pixel, since a 1px hairline
  is a blend. Add the `de`, `ckb`, 200% and grayscale no-reference passes.
- **Acceptance** — Paired sheet in the PR with every Tier-2 measurement stated as a number.

## Visual parity

**Reference:** frame 4 — "Progress" (row 2, column 1; CSS rect `[27, 1494, 390, 844]`) in all four
committed sheets.

**Variants:** light/en, light/fa, dark/en, dark/fa. Plus `de` longest-string (the adherence caption
is the longest string on the screen), `ckb`, 200% scale (which must show the list, not the chart),
and grayscale (the flare and hold marks).

**What must match exactly:** element order — "Progress" title → chart card ("Your dose over time"
overline, staircase, "2 flares and 1 hold recorded" line) → "Started 12 September 2024 at 15mg" →
the 2+1 stat grid → the encouragement card → the secondary export button → tab bar with Progress
active. The chart card's `wash` gradient and `elevation.level2`; four gridlines in `border`; the
staircase's 3px stroke — in `primaryDeep`, not `primary`, because it carries information and must
clear 3:1 — descending **twelve treads (two per step over six 1mg steps)** from the 15mg gridline to
the 9mg gridline; two `danger`-ringed flare marks with their glyph and any hold brackets;
the `stateToday` dot at the series end; axis labels at the start edge (15mg / 12mg
/ 9mg) and the two date labels at the baseline; the stat blocks as EPIC-07 ships `ProgressStatBlock`
with `title`-size tabular values; the `tintSuccess` encouragement card; the export button's 2px
`borderStrong`.

**RTL:** the time axis runs right-to-left (earliest date at the start edge), the dose axis labels move
to the right edge, glyph-bearing rows mirror, and every numeral renders in the Persian numeral system
with Jalali month names ("شهریور ۱۴۰۳").

Method, tolerances and the PR sheet: `daybreak-visual-parity`.

## Definition of done

- [ ] `DoseStaircasePainter` takes a full token snapshot; no `BuildContext`, `Theme` or `MediaQuery`
      in the painter file; `shouldRepaint` compares every field
- [ ] Axis label `TextPainter`s are laid out at the widget layer, never inside `paint()`
- [ ] A 780-day taper reduces to ≤ 32 segments; the reduction is documented in dartdoc, and a
      six-step 15→9 fixture produces exactly 12 segments on the two-treads-per-step rule
- [ ] Days-on-drug, cumulative-mg and adherence are **consumed from `lib/core/dsns/cumulative.dart`**
      — this epic re-implements none of them and only formats their results
- [ ] Doses in the view state are `Milligrams`; the only `double` conversion is inside the painter's
      y-axis mapping
- [ ] The staircase stroke clears 3:1 against the card fill at both gradient endpoints, light and
      dark, proven by a unit test
- [ ] Adherence is phrased gently ("574 of 581 days ticked so far"), never as a streak or a failure
- [ ] Flare marks carry ring + glyph and **hold marks carry a distinct bracket shape**, with both
      counts stated in words; the grayscale golden proves both are identifiable without colour
- [ ] The chart has a semantic summary and a real `DoseHistoryList`; above 1.5× scale the list
      replaces the chart
- [ ] Export button navigates to `/progress/export`; no PDF/CSV dependency added in this epic
- [ ] Stat grid reflows to one column at large scale with no truncated label in `de`
- [ ] Goldens for light/dark × en/fa × 1.0/2.0 plus grayscale committed and green
- [ ] Frame-4 parity sheet for all four reference cells, plus `de`, `ckb`, 200% and grayscale passes
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, parity evidence, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
