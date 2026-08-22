# EPIC-08 — Today screen

**Branch:** `epic/08-today-screen`
**Depends on:** EPIC-06 (app shell, routing, bootstrap), EPIC-07 (Daybreak component library)

## Where we are now

The app runs. `EPIC-06` left a `StatefulShellRoute.indexedStack` with five branches (`/today`,
`/schedule`, `/progress`, `/plan`, `/settings`), a `DaybreakTabBar` that is always labelled, a
bootstrap that opens the drift database and hydrates settings, and the three seams this epic builds
on: `clockProvider`, `todayDateProvider` (a **`Provider<LocalDate>`** that EPIC-06's `DayTicker`
invalidates at local midnight and on resume — it is not a stream and it owns the only timer),
`derivedScheduleProvider` (`generateSchedule` run **once**, in the app layer, over the repository's
snapshot), and `appLocalizationsProvider`. The Today branch currently renders a placeholder.

> **Contract:** CONTRACTS §4 — derivation lives in app/feature providers, never in the repository,
> and `appLocalizationsProvider` is the only sanctioned way to reach `AppLocalizations` outside a
> widget.

`EPIC-04` shipped the pure engine under `lib/core/dsns/` — `blockTable` (the eleven-block table of
SPEC §3.1, single day leads, `patternVersion` frozen per step), `generateSchedule(plan, steps,
flares, holds) -> List<DayPlan>`, and `composeTablets(doseMg, strengths, allowHalves) ->
TabletComposition` which returns an explicit `unachievable` case rather than rounding. The generator
emits a `DayPlan` for **every** date in range: `DayKind.step` days inside a step, and
`DayKind.steadyState` days (dose = that step's `toDose`, `blockIndex: null`, `dayInStep: null`)
after a step's realised length, between steps, and indefinitely after the final step.

> **Contract:** CONTRACTS §5 — steady-state days exist. Day 53 of a step, the gap before the user
> taps *Start next step*, and every day after the taper reaches target all have a `DayPlan`, and
> this screen must render them.

`EPIC-05` shipped **one** repository, `TaperRepository` at `lib/data/taper_repository.dart`, with a
single read — `Stream<Result<TaperSnapshot, StorageFailure>> watchSnapshot()` — and a **single write
path**: `markTaken(LocalDate, {required Milligrams plannedMg})`, `undoTaken(LocalDate)`,
`setNote(LocalDate, String?)`, `recordFlare({required LocalDate on, required Milligrams revertTo})`,
`recordHold({required int stepId, required LocalDate from, required int extraDays})` and
`startNextStep()`, every one returning `Result<void, StorageFailure>`. There is no `watchToday`, no
`TodaySnapshot`, and no `markDay`/`unmarkDay`/`addNote` — CONTRACTS §3 and §15 settled those names
and this epic must not reintroduce them.

`EPIC-07` delivered the recipes catalogued in `daybreak-components` as named `const` widget classes
with gallery entries and component goldens — including `DoseHeroCard` at
`lib/features/today/presentation/widgets/dose_hero_card.dart` (gradient card, `SunriseArcPainter`,
degradation ladder) and `BackfillBanner`, `PrimaryPillButton`, `TertiaryButton`. They are wired to
constructor arguments only; nothing feeds them real data yet.

There is no `TodayNotifier`, no Today screen, no parity evidence for frame 2.

## Why this epic exists

Today is the product. A person aged 60–80 opens this app on roughly 780 consecutive mornings and asks
one question — *what do I swallow today?* — and everything else in the app exists to make that answer
trustworthy. If the answer needs a scroll, a tap, or a squint, the app has failed regardless of how
correct the DSNS arithmetic underneath is (SPEC §4.1).

It is also where the write path is proven. Ticking **Taken** is the entire daily interaction, and it
has to commit through `TaperRepository` so the watched stream re-emits and every other surface —
Schedule's row state, Progress's cumulative mg, the notification's payload — sees the same fact
without anyone re-deriving it. Any shortcut here (writing straight to a DAO, keeping a local `bool`)
becomes a divergence bug two years into a taper, and by then the evidence is gone.

And it is where the alternating-day method has to *read* as obvious. A DSNS day is either the old
dose or the new one, and the difference between 9mg and 10mg is invisible unless the screen says so
in shape, glyph and words. The "New dose day" badge and the quiet context line are the two devices
that keep the user oriented inside a 52-day block structure they did not design and cannot see.

## What we will have when it is done

Opening the app lands on a Today screen that answers the dose question at arm's length without
glasses and without scrolling: the date, a sunrise hero card carrying the numeral, the tablet
breakdown as physical counts, a "New dose day" badge when the dose changed, and one 88pt-tall Taken
button. Tapping Taken writes through the repository, the stream re-emits, the card flips to a taken
state with a haptic and a live-region announcement, and killing the app and reopening it shows the
same thing. If days were never ticked, a persistent banner says how many and offers one tap to
backfill. **Flare** and **Hold** — SPEC §5.2's headline features — are fully built here: each opens a
confirm sheet that lets the user choose the values (a revert dose and next step size for Flare, a
number of extra days for Hold), states plainly that history and the cumulative total are kept, and
commits through the repository. When a step's 52 days are done and the next has not been started, the
screen says so and offers *Start next step* instead of rendering nothing. The screen survives 200%
text scale with the numeral untouched, reads as one natural sentence under VoiceOver, and matches
frame 2 of the Daybreak reference in light and dark, LTR and RTL.

## Skills to load

| Skill | What it governs here |
|---|---|
| `daybreak-visual-parity` | The frame-2 capture/compare method, the 4-cell matrix, and the PR evidence sheet. |
| `daybreak-components` | Dose hero card, badge, Taken button ladder, backfill banner, degradation order, never-colour-alone. |
| `daybreak-tokens` | Every colour/radius/shadow/spacing read; the `onPrimary`-on-both-gradient-stops contrast check. |
| `state-management-riverpod` | `TodayNotifier` as a `StreamNotifier`, mutation methods, no business logic in the widget. |
| `widget-composition` | Class-not-method for every part of the screen; dumb views taking pre-formatted primitives. |
| `ui-states-and-feedback` | Loading / empty (no plan) / error / step-finished / taper-complete states, EPIC-07's `ConfirmSheet` for Flare and Hold, the inline undo row for Taken. |
| `accessibility-as-code` | The one-sentence semantic container, 44/88pt targets, never clamping `textScaler`. |
| `motion-and-haptics` | The Taken press animation and `HapticFeedback`, collapsing under reduced motion. |
| `widget-golden-and-a11y-testing` | Golden lanes for light/dark × en/fa × 1.0/2.0, and the a11y guideline assertions. |
| `adaptive-layout` | Landscape and tablet behaviour (SPEC §5.4 — people prop tablets on a kitchen table). |
| `scaffold-feature-module` | The `lib/features/today/` layout this epic fills in. |
| `i18n-rtl-l10n` | ARB keys, `NumberFormat`/`DateFormat` per locale, mirrored arc and chevron. |

## Tasks

### 1. Fill in the Today feature module

- **What** — Complete `lib/features/today/` so the screen, its state, and its widgets sit where
  `scaffold-feature-module` puts them.
- **Where** — `lib/features/today/application/today_view_provider.dart` (notifier + provider, per
  CONTRACTS §4), `lib/features/today/presentation/today_screen.dart`, `today_view_state.dart`, and
  `presentation/widgets/` (existing `dose_hero_card.dart`, new `today_date_header.dart`,
  `dose_context_line.dart`, `quiet_action_row.dart`, `new_dose_badge.dart`,
  `tablet_breakdown_pill.dart`, `flare_sheet.dart`, `hold_sheet.dart`).
- **Tests first** — *Scaffold.* Creating directories and empty files asserts nothing; a test that
  pumps an empty module only proves Flutter compiles. The layering rule this task establishes is
  verified by the grep in **Acceptance**, added as a rule group to `tool/check_bans.sh`
  (`lib/features/*/presentation/widgets/` may not match `package:drift`, `taper_repository`,
  `WidgetRef`, `ProviderScope`) so CI fails the day someone reaches for the repository from a widget.
- **Details** — No file in `presentation/widgets/` may import drift, `TaperRepository`, or
  `WidgetRef`. Each widget takes pre-formatted, pre-localized `String`s and callbacks. The screen
  itself is the only `ConsumerWidget`.
- **Acceptance** — `grep -rn "package:drift\|WidgetRef" lib/features/today/presentation/widgets/`
  returns nothing.

### 2. `TodayViewState` — the whole screen as one immutable value

- **What** — A sealed view state that the widget layer renders without a single conditional over
  domain types.
- **Where** — `lib/features/today/presentation/today_view_state.dart`.
- **Tests first (TDD)** — `test/features/today/today_view_state_test.dart`, pure `package:test`
  (this file is data only: it imports `package:meta`, `LocalDate` and `Milligrams`, and no Flutter,
  so it must not need `flutter_test` to be tested — if it does, the file has a dependency it should
  not have). Write and watch fail, in this order:
  1. two `TodayDose`s built from identical field values are `==` and have equal `hashCode`; flipping
     `taken` alone makes them unequal — this is what stops every stream emission repainting the hero
  2. `TodayDose(tablets: null, unachievableMessage: null)` throws (assertion): a null breakdown must
     always carry the flagged reason, per SPEC §3.3 — never a silently empty pill
  3. `TodayDose(isSteadyState: true, dayInStep: '14', stepLength: '52')` throws: on a steady-state day
     `dayInStep`/`blockIndex` are null upstream and must never be formatted, which is the whole
     reason the flag exists
  4. `TodayStepFinished` equality over `nextStepPreview` and `canStartNextStep`; `TodayNoPlan` and
     `TodayTaperComplete` are each equal to another instance of themselves (const singletons)

  Exhaustiveness of a four-arm `switch` is a **compile-time** guarantee of `sealed`, not a runtime
  assertion — do not write a test for it; adding a fifth variant breaks the build, which is the point.
- **Details** — `sealed class TodayViewState` with **four** variants: `TodayNoPlan`,
  `TodayStepFinished`, `TodayTaperComplete`, and `TodayDose` (the normal case).
  `TodayDose` carries:
  `dateLine` (localized "Wednesday 16 April"), `doseAmount` (String, `NumberFormat.decimalPattern`
  in the active locale — Persian renders `۹`), `doseUnit`, `tablets` (String, e.g.
  `1 × 5mg · 4 × 1mg`, or `null` when the composition is `unachievable`),
  `unachievableMessage` (String?), `isNewDoseDay` (bool), `taken` (bool), `stepIndex`, `stepCount`,
  `fromDose`, `toDose`, `dayInStep`, `stepLength` (all pre-formatted Strings for the context line),
  `backfill` (`BackfillPrompt?` = `LocalDate oldest`, `int count`, localized label),
  `noteText` (String?), and the two prompts task 9 needs — `FlarePrompt flare` and
  `HoldPrompt? hold` (null when there is no active step to hold).
  `TodayStepFinished` is the variant for **"this step's days are used up and you have not started
  the next one"**. On those dates `generateSchedule` returns a `DayKind.steadyState` day at the
  step's `toDose`, so the screen still has a dose to render — it renders the same hero (dose,
  tablets, Taken) plus a *Start next step* primary action and a one-line explanation
  (`l10n.stepFinishedExplainer`). It carries the same dose/tablet/taken fields as `TodayDose` plus
  `stepIndex`, `stepCount`, `nextStepPreview` (pre-formatted "9mg → 8.5mg") and
  `canStartNextStep` (bool). Without this variant day 53 of a 780-day taper renders nothing.
  `TodayDose.isSteadyState` (bool) marks a steady-state day that is *not* the end of a step — the
  context line then reads `l10n.holdingAtDose(dose)` instead of "Day 14 of 52", because
  `dayInStep`/`blockIndex` are null on those days and must never be formatted as `0`.
  Use `@immutable` + `==`/`hashCode` (or `equatable`-free manual overrides per
  `dart3-idioms-and-coding-standards`) so `StreamNotifier` rebuilds are cheap.
  > **Contract:** CONTRACTS §5 — steady-state days and the fourth variant exist because the
  > generator now covers every date. CONTRACTS §1 — `LocalDate` and `Milligrams` are the only date
  > and dose types; this file defines neither.
- **Acceptance** — A widget test can construct every variant with no repository and no container; a
  `switch` over `TodayViewState` is exhaustive with exactly four arms.

### 3. `TodayNotifier` — the stream, not a snapshot

- **What** — A `StreamNotifier` that composes today's date, the derived schedule and the logs into
  `TodayViewState`, and exposes the mutations.
- **Where** — `lib/features/today/application/today_view_provider.dart` (the notifier and its
  provider live under `application/`, per CONTRACTS §4; the widgets stay in `presentation/`).
- **Tests first (TDD)** — two files, two tiers. This task is the epic's real logic and carries the
  most tests; write them all before the notifier exists.

  **(a) `test/features/today/today_projection_test.dart`** — the pure projection. `flutter_test` but
  **no `pumpWidget` and no container**: `_project` is exposed as
  `@visibleForTesting static TodayViewState project(...)` and takes `AppLocalizations` (a Flutter
  type), so the binding is needed only to `await AppLocalizations.delegate.load(const Locale('en'))`.
  Everything else is `f(input) → output`. Build the snapshot/schedule inputs by hand — small, named,
  literal — not from the golden fixture. Write and watch fail, in this order:
  1. new-dose day: `DayPlan(date 2025-04-16, doseKind newDose, dose 900, blockIndex 3, dayInStep 14)`,
     no log → `TodayDose` with `isNewDoseDay true`, `taken false`, `doseAmount '9'`,
     `tablets '1 × 5mg · 4 × 1mg'`, `dayInStep '14'`, `stepLength '52'`, `isSteadyState false`
  2. old-dose day: same step, `doseKind oldDose`, `dose 1000` → `isNewDoseDay false`,
     `doseAmount '10'`, `tablets '2 × 5mg'`
  3. steady-state day: `blockIndex null`, `dayInStep null`, dose = step's `toDose` →
     `isSteadyState true`, `dayInStep null`, and the context segment is `l10n.holdingAtDose('9')` —
     assert the string is **not** `'0'` anywhere, which is the bug this branch exists to prevent
  4. unachievable composition (dose 75 = 0.75mg against strengths 5mg+1mg, halves on) →
     `tablets == null` and `unachievableMessage == l10n.doseNotAchievable('0.75')`
  5. already taken: a `DoseLog(date today, taken true, actualMg 900)` → `taken true`,
     `backfill == null`
  6. trailing run: today untaken, the four calendar days before it in-plan with no `taken` log, and
     the day before *those* taken → `backfill.count == 4` and `backfill.oldest == today - 4 days`.
     The taken day terminates the run: a fifth untaken day *behind* it does **not** raise the count
     to 5 — the prompt is the trailing run, not the lifetime total
  7. no plan (`TaperSnapshot.plan == null`) → `TodayNoPlan`
  8. step's realised days exhausted, next step not started → `TodayStepFinished` with
     `nextStepPreview '9mg → 8.5mg'` (CONTRACTS §6's corrected worked example — never `9mg → 8mg`)
     and `canStartNextStep true`, and it still carries a dose, tablets and `taken` because
     day 53 is a real day with a real dose
  9. target reached (plan target 0, current dose 0) → `TodayTaperComplete`
  10. `fa` locale on case 1 → `doseAmount == '۹'` and the date line is Jalali, proving formatting
      lives here and not in a widget
  11. seeded fuzz over the whole generated range (`seed 0…199`, one `LocalDate` each, drawn from the
      schedule with `Random(0x70DA7)`): for every date, `project` returns exactly one variant, never
      throws, and — the independent oracle being the `DayPlan` list itself — the projected
      `doseAmount` parses back to that day's `DayPlan.dose`. Echo the date in `reason:`.

  **(b) `test/features/today/today_notifier_test.dart`** — the writes, headless via
  `ProviderContainer` (never a pumped widget), with a bare-`implements` `FakeTaperRepository` that
  records calls and can be told to fail; `clockProvider.overrideWithValue(Clock.fixed(...))` and
  `todayDateProvider.overrideWithValue(LocalDate(2025, 4, 16))`; `addTearDown(container.dispose)`.
  Write and watch fail:
  1. `markTakenToday()` → the fake records **exactly one** `markTaken(2025-04-16, plannedMg: 900)`;
     the recorded `plannedMg` is the `DayPlan`'s dose, not a default and not `null`
  2. the fake's next emission with that log flips the state to `taken: true` — the notifier holds no
     local bool
  3. `saveNote('slept badly')` → exactly one `setNote(2025-04-16, 'slept badly')`, and the call
     carries `plannedMg` for the row-creating case (CONTRACTS §3)
  4. `undoLast()` → exactly one `undoTaken(2025-04-16)`
  5. failure arm: the fake returns `Failure(StorageFailure.io())` from `markTaken` → state is
     `AsyncError` **and** `state.hasValue` is still true with the previous `TodayDose` intact
     (`copyWithPrevious`), so the screen does not blank; and no second call is issued on retry-less
     rebuild
  6. `backfill(date)` forwards *that* date's `plannedMg`, not today's
- **Details** —
  ```dart
  final todayViewProvider =
      StreamNotifierProvider<TodayNotifier, TodayViewState>(TodayNotifier.new);

  class TodayNotifier extends StreamNotifier<TodayViewState> {
    @override
    Stream<TodayViewState> build() {
      final date     = ref.watch(todayDateProvider);        // Provider<LocalDate>, EPIC-06
      final schedule = ref.watch(derivedScheduleProvider);  // EPIC-06: generateSchedule, once
      final l10n     = ref.watch(appLocalizationsProvider); // EPIC-06: rebuilds on locale change
      final repo     = ref.watch(taperRepositoryProvider);
      return repo.watchSnapshot().map((r) => _project(r, schedule, date, l10n));
    }
  }
  ```
  > **Contract:** CONTRACTS §4 — the provider is named `todayViewProvider` (EPIC-06's
  > `todayProvider` was deleted, so there is no name collision), and it reads
  > `derivedScheduleProvider` rather than opening a second repository query or calling
  > `generateSchedule` itself. Nothing here re-derives what EPIC-06 already derived.

  `_project` is a **pure static function** — snapshot + schedule + date + l10n in, view state out —
  so it is unit-testable with no container. It selects today's `DayPlan` from the schedule, the
  `DoseLog`s for today and for the trailing run of un-ticked past days, and the active step; it
  chooses the variant (`TodayNoPlan` / `TodayStepFinished` / `TodayTaperComplete` / `TodayDose`)
  and formats every string. Formatting (`DateFormat.yMMMMEEEEd(locale)`, `NumberFormat`) happens
  here, never in a widget.

  Mutations, all named for CONTRACTS §3's repository API:
  `Future<void> markTakenToday()` → `repo.markTaken(today, plannedMg: dayPlan.dose)`;
  `Future<void> backfill(LocalDate date)` → `repo.markTaken(date, plannedMg: thatDay.dose)`;
  `Future<void> undoLast()` → `repo.undoTaken(date)`;
  `Future<void> saveNote(String? text)` → `repo.setNote(date, text)`;
  plus `recordFlare` and `recordHold` from task 9.
  **`plannedMg` is mandatory on `markTaken` and `setNote`** — `DoseLogs.plannedMg` is non-null and
  the repository does not run the generator, so the notifier passes the `DayPlan`'s dose it already
  holds (CONTRACTS §3). Each mutation awaits the repository's `Result`, and on `Failure` sets
  `state = AsyncError(e, st).copyWithPrevious(state)` so the screen never blanks on a write error.
  No mutation writes to a DAO directly.
- **Acceptance** — Unit tests over `_project` cover new-dose day, old-dose day, steady-state day,
  unachievable dose, already-taken, a run of un-ticked past days, no plan, step finished but next
  not started, and target reached. A write test asserts exactly one `markTaken` call — with the
  right `plannedMg` — reaches the repository per tap.

### 4. Date header and app bar

- **What** — The date line above the "Today" title, plus the note icon button.
- **Where** — `widgets/today_date_header.dart`, used from `today_screen.dart`.
- **Tests first (TDD)** — `test/features/today/widgets/today_date_header_test.dart`, `flutter_test`
  widget tier (the header takes pre-formatted strings, so nothing here needs a container). Write and
  watch fail:
  1. tapping the trailing icon button invokes `onOpenNote` **once**; the widget itself opens nothing
  2. LTR: the icon button's `globalTopLeft.dx` is greater than the date text's — trailing edge
  3. RTL (`Directionality(textDirection: TextDirection.rtl)`, same widget, same strings): the
     comparison **inverts**, with no `Positioned`/`EdgeInsets.only(left:)` anywhere in the file
  4. the icon button's hit rect is ≥ 44×44 at `TextScaler.linear(1.0)` and at `2.0`
  5. the datestamp and the title are two nodes, the title reading as a heading

  The Jalali date *string* is asserted in task 3's projection test (case 10), not here — this widget
  is handed the string. Golden written alongside; gate, not driver.
- **Details** — Reference: `.appbar` with `.datestamp` (`fs-body` / w700 / `inkMuted`) above `h2`
  (`fs-title` / w800, `titleLarge` in the mapped text theme). Trailing 44×44 `iconbtn` (surface fill,
  `border` hairline, `elevation.level1`, `shapes.radiusPill`) opening the note sheet. In RTL the trailing button moves to
  the start edge automatically — use `Row` with `MainAxisAlignment.spaceBetween`, never
  `Positioned(left:)`.
- **Acceptance** — RTL pump shows the icon button on the left; the date string is Jalali-formatted in
  `fa` per the locale's `DateFormat`.

### 5. Complete the dose hero

- **What** — Give `DoseHeroCard` the parts the gallery stub lacks: the badge slot, the tablet
  breakdown pill, and the unachievable-dose path.
- **Where** — `widgets/dose_hero_card.dart`, `widgets/new_dose_badge.dart`,
  `widgets/tablet_breakdown_pill.dart`.
- **Tests first (TDD)** — `test/features/today/widgets/dose_hero_card_test.dart`, `flutter_test`
  widget tier, pumped inside `buildDaybreakTheme` with `loadAppFonts()`. Write and watch fail:
  1. `isNewDoseDay: true` → `find.byType(NewDoseBadge)` finds one, and its subtree contains **both**
     the sunrise glyph and the localized words — never the colour alone
  2. `isNewDoseDay: false` → `findsNothing`; the slot is empty, not a second badge
  3. `tablets: '1 × 5mg · 4 × 1mg'` → the pill renders that text; `tablets: null` with
     `unachievableMessage` set → the pill is absent and the warning strip carries the message
     verbatim (SPEC §3.3: flagged, never rounded)
  4. tapping `TakenButton` when `taken: false` invokes `onTaken` **once** — a double tap within the
     press animation still invokes it once
  5. `taken: true` → the button renders the taken state with `l10n.takenAt(...)` and its tap invokes
     `onUndo`, not `onTaken`; `find.byType(SnackBar)` is `findsNothing` after either
  6. the numeral's resolved `fontSize` (read off the `RichText`'s `TextStyle`) is **identical** at
     `TextScaler.linear(1.0)` and `2.0`, and `tester.takeException()` is null at 2.0 — no overflow,
     no `FittedBox`, no clamp
  7. a contrast unit test (pure `flutter_test`, no pump): `onPrimary` against the **first and last**
     stop of `c.sunrise` is ≥ 4.5:1 in light and in dark — four assertions, each naming its stop
- **Details** — Card geometry, fill and elevation are **EPIC-07's**, not this epic's: use
  `DoseHeroCard` exactly as shipped (`c.sunrise`, `shapes.radiusXl`, `elevation.glow`,
  `clipBehavior: Clip.antiAlias`). This epic adds slots and data, and states no token values of its
  own for the card.
  > **Contract:** CONTRACTS §9 — EPIC-07 is authoritative for component token values, and the slot
  > names are `DaybreakShapes.radius*` / `DaybreakElevation.level0…level3` + `glow`.
  > `DaybreakRadii`, `DaybreakSpacing`, `shadow0…shadow3` and `shadowGlow` do not exist.
  Arc: `SunriseArcPainter` positioned `end: -70, top: -90`,
  opacity 0.5, mirrored in RTL (`Transform.scale(scaleX: -1)` gated on `Directionality`),
  `ExcludeSemantics`, dropped above 1.6× scale.
  Numeral: `displayLarge` + `w800` + `FontFeature.tabularFigures()`, `letterSpacing` already
  converted to logical px by `daybreak-bilingual-type` (−0.045em at 72 = −3.24; Persian steps to 58
  with tracking 0). **It never shrinks** — no `FittedBox`, no `maxLines`, no `ellipsis`.
  Unit `mg` at `titleLarge`/w700, baseline-aligned via `Row(crossAxisAlignment:
  CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic)`.
  Badge (`NewDoseBadge`): pill on `rgba(surface, .92)`, `on-primary` ink, min height 34, sunrise
  glyph + the localized words "New dose day" — **shape + glyph + label, never the colour alone**.
  It is rendered only when `isNewDoseDay`; on an old-dose day the slot is empty (not a second badge).
  Tablets pill: translucent surface fill, `shapes.radiusPill`, pill glyph + counts. When the composition is
  unachievable, the pill is replaced by a `tintWarning` strip carrying
  `l10n.doseNotAchievable(dose)` — SPEC §3.3/§7: flagged, never silently rounded.
  Taken action: EPIC-07's **`TakenButton`** — filled `c.sunrise` with `c.onPrimary` ink, 88 logical
  px tall, full bleed inside the card margins (EPIC-07 task 6's ladder table is the single source
  for the fill; there is no `onHero` variant of `PrimaryPillButton` and this epic does not restate
  the fill). Label from `l10n.markTaken`; when `taken` it renders the taken state (check glyph +
  `l10n.takenAt(time)`) and its tap becomes **undo** through the inline undo row named in EPIC-07
  task 8 — never a `SnackBar`.
- **Acceptance** — A test at `TextScaler.linear(2.0)` finds no overflow and asserts the numeral's
  resolved `fontSize` is unchanged from 1.0. A contrast test asserts `onPrimary` ≥ 4.5:1 against both
  the first and last stop of `c.sunrise`, light and dark.

### 6. The quiet context line

- **What** — `Step 3 of 15 · 10mg → 9mg · Day 14 of 52`.
- **Where** — `widgets/dose_context_line.dart`.
- **Tests first (TDD)** — `test/features/today/widgets/dose_context_line_test.dart`, `flutter_test`
  widget tier. Write and watch fail:
  1. given `stepIndex '3'`, `stepCount '15'`, `fromDose '10mg'`, `toDose '9mg'`, `dayInStep '14'`,
     `stepLength '52'` the line renders three segments separated by `·`
  2. `isSteadyState: true` → the third segment is `l10n.holdingAtDose('9mg')`; the strings `'52'`
     and `'0'` appear nowhere in the rendered text
  3. the semantics tree contains **exactly one** node for the line, whose label is
     `l10n.contextLineSemantics(...)` — assert the count, so six fragments is a failing state
  4. the arrow is `Icons.adaptive.arrow_forward`; `find.byIcon(Icons.arrow_forward)` is
     `findsNothing` (the ban gate greps for it too, but this pins the rendered tree)
  5. at `TextScaler.linear(2.0)` the `Wrap` reflows and `takeException()` is null — a `Row` here
     overflows, which is why it is a `Wrap`

  The RTL golden showing the arrow pointing left is written alongside; gate, not driver.
- **Details** — A `Wrap` (not a `Row`) of pre-formatted spans with `·` separators in `inkFaint`,
  body size, w600, `inkMuted`. The arrow is **`Icons.adaptive.arrow_forward`**, which already
  mirrors under RTL — no manual `Transform`. `Icons.arrow_forward` is forbidden by EPIC-01 task 6's
  ban gate, and the adaptive icon is exactly what that gate exists to force; the *logical* reading
  is "from 10mg to 9mg", so the glyph points toward the reading direction's end in both directions.
  On a steady-state day (`isSteadyState`) the third segment is `l10n.holdingAtDose(dose)` rather
  than "Day n of 52" — there is no `dayInStep` to print.
  The whole line is a single `Semantics(label: l10n.contextLineSemantics(...))` with the children
  excluded, so the reader says "Step 3 of 15, reducing from 10 milligrams to 9 milligrams, day 14 of
  52" instead of six fragments.
- **Acceptance** — RTL golden shows the arrow pointing left; the semantics tree contains one node for
  the line.

### 7. Backfill banner — the whole missed run, not just yesterday

- **What** — The un-ticked-days prompt, and the tap that commits or routes.
- **Where** — `widgets/` (reuse EPIC-07's `BackfillBanner`), wired in `today_screen.dart`.
- **Tests first (TDD)** — the *count* rule is projection logic and is tested headlessly before any
  banner is pumped; only the tap behaviour needs a widget.

  **(a) `test/features/today/today_projection_test.dart`** (extending task 3's file), no container:
  1. today untaken, yesterday untaken, the day before taken → `backfill.count == 1`,
     `backfill.oldest == yesterday`, label is the ICU `one` form
  2. four consecutive untaken past days → `count == 4`, `oldest` is the earliest of the four, label
     is the `other` form containing `'4'`
  3. `fa` → the label contains `'۴'`, not `'4'`
  4. every past day ticked → `backfill == null` (the banner must not render an empty prompt)
  5. a future untaken day never counts, and days before the plan's `startDate` never count

  **(b) `test/features/today/widgets/backfill_banner_test.dart`**, `flutter_test` widget tier with a
  `ProviderScope` over the fake repository and a recording `GoRouter`:
  6. `count == 1`, tap → exactly one `markTaken(yesterday, plannedMg: <yesterday's dose>)` and
     **zero** navigations; on the next stream emission `find.byType(BackfillBanner)` is `findsNothing`
     and the inline undo row is present
  7. `count == 4`, tap → **zero** repository calls and exactly one push of
     `/schedule?focus=2025-04-12` (the oldest missed date, ISO)
  8. `find.byType(SnackBar)` is `findsNothing` in both cases, and the banner survives a
     `tester.drag` of the body — it is not a transient
- **Details** — Shown when `TodayDose.backfill != null`. `BackfillPrompt` carries the **trailing run
  of past days that exist in the plan and have no `DoseLog` with `taken: true`** — its `count` and
  the `oldest` date, not just yesterday. Chrome is EPIC-07's `BackfillBanner` as shipped
  (`tintWarning` fill, `shapes.radiusLg`, 1px `warningFill` border, alert glyph in a 40pt ring,
  body ink at full contrast — never `c.warning` for the text, trailing chevron that mirrors in RTL,
  min height 64, `liveRegion: true`). **Never a `SnackBar`** — it must survive a scroll and a
  backgrounding.
  Copy takes the count: `l10n.nDaysNotTicked(n)`, with an ICU plural so `n == 1` reads "Yesterday
  wasn't ticked" and `n > 1` reads "You haven't marked the last 3 days." (four locales; Arabic-style
  plural categories are not needed for en/de/fa/ckb beyond one/other, but the ARB uses `plural` so
  the translator can add them).
  Tap behaviour: when `n == 1`, backfill inline — `TodayNotifier.backfill(oldest)` →
  `repo.markTaken(date, plannedMg: thatDay.dose)` → the stream re-emits and the banner disappears,
  followed by the inline undo row (EPIC-07 task 8's undo surface, not a `SnackBar`). When `n > 1`,
  the tap **routes to Schedule scrolled to the oldest missed day** (`/schedule?focus=<iso date>` —
  EPIC-09 task 7 accepts that parameter), because ticking four separate days belongs on the screen
  built for it. This deletes the old "the plural variant is left to EPIC-09" hand-off: EPIC-08 owns
  the banner and its copy, EPIC-09 owns only the row-level ticking and the deep-link target.
- **Acceptance** — Tests: (a) seed a plan with yesterday un-ticked, pump, tap the banner, assert one
  `markTaken(yesterday, plannedMg: …)` and that the banner is gone on the next emission; (b) seed
  four un-ticked days, assert the copy is the plural form with `4` in the active locale's numerals
  and that the tap pushes `/schedule` with the oldest missed date, issuing **no** write.

### 8. Quiet action row

- **What** — Add note · Hold · Flare, subordinate and equal-width.
- **Where** — `widgets/quiet_action_row.dart`.
- **Tests first (TDD)** — `test/features/today/widgets/quiet_action_row_test.dart`, `flutter_test`
  widget tier. Write and watch fail:
  1. three tiles render; their measured widths are equal within 0.5 logical px at 390 wide
  2. each tile's callback (`onAddNote`, `onHold`, `onFlare`) fires exactly once on tap, and tapping
     one does not fire the others
  3. `hold == null` → the Hold tile is **present**, `onHold` is not invoked on tap, and its semantics
     node carries `l10n.holdNeedsActiveStep` — a test asserting the tile is *absent* is the wrong
     test and must not be written (disabled-with-reason, never hidden)
  4. every tile's hit rect is ≥ 44×44 at 1.0 and at 2.0 scale
  5. at `TextScaler.linear(1.5)` the layout is still a `Row`; at `1.6` `find.byType(Column)` matches
     the tile container and `takeException()` is null — the threshold is asserted on both sides
- **Details** — Three `Expanded` tertiary tiles, min height 52 (still ≥ 44 target), `surface` fill,
  `border` hairline, `elevation.level1`, `shapes.radiusMd`, icon in `inkFaint` above a `label`-size
  w700 caption in `inkMuted`. They must not compete with Taken: no gradient, no glow, no primary
  ink.
  *Add note* opens a modal bottom sheet with a `TextField` (one free-text note per day, SPEC §8) →
  `saveNote(text)` → `repo.setNote(date, text)` (which also needs `plannedMg` when no log row
  exists yet — CONTRACTS §3 — so the notifier passes the `DayPlan`'s dose).
  *Hold* and *Flare* open the sheets built in **task 9**; this task only places the two tiles and
  wires their `onTap` to the sheet routes. `Hold` is disabled with a localized reason
  (`l10n.holdNeedsActiveStep`) when `TodayDose.hold == null` — disabled-with-reason, never hidden.
  At >1.5× text scale the row reflows to a `Column` of full-width tiles.
- **Acceptance** — All three targets ≥ 44×44 at 1.0 and at 2.0 scale; the row is a `Column` at 2.0;
  the disabled *Hold* tile exposes its reason to the semantics tree rather than being absent.

### 9. Flare and Hold — SPEC §5.2's headline features

- **What** — The two adjustment actions, with real value pickers, real confirmation copy and real
  repository calls. This is the thing every competitor gets wrong (SPEC §5.2); it does not ship as a
  two-button `AlertDialog` with hardcoded arguments.
- **Where** — `widgets/flare_sheet.dart`, `widgets/hold_sheet.dart`, plus the two prompt types on
  `today_view_state.dart` and the two mutations on the notifier.
- **Tests first (TDD)** — the prompts are built by the projection and the writes go through the
  notifier, so two thirds of this task is testable with no widget at all. Do that part first.

  **(a) `test/features/today/flare_prompt_test.dart`** — projection tier (`flutter_test`, no pump):
  1. a plan with three completed steps → `FlarePrompt.candidates` has three entries, **newest
     first**, each labelled `'9mg — from 3 March to 24 April'` with the locale's numerals
  2. `defaultRevertTo` is the previous step's `fromDose`, not the current dose
  3. `suggestedStep` equals `suggestStep(revertTo, target, strengths, halves).suggested` and
     `stepDiffersFromCommunity` equals that call's `communityPracticeDiffers` — assert the pair at
     `revertTo = 9mg` gives `0.5mg` + `true` (CONTRACTS §6; `1mg` + `false` here is the old, wrong
     SPEC §4.4 example and must fail)
  4. no completed steps → `candidates` is empty and the sheet's caller shows the no-history copy
  5. `HoldPrompt` is null when no step is active; when active, `defaultExtraDays == 7`,
     `min == 1`, `max == 28`, and `blockLabel == l10n.blockTitle(3, 11)`

  **(b) `test/features/today/today_notifier_test.dart`** — `ProviderContainer` + fake repository:
  6. `recordFlare(Milligrams(900), Milligrams(50))` → exactly one
     `repo.recordFlare(on: 2025-04-16, revertTo: 900)`; the step size is **not** passed to
     `recordFlare` (CONTRACTS §3 has two named arguments) and reaches the repository through the
     plan/step path instead — assert the argument list, so a third argument fails to compile
  7. `recordHold(5)` → exactly one `repo.recordHold(stepId: <active>, from: 2025-04-16, extraDays: 5)`
  8. `recordHold(0)` and `recordHold(29)` are rejected before any repository call

  **(c) `test/features/today/widgets/flare_hold_sheet_test.dart`** — widget tier:
  9. select the **second** candidate, confirm → exactly one `recordFlare` with *that* dose, not
     `defaultRevertTo`. This is the test that catches the hardcoded-argument dialog SPEC §5.2 warns
     about, so write it before the sheet exists
  10. stepper to 5, confirm → exactly one `recordHold(extraDays: 5)`
  11. cancel, and dismiss-by-barrier-tap → **zero** repository calls for both sheets
  12. both sheets render `l10n.flareHistoryKept` / `l10n.holdConsequence` verbatim, and every target
      is ≥ 44 at 2.0 scale with `takeException()` null
  13. a projection-tier assertion that `cumulativeTakenMg` over the logs is byte-identical before and
      after a flare is recorded — the flare appends a fact and rewrites no history

  Sheet goldens in light/en and dark/fa are written alongside; gate, not driver.
- **Details** —
  ```dart
  final class FlarePrompt {                  // on TodayDose and TodayStepFinished
    final List<FlareCandidate> candidates;   // prior step doses, newest first
    final Milligrams defaultRevertTo;        // the previous step's fromDose
    final Milligrams suggestedStep;          // suggestStep(revertTo, …).suggested
    final bool stepDiffersFromCommunity;     // StepSuggestion.communityPracticeDiffers
  }
  final class FlareCandidate {
    final Milligrams dose;                   // pre-formatted label alongside
    final String label;                      // "9mg — from 3 March to 24 April"
  }
  final class HoldPrompt {
    final int stepId;                        // the active step; null prompt == no active step
    final String blockLabel;                 // "Block 3 of 11", pre-formatted
    final int defaultExtraDays;              // 7
    final int minExtraDays;                  // 1
    final int maxExtraDays;                  // 28 — a longer stall is a plan change, not a hold
  }
  ```
  **Flare sheet.** "Go back to the last dose that worked" is a *judgement*, not a value the app
  holds, so the sheet lists the doses the person has actually been on — one row per prior step with
  its date range, newest first — with the previous step's `fromDose` preselected. Below it, the next
  step size from `suggestStep`, editable with the same stepper the Plan screen uses, and the honest
  sentence when `stepDiffersFromCommunity` (CONTRACTS §6). The body states plainly what happens:
  *"Your history and your total so far are kept. Days from today are rebuilt from this dose."*
  (SPEC §5.2). Confirm → `TodayNotifier.recordFlare(Milligrams revertTo, Milligrams step)` →
  `repo.recordFlare(on: today, revertTo: revertTo)`.
  **Hold sheet.** A bounded stepper over `extraDays` (default 7, 1–28) with the plain-language
  consequence — *"You stay at 9mg for 7 more days. The step is not abandoned and nothing is lost."*
  Confirm → `TodayNotifier.recordHold(int extraDays)` →
  `repo.recordHold(stepId: prompt.stepId, from: today, extraDays: extraDays)`.
  **Both** are presented in EPIC-07 task 8's shared `ConfirmSheet` (title, body naming exactly what
  will happen, confirm + cancel, `isDismissible: true`, modal-route semantics) with the picker as
  its content — this epic does not invent a private confirm dialog. Both sheets are RTL-correct,
  use the locale's numeral system, keep every target ≥ 44pt, and reflow to a scrollable column at
  200% scale.
  > **Contract:** CONTRACTS §3 — the signatures are `recordFlare({required LocalDate on, required
  > Milligrams revertTo})` and `recordHold({required int stepId, required LocalDate from, required
  > int extraDays})`. Note the deviation from the review's suggested fix, which named a third
  > `step:` argument on `recordFlare`: the contract's signature has two, so the chosen next-step
  > size is written through the plan/step path, not through `recordFlare`.
  ARB keys budgeted here: `flareTitle`, `flareBody`, `flarePickDose`, `flareHistoryKept`,
  `flareConfirm`, `holdTitle`, `holdBody`, `holdExtraDays`, `holdConsequence`, `holdConfirm`,
  `holdNeedsActiveStep`, `stepFinishedExplainer`, `startNextStep`, `holdingAtDose` — plus the
  plural `nDaysNotTicked` from task 7, in all four locales.
- **Acceptance** — Widget tests assert: selecting the second candidate dose and confirming issues
  **exactly one** `recordFlare` with *that* dose (not the default) and today's date; changing the
  stepper to 5 and confirming issues exactly one `recordHold` with `extraDays: 5` and the active
  `stepId`; cancelling issues none. A `_project`-level test asserts the cumulative total is
  unchanged across a flare (it consumes EPIC-04's `cumulativeTakenMg`, which only appends facts).
  Goldens for both sheets in light/en and dark/fa.

### 10. Midnight rollover, timezone and lifecycle

- **What** — Today must roll over while the app is open, and a flight must not reshuffle anything.
- **Where** — `lib/features/today/application/today_view_provider.dart` only.
- **Tests first (TDD)** — `test/features/today/today_rollover_test.dart`, `ProviderContainer` tier
  with `clockProvider.overrideWithValue(Clock.fixed(...))` and `fakeAsync` driving EPIC-06's
  `DayTicker`; no widget pumped. Write and watch fail:
  1. container at `2025-04-16 23:59:50`, listen to `todayViewProvider`; `async.elapse(20 s)` →
     the ticker invalidates `todayDateProvider` and a **new** state arrives whose `dateLine` is
     17 April and whose `taken` is false again
  2. the same, but the clock jumps from `23:00` on the 16th to `07:00` on the 18th with no elapse
     (device asleep, timer never fired) and `AppLifecycleState.resumed` is delivered → the state
     re-projects to the 18th, skipping the 17th entirely
  3. a `tz` offset change (`Europe/Berlin` → `Asia/Tehran`) at a fixed instant leaves `dayInStep`
     unchanged — the comparison is on `LocalDate`, never elapsed seconds (SPEC §7)
  4. `grep -rn "Timer\|WidgetsBindingObserver" lib/features/today/` returns nothing, asserted in the
     test file's own `expect` over the source, so a second ticker cannot be added quietly
- **Details** — **This epic builds no timer and no lifecycle hook.** EPIC-06 task 6 owns the single
  `DayTicker`: it holds the `Timer`, invalidates `todayDateProvider` (a `Provider<LocalDate>`) at
  the next local midnight, reschedules, and re-invalidates on `AppLifecycleState.resumed` (a device
  asleep past midnight never fires the timer). `TodayNotifier.build()` simply
  `ref.watch(todayDateProvider)`, so an invalidation rebuilds the notifier and re-projects the
  screen. There is no `lib/core/time/today_date_provider.dart` in this epic — a second timer would
  double-fire the resume handler and make one of the two rollover tests vacuous.
  All comparisons are on `LocalDate` (y/m/d), never on elapsed seconds — SPEC §7. Never call
  `DateTime.now()`; the lint from EPIC-01 forbids it.
- **Acceptance** — A test with a fake clock advancing across midnight (driving EPIC-06's ticker)
  asserts the hero re-projects to the next day without a manual refresh; a test moving the timezone
  (`tz` offset change) asserts the day index is unchanged. Neither test constructs a `Timer` in this
  feature.

### 11. Screen assembly, states and adaptive layout

- **What** — `TodayScreen` composing everything, plus the non-happy states.
- **Where** — `lib/features/today/presentation/today_screen.dart`.
- **Tests first (TDD)** — `test/features/today/today_screen_test.dart`, `flutter_test` widget tier
  over a `ProviderScope` that overrides `todayViewProvider` with a fixed `AsyncValue` — the projection
  is already covered in task 3, so this file asserts only *which* tree each state produces. Write and
  watch fail:
  1. `AsyncLoading` → the skeleton renders and its height equals the hero's height within 1 px (no
     jump when data arrives); `find.byType(CircularProgressIndicator)` is `findsNothing`, and no
     `pumpAndSettle` is used anywhere in this file
  2. `AsyncError` → the error panel with a retry control whose tap invalidates the provider once
  3. `TodayNoPlan` → `TaperEmptyState`, and its action pushes `/plan`
  4. `TodayStepFinished` → the hero **and** the Taken button are still present (day 53 is a real
     dose), plus a *Start next step* action that calls `startNextStep()` exactly once, plus
     `l10n.stepFinishedExplainer`
  5. `TodayTaperComplete` → the finish card; no Taken button, no negative dose rendered
  6. `TodayDose` at 390×844, `TextScaler.linear(1.0)` → the scroll view's
     `position.maxScrollExtent == 0.0`; at `2.0` it is `> 0` and `takeException()` is null
  7. at 601 logical px width the hero and the context column are siblings in a `Row`; at 599 they are
     not — assert both sides of the breakpoint
- **Details** — `ConsumerWidget` watching `todayViewProvider`; `AsyncValue.when` maps loading → a
  skeleton that reserves the hero's height (no spinner jump), error → the `ui-states-and-feedback`
  error panel with a retry, data → an exhaustive `switch` over the four sealed variants.
  `TodayNoPlan` → `TaperEmptyState` ("Your plan starts here") with one primary action routing to
  `/plan`. `TodayStepFinished` → the normal hero (the steady-state dose is still a real dose to
  take, so Taken still works) with a *Start next step* primary action under it calling
  `repo.startNextStep()`, and `l10n.stepFinishedExplainer` saying the previous step's days are done
  and the dose stays where it is until they start the next one.
  `TodayTaperComplete` → the finish card (SPEC §7: the taper ends cleanly, no negative-dose step is
  generated) — reached when the plan's target is met, on which dates the generator still emits a
  steady-state day at the target dose. Body is a `SingleChildScrollView` with
  `physics: ClampingScrollPhysics()` — at 1.0 scale on a 390×844 frame **nothing scrolls**, which is
  the requirement; the scroll view exists only so 200% and landscape do not overflow.
  Landscape/tablet (`adaptive-layout`): above 600 logical px width, hero and the
  context/banner/actions column sit side by side in a `Row`; the hero keeps its numeral size.
- **Acceptance** — At 390×844, 1.0 scale, the screen reports no scroll extent. At 2.0 scale it
  scrolls and nothing clips.

### 12. Degradation ladder at large text scale

- **What** — Implement and comment the declared order.
- **Where** — `widgets/dose_hero_card.dart`, `today_screen.dart`.
- **Tests first (TDD)** — `test/features/today/degradation_ladder_test.dart`, `flutter_test` widget
  tier, one `group` per rung and **both sides of every threshold** — a ladder tested only at 1.0 and
  2.0 passes with the thresholds off by 0.3. Write and watch fail:
  1. arc: `find.byType(CustomPaint)` matching `SunriseArcPainter` is present at 1.6× and absent at
     1.61×
  2. amount/unit: siblings in a `Row` at 1.3×, in a `Column` at 1.31×
  3. quiet action row: `Row` at 1.5×, `Column` at 1.51×
  4. context line: three segments on one line at 1.8×, three lines at 1.81×
  5. the numeral's resolved `fontSize` is the same value at 1.0, 1.3, 1.6, 1.8 and 2.0 — five reads,
     one expectation
  6. `grep` in the test asserts no `MediaQuery(data: …copyWith(textScaler:` clamp in
     `lib/features/today/`; `takeException()` is null at every step above
- **Details** — In order: (1) above 1.6× drop the decorative arc; (2) above 1.3× the
  amount/unit `Row` becomes a `Column`; (3) above 1.5× the quiet action `Row` becomes a `Column`;
  (4) above 1.8× the context line's three segments stack one per line. **The numeral is never
  touched at any scale**, and `MediaQuery.textScalerOf(context)` is never clamped. Each threshold is
  a named `static const` with a one-line comment saying why.
- **Acceptance** — Golden at 2.0 scale in light/en and dark/fa; a test asserts the arc's
  `CustomPaint` is absent at 2.0 and present at 1.0.

### 13. Semantics: the screen as a sentence

- **What** — Make VoiceOver read Today the way a person would say it (SPEC §5.4).
- **Where** — `today_screen.dart`, `dose_hero_card.dart`.
- **Tests first (TDD)** — `test/features/today/today_semantics_test.dart`, `flutter_test` with
  `SemanticsTester` / `tester.getSemantics`. Write the expected sentences down **before** the tree
  exists — they are copy decisions, and writing them after the fact means accepting whatever the
  widget happened to emit. Write and watch fail:
  1. `en`, new-dose day, untaken → the hero is one node labelled exactly *"Today, 9 milligrams: one
     5 milligram tablet, four 1 milligram tablets. New dose day. Not yet taken."*
  2. `fa` → the same sentence from the ARB with Persian numerals, asserted as a literal
  3. taken → the trailing clause becomes *"Taken at 08:12"*; the label is otherwise unchanged
  4. the Taken control is a **separate** child node with `isButton` and a non-null `onTapHint`, not
     folded into the hero's label
  5. after `markTakenToday()` succeeds a node with `isLiveRegion` carries *"Marked as taken"*
  6. traversal order is date → hero → context → banner → actions, asserted over
     `tester.semantics.simulatedAccessibilityTraversal()` and **not** over paint order
  7. `meetsGuideline` for `textContrastGuideline`, `androidTapTargetGuideline`,
     `iOSTapTargetGuideline` and `labeledTapTargetGuideline`, each at 1.0 and 2.0 scale
- **Details** — The hero is one `Semantics(container: true, label: ...)` with visual children under
  `ExcludeSemantics`, producing: *"Today, 9 milligrams: one 5 milligram tablet, four 1 milligram
  tablets. New dose day. Not yet taken."* The Taken control is a separate child node with
  `button: true` and an explicit `onTapHint`. Success announces via a `liveRegion`
  ("Marked as taken"). Ordering is set with `SemanticsSortKey`s so the reader goes date → hero →
  context → banner → actions regardless of paint order.
- **Acceptance** — A `SemanticsTester` test asserts the exact label strings in `en` and `fa`;
  `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline`, `iOSTapTargetGuideline`,
  and `labeledTapTargetGuideline` all pass.

### 14. Tests

- **What** — The test set that holds this screen still.
- **Where** — `test/features/today/`, `test/golden/today/`, `parity/`.
- **Tests first (TDD, for what is left)** — tasks 2–13 already wrote the behavioural suite test-first;
  this task must not re-list it. What is genuinely new here divides in two:
  - **TDD** — `test/features/today/today_persistence_test.dart`: build a `ProviderContainer` over a
    **file-backed** `AppDatabase` in a temp directory (not `NativeDatabase.memory()` — the claim is
    about durability), `markTakenToday()`, await the write, dispose the container, build a *second*
    container over the same file, and assert the new `TodayViewState` equals the first byte for
    byte. Then a negative case: the same flow without awaiting the `Result` must **not** be what the
    test relies on. `addTearDown` closes both databases and deletes the temp dir. Write it first —
    it fails today because nothing persists.
  - **Gate, not driver** — the eight goldens (light/dark × en/fa × 1.0/2.0), the two sheet goldens,
    the grayscale badge lane and the a11y guideline sweep. A screenshot comparison cannot be written
    failing before the screen exists; these are captured alongside the widgets and reviewed, with
    `loadAppFonts`, the pinned clock and `test/fixtures/seeded_taper.dart`.
- **Details** — Unit tests for `_project` (all nine cases from task 3); widget tests for each of the
  four variants and each mutation (asserting the repository call **and its arguments**, not the
  UI's internal bool) — `markTaken` with the right `plannedMg`, `undoTaken`, `setNote`,
  `recordFlare` with the user's chosen dose, `recordHold` with the user's chosen `extraDays`;
  goldens across light/dark × en/fa × 1.0/2.0 (8 files) plus the two sheet goldens from task 9,
  using `loadAppFonts` and a pinned clock + seeded fixture from
  `seeded-determinism-and-golden-vectors`; a11y guideline tests; a grayscale golden proving the
  new-dose badge is still readable without colour.
  **Persistence** is proven the way EPIC-05 task 9 already proves it — rebuild the provider
  container over the *same* file-backed database and assert the state is identical. There is no
  `integration_test` lane in this plan and a widget test cannot kill the host process, so "kill and
  relaunch" is not a claim this epic's tests can make; the container-rebuild test is, and it is the
  honest form of the same assurance.
- **Acceptance** — `flutter test` green; goldens committed and reproducible on CI's Linux runner
  (fonts bundled, `debugDisableShadows` handled per the golden skill).

### 15. Visual parity pass

- **What** — Prove the built screen against frame 2 and put the evidence in the PR.
- **Where** — `parity/ref/02--today--{light,dark}--{en,fa}.png`, `parity/app/…`, `parity/sheet.html`.
- **Tests first** — *Scaffold.* Parity is a **gate, not a driver**: there is no failing screenshot to
  write before the screen exists, and inventing one would only pin the reference crop. The captures
  and the paired sheet are produced after task 11 renders, and the standard is
  `daybreak-visual-parity`'s Tier-1/Tier-2 table, judged by a human against the reference PNGs.
- **Details** — Follow `daybreak-visual-parity` exactly: crop frame 2 from the committed sheets at
  CSS rect `[455, 516, 390, 844]` (PNG `+910+1032`, 780×1688), content-box adjusted by the 54px
  status bar; capture the app in a widget test at 390×844 DPR 2 with `debugDisableShadows = false`,
  `loadAppFonts`, pinned clock, seeded fixture. Plus the three no-reference passes: `de`
  longest-string, `ckb` script/numerals, and 200% scale.
- **Acceptance** — The paired sheet is attached to the PR; every Tier-1 row (tokens, order, state
  signals, copy, RTL mirroring) matches exactly, and each Tier-2 measurement is inside ±2 logical px
  with the number stated.

## Visual parity

**Reference:** `design/reference/daybreak-screens-{light,dark}-{en,fa}.png`, **frame 2 — "Today
(home)"** (row 1, column 2; CSS rect `[455, 516, 390, 844]`).

**Variants:** light/en, light/fa, dark/en, dark/fa — all four are reference-backed. Plus `de`
longest-string, `ckb`, and 200%-scale passes with no reference, judged against the declared
degradation order.

**What must match exactly:** element order (date line → "Today" + note button → hero → context line →
backfill banner → quiet action row → tab bar); the hero as EPIC-07 ships it (`shapes.radiusXl`,
`sunrise` gradient, `elevation.glow` — this epic asserts the component, not its values); the numeral
at display/800 with tabular figures and the Persian 72→58 step; the badge's pill shape + sunrise
glyph + label; the tablets pill's translucent fill and pill glyph; the `TakenButton`'s 88pt height
with its `sunrise` fill and `onPrimary` label per EPIC-07 task 6; the banner's `tintWarning` fill,
`warningFill` border, 40pt glyph ring and trailing chevron; the three quiet tiles' equal widths and
`inkFaint` glyphs; the active Today tab's `tintPrimary` icon pill and `primaryDeep` label.

**RTL:** the arc mirrors to the start edge, the context-line arrow flips, the banner chevron flips,
the note button moves to the leading (left) edge, and numerals render in the Persian numeral system.

Method, tolerances and the PR sheet: `daybreak-visual-parity`.

## Definition of done

- [ ] Every TDD task's tests were written first and observed failing before its implementation
- [ ] `lib/features/today/` complete; no widget imports drift, the repository, or `WidgetRef`
- [ ] `TodayViewState` is sealed with **four** variants including `TodayStepFinished`; `_project` is
      covered by unit tests for all nine cases, steady-state days among them
- [ ] `todayViewProvider` reads `derivedScheduleProvider`, `todayDateProvider` and
      `appLocalizationsProvider` — it opens no repository stream of its own beyond `watchSnapshot()`
      and never calls `generateSchedule`
- [ ] Every mutation goes through `TaperRepository`'s contract names (`markTaken` with `plannedMg`,
      `undoTaken`, `setNote`, `recordFlare`, `recordHold`, `startNextStep`) and returns `Result`;
      write errors keep the previous good value on screen
- [ ] Taken commits once per tap, the watched stream re-emits, and a container rebuild over the same
      database file shows the same state
- [ ] Unachievable dose is flagged in words on the hero — never rounded
- [ ] Backfill banner states the **count** of un-ticked days, backfills inline at n == 1, routes to
      Schedule's oldest missed day at n > 1, and is not a `SnackBar`
- [ ] Flare and Hold each ship a real picker in EPIC-07's `ConfirmSheet`, commit exactly one
      repository call with the user's chosen values, and say that history and the total are kept
- [ ] A finished step renders `TodayStepFinished` with *Start next step* — day 53 is never blank
- [ ] Midnight rollover and resume-after-midnight both re-project without a manual refresh, using
      EPIC-06's `DayTicker` — this epic ships no timer
- [ ] 200% text scale: no overflow, no clamp, numeral unchanged, all targets ≥ 44 (Taken ≥ 88)
- [ ] VoiceOver reads Today as one sentence; all four a11y guideline tests pass
- [ ] Nothing scrolls at 390×844 / 1.0 scale; landscape and ≥600px use the side-by-side layout
- [ ] Goldens for light/dark × en/fa × 1.0/2.0 plus the Flare and Hold sheets committed and green on CI
- [ ] Frame-2 parity sheet produced for all four reference cells, plus `de`, `ckb` and 200% passes
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, parity evidence, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
