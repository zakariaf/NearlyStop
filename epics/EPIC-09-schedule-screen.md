# EPIC-09 — Schedule screen

**Branch:** `epic/09-schedule-screen`
**Depends on:** EPIC-06 (app shell, routing, `derivedScheduleProvider`, `appLocalizationsProvider`,
`todayDateProvider`), EPIC-07 (component library — `DayStateRow`, `DayStateMarker`, `BlockHeader`,
`ConfirmSheet` and the inline undo row). **Can run in parallel with EPIC-08 and EPIC-10** — it
imports nothing from `lib/features/today/`; the day-state vocabulary is EPIC-07's, not EPIC-08's.

## Where we are now

The Schedule branch of the `StatefulShellRoute` still renders a placeholder.

`EPIC-04` gives us `generateSchedule(plan, steps, flares, holds) -> List<DayPlan>` — pure, no clock,
no I/O — where each `DayPlan` carries `date` (a `LocalDate`), `stepIndex`, `blockIndex` (1–11 on
step days, `null` on steady-state days), `dayInBlock`, `dayInStep`, `dose` (`Milligrams`),
`doseKind`, `isHoldDay`, and the `TabletComposition` (including the explicit `unachievable` case).
It emits a `DayPlan` for **every** date in range, including the `DayKind.steadyState` days after a
step's realised length and after the final step.

`EPIC-05` gives **one** repository — `TaperRepository` at `lib/data/taper_repository.dart` — with a
single read, `watchSnapshot()`, and the mutations `markTaken(LocalDate, {required Milligrams
plannedMg})`, `undoTaken(LocalDate)`, `setNote`, `recordFlare`, `recordHold`, `startNextStep`.
There is no `watchStep(int)` and no `StepSnapshot`; there is no `markDay`/`unmarkDay`.

`EPIC-06` gives `derivedScheduleProvider` — `generateSchedule` run **once**, in the app layer, over
that snapshot — plus `todayDateProvider` (`Provider<LocalDate>`) and `appLocalizationsProvider`.

> **Contract:** CONTRACTS §3, §4, §15 — one repository, contract mutation names, derivation in
> providers. Nothing in this app is "cached in the repository layer"; that phrase is struck from
> this epic.

`EPIC-07` shipped `DayStateRow` (four states, shape-first: filled disc / hollow ring / ring-with-core
/ dashed circle, each with a glyph and a localized label) and `BlockHeader` at their canonical paths,
with component goldens. Nothing assembles them into a list yet, and there is no test anywhere that
stops a future contributor from reaching for a calendar widget.

## Why this epic exists

This screen is the core teaching idea of the entire product. DSNS is not "take a pill each day" — it
is a sequence of eleven blocks in which one day differs from its neighbours, and the gap between
those days shrinks and then inverts (SPEC §3.1). Patients who fail at this method fail because they
cannot hold that structure in their head, and the single most-asked question on the forum is *"what's
happening on the other four days?"*. Block headers answer it before it is asked: `Block 3 of 11 — one
day at 9mg, then 4 days at 10mg`. The header is the feature; the rows are the detail.

The corollary is the ban. A 7-column month grid re-creates precisely the confusion the app exists to
remove (SPEC §4.2, `daybreak-components` rule 4). A calendar square has no room for a state shape, a
localized state word and 200% text; it forces the eye to scan horizontally across unrelated days; and
it teaches "a taper is a month" when a taper is a sequence of blocks. So the ban is not a style
preference to be relitigated in a future PR — it gets a test.

Schedule is also where backdating lives. Several competitor reviews complain that ticking three days
late is impossible; SPEC §7 makes it a v1 requirement. Today's banner handles yesterday; everything
older is handled here, from the row itself.

## What we will have when it is done

A vertical, block-grouped day list that opens centred on today. Above it, the tail of the previous
block; below, the rest of the current block and the next block's header — scrollable in both
directions across the whole 52-day step. Completed steps are reached read-only through the step
switcher, not by scrolling into them. Each row reads weekday, date, dose, tablets, and a state that
is legible in grayscale and to a screen reader; hold days say they are hold days rather than
repeating "day 14 of 52" with no explanation. Today is pinned and highlighted with a sunrise marker;
a jump-to-today control returns to it from anywhere, and a `focus` route parameter lands the list on
a specific date so Today's backfill banner can send the user to their oldest missed day. Past days in
the active step can be ticked with one tap and undone. A past taken row keeps the dose and tablet
breakdown that was **recorded**, even after the prescription's strengths change. Scrolling a 780-row
history stays at 60/120fps. And a test in CI fails the build if anyone adds a grid.

## Skills to load

| Skill | What it governs here |
|---|---|
| `daybreak-visual-parity` | Frame-3 capture/compare, the 4-cell matrix, PR evidence. |
| `daybreak-components` | `BlockHeader`, `DayStateRow`'s four shapes, the explicit no-month-grid rule. |
| `daybreak-tokens` | Row/header fills, the today row's 2px `stateToday` border, `elevation.level1/level2`, `stateMissed` (never `danger`). |
| `state-management-riverpod` | `ScheduleNotifier`, the family over `stepIndex`, and memoised derivation. |
| `widget-composition` | Sliver group per block; every row a `const` class, never a `_buildRow()`. |
| `flutter-performance` | Lazy slivers, stable extents, `RepaintBoundary`, no per-frame regeneration. |
| `adaptive-layout` | Two-pane Schedule on wide screens; landscape row density. |
| `ui-states-and-feedback` | Empty (no plan), loading skeleton, tick/undo contract, read-only messaging. |
| `accessibility-as-code` | Row semantics as one sentence, 44pt rows, header semantics as `header: true`. |
| `widget-golden-and-a11y-testing` | Golden lanes incl. a grayscale lane for the four states. |
| `i18n-rtl-l10n` | Localized weekday/date, block-summary plurals, RTL row mirroring, numeral systems. |

## Tasks

### 1. Scaffold the Schedule feature module

- **What** — Create the feature under the standard layout.
- **Where** — `lib/features/schedule/application/schedule_view_provider.dart` (notifier + provider,
  per CONTRACTS §4), `lib/features/schedule/presentation/schedule_screen.dart`,
  `schedule_view_state.dart`, and `presentation/widgets/`
  (`schedule_block_group.dart`, `schedule_day_row.dart` wrapping EPIC-07's `DayStateRow`,
  `jump_to_today_button.dart`, `step_switcher_sheet.dart`, `earlier_days_affordance.dart`).
- **Details** — Same rule as Today: nothing in `widgets/` sees drift, the repository, or `WidgetRef`.
- **Acceptance** — `scaffold-feature-module`'s checklist satisfied; module compiles with a stub state.

### 2. `ScheduleViewState` — blocks, not days

- **What** — Model the screen as a list of blocks, each with its header text and its rows.
- **Where** — `lib/features/schedule/presentation/schedule_view_state.dart`.
- **Details** —
  ```dart
  final class ScheduleBlockVm {
    final int? blockNumber;           // 1..11; null for the steady-state group
    final String title;               // l10n.blockTitle(3, 11) -> "Block 3 of 11"
    final String summary;             // l10n.blockSummary(1, '9mg', 4, '10mg')
    final BlockStatus status;         // completed | current | upcoming
    final List<ScheduleDayVm> days;
  }
  final class ScheduleDayVm {
    final String dayLabel;            // "Wed 16 Apr", locale-formatted
    final String doseLabel;           // "9mg"  — see the source rule below
    final String tabletsLabel;        // "1 × 5mg, 4 × 1mg"  (or the unachievable message)
    final bool unachievable;
    final DayState state;             // taken | missed | today | upcoming — CONTRACTS §1
    final bool isNewDose;             // a separate bool, never a fifth DayState member
    final bool isHoldDay;             // DayPlan.isHoldDay — this day is held, not a new day 14
    final bool tickable;              // active step && date <= today
    final LocalDate date;             // only value the callback needs
    final Milligrams plannedMg;       // passed to markTaken — DoseLogs.plannedMg is non-null
  }
  ```
  > **Contract:** CONTRACTS §1 — `LocalDate` and `Milligrams` are the only date and dose types;
  > `DayState` has exactly `{taken, missed, today, upcoming}` and `isNewDose` is a separate bool.
  > CONTRACTS §3 — `markTaken` needs `plannedMg`, so the row carries it.

  **Where the labels come from — SPEC §5.2, and this is a correctness rule, not a detail.** For a
  row whose `state == taken`, `doseLabel` and `tabletsLabel` are sourced from the **`DoseLog`'s
  recorded `actualMg`** (and its recorded composition, where EPIC-05 stores one); for every other
  row they come from the derived `DayPlan`. EPIC-04's generator recomposes *all* days from the
  plan's current strengths, past included — so if the prescription changes from 5mg+1mg to
  2.5mg+1mg and the Schedule renders past rows from the `DayPlan`, every day the person already
  swallowed silently rewrites itself to a breakdown they never took. **Presentation joins; it does
  not overwrite.**

  **Hold days.** `DayPlan.isHoldDay` days repeat the host day's dose, `blockIndex`, `dayInBlock` and
  `dayInStep` — `dayInStep` deliberately does not advance. Without an explicit marker the list grows
  five identical rows all reading "day 14 of 52", which reads as a bug on the one screen whose whole
  job is making the structure legible. So `isHoldDay` rides on the vm and task 5 gives it chrome and
  a word.

  **Steady-state days.** Days with `blockIndex == null` (after a step's realised length, and after
  the taper reaches target) are not part of any block. They are grouped under a final
  `ScheduleBlockVm` with `blockNumber: null` and the title `l10n.steadyStateTitle` ("Holding at
  9mg"), so the list still covers every date the generator emits.
  `sealed class ScheduleViewState` = `ScheduleNoPlan | ScheduleLoaded(steps: StepNav, blocks:
  List<ScheduleBlockVm>, todayLocator: (blockIndex, dayIndex)?)`. `StepNav` carries the current step
  index, the total step count, and whether previous/next steps exist, so the app-bar switcher needs
  no extra query.
  The **block summary string is generated from the block table, not hardcoded** — it reads the
  pattern for that block and its dose pair, so blocks 7–11 correctly say "one day at 10mg, then 4
  days at 9mg" (the inverted half, SPEC §3.1) rather than always naming the new dose first.
- **Acceptance** — Unit tests assert the summary text for blocks 1, 6, 7 and 11 of a 10mg→9mg step,
  in `en` and `de`, and that block 6's single day still leads (SPEC §3.1's accepted crossover). Plus
  a test named for SPEC §5.2: change the plan's tablet strengths, re-project, and assert a **past
  taken** row's `doseLabel`/`tabletsLabel` are byte-identical to before while a **future** row's
  breakdown recomposes.

### 3. `ScheduleNotifier`

- **What** — A `StreamNotifier` family keyed by step index.
- **Where** — `lib/features/schedule/application/schedule_view_provider.dart` (per CONTRACTS §4 the
  notifier and its provider live under `application/`; the widgets stay in `presentation/`).
- **Details** —
  ```dart
  final scheduleViewProvider = StreamNotifierProvider.family<
      ScheduleNotifier, ScheduleViewState, int>(ScheduleNotifier.new);
  ```
  > **Contract:** CONTRACTS §4 — the provider is `scheduleViewProvider(stepIndex)`. EPIC-06's
  > bridge is `derivedScheduleProvider`; there is no second provider called `scheduleProvider` and
  > no name collision.

  `build(int stepIndex)` watches `todayDateProvider`, `derivedScheduleProvider` and
  `appLocalizationsProvider`, and maps `repo.watchSnapshot()` through a pure static
  `_project(snapshot, schedule, stepIndex, today, l10n)`. It **selects** the days of `stepIndex`
  from the already-derived schedule and joins them against the snapshot's `DoseLog`s; it does not
  call `generateSchedule` and it does not open a per-step query.

  **Derivation cost.** `generateSchedule` runs once, in EPIC-06's `derivedScheduleProvider`; this
  notifier selects a step from its output and memoises the block grouping. **Nothing is cached in
  the repository layer** — the repository returns facts only (CONTRACTS §4), and the earlier claim
  that it derives and caches per step is struck.

  Mutations: `markTaken(LocalDate date, {required Milligrams plannedMg})` and `undoTaken(LocalDate)`
  — the contract names (CONTRACTS §3, §15), forwarding the row's `plannedMg` because
  `DoseLogs.plannedMg` is non-null. Both refuse when the day is in a completed step or in the future,
  returning a typed `Failure.readOnly` / `Failure.futureDay` rather than silently no-oping.
  A `currentStepIndexProvider` (derived from the active step in the snapshot) supplies the default
  argument so the screen opens on the active step.
- **Acceptance** — Tests: ticking a past day in the active step calls `markTaken` once, with that
  day's `plannedMg`; ticking a day in a completed step returns `Failure.readOnly` and issues no
  write; switching `stepIndex` disposes the previous subscription (`ref.onDispose` asserted); and a
  `_project` test over a step containing a `HoldEvent` asserts the hold days carry `isHoldDay: true`
  and do not advance `dayInStep`.

### 4. The sliver list, centred on today

- **What** — Build the scroll view with pinned block headers and bidirectional growth.
- **Where** — `schedule_screen.dart`, `widgets/schedule_block_group.dart`.
- **Details** — `CustomScrollView` with a `center:` key placed on the **current block's**
  `SliverMainAxisGroup`. Slivers listed *before* the center sliver grow toward the leading edge and
  are therefore emitted in **reverse order** — this is the real Flutter mechanism for "opens in the
  middle, scrolls both ways" and it avoids any offset arithmetic or a third-party positioned-list
  package. Each block is:
  ```dart
  SliverMainAxisGroup(slivers: [
    SliverPersistentHeader(pinned: true, delegate: BlockHeaderDelegate(vm)),
    SliverList.builder(itemCount: vm.days.length, itemBuilder: …),
  ])
  ```
  `SliverMainAxisGroup` (Flutter 3.16+) is what makes a pinned header stick only for the duration of
  its own block instead of the whole list — with plain slivers, header 3 would pin over block 4's
  rows. `BlockHeaderDelegate` must return stable `minExtent`/`maxExtent`; because the header height
  depends on text scale, compute it once per build from `MediaQuery.textScalerOf(context).scale(…)`
  and rebuild the delegate when the scale changes (`shouldRebuild` compares it).
- **Acceptance** — Pumping the screen shows the current block's header at the top and today's row
  visible without any programmatic scroll; dragging up reveals the previous block's tail, dragging
  down reveals the next block's header.

### 5. Day row

- **What** — Render `DayStateRow` with the schedule's data and its tap behaviour.
- **Where** — `widgets/schedule_day_row.dart`.
- **Details** — The row wraps EPIC-07's `DayStateRow` and `DayStateMarker`; **the marker's diameter,
  the four shapes and the four state colour slots are EPIC-07's** and are not restated here (it is a
  fixed 28 logical px marker, not 26). This epic supplies data, layout around the marker, and tap
  behaviour.
  Reference geometry: `surface` fill, `border` hairline, `shapes.radiusMd`, padding
  `shapes.s3`/`shapes.s4`, min height 64, 8px gap between rows.
  Middle column: `dayLabel` at body/w800 over `tabletsLabel` at caption/w600 `inkMuted`. Trailing
  column, end-aligned: `doseLabel` at body-lg/w800 over the state word — uppercase + `.06em` tracking
  in Latin, **no `toUpperCase()` and no tracking in `fa`/`ckb`** (`daybreak-bilingual-type`).
  State-specific chrome, exactly as the reference: `today` gets a 2px `stateToday` border,
  `elevation.level2`, larger padding, a sunrise-gradient marker with `elevation.glow`, and its state
  word in `primaryDeep`; `taken` state word in `success`; **`missed` gets a dashed border in
  `c.stateMissed` and its word in `c.stateMissed` — never `danger`**; `upcoming` keeps the flat
  surface and a dashed faint marker.
  > **Contract:** CONTRACTS §9 — `missed` is `stateMissed`, the warm taupe, and never `danger`.
  > EPIC-02 argued this deliberately (red punishes a person for a bad week), EPIC-07 repeats it, and
  > EPIC-14 ships a gate that fails the build if it drifts to `danger`. The earlier `danger` +
  > `borderStrong` instruction in this task and in the parity section was wrong and is removed.
  > CONTRACTS §9 also settles the slot names: `elevation.level0…level3` / `glow`, never `shadow*`.
  A row whose dose differs from the previous day carries the `newDose` marker
  (`stateNewDose` + up/down glyph + the word) — the moment this population makes mistakes.
  **A hold day (`isHoldDay`)** carries its own marker — a bracketed tread glyph, distinct in *shape*
  from the four day states, not a colour variant — plus the localized word `l10n.held` in the
  trailing column where the state word sits, and its middle column reads
  `l10n.heldAtBlock(blockNumber)` instead of repeating "day 14 of 52". Its semantics sentence says
  the day is a hold (task 9).
  Unachievable days replace `tabletsLabel` with the warning text and add the alert glyph.
  Tap: only when `tickable`; single tap toggles taken with `HapticFeedback.selectionClick()` and the
  **inline undo row** named in EPIC-07 task 8 — never a `SnackBar`. Non-tickable rows are not
  `InkWell`s at all (no dead-tap feedback) but expose an `onLongPress`-free
  `Semantics(hint: l10n.pastStepReadOnly)`.
- **Acceptance** — Grayscale golden of all four states plus new-dose plus a hold day: each is still
  identifiable by shape and word. A test asserts an upcoming row has no gesture detector, and a test
  asserts the missed row's border and state-word colours both resolve to `c.stateMissed` in light
  and dark.

### 6. Ban the month grid — with a test

- **What** — Make the calendar ban mechanically enforced, not a convention.
- **Where** — `test/features/schedule/no_calendar_grid_test.dart`, plus a rule group added to
  **`tool/check_bans.sh`** — the single accumulate-and-fail-once gate EPIC-01 established. Do not
  create `scripts/check_no_calendar.sh`: `tool/` is the script directory and one entry point is the
  convention, so a rule tightened here is not silently missing from a second script.
- **Details** — Two layers.
  (a) **Widget test:** pump `ScheduleScreen` with a seeded plan and assert
  `find.byType(GridView)`, `find.byType(SliverGrid)`, `find.byType(CalendarDatePicker)`,
  `find.byType(Table)` are all `findsNothing`, and that `find.byType(BlockHeader)` is
  `findsAtLeastNWidgets(2)`.
  (b) **Source check:** a rule in `tool/check_bans.sh` grepping `lib/features/schedule/` for
  `GridView`, `SliverGrid`, `GridDelegate`, `table_calendar`, `CalendarDatePicker`, `showDatePicker`,
  contributing a failure with a message naming SPEC §4.2 as the reason. `showDatePicker` remains
  legal in the Plan feature (date *entry*), and the rule is path-scoped to the schedule directory to
  say so precisely.
- **Acceptance** — Both run in CI; deliberately adding a `GridView` to the screen turns the build
  red, and the failure message explains why rather than just failing.

### 7. Jump to today, and step navigation

- **What** — Get back to today from anywhere; browse other steps read-only.
- **Where** — `widgets/jump_to_today_button.dart`, `widgets/step_switcher_sheet.dart`.
- **Details** — Jump-to-today is a small pill button that appears only when today's row is off
  screen; it is driven by a `ScrollController` listener comparing the controller offset against zero
  (with the `center:` key, today's block starts at offset 0, so "today is off screen" is
  `offset.abs() > todayRowOffsetWithinBlock + slack`) and animating back with
  `animateTo(0, duration: motion.base, curve: motion.easeOut)` — both read from `resolveMotion`, so
  it collapses to `jumpTo` under reduced motion. **A bare `Curves.` outside `lib/theme/` is rejected
  by the raw-values gate**, so the curve comes from the `DaybreakMotion` slot, never from
  `Curves.easeOutCubic`. When the user is browsing a *different* step, the same control switches back
  to the active step first.
  The app-bar chevron is `Icons.adaptive.arrow_forward`/`arrow_back` (which mirror themselves —
  EPIC-01's ban gate rejects the non-adaptive names) and opens a sheet listing the steps
  (`Step 1 · 15mg → 14mg · completed`, …) and sets the family argument. Non-active steps render with
  a read-only strip at the top: `l10n.pastStepReadOnly`.
  **Deep link.** The route accepts an optional `focus` query parameter carrying an ISO date
  (`/schedule?focus=2026-04-13`). On entry the screen selects the step containing that date and
  scrolls its row into view with the same animation. This is what EPIC-08 task 7's backfill banner
  targets when more than one day is outstanding — EPIC-08 owns the banner and its plural copy; this
  epic owns only the landing.
- **Acceptance** — Scrolling 30 rows away shows the control; tapping it returns today's row to view;
  switching to step 1 shows the read-only strip and rows with no gesture detectors; entering with
  `?focus=<a date four days back>` opens on that date's step with the row visible and tickable.

### 8. Loading old blocks and long-history performance

- **What** — Keep a 780-row history smooth.
- **Where** — `schedule_screen.dart`, `schedule_notifier.dart`.
- **Details** — Only the selected step (52 rows + 11 headers) is materialised; other steps are
  reached through the switcher, not by scrolling into them, which keeps the sliver tree bounded and
  makes `center:` arithmetic exact. Rows are `const`-constructible with a stable `ValueKey(date)`;
  wrap each block's `SliverList` in a `RepaintBoundary`; supply
  `SliverChildBuilderDelegate(addAutomaticKeepAlives: false, addRepaintBoundaries: true)` semantics
  defaults deliberately rather than by accident. No `Opacity`, no `ClipRRect` per row (use
  `BoxDecoration(borderRadius:)`). Profile with `flutter run --profile` + the DevTools timeline over
  a 52-row fling and record the worst frame in the PR.
- **Acceptance** — No frame over 16ms in the profile-mode fling on the reference device; the raster
  thread shows no per-row clip layers.

### 9. Accessibility

- **What** — Rows and headers that read as sentences.
- **Where** — `widgets/schedule_day_row.dart`, `widgets/schedule_block_group.dart`.
- **Details** — Each row is one `Semantics(container: true, button: tickable, label: …)` reading
  *"Wednesday 16 April, 9 milligrams, one 5 milligram tablet and four 1 milligram tablets, taken"*,
  with children excluded. Today's row adds the word "today" first. Block headers are
  `Semantics(header: true)` so rotor/heading navigation jumps block to block — the fastest way for a
  screen-reader user to traverse 52 days. A hold day's sentence says so explicitly —
  *"Wednesday 16 April, held at 9 milligrams, extra day in block 3, taken"* — so a run of five
  identical-looking rows is explained rather than mysterious. Tick/untick announces through a
  `liveRegion`. Every row is ≥ 44 tall at every scale; at 2.0 the trailing column moves beneath the
  middle column (`Row` → `Column`) rather than truncating.
- **Acceptance** — `SemanticsTester` asserts the sentences in `en` and `fa`; heading navigation test
  finds 11 headers; all four guideline tests pass at 1.0 and 2.0 scale.

### 10. Adaptive layout

- **What** — Wide-screen and landscape behaviour.
- **Where** — `schedule_screen.dart`.
- **Details** — Above 840 logical px, `adaptive-layout`'s two-pane Schedule: a step list on the
  leading side, the block list on the trailing side, sharing the same providers. In landscape phone
  (height < 500), the header keeps its pinned behaviour but drops the summary's second line before
  anything else. The list never becomes multi-column — that is a grid by another name.
- **Acceptance** — Golden at 1024×768 shows two panes; golden at 844×390 (landscape phone) shows a
  single column with no clipping.

### 11. Tests and goldens

- **What** — The set that holds the screen.
- **Where** — `test/features/schedule/`, `test/golden/schedule/`.
- **Details** — `_project` unit tests (grouping, block summaries, today locator, tickability, hold
  days, the steady-state group, and the SPEC §5.2 strengths-change join from task 2); widget tests
  for tick/untick/read-only/undo and for the `?focus=<date>` landing; the calendar-ban test from
  task 6; goldens across light/dark × en/fa × 1.0/2.0 plus one grayscale lane that includes a hold
  row; all against a pinned clock and a seeded fixture at step 3, block 3, day 14 of 52 so the
  capture matches the reference's content.
- **Acceptance** — `flutter test` green; goldens reproducible on the CI runner.

### 12. Visual parity pass

- **What** — Prove the screen against frame 3.
- **Where** — `parity/ref/03--schedule--{light,dark}--{en,fa}.png`, `parity/app/…`, `parity/sheet.html`.
- **Details** — Crop frame 3 at CSS rect `[883, 516, 390, 844]` (PNG `+1766+1032`, 780×1688),
  content-box adjusted for the 54px status bar; capture at 390×844 DPR 2 with the seeded fixture that
  reproduces the reference content: block 2 tail (Mon 14 Apr taken, Tue 15 Apr not ticked), block 3
  current with Wed 16 Apr as today, four upcoming days, then block 4's header. Add the `de`, `ckb`
  and 200% no-reference passes and the grayscale pass (`daybreak-visual-parity` rule table).
- **Acceptance** — Paired sheet in the PR; Tier-1 rows exact, Tier-2 measurements stated and inside
  ±2 logical px.

## Visual parity

**Reference:** frame 3 — "Schedule (blocks, not a calendar)" (row 1, column 3; CSS rect
`[883, 516, 390, 844]`) in all four committed sheets.

**Variants:** light/en, light/fa, dark/en, dark/fa. Plus `de` longest-string (German block summaries
are the longest strings in the app — "ein Tag mit 9 mg, dann 4 Tage mit 10 mg"), `ckb`, 200% scale,
and the grayscale pass that `daybreak-visual-parity` requires specifically for Schedule.

**What must match exactly:** the "Schedule" title and the trailing chevron button; the block header
**as EPIC-07 ships `BlockHeader`** — its fill, radius, hairline and glyph treatment are EPIC-07's
call and this epic asserts the component rather than restating values; the current block header's
selected treatment; the row order (block 2 tail: one taken, one not-ticked → block 3 header → today
→ four upcoming → block 4 header); the today row's 2px `stateToday` border, `elevation.level2` and
gradient marker; the taken row's `success` state word; **the missed row's dashed `c.stateMissed`
border and `c.stateMissed` word — never `danger`**; the trailing dose/state column's end alignment.
And, non-negotiably, that **no cell of the rendered screen is a calendar square**.

Where this section and EPIC-07 disagree about a component's tokens, EPIC-07 wins and the difference
is resolved against the reference PNG **in EPIC-07 only** (CONTRACTS §9).

**RTL:** the whole row mirrors (marker on the right, dose column on the left), the app-bar chevron
flips, the state words lose their uppercase and tracking, and dates render in the Jalali calendar
with Persian numerals.

Method, tolerances and the PR sheet: `daybreak-visual-parity`.

## Definition of done

- [ ] Days render as a vertical list grouped under pinned `BlockHeader`s — one `SliverMainAxisGroup`
      per block
- [ ] `no_calendar_grid_test.dart` and the schedule rule group in `tool/check_bans.sh` both run in CI
      and both fail on an introduced grid, with a message naming SPEC §4.2
- [ ] Block summaries are generated from the block table and correct for the inverted second half
- [ ] `scheduleViewProvider(stepIndex)` selects from EPIC-06's `derivedScheduleProvider`; nothing in
      this feature calls `generateSchedule` and nothing is cached in the repository layer
- [ ] The screen opens centred on today via `CustomScrollView(center:)`; both directions scroll;
      `?focus=<date>` lands on that date's step and row
- [ ] Jump-to-today appears only when today is off screen and returns to it, using `resolveMotion` —
      no bare `Curves.` anywhere in the feature
- [ ] Past days in the active step tick and untick through `TaperRepository`'s `markTaken`(with
      `plannedMg`)/`undoTaken`; completed steps are read-only and say so
- [ ] A past **taken** row renders the recorded `actualMg` and its recorded breakdown; changing
      tablet strengths recomposes future days only (SPEC §5.2), proven by a `_project` test
- [ ] Hold days carry their own marker and the word "held", and a `_project` test over a `HoldEvent`
      pins that `dayInStep` does not advance
- [ ] All four day states carry shape + glyph + localized word, and `missed` is `c.stateMissed` —
      never `danger`; the grayscale golden proves the shapes
- [ ] Rows read as one sentence; block headers are semantic headings; every row ≥ 44 tall at 2.0 scale
- [ ] Profile-mode fling over a full 52-day step shows no frame over 16ms; evidence in the PR
- [ ] Goldens for light/dark × en/fa × 1.0/2.0 plus grayscale committed and green
- [ ] Frame-3 parity sheet for all four reference cells, plus `de`, `ckb`, 200% and grayscale passes
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, parity evidence, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
