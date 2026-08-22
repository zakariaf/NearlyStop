# EPIC-11 — Plan, Settings & Welcome screens

**Branch:** `epic/11-plan-settings-welcome`
**Depends on:** EPIC-06 (app shell, routing, bootstrap), EPIC-07 (Daybreak component library)

## Where we are now

The shell from EPIC-06 exists: a `StatefulShellRoute.indexedStack` with five branches (`/today`,
`/schedule`, `/progress`, `/plan`, `/settings`), a five-destination tab bar, `clockProvider`,
`resolvedLocaleProvider`/`appLocalizationsProvider`, the `/welcome` route and its first-run redirect,
one `SettingsController`, and `ProviderScope` wired from `bootstrap()`. EPIC-05 shipped `AppDatabase`
with the `TaperPlan`, `Step`, `DoseLog`, `FlareEvent`, `HoldEvent` and `Settings` tables behind **one**
`TaperRepository` (`lib/data/taper_repository.dart`) plus a separate `settingsRepository`, each returning
`Result<T, F extends Failure>`. EPIC-04 shipped the pure engine: `generateSchedule()`, `suggestStep()`,
`composeTablets()`, `stepStatusFor()`, the `TaperMethod` enum and the `Milligrams` / `LocalDate` value
objects, with zero Flutter imports. EPIC-07 shipped the component classes this epic assembles —
`StrengthChip`, `MethodSegmentedControl`, `PrimaryPillButton`, `SecondaryButton`, `DestructiveButton`,
`DisclaimerSheet`, `TaperEmptyState`, the shared confirm sheet — each `const`, each taking pre-formatted
primitives.

> **Contract:** CONTRACTS §1/§3/§8 — `Milligrams` and `LocalDate` are the only dose and date types;
> `PlanRepository`, `StepRepository` and `SettingsRepository` **do not exist**; `TaperMethod` is declared
> in `lib/core/`. This epic uses `taperRepository` and `settingsRepository` and nothing else.

`/plan` and `/settings` are still placeholder `Scaffold`s with a title. Nothing writes to the settings
row yet: `reminderEnabled`, `reminderTime`, `textScale`, `highContrast`, `localeTag` and
`disclaimerAcceptedAt` are columns nobody has ever set. Nothing anywhere creates the **first** `Step`, so
no saved plan has ever produced a schedule. Frames 1, 5 and 6 of
`design/reference/daybreak-screens-*.png` have no implementation behind them.

## Why this epic exists

Plan is where the taper is *created*. Until it exists the app has no data: EPIC-08's Today screen and
EPIC-09's Schedule render from a `TaperPlan` that currently can only be inserted by a test. This is the
screen a user touches at setup and then roughly every 52 days, which makes it the one place where a
wrong keystroke costs two years of history — so it is the screen that most needs real validation, a
confirm step on anything destructive, and copy that never pretends the app knows better than the
prescriber. The next-step preview carries the single most important sentence in the product: 10% of 9mg
is 0.9mg, the community steps 1mg anyway, and the doctor's instruction wins. SPEC §3.2 makes that a
*default the user can override, never a lock*, and the UI has to say so out loud.

Settings is where the app's promises are kept and stated. The reminder toggle is the only thing standing
between the user and EPIC-12's notification engine. Text size and high contrast are not decoration for a
60–80 audience — SPEC §5.4 makes them v1 requirements on top of the OS settings, for people whose OS text
size is already maxed and still not enough. The Export/Import buttons are the visible half of SPEC §4.5's
backup, which is v1 precisely because a lost two-year plan is unrecoverable. And the "everything stays on
this phone" footnote is the app's whole positioning, rendered where a sceptical user goes looking for it.

Welcome is the legal and ethical gate. SPEC §4.0 and §5.3 require it on first run, and require it to stay
re-readable. It is not a screen in the tab bar and it is not skippable.

## What we will have when it is done

A user can install the app cold, read and accept the disclaimer, enter a plan — drug name, current dose,
target dose, the tablet strengths they actually hold, whether they can split, method, start date — and
see the next step previewed with its honest caveat before anything is generated. They can come back
mid-taper, change strengths because the prescription changed, edit the step because the rheumatologist
said something different by phone, and start the next step when one completes. Saving a plan for the
first time creates `Step 0` in the same transaction, so the schedule exists the moment the form is
submitted. In Settings they can turn the daily reminder on and pick its time, scale text beyond the OS
maximum, switch on high contrast, **choose the app's language independently of the phone's**, read the
disclaimer again, and see the app's name, version and licences. Every one of those screens matches its
reference frame in light and dark, LTR and RTL, and survives 200% text scale.

## Skills to load

| Skill | What it governs for this epic |
|---|---|
| `daybreak-visual-parity` | The proof that frames 1, 5 and 6 match the reference PNGs — the crop, the capture, the three-tier standard. |
| `forms-and-input` | `Form` + `GlobalKey<FormState>` + `TextFormField`, localized sync validators, `AutovalidateMode.onUserInteraction`, controller/focus disposal, derived submit-enabled. |
| `daybreak-components` | `StrengthChip`, `MethodSegmentedControl`, the button ladder, `DisclaimerSheet`, the row-item and card recipes these three screens are built from. |
| `daybreak-tokens` | Every colour, radius, shadow, spacing and duration on these screens is a slot read; the danger-zone surface uses `dangerTint`/`dangerFill`. |
| `ui-states-and-feedback` | The one-state resolution point, the surface ladder for the "plan saved" confirmation, and the confirm-sheet contract every destructive action routes through. |
| `state-management-riverpod` | `PlanEditorNotifier` as a `Notifier`; reading EPIC-06's `SettingsController` rather than adding a second one; `select()` so a keystroke does not rebuild the screen. |
| `navigation-and-routing` | Pushing `/settings/disclaimer` and the licenses page — the `/welcome` route and the first-run `redirect` themselves belong to EPIC-06. |
| `accessibility-as-code` | 44×44 targets, switch/segment/chip semantics, announced validation errors, no colour-only state, never clamping `textScaler`. |
| `widget-golden-and-a11y-testing` | Goldens for all three screens across light/dark × en/fa × 1.0/2.0 scale, plus the a11y guideline assertions. |
| `i18n-rtl-l10n` | Every string in the four ARBs, ICU plurals for tablet counts, numeral rendering for fa/ckb, mirrored chevrons and sliders. |
| `adaptive-layout` | Landscape and tablet: the two-column Plan form and the `NavigationRail` swap the shell already provides. |

## Tasks

### 1. Plan feature module and its editor state

- **What** — Scaffold the Plan feature and the `Notifier` that holds an in-progress edit of a `TaperPlan`
  separately from the persisted one.
- **Where** — `lib/features/plan/presentation/plan_screen.dart`,
  `lib/features/plan/presentation/plan_editor_notifier.dart`,
  `lib/features/plan/presentation/widgets/` (new), `lib/features/plan/presentation/plan_view_state.dart`.
- **Details** — `PlanEditorNotifier extends Notifier<TaperPlanDraft>` where `TaperPlanDraft` is an
  immutable record of the editable facts: `drugName`, `currentDose` (`Milligrams`), `targetDose`,
  `strengths` (a sorted, deduplicated `List<Milligrams>` — exactly what EPIC-05's `StrengthListConverter`
  stores), `allowHalves`, `method` (the `TaperMethod` enum from `lib/core/`, EPIC-04), `percentage?`,
  `fixedStepMg?`, `startDate` (`LocalDate`), and `stepOverride` (`Milligrams?`). The draft is seeded from
  `taperRepository.watchSnapshot()` and is **never** the persisted row — the screen reads the draft,
  `Save` writes it through `taperRepository.savePlan(TaperPlanDraft)`, which returns
  `Result<void, StorageFailure>`.
  > **Contract:** CONTRACTS §3 — there is one `TaperRepository`. `PlanRepository.upsert()`,
  > `PlanRepository.applyPlanEdit()` and `StepRepository` were names this epic invented; they are gone.
  Editing an existing plan mid-step must not delete `Step`s or `DoseLog`s: SPEC §5.2 requires past logs
  stay exactly as recorded and only *future* days recompose. That is `savePlan`'s job inside its own
  transaction (EPIC-05), not the screen's — no table surgery here.
- **Saving creates the first step.** `savePlan` inserts, in the same transaction, **when the plan has no
  steps**:
  `Step(index: 0, fromDose: currentDose, toDose: currentDose - suggestedOrOverriddenStep,
  startDate: plan.startDate, status: active, patternVersion: DsnsPattern.v1().version)`.
  > **Contract:** CONTRACTS §7. Without this, nothing anywhere creates `Step 0`: `generateSchedule` takes
  > `List<StepFacts>`, so a plan with zero steps returns an empty schedule and Today, Schedule and
  > Progress all render empty forever. `startNextStep()` (task 5) needs a *last* step and cannot be the
  > first one. **EPIC-05 owns the insert; this epic owns passing the suggested-or-overridden step size
  > into the draft** — say so in the PR, because EPIC-05's `savePlan` acceptance depends on it.
- **Acceptance** — `flutter test` proves that seeding the draft, mutating every field, and discarding
  leaves the persisted plan unchanged; saving writes exactly one `TaperPlan` row and **appends exactly
  one `Step` row when none exists, and none thereafter**.

### 2. Plan screen layout — frame 5

- **What** — Build the four stacked cards of the Plan reference frame.
- **Where** — `plan_screen.dart` plus `widgets/plan_summary_card.dart`, `widgets/strengths_card.dart`,
  `widgets/method_card.dart`, `widgets/next_step_card.dart`.
- **Details** — In reference order, top to bottom:
  1. **Summary card** — three `rowitem`s: drug name with a pill glyph and the "Medicine" sublabel;
     "Current dose" with the value right-aligned (`Directionality`-aware — use `Row` + `Spacer`, never a
     hardcoded `Alignment.centerRight`); "Target". Values use `tabularFigures` and the number formatting
     from `daybreak-bilingual-type`.
  2. **Strengths card** — an `h3` heading, a `Wrap` of `StrengthChip`s (never a horizontal scroller), and
     the "I can split tablets" row with a `Switch` and an On/Off sublabel. Chips carry a check glyph and
     a weight step when selected, not colour alone.
  3. **Method card** — `MethodSegmentedControl` with DSNS / Percentage / Fixed mg. DSNS is the default.
     All three segments are **live**, not decorative: selecting Percentage reveals the percentage field
     and selecting Fixed mg reveals the fixed-amount field (task 3), and EPIC-04 generates all three.
     > **Contract:** CONTRACTS §8 — `dsns`, `percentage` and `fixedMg` are all real generators.
     > Percentage and Fixed differ only in how the step *size* is computed; both then lay down the new
     > dose every day for a hold period. The earlier "ship two dead segments" plan is withdrawn.
     Above 1.5× text scale it reflows to a vertical radio list — the component already does this; the
     screen must not fight it with a fixed-height parent.
  4. **Next-step card** — the raised variant with a `primary`-tinted border, the `from → to` pair at
     `headlineLarge`/`w800` with a **mirrored** arrow glyph (for the pinned fixture of task 13,
     `10mg → 9mg`), the "suggested step {n}" line, and the caveat banner (task 4).
- **Acceptance** — The four cards appear in reference order with reference spacing; no `GridView`, no
  `ListTile` defaults leaking Material padding that breaks the ±2px measurement.

### 3. The edit form

- **What** — The `Form` behind the summary and strengths cards.
- **Where** — `lib/features/plan/presentation/plan_edit_form.dart`, `widgets/dose_field.dart`,
  `widgets/strength_editor_sheet.dart`.
- **Details** — One `Form` with a `GlobalKey<FormState>`, `autovalidateMode:
  AutovalidateMode.onUserInteraction`. Fields:
  - `drugName`: `TextFormField`, `textCapitalization: TextCapitalization.words`, default
    `l10n.defaultDrugName` ("Prednisolone"), required, trimmed, max 60 chars.
  - `currentDose` / `targetDose`: `keyboardType: const TextInputType.numberWithOptions(decimal: true)`,
    with the input formatter **`kDoseInputFormatter`, which lives in `lib/l10n/numeric_input.dart`
    (EPIC-03) alongside `normalizeToAscii`** — this file must not write a digit table of its own.
    > **Contract:** EPIC-03's CI grep rejects `'٫'`, `'۰'` or any hand-written digit range outside
    > `lib/l10n/`. The previous `FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.,٫]'))` literal in
    > `dose_field.dart` would have failed that gate; exporting the constant from `lib/l10n/` also
    > guarantees the formatter and the normalizer accept exactly the same character set, which is the
    > real invariant.
    Parsing goes through `parseDose(String, Locale) → Result<Milligrams, UnitFailure>` from EPIC-03
    (never `double.parse` on raw input — `٫` is a decimal separator), and the locale it parses with is
    the **app** locale (`resolvedLocaleProvider`, the same one the UI formats with), not the OS locale —
    the user can now override it in Settings (task 7). Input containing more than one separator, or a
    separator that is not that locale's decimal separator, is rejected with a localized error rather than
    coerced. Validators return localized `String?`: empty, unparseable, negative, `target >= current`,
    and `> 100mg` (a sanity ceiling, warn-not-block).
  - `percentage` (shown only when `method == percentage`): a percent field, 1–50, default 10.
    `fixedStepMg` (shown only when `method == fixedMg`): a dose field with the same formatter, `> 0` and
    `<= currentDose - targetDose`. Both also take a hold-period field in days (default 52, min 1) —
    CONTRACTS §8's "then the new dose every day for a hold period". Neither field is rendered for DSNS.
  - `startDate`: a `showDatePicker` (date *entry* may use a platform picker; date *browsing* may not),
    converted to `LocalDate` on the way into the draft. Default is today per SPEC §11.3, and the picker
    allows a past start so a user mid-taper can enter reality.
  - Strengths: an "Add strength" tertiary action opening `StrengthEditorSheet` — a small numeric form;
    removing a strength that is used by a *future* day is allowed and triggers recomposition, removing
    the last strength is refused with a localized message.
  - **Defaults for a clean install (SPEC §11.2, previously owned by nobody).** Define
    `kDefaultStrengths` in `lib/features/plan/domain/default_strengths.dart` as a small const table keyed
    by the store/OS region, seeded into the draft on first run when the snapshot has no plan:
    `en_GB` and any other en → prednisolone `1, 2.5, 5mg`; `de` → prednisolon `1, 2, 5, 10, 20, 50mg`;
    `en_US` → **prednisone** `1, 2.5, 5, 10, 20mg` (the drug name differs, not just the list);
    `fa`/`ckb` → prednisolone `1, 5mg`. The default `drugName` comes from the same table. A one-line
    localized note under the chips says the list is what the user actually holds and is editable — this
    is not a drug database (SPEC §2). Record the §11.2 decision in `epics/README.md`.
  - Every `TextEditingController` and `FocusNode` is created in a `State` and disposed. Traversal is
    `TextInputAction.next` through the chain, `done` on the last. Submit-enabled is **derived** from
    `_formKey.currentState?.validate()` at build time plus draft-dirtiness, never a stored `bool`.
- **Acceptance** — `tool/check_forms.sh` clean, and EPIC-03's digit-table grep clean (no numeral literal
  anywhere under `lib/features/`). A widget test types an invalid dose, asserts the localized error text
  is present and announced, fixes it, and asserts Save enables. One unit test per region in
  `kDefaultStrengths` asserting a clean install lands on a non-empty, editable strength list with the
  right drug name.

### 4. Next-step preview and the honest note

- **What** — Render the suggested next step from the pure engine, with the caveat, and let the user
  override the step.
- **Where** — `widgets/next_step_card.dart`, `plan_editor_notifier.dart`.
- **Details** — Call `suggestStep(current, target, strengths, allowHalves)` from EPIC-04 — a pure
  function, no `ref`, no clock. It returns
  `StepSuggestion { Milligrams suggested; Milligrams tenPercent; bool communityPracticeDiffers; }`.
  > **Contract:** CONTRACTS §6. `suggested` is the **largest achievable increment ≤ 10% of the current
  > dose**; when none exists — which is every dose below 5mg, i.e. ten of the fifteen steps — it is the
  > **smallest** achievable increment with `communityPracticeDiffers: true`. `suggested` never exceeds
  > `current - target` and never exceeds `current`. **The pair rendered on the card is
  > `current → current - suggested`, i.e. the function's own return value** — the card never renders a
  > different number from the one the engine computed.
  Render `from → to`, "suggested step {n}", and a tappable stepper so the user can override; the override
  is stored on the draft as `stepOverride` and it wins (SPEC §3.2 — a default, never a lock). The banner
  shows exactly when `communityPracticeDiffers` is true and reads, verbatim in English,
  `10% of 9mg is 0.9mg — your doctor's instruction wins`, generated from an ICU message taking
  `{currentDose}`, `{percentDose}` and `{stepDose}` as `number` placeholders so fa/ckb render Persian
  numerals. It covers both honest divergence regimes: 10mg–5mg, where 10% permits a *smaller* step than
  community practice actually uses, and below 5mg, where 10% permits **no** achievable step at all.
  Clamp per SPEC §7: if `current - suggested < target`, the preview shows `→ target` and says so; if
  `current == target`, the card becomes the "Taper complete" state and the start-next-step action
  disappears rather than generating a negative dose.
  **Worked example, corrected.** SPEC §4.4's illustration `9mg → 8mg, suggested step 1mg` is *not* what
  `suggestStep` returns: with 5mg + 1mg strengths and halves on, 10% of 9mg is 0.9mg and the largest
  achievable increment ≤ 0.9mg is **0.5mg**. The card therefore renders **`9mg → 8.5mg`, "suggested step
  0.5mg"**, banner shown. SPEC's `9 → 8` line is an illustration of the **override**, not of the
  function's return value; the stepper is how the user gets there.
- **Acceptance** — Unit tests, each asserting the pair, the suggested figure and the banner:
  - 9mg, target 0, strengths 5/1 + halves → suggested **0.5mg**, pair `9 → 8.5`, banner **shown**.
  - 5mg, strengths 5/1 + halves → suggested **0.5mg**, banner **absent** (0.5mg *is* exactly 10% of 5mg,
    so the figures do not diverge).
  - 10mg, strengths 5/1, halves off → suggested **1mg**, pair `10 → 9`, banner **absent** (10% of 10mg is
    exactly 1mg).
  - 2mg, strengths 5/1 + halves → no increment ≤ 0.2mg exists, so the **smallest** achievable (0.5mg) is
    returned with `communityPracticeDiffers: true`, banner **shown**.
  - 0.5mg with a 0mg target → clamped to the target, no negative step.

### 5. Start next step, and the destructive actions

- **What** — The "Start next step" primary action and a danger zone.
- **Where** — `widgets/next_step_card.dart`, `widgets/plan_danger_zone.dart`,
  `lib/features/plan/presentation/confirm_start_step_sheet.dart`.
- **Details** — "Start next step" is enabled only when the active `Step` is `completed`, and "completed"
  has exactly **one** definition: EPIC-04's pure `stepStatusFor(step, holds, today)`, which returns
  `completed` when `today >= startDate + 52 + Σ holdExtraDays`. The screen calls that one function and
  invents no second criterion (the earlier "52 days elapsed *or* all its days logged" was two rules in
  one parenthesis). Otherwise the button is present but disabled with a localized reason, never hidden —
  a disappearing control is unexplainable. It calls `taperRepository.startNextStep()` (CONTRACTS §3 —
  there is no `StepRepository`), which appends a `Step` row with the frozen `patternVersion` (SPEC §6)
  and never mutates the previous one; note that it requires a *last* step, which is why task 1's
  `Step 0` insert exists. The danger zone holds `DestructiveButton` "Delete plan": per SPEC §7 it routes
  through EPIC-07's shared confirm sheet (`lib/features/shared/confirm_sheet.dart` — this epic's
  delete-plan, EPIC-08's Hold/Flare and EPIC-13's `ExportGuard` are its three consumers, which is
  EPIC-07's own threshold for a shared component; if it has not landed, build it *there*, never privately
  here). The sheet **offers an export first** — in this epic the export action is a callback wired to a
  `TODO` provider that EPIC-13 replaces; the sheet, the wording, and the "Export first" button all ship
  now.
- **Acceptance** — Deleting requires two deliberate taps and the confirm sheet names what will be lost.
  A test asserts the export-first action is present and that dismissing the sheet (`null` from
  `showModalBottomSheet`) deletes nothing.

### 6. Settings view state — on top of EPIC-06's controller

- **What** — The screen-level projection of the settings row. **Not** a second settings notifier.
- **Where** — `lib/features/settings/application/settings_view_state.dart`.
- **Details** — EPIC-06 owns `SettingsController` (a `StreamNotifier<AppSettings>` over
  `settingsRepository`) and owns its write policy: **the stream is the source of truth; local state is
  never mutated optimistically and reconciled.** This epic previously specified a second
  `SettingsNotifier` in `features/settings/presentation/` with optimistic-with-rollback writes — two
  objects writing the same row under opposite reconciliation rules. That paragraph is deleted. Every
  write on this screen calls EPIC-06's controller and awaits its `Result<void, StorageFailure>`; the row
  reflects the stream, so a failed write simply never moves, and the screen renders an inline error
  beside the row that failed (never a `SnackBar` — a setting the user must act on does not time out).
  What this epic still fixes are the *units*, because EPIC-12 and EPIC-06 both read them: `reminderTime`
  is **minutes since local midnight** (`int?`), not a `DateTime` and not a UTC instant — EPIC-12 needs
  wall-clock + rule, and a stored instant drifts an hour across every DST boundary. `textScale` is a
  `double` in `[1.0, 2.0]` stored in 0.1 steps; `highContrast` is a `bool`; `localeTag` is a BCP-47
  `String?` where **null means "follow the OS"** (task 7).
- **Acceptance** — A failing repository write leaves the row visually where it started (because the
  stream never emitted) and shows a reason. A grep proves there is exactly one settings notifier class in
  the repository.

### 7. Settings screen layout — frame 6

- **What** — Build the cards and the footnote of the Settings reference frame.
- **Where** — `lib/features/settings/presentation/settings_screen.dart`,
  `widgets/reminder_row.dart`, `widgets/text_size_row.dart`, `widgets/language_row.dart`,
  `widgets/backup_card.dart`, `widgets/about_card.dart`, `widgets/privacy_footnote.dart`.
- **Details** — In reference order:
  1. Card one: **Daily reminder** row (clock glyph, "On · 8:00 am" sublabel formatted with
     `DateFormat.jm(locale)`, a `Switch`) which opens `showTimePicker` when tapped; **Text size** row
     with an `A`—slider—`A` control (`Slider` with `divisions: 10`, `label` announced) and a "Large"
     value word; **High contrast** row with a `Switch` and an On/Off sublabel.
  2. Card two: **Language** — a single row (globe glyph, current selection as the sublabel, **mirrored**
     chevron) opening a picker with five options: **System · English · Deutsch · فارسی · کوردیی
     ناوەندی**. Each option is rendered **in its own script and its own font** — `DaybreakScript.latin`
     for the first three, `DaybreakScript.arabic` (Vazirmatn) for `fa`/`ckb` — never transliterated into
     English, because the person who needs this row cannot read the English label for it. Choosing writes
     `localeTag` through EPIC-06's `SettingsController` (`'en'`, `'de'`, `'fa'`, `'ckb'`, or **null for
     System**); `resolvedLocaleProvider` picks it up and the app re-renders in place, including the text
     direction. The row itself is always rendered in the *current* app locale.
     > **Contract:** CONTRACTS §13. `localeTag` is a persisted column EPIC-05 ships and EPIC-06 reads
     > into `MaterialApp.locale`, and EPIC-12 explicitly assumes "the user may have overridden it" — but
     > until now **no epic built a control that writes it**, so it was a dead column and a Sorani or
     > Persian speaker on an English phone could never reach their own build. EPIC-15 additionally ships
     > `android:localeConfig` + `CFBundleLocalizations` so the OS per-app pickers work too; this row is
     > the one that works on every OS version.
  3. Card three: **Backup**, an `h3` plus two `SecondaryButton`s side by side — "Export data" (download
     glyph) and "Import data" (upload glyph), `min-height 52`. Both call providers that EPIC-13 fills in;
     in this epic they are wired to a stub that returns `Err(NotImplementedYet)` and renders the
     `ui-states-and-feedback` error surface, so the wiring is proven before the feature lands. At text
     scale > 1.3 the `Row` becomes a `Column` — two Persian button labels cannot share a row.
  4. Card four: **About** — SPEC §4.5's "re-read the disclaimer; about; version", none of which existed.
     Four rows: the app name and one-line description; **version and build** read from
     `package_info_plus` (`'${info.version} (${info.buildNumber})'`, rendered with
     `tabularFigures` and localized numerals, and selectable/long-press-copyable — it is the first thing
     a user has to read out when reporting a lost plan); **"Read the disclaimer again"** with an alert
     glyph and a **mirrored** chevron, pushing the re-read route; and **"View licenses"**, which pushes
     `showLicensePage(context: context, applicationName: …, applicationVersion: …, applicationIcon: …)`
     — Flutter's own page, wrapped so it inherits the Daybreak `ThemeData` and the current
     `Directionality` rather than falling back to bare Material. EPIC-02's OFL registration for Nunito
     and Vazirmatn is verified *through this page*, and EPIC-15 hangs its "Send diagnostic report" row
     off this card rather than inventing an About section during the release epic.
     > **Contract:** CONTRACTS §13. Add `package_info_plus` to this epic's dependency list — it is the
     > earliest epic that uses it (EPIC-13's envelope header uses it later).
  5. The footnote: a lock glyph in `success` plus "Everything stays on this phone. No account, no
     internet." — `bodyLarge`, `inkMuted`, centred with the glyph and text in one `Wrap` so it reflows
     instead of clipping.
- **Acceptance** — Frame-6 parity; every row ≥ 44 tall; each `Switch` carries
  `Semantics(toggled: …, label: …)` reading as a sentence. Picking فارسی on an English phone flips the
  whole app to Persian and RTL without a restart, and survives one; picking System clears `localeTag` and
  follows the OS again. The About card shows a real version string in a widget test with a fake
  `PackageInfo`, and "View licenses" opens a page listing both bundled faces.

### 8. Applying text scale and high contrast

- **What** — Make the two accessibility settings actually change the app, composing with the OS settings
  rather than replacing them.
- **Where** — `lib/app.dart` (EPIC-06 owns this file and built the `MaterialApp.router` in it — this epic
  edits it, so say so in the PR), `lib/theme/user_text_scaler.dart`.
- **Details** — **Do not** call `MediaQuery.withClampedTextScaling` and do not pass
  `TextScaler.linear(settings.textScale)` — both throw away the OS scaler. Write a small
  `UserTextScaler extends TextScaler` that wraps the inherited one:
  `double scale(double fontSize) => _base.scale(fontSize) * _factor;`, with `textScaleFactor`,
  `operator ==` and `hashCode` implemented so `MediaQuery` rebuilds correctly. **`textScaleFactor` is an
  abstract, deprecated getter in the SDK — a `TextScaler` subclass cannot compile without it**; carry a
  one-line comment at the declaration saying so, and note that EPIC-14's grep gate must therefore scope
  its `textScaleFactor` rule (path-exclude `lib/theme/user_text_scaler.dart`, or ban only
  `MediaQuery.textScaleFactorOf` / the named argument) and must allow `MediaQuery.of(context).copyWith`
  while banning the aspect-getter reads. A path-scoped rule inside the script is not the allowlist file
  EPIC-14 forbids.
  Insert it with
  `MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: UserTextScaler(base, factor)), …)` inside
  the router's `builder`, above the shell.
  **Composition ceiling — decided here.** The app factor *multiplies* the OS scaler, so the real worst
  case is iOS AX5 (~3.1×) × the slider at 2.0 ≈ 6.2×, which no golden renders and no 320pt device
  survives. Bound the composed result at **4.0× the unscaled font size**:
  `min(_base.scale(fontSize) * _factor, fontSize * 4.0)`. This is a *composition* cap, not a clamp of the
  OS scaler — with the slider at 1.0 the OS setting is passed through untouched at any value, so SPEC
  §10's "usable at the largest OS text size" is still honoured in full; only the product of the two is
  bounded. Write 4.0× into the code comment and hand it to EPIC-14 for its overflow matrix
  (compact_320 × OS 3.0 × app 2.0 × bold, all six screens, en + de).
  High contrast selects the third `ColorScheme`/`DaybreakColors` pair via
  `buildDaybreakTheme(brightness, script, highContrast: …)` from EPIC-02 (CONTRACTS §9 — the ≥7:1
  palette is v1 and EPIC-02 ships it), OR-ed with `MediaQuery.highContrastOf(context)` so an OS-level
  request is honoured even when the app toggle is off.
- **Acceptance** — With the OS at 1.5× and the app slider at 1.3×, text renders at ~1.95×; at OS 3.0×
  with the slider at 2.0× the composed scale is the documented 4.0× cap, not 6.2×, and a golden at that
  composed scale shows no clipping on Today, Plan or Settings.

### 9. Welcome — the content of the first-run gate

- **What** — The disclaimer content and its accept gate. **The route and the redirect belong to EPIC-06.**
- **Where** — `lib/features/welcome/presentation/welcome_screen.dart`,
  `lib/features/welcome/presentation/disclaimer_content.dart`.
- **Details** — EPIC-06 owns the `/welcome` route entry, its non-opaque `pageBuilder`
  (`CustomTransitionPage(opaque: false, barrierDismissible: false, barrierColor: c.overlay, …)` above the
  shell so the reference frame's dimmed Today stays painted behind it), and the top-level `redirect` that
  sends every location to `/welcome` while `disclaimerAcceptedAt == null` off a synchronously-available
  provider seeded in `bootstrap()`. This epic previously rebuilt all three, with a different re-read
  path; that duplication is deleted. **One re-read path, settled: `/settings/disclaimer`** — EPIC-06
  registers it in place of its `/welcome?readOnly=true` sketch, and this epic supplies its content. Say
  so in the PR, because EPIC-06's route table changes with it.
  What this epic builds is the body: the sunrise seal, the heading, the paragraph from SPEC §4.0, and a
  single "I understand" `PrimaryPillButton`, wrapped in `PopScope(canPop: false)` so Android back and the
  iOS swipe cannot dismiss it. Accepting writes `disclaimerAcceptedAt = clock.now()` through EPIC-06's
  `SettingsController` and `context.go('/today')`.
  **The read gate, restated so it cannot brick a clean install.** "Disabled until the scroll controller
  reaches the end" fails closed on a body that does not scroll: at 1.0 scale on a 390×844 surface the
  paragraph fits, `maxScrollExtent == 0`, no scroll notification ever fires, and the button stays
  disabled forever behind a redirect that forces every route here — an uninstallable first run, on
  exactly the configuration the goldens and parity captures use. The gate is:
  enabled when `!position.hasContentDimensions || position.maxScrollExtent <= 0 ||
  (position.atEdge && position.pixels >= position.maxScrollExtent)`, evaluated in a post-frame callback
  after the first layout, and **unconditionally enabled when `MediaQuery.accessibleNavigationOf(context)`
  is true** — a screen-reader user scrolls by focus movement and may never emit a scroll event at all.
  `/settings/disclaimer` renders the same `DisclaimerContent` inside a normal dismissible sheet with a
  "Close" action, no gate, and no write.
- **Acceptance** — A fresh install lands on `/welcome`; pressing back does nothing; accepting persists and
  a restart goes straight to Today. An integration test kills and restarts the app to prove it. Three
  gate tests: a 1.0-scale pump where the content does not scroll asserts the button is **enabled on the
  first frame**; a 2.0-scale pump asserts it is disabled until scrolled to the end; an
  `accessibleNavigation: true` pump asserts it is enabled.

### 10. Localization for all four locales

- **What** — Every string on these three screens in en, de, fa, ckb.
- **Where** — `lib/l10n/arb/app_en.arb`, `app_de.arb`, `app_fa.arb`, `app_ckb.arb` (the `arb-dir` in
  `l10n.yaml` is `lib/l10n/arb` — EPIC-03 set it; this epic previously wrote `lib/l10n/`).
- **Details** — Roughly 75 new keys, including the ~6 for the Language row (its title, the "System"
  option, and the four language names — note the four **language names are not translated**: `English`,
  `Deutsch`, `فارسی`, `کوردیی ناوەندی` are the same literal in all four ARBs) and the ~6 for the About
  card (app name, description, version label, disclaimer re-read, "View licenses", and the licenses page
  title). ICU plurals for tablet counts and "{n} strengths". The 10%-caveat message takes
  `{currentDose}`, `{percentDose}` and `{stepDose}` as `number` placeholders so numerals localize.
  No `toUpperCase()` on any label. Persian and Sorani copy is authored, not machine-mangled, and the
  Sorani strings ship in the app ARB while framework strings still fall back through the custom
  delegate EPIC-03 built (`flutter_localizations` has no `ckb`).
- **Acceptance** — `flutter gen-l10n` clean, no `MISSING` placeholders, and the untranslated-message
  report is empty for all four.

### 11. Adaptive layout and landscape

- **What** — These screens must work on a tablet propped on a kitchen table (SPEC §5.4).
- **Where** — `plan_screen.dart`, `settings_screen.dart`.
- **Details** — Above the `medium` breakpoint from `adaptive-layout`, the Plan cards go two-up in a
  `Wrap`/`LayoutBuilder` with the next-step card full width beneath; Settings stays a single centred
  column with `maxWidth: 640` rather than stretching rows to 1200px. The shell's `NavigationRail` swap
  is already handled by EPIC-06 — do not re-implement it here.
- **Acceptance** — A 1024×768 landscape golden for both screens shows no full-width stretched rows and
  no horizontal scroll.

### 12. Tests

- **What** — Goldens, a11y assertions, and behaviour tests.
- **Where** — `test/features/plan/`, `test/features/settings/`, `test/features/welcome/`,
  `test/golden/`.
- **Details** — Golden matrix per `widget-golden-and-a11y-testing`: {plan, settings, welcome} × {light,
  dark} × {en, fa} × {1.0, 2.0} = 24 goldens, captured with `loadAppFonts()`, `debugDisableShadows`, and
  a pinned `Clock.fixed`. The Settings goldens include the Language and About cards — they are rows on an
  existing screen, not new golden pairs — plus one extra golden of the **language picker open** in `fa`,
  proving each option renders in its own script. A11y:
  `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline`, `iOSTapTargetGuideline`,
  `labeledTapTargetGuideline` on all three. Behaviour: the form validation test from task 3, the
  per-region default-strengths tests, the `suggestStep` cases from task 4, the Step-0-on-first-save test,
  the start-next-step disabled-with-reason test, the delete-requires-confirm test, the failed-settings-
  write test, the language-switch test, the About version test, and the three Welcome gate tests from
  task 9.
- **Acceptance** — All green in CI; goldens committed with the platform-pinned font bundle.

### 13. Visual parity pass

- **What** — Prove frames 1, 5 and 6 against the reference.
- **Where** — `docs/parity/epic-11/` (contact sheets, not committed to `lib/`).
- **Details** — Follow `daybreak-visual-parity`: dump the crop rects, crop frames 01, 05 and 06 from all
  four reference PNGs, capture the built screens at 390×844 @ DPR 2 with the pinned fixture, and build
  the paired sheets.
  **The fixture, pinned once and repeated verbatim** wherever it appears (here, EPIC-14 tasks 2/9/12,
  EPIC-15 task 8), defined in code as `test/fixtures/seeded_plan.dart` so no epic retypes it:
  *Prednisolone, current 10mg, target 0mg, strengths 5mg + 1mg, halves on, DSNS, active step
  **10mg → 9mg**, day 14 of 52, clock pinned to 2025-04-16.*
  The old "next step 9→8" line contradicted its own 10mg current dose. At 10mg, 10% is exactly 1mg and
  1mg is achievable, so `suggestStep` returns 1mg and the pair is `10 → 9` with the caveat banner
  **absent** — this deviates from the minor finding's suggested `10 → 9.5`, which does not follow from
  CONTRACTS §6's rule.
- **Acceptance** — See the Visual parity section below.

## Visual parity

**Reference:** `design/reference/daybreak-screens-{light,dark}-{en,fa}.png`, frames **01 (Welcome /
disclaimer)**, **05 (Plan)** and **06 (Settings)** — the crop rects come from the rect dump in
`daybreak-visual-parity/references/capture-and-compare.md`, never hard-coded.

**Variants:** 3 frames × {light, dark} × {en (LTR), fa (RTL)} = 12 paired comparisons, plus the two
no-reference passes: `de` (longest strings — "Ich kann Tabletten teilen", "Erneut lesen") and `ckb`, and
a 200%-scale pass on each screen.

**Must match exactly:** card order and count on Plan (summary → strengths → method → next step) and on
Settings (accessibility → **language** → backup → **about** → footnote — the language and about cards are
new since the reference frames were drawn, so they are a *no-reference* row: measured against the token
system and the row-item recipe, never against a frame that does not contain them); every token value;
the segmented control's
three labels and the selected segment's raised tile; the chip selected state carrying glyph + weight +
ring; the next-step card's `primary`-tinted border; the warning banner's glyph, wording and tint; the
switch knob check glyph in the on state; the footnote's `success`-coloured lock. In `fa`: the arrow in
the next-step pair and the chevron on the disclaimer row are **mirrored**; the slider fills from the
right; the row-item value column sits on the left; all numerals are Persian.

**Tolerated:** glyph rasterisation and hinting between Chrome and Impeller, gradient dithering on the
Welcome sheet's seal, shadow falloff on the raised cards, the mockup's drawn status bar, bezel rings and
home indicator (never a finding), and platform switch/slider chrome — Material's `Switch` and `Slider`
will not be pixel-identical to the CSS mock; match size, position, state signalling and colour tokens,
not the knob's exact geometry.

**Standard:** ±2 logical px on measured spacing and component dimensions, ΔE00 ≤ 2 on sampled flat fills.
Fix the implementation, never the reference.

## Definition of done

- [ ] Plan renders the four reference cards and reads/writes a real `TaperPlan` through the single
      `taperRepository`; the names `PlanRepository`, `StepRepository` and `SettingsRepository` appear
      nowhere, and no file defines a `DoseMg` or a `CalendarDate`
- [ ] **Saving a plan with no steps appends exactly one `Step` row (`index: 0`, `status: active`, frozen
      `patternVersion`) in the same transaction, and none thereafter** — a brand-new plan produces a
      schedule (CONTRACTS §7)
- [ ] A clean install lands on a non-empty, editable strength list and the right drug name for its region
      (`kDefaultStrengths`, SPEC §11.2), with a unit test per region
- [ ] The form validates every field with localized messages; controllers and focus nodes are disposed;
      `tool/check_forms.sh` passes; the dose formatter is `kDoseInputFormatter` from `lib/l10n/` and
      EPIC-03's digit-table grep is clean
- [ ] All three method segments are live, with a percentage field, a fixed-mg field and a hold-period
      field, matching EPIC-04's three generators (CONTRACTS §8)
- [ ] Next-step preview renders `suggestStep`'s own return value (`9mg → 8.5mg, suggested step 0.5mg` for
      the SPEC §4.4 case), allows override, shows the caveat banner exactly when
      `communityPracticeDiffers`, and clamps at target instead of going negative
- [ ] "Start next step" is gated by EPIC-04's single `stepStatusFor`, not by a second local rule
- [ ] Editing a plan mid-step preserves all `DoseLog` history; changing strengths recomposes only future
      days
- [ ] Delete plan requires confirmation through the shared confirm sheet and offers an export first
      (action stubbed for EPIC-13)
- [ ] Settings renders reminder/text-size/high-contrast, **language**, backup and **about** plus the
      privacy footnote, and persists every value through EPIC-06's one `SettingsController` — no second
      settings notifier and no optimistic-with-rollback path exists
- [ ] The Language picker writes `localeTag` (null = System) and switches the whole app, including
      direction, without a restart — the column is no longer dead (CONTRACTS §13)
- [ ] The About card shows name, version + build from `package_info_plus`, the disclaimer re-read, and
      "View licenses" via a Daybreak-themed `showLicensePage` listing both bundled faces
- [ ] `reminderTime` is stored as wall-clock minutes, ready for EPIC-12
- [ ] App text scale composes with the OS scaler via `UserTextScaler` under a documented 4.0× composition
      cap; high contrast selects EPIC-02's ≥7:1 palette and ORs with `MediaQuery.highContrastOf`
- [ ] Welcome's accept gate is enabled on the first frame when the body does not scroll and whenever
      `accessibleNavigation` is on; the route and redirect stay EPIC-06's; acceptance persists and is
      re-readable from Settings → About via `/settings/disclaimer`
- [ ] All strings in en/de/fa/ckb; `flutter gen-l10n` clean; no untranslated messages
- [ ] 24 goldens + a11y guideline assertions green
- [ ] Visual parity sheets attached for 12 variants; no exact-tier difference outstanding
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, parity evidence, tests added,
      deferrals
- [ ] CI green
- [ ] Merged to `main`
