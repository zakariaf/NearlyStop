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
- **Tests first** — *Scaffold.* Creating files asserts nothing. Two rules this task establishes are
  verified by greps, not by tests written about the scaffold: the shared
  `lib/features/*/presentation/widgets/` purity rule in `tool/check_bans.sh` (no drift, no
  `taper_repository`, no `WidgetRef`), and task 4's painter grep. Both are gates this task enables.
- **Details** — Painter lives beside its widget, not in `lib/core/`; it is specific to this chart.
  No widget in `widgets/` imports drift, the repository, or `WidgetRef`.
- **Acceptance** — Module compiles with a stub state; `scaffold-feature-module`'s checklist satisfied.

### 2. `ProgressViewState` and the series model

- **What** — Model the chart as segments, not per-day points.
- **Where** — `lib/features/progress/presentation/progress_view_state.dart`.
- **Tests first (TDD)** — `test/features/progress/segment_reduction_test.dart`. The reduction is
  `f(List<DayPlan>, flares, holds) → List<DoseSegment>` with no localization in it, so this is pure
  `package:test` — extract it as a top-level function in the view-state file rather than burying it
  in `_project`, precisely so it can be tested at this tier. Write and watch fail:
  1. **the acceptance case, first:** a 6-step 15→9 fixture (15→14→13→12→11→10→9, the 1mg steps SPEC
     §3.2 mandates above 10mg) produces **exactly 12** segments. Assert the full list, not the
     length alone: segment *n*'s `dose` and its `[startDayIndex, endDayIndex]`, with boundaries at
     each step's start day and at each step's **day-27 crossover**
  2. two treads per step, never one and never 52: segment 1 is `fromDose` for days 0–25, segment 2 is
     `toDose` for days 26–51 — the alternating days are *not* 1-day treads
  3. adjacent equal doses across a step boundary (step *n*'s `toDose`, step *n+1*'s `fromDose`) are
     **not** merged: the boundary index survives in the list even though the painter draws one line
  4. a flare on day 300 opens a new segment at the reverted dose; the segment before it ends on day
     299 with no gap and no overlap
  5. a hold produces no extra segment — it extends the host tread's `endDayIndex` by `extraDays`
  6. steady-state days after the final step extend the last tread rather than terminating the series;
     the last segment's `endDayIndex` equals the last day index in the input
  7. a 5mg → 0 plan in 0.5mg increments: every emitted `dose` is `==` (integer hundredths, so `==`
     is legal) to the `Milligrams` that generated it — no `double` round-trip at the seam
  8. a 780-day fixture yields ≤ 32 segments
  9. seeded fuzz, `seed 0…299`, random step counts and increments: the segments **tile** the input
     exactly — sorted by `startDayIndex` they are contiguous, non-overlapping, and
     `last.endDayIndex - first.startDayIndex + 1 == dayPlans.length`. The oracle is the input day
     list, never the reduction itself; echo the seed and the step table in `reason:`
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
- **Tests first (TDD)** — two files, and the boundary between them is the point: this epic formats,
  EPIC-04 computes.

  **(a) `test/features/progress/progress_projection_test.dart`** — `flutter_test`, no `pumpWidget`,
  with `AppLocalizations.delegate.load(...)` per locale. Write and watch fail:
  1. `daysOnDrug` for a plan started 2024-09-12 with today 2026-04-16 formats as `'581'` in `en`,
     `'581'` in `de`, `'۵۸۱'` in `fa` and `'۵۸۱'` in `ckb` (`fa` number symbols, U+06Fx — never the
     Arabic block, CONTRACTS §10)
  2. `cumulativeMg` 684200 hundredths formats as `'6,842'` in `en` and `'6.842'` in `de`; in `fa` the
     digits are U+06Fx (`۶۸۴۲`) and the grouping separator is whatever
     `NumberFormat.decimalPattern('fa')` supplies — assert the formatter's own output, never a
     hand-typed separator, and never the Arabic-block digits U+066x (CONTRACTS §10)
  3. `adherence` renders `l10n.daysTickedSoFar(574, 581)` → *"574 of 581"*; the string contains no
     `%`, no "streak", and no "broken" — assert the absence explicitly, because SPEC §4.3 is a
     wording rule and wording rules rot silently
  4. day one: `daysOnSteroids == 1`, zero logs → the adherence string is *"0 of 1"* and nothing
     divides by zero
  5. `encouragement`: start 15mg, current 9mg → `l10n.lowerThanStart('6mg')`; `delta == 0` → the warm
     neutral line, and the string `'0mg'` appears nowhere
  6. `ProgressNoPlan` when the snapshot has no plan
  7. **the boundary test:** with a stub that makes `cumulativeTakenMg` return a sentinel, the
     projected string is that sentinel formatted — proving `_project` reads the core function's
     result and does not re-add anything. A grep in the same file asserts
     `lib/features/progress/` contains no `fold`/`reduce` over `DoseLog` and no `.inDays` — the
     arithmetic must not be re-implemented here, where it would drift from EPIC-13's CSV
  8. `cumulativeMg` is sourced from `actualMg`, not `plannedMg`: a backfilled day logged at a
     reverted 10mg against a planned 9mg produces the 10mg total

  The flare-preserves-cumulative test stays in EPIC-04's `cumulative_test.dart`; do not copy it here.

  **(b) `test/features/progress/progress_notifier_test.dart`** — `ProviderContainer` tier with the
  bare-`implements` fake repository, `todayDateProvider` and `clockProvider` overridden,
  `addTearDown(container.dispose)`:
  9. the provider emits `ProgressLoaded` from one `watchSnapshot()` subscription — the fake counts
     subscriptions and the count is 1
  10. a repository `Failure` emission → `AsyncError` with the previous value retained
  11. changing the locale override re-emits with re-formatted numbers and **no** recomputation of the
      series (the memoised segments are identical by `identical()`)
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
- **Tests first (TDD)** — `test/features/progress/dose_staircase_painter_test.dart`, `flutter_test`
  but **no widget pumped**: the painter takes a value snapshot, so it is driven directly through
  `TestRecordingCanvas` / `TestRecordingPaintingContext` and through an
  `@visibleForTesting Path buildStaircasePath(Size)` that the paint method also calls. Write and
  watch fail, in this order:
  1. a three-segment series over `Size(320, 176)` in LTR: `buildStaircasePath` emits vertices whose
     **first** point is `(0, y(15mg))` and whose **last** is `(320, y(9mg))`, with
     `closeTo(expected, 1e-9)` on every double, and the intermediate moves alternate H then V — a
     staircase, not a polyline through the middle of each tread
  2. the same series in RTL: first point `(320, y(15mg))`, last `(0, y(9mg))` — earliest date at the
     reading start edge in both directions, which is the stated design decision and the thing a
     later "fix" would silently reverse
  3. y-mapping: the minimum dose in the series maps to the baseline and the maximum to the top
     gridline, and a dose exactly between two gridlines lands exactly between them
  4. a `FlareMark` emits a circle **and** the glyph path — assert two draw ops at that x, so a
     colour-only ring fails
  5. a `HoldMark` emits its bracket: three line ops spanning `dayIndex … dayIndex + days`, distinct
     in op-shape from the flare's circle — the two must never be told apart by colour
  6. the today marker emits a filled circle plus a ring at the series end
  7. `paint()` on a 780-day/32-segment series allocates ≤ 4 `Paint` objects (count them through the
     recording canvas) and issues **zero** `TextPainter.layout` calls — the labels arrive
     pre-laid-out
  8. `shouldRepaint`: `false` for an identical snapshot; `true` for each field changed one at a time
     — including a `segments` list of equal length but different contents, **and** an equal-content
     list with different identity, so both halves of the documented comparison are covered
  9. **contrast, as a unit test with no canvas:** the stroke gradient's first and last stop against
     the card's `wash` fill is ≥ 3.0:1 in light **and** dark — four assertions naming their stop.
     Assert the same for `c.primary` and watch it fail at 2.76:1: that failing case is the reason
     the stroke is `primaryDeep`, and keeping it as a documented expectation (as `primary`'s known
     ratio) stops someone "simplifying" the slot back
  10. a source grep in the test file: `BuildContext`, `Theme`, `MediaQuery` and `Localizations` all
      absent from `dose_staircase_painter.dart`
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
- **Tests first (TDD)** — `test/features/progress/widgets/dose_staircase_chart_test.dart`,
  `flutter_test` widget tier. Write and watch fail:
  1. the axis-label `TextPainter`s handed to the painter are built in `build`: assert the painter
     instance's label record is non-null and already laid out (`.width > 0`) before the first paint
  2. rebuilding an unrelated sibling (a `ValueNotifier` driving the encouragement card) does **not**
     construct a new painter — assert `identical(oldPainter, newPainter)`, or that `shouldRepaint`
     is never consulted, via a counting subclass
  3. changing the segments **does** produce a repaint
  4. the `CustomPaint` has a `RepaintBoundary` ancestor and sits under `ExcludeSemantics`, with the
     summary node as a sibling (task 6 asserts the summary's text)
  5. the card is 176 logical px tall at 1.0 scale, and the overline is not uppercased and carries no
     letter-spacing in `fa`/`ckb` while it is uppercased in `en`
  6. **no interaction:** tapping and dragging the card produce no state change and no navigation —
     `find.byType(GestureDetector)` within the card is `findsNothing`. v1's deliberate deferral gets
     a test so it is a decision, not an omission
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
- **Tests first (TDD)** — a painted chart is a blank rectangle to a screen reader, so this is the one
  part of the screen where the test *is* the feature. Two files.

  **(a) `test/features/progress/chart_semantics_test.dart`**, `flutter_test` + `SemanticsTester`.
  Write the sentence as a literal before the widget exists:
  1. `en`, 2 flares and 1 hold → exactly *"Chart: your dose fell from 15 milligrams in September 2024
     to 9 milligrams in April 2026, with 2 flares and 1 hold recorded."* — one node
  2. `fa` → the ARB sentence with Persian numerals and Jalali month names
  3. 0 flares, 1 hold → the flare clause is **dropped**, not rendered as "0 flares"; 2 flares, 0
     holds → the hold clause is dropped; 0 and 0 → the trailing clause disappears entirely and the
     sentence still ends cleanly
  4. the `CustomPaint` subtree contributes **no** semantics nodes (`ExcludeSemantics` works)

  **(b) `test/features/progress/dose_history_list_test.dart`**, `flutter_test`:
  5. one row per segment: *"15 milligrams from 12 September 2024 for 52 days"*, in series order
  6. a fixture with one flare on 2025-03-03 and one hold from 2025-06-12 interleaves both rows **in
     date order** among the segment rows — assert the full ordered list of row labels, since "in date
     order" is exactly what an append-at-the-end implementation gets wrong
  7. the rows are real focusable widgets, not a hidden `Semantics` string: each is reachable by
     `find.text` and by traversal
  8. the swap, on both sides of the threshold: at `TextScaler.linear(1.5)` the chart's `CustomPaint`
     is present and `DoseHistoryList` is absent; at `1.51` the reverse. `takeException()` is null at
     1.51, 1.8 and 2.0
  9. `meetsGuideline(textContrastGuideline)` and the two tap-target guidelines over the list at 2.0
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
- **Tests first (TDD)** — `test/features/progress/widgets/progress_blocks_test.dart`, `flutter_test`
  widget tier; all three widgets take pre-formatted strings, so no container. Write and watch fail:
  1. every stat block renders its **unit in words** — assert `'mg'` and `'days'` appear as text in
     the three blocks, not implied by a heading
  2. the stat grid contains no `GridView` and no `SliverGrid` (`findsNothing`) — the ban applies here
     too, and this is its only enforcement point on this screen
  3. layout on both sides of the threshold: at `TextScaler.linear(1.3)` two blocks share a row; at
     `1.31` all three are full width in a `Column`
  4. `de` at 1.0 and at 2.0: no stat label is truncated — assert each label's `Text` has
     `overflow != TextOverflow.ellipsis`, that its rendered line count is ≤ 2, and that
     `takeException()` is null. `de` is the longest-string locale and the adherence caption is the
     longest string on the screen
  5. the encouragement card renders `l10n.lowerThanStart('6mg')`; with `delta == 0` it renders the
     neutral line — the widget shows what it is handed and contains no `if (delta == 0)` of its own
     (that branch is task 3's, and case 5 there covers it)
  6. the start line renders *"Started 12 September 2024 at 15mg"* in `en` and its Jalali equivalent
     in `fa`, with the glyph excluded from semantics so the reader says one sentence
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
- **Tests first (TDD)** — `test/features/progress/export_entry_test.dart`, `flutter_test` widget tier
  with a recording `GoRouter`. Small, but it is the difference between a live route and a dead tap.
  Write and watch fail:
  1. tapping the button pushes `/progress/export` **exactly once**; the button is never `onPressed:
     null` — assert `enabled`, because a disabled button is the failure mode this task names
  2. `/progress/export` renders the `ui-states-and-feedback` "coming next" panel with a working back
     affordance, reachable by deep link as well as by tap
  3. the button's target is ≥ 44 tall (56 as specified) at 1.0 and 2.0 scale and carries its label in
     the semantics tree
  4. `pubspec.yaml` contains no `pdf`, `csv` or `share_plus` entry — a source assertion in this test
     file, so EPIC-13's dependencies cannot arrive early through a merge (`dependency-hygiene`)
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
- **Tests first (TDD)** — `test/features/progress/progress_screen_test.dart`, `flutter_test` widget
  tier over a `ProviderScope` overriding `progressViewProvider` with a fixed `AsyncValue`; the
  projection is task 3's. Write and watch fail:
  1. `AsyncLoading` → the skeleton's chart-card height equals the loaded card's within 1 px, so the
     page does not jump; no `pumpAndSettle` in this file (the skeleton shimmers indefinitely —
     `testing-strategy` rule 10) and no `CircularProgressIndicator`
  2. `AsyncError` → the error panel, whose retry invalidates the provider once
  3. `ProgressNoPlan` → `TaperEmptyState` whose action pushes `/plan`
  4. `ProgressLoaded` → the element order asserted as a list: title → chart card → start line → stat
     grid → encouragement → export button, read off the widget tree, so a reordering is a failure
  5. the body scrolls at 390×844 (`maxScrollExtent > 0`) — unlike Today, this screen is expected to
  6. at 841 logical px the chart card and the stat column are siblings in a `Row` and the chart's
     `AspectRatio` is unchanged from the narrow case; at 839 they are stacked. Both sides asserted
- **Details** — `ConsumerWidget` over `progressViewProvider`; loading → a skeleton reserving the chart
  card's height; error → the standard error panel with retry; `ProgressNoPlan` → `TaperEmptyState`
  routing to `/plan`. Body scrolls (unlike Today, this screen is expected to). Above 840 logical px,
  the chart card and the stat column sit side by side; the chart keeps its aspect ratio rather than
  stretching to a letterbox.
- **Acceptance** — Goldens for empty, loading and loaded; tablet golden at 1024×768.

### 10. Tests

- **What** — The set that holds this screen.
- **Where** — `test/features/progress/`, `test/golden/progress/`.
- **Tests first (TDD, for what is left)** — tasks 2–9 already wrote the behavioural suite test-first;
  this task collects it and must not re-list it. What is left divides in two:
  - **TDD** — one acceptance gate (`testing-strategy` rule 8) at
    `test/features/progress/progress_acceptance_test.dart`: the seeded 581-day fixture projected
    end to end must produce **exactly** `daysOnDrug '581'`, `cumulativeMg '6,842'`,
    `adherence '574 of 581'`, 12 segments, 2 flare marks and 1 hold mark — the same numbers the
    reference frame shows. Plus the conservation invariant: the segments' day spans sum to 581, and
    `cumulativeMg` equals the sum of the fixture's `actualMg` over taken logs computed independently
    in the test. Back it with a runtime `assert` inside the reduction itself.
  - **Gate, not driver** — goldens across light/dark × en/fa × 1.0/2.0 and the grayscale lane proving
    the flare ring and the hold bracket are identifiable by shape alone. Captured alongside the
    widgets with `loadAppFonts`, the pinned clock and the shared fixture; the shape rule itself is
    already pinned by task 4's cases 4 and 5, which is what makes the grayscale image a check rather
    than the only evidence.
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
- **Tests first** — *Scaffold.* Parity is a **gate, not a driver**: the ΔE00 samples and the paired
  sheet can only be produced once the screen renders, and there is no honest way to write them
  failing first. The two claims in this section that *are* machine-checkable are already tests
  elsewhere — the stroke's 3:1 contrast (task 4, case 9) and the twelve treads (task 2, case 1).
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

- [ ] Every TDD task's tests were written first and observed failing before its implementation
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
