# Cross-epic contracts

The epics were drafted in parallel and diverged at every seam: two dose types, two date types, two
repository shapes, two provider architectures, three spellings of the elevation slots. An adversarial
review found 23 blockers and 69 major issues, nearly all of them integration defects rather than bad
ideas.

**This file is the arbiter. Where an epic disagrees with this file, this file wins.** Read it before
starting any epic. Changing a contract here is a deliberate act that updates every affected epic in the
same commit.

---

## 1. Canonical types — one owner each

| Type | File | Owned by | Rule |
|---|---|---|---|
| `Milligrams` | `lib/core/units/milligrams.dart` | EPIC-04 | Integer **hundredths**. The only dose type. |
| `LocalDate` | `lib/core/time/local_date.dart` | EPIC-04 | Calendar date, no time, no zone. The only date type. |
| `Clock` | `lib/core/time/clock.dart` | EPIC-01 | `package:clock` only. **No Riverpod.** |
| `clockProvider` | `lib/providers.dart` | EPIC-01 | Lives **outside** `lib/core/`, so the purity gate holds. |
| `DayState` | `lib/core/day_state.dart` | EPIC-04 | `enum DayState { taken, missed, today, upcoming }` — exactly four. |
| `Result<T, F>` | `lib/core/result.dart` | EPIC-01 | Typed error arm everywhere. |

**`CalendarDate` and `DoseMg` do not exist.** EPIC-03 must not create `lib/core/dose.dart`; EPIC-08/09/10
must not say `CalendarDate`. `isNewDose` is a **separate bool on `DayPlan`**, never a fifth `DayState`
member — a day can be both `today` and a new-dose day.

**Consequence: EPIC-03 now depends on EPIC-04**, because it formats `Milligrams`. The README graph and
EPIC-03's own "Depends on" line must say `01, 02, 04`. EPIC-03 owns only the projection —
`formatDose(Milligrams, Locale)` and `parseDose(String, Locale) → Result<Milligrams, UnitFailure>` in
`lib/l10n/number_formats.dart`.

## 2. The purity gate

`lib/core/**` may not import `package:flutter/`, `package:flutter_riverpod`, `package:hooks_riverpod`,
`package:riverpod`, `package:drift`, `package:flutter_test`, or `dart:ui`.

**One exception, and it is deliberate:** `lib/core/notifications/**` may import `package:timezone`,
because a scheduling core without `TZDateTime` cannot express "08:00 local on this date". The CI gate
must encode the exception rather than the epic quietly violating the rule.

## 3. Data layer — one repository

EPIC-05 ships **one** `TaperRepository` at `lib/data/taper_repository.dart`.

```
Stream<Result<TaperSnapshot, StorageFailure>> watchSnapshot()

Future<Result<void, StorageFailure>> markTaken(LocalDate, {required Milligrams plannedMg})
Future<Result<void, StorageFailure>> undoTaken(LocalDate)
Future<Result<void, StorageFailure>> setNote(LocalDate, String?)
Future<Result<void, StorageFailure>> recordFlare({required LocalDate on, required Milligrams revertTo})
Future<Result<void, StorageFailure>> recordHold({required int stepId, required LocalDate from, required int extraDays})
Future<Result<void, StorageFailure>> savePlan(TaperPlanDraft)      // inserts Step 0 — see §6
Future<Result<void, StorageFailure>> startNextStep()
```

Settings live behind a separate `settingsRepository`. **`PlanRepository`, `StepRepository` and
`SettingsRepository` do not exist** — delete those names from EPIC-11.

`markTaken` and `setNote` both need `plannedMg` to create a row, because `DoseLogs.plannedMg` is
non-null. The caller has it from the `DayPlan`; pass it.

## 4. Derivation — providers, not repository methods

The repository returns **facts**. `generateSchedule` runs in the **app layer**, once.

| Provider | File | Owned by |
|---|---|---|
| `derivedScheduleProvider` | `lib/app/derived_schedule_provider.dart` | EPIC-06 |
| `resolvedLocaleProvider` | `lib/app/locale_providers.dart` | EPIC-06 |
| `appLocalizationsProvider` | `lib/app/locale_providers.dart` | EPIC-06 |
| `todayViewProvider` | `lib/features/today/application/` | EPIC-08 |
| `scheduleViewProvider(stepIndex)` | `lib/features/schedule/application/` | EPIC-09 |
| `progressViewProvider` | `lib/features/progress/application/` | EPIC-10 |

EPIC-06 **does not** define `todayProvider`, `missedDaysProvider` or `currentStepProgressProvider` —
those were duplicates of the screen-level providers. Nothing is "cached in the repository layer";
strike that phrase from EPIC-09.

`appLocalizationsProvider` is the **only** sanctioned way to reach `AppLocalizations` outside a widget.
Notifiers that format strings read it. It rebuilds on both a settings change and an OS locale change.

## 5. The generator must cover every date

**Blocker fixed here.** A step is 52 days (+ holds). SPEC §3.1 then says *"the new dose every day, and
that dose becomes the old dose of the next step."* Those steady-state days were missing entirely, which
left the Today screen with nothing to render on day 53 — and on every day after the taper finished.

`generateSchedule` emits, for every date in range:
- **Step days** — `kind: DayKind.step`, `blockIndex: 1..11`, `dayInStep: 1..52+holds`.
- **Steady-state days** — after a step's realised length and before the next step's `startDate`:
  `kind: DayKind.steadyState`, `blockIndex: null`, `dayInStep: null`, dose = that step's `toDose`.
- **After the final step** — steady-state at the target dose, indefinitely.

A step's realised length is `min(52 + holds, days until the next step's startDate)`. Property test:
generate over `lastStepStart + 200 days` and assert **every date in range has exactly one `DayPlan`**.

## 6. Step sizing — and the case that had no answer

```
suggestStep(current, target, strengths, allowHalves) → StepSuggestion {
  Milligrams suggested;      // never exceeds (current - target), never exceeds current
  Milligrams tenPercent;     // reported so the UI can show the honest sentence
  bool communityPracticeDiffers;
}
```

Take the **largest achievable increment ≤ 10% of the current dose**. **If none exists — which is every
dose below 5mg, i.e. ten of the fifteen steps — return the *smallest* achievable increment and set
`communityPracticeDiffers: true`.** Without this the rule is undefined for 520 of the 780 days.

Two divergence regimes, both honest, both surfaced in the Plan screen banner:
- **10mg–5mg** — 10% permits a *smaller* step than community practice actually uses.
- **below 5mg** — 10% permits *no achievable step at all*.

The worked example in SPEC §4.4 (`9mg → 8mg, suggested 1mg`) is **wrong** under this rule and is
corrected to **`9mg → 8.5mg, suggested step 0.5mg`**, banner shown. The user can override to 1mg — SPEC
§3.2 says the suggestion is a default, never a lock.

Tablet composition minimises **total tablets first, then splits** — in that order. An unachievable dose
is **flagged**, never silently rounded.

## 7. Who creates the first step

`savePlan` inserts, in the same transaction, when the plan has no steps:

```
Step(index: 0, fromDose: currentDose,
     toDose: currentDose - suggestedOrOverriddenStep,
     startDate: plan.startDate, status: active,
     patternVersion: DsnsPattern.v1().version)
```

Acceptance: *"appends exactly one Step row when none exists, and none thereafter."* Without this no
plan ever produces a schedule.

## 8. Step rules — all three are real

The Plan screen offers DSNS, Percentage and Fixed mg, and `TaperMethod` is a stored column, so EPIC-04
implements all three rather than shipping two dead segments:

- **`dsns`** — the eleven-block, 52-day alternating calendar.
- **`percentage`** — step = N% of current dose, then the new dose daily for a hold period.
- **`fixedMg`** — step = a fixed mg amount, then the new dose daily for a hold period.

Percentage and Fixed differ only in how the step *size* is computed; both produce the simple
"new dose every day" shape. `TaperMethod` is declared in `lib/core/`, not in `lib/data/` converters.

## 9. Design tokens

`DaybreakColors` · `DaybreakShapes` (radii `radiusXs…radiusPill` **and** spacing `s1…s9`) ·
`DaybreakElevation` (`level0…level3`, `glow`) · `DaybreakMotion`. `DaybreakScript` is an enum owned by
`daybreak-bilingual-type`.

**`DaybreakRadii`, `DaybreakSpacing`, `shadow0…shadow3` and `shadowGlow` do not exist.** EPIC-08/09/10
still contain them and must be swept.

**EPIC-07 is authoritative for component token values.** EPIC-08/09/10 reference the component by name
("per EPIC-07's `DoseHeroCard`") and carry **no token values of their own**. Where 07 and a screen epic
disagree, resolve against the reference PNG and write the winner into 07 only.

**`missed` is `stateMissed`, warm taupe — never `danger`.** This was argued deliberately in EPIC-02:
red punishes a person for a bad week. EPIC-09 currently says `danger`; it is wrong.

**High contrast is v1.** SPEC §4.5/§5.4 require the toggle and EPIC-05 stores the column, but no epic
built the palette. EPIC-02 ships a third `ColorScheme`/`DaybreakColors` pair at a **≥7:1** floor, and
`buildDaybreakTheme(Brightness, DaybreakScript, {bool highContrast})`. EPIC-14 then loops **four**
themes, not two.

## 10. Formatting

`maximumFractionDigits: 2`, `minimumFractionDigits: 0`. **`1` truncates 0.25mg to "0.3"** — and 0.25mg
is reachable (half of a 0.5mg tablet), as is 1.25mg. Test `formatDose(Milligrams(25), en) == '0.25'`
and the Persian rendering of 1.25.

Normalisation to ASCII digits runs before every parse. `ckb` uses `fa` number symbols (U+06Fx), never
the Arabic block (U+066x).

## 11. Backup identity and versioning

Rows need stable ids across an export/import round trip. Add **`uid TEXT NOT NULL UNIQUE`** to all six
tables in **EPIC-05's schema v1**, minted at insert, with a `ulid` dependency. EPIC-13 must not assume
a column that no epic creates.

Backup versioning is a **payload upgrade ladder in the codec** — `upgradePayload(N → N+1)` pure row
transformers keyed off the header's `schemaVersion`, run up to `AppDatabase.schemaVersion` *before*
inserting into a current-schema staging database. Do not try to build a staging DB at the payload's old
version and migrate it. Refuse a payload newer than the app.

**Ship schema v1 at v1.0.0.** The artificial v2-with-a-dead-column is removed. The migration harness is
still proven by a test against a generated v2 fixture — the ladder is exercised before it is needed,
without shipping a dead column. EPIC-14/15's "install the previous release and upgrade" step is
impossible for a first release; it becomes a v1.1 gate.

## 12. Notifications

**No `SCHEDULE_EXACT_ALARM`.** A daily "your plan for today" does not need alarm-clock precision, and
the permission draws Play review scrutiny for no benefit. Use
`AndroidScheduleMode.inexactAllowWhileIdle`. EPIC-15's manifest expectation stands; EPIC-12's
exact-alarm branch is removed.

Authorization must be **re-checked on resume**, not only at toggle-on — a user can revoke it in OS
settings and the app would keep claiming reminders are on. **Verify the plugin's actual API surface
against the version in `pubspec.lock` before writing the call**; the method EPIC-12 currently names was
checked against the installed plugin and does not exist.

## 13. Settings — two missing sections

SPEC §4.5 requires "Re-read the disclaimer; **about; version**", and none of it was built. EPIC-11 adds:

- **About card** — app name, version + build from `package_info_plus`, and "View licenses" opening
  `showLicensePage` styled with the Daybreak theme.
- **Language picker** — System · English · Deutsch · فارسی · کوردیی ناوەندی, each rendered in its own
  script, writing `localeTag` (null = follow the OS). Without it, `localeTag` is a column nothing can
  set. EPIC-15 additionally ships `android:localeConfig` + `CFBundleLocalizations`.

Both get ARB keys, a frame-6 parity row, and goldens.

## 14. Dependency pins

`intl: ^0.20.2` — the installed `flutter_localizations` pins `intl` exactly, and a wider range will not
resolve.

## 15. Naming, settled once

`markTaken` / `undoTaken` / `setNote` — **not** `markDay` / `unmarkDay` / `addNote`.
`LocalDate` — not `CalendarDate`. `Milligrams` — not `DoseMg`.
`e.level0…level3` / `e.glow` — not `shadow*`.
