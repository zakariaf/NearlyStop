# EPIC-04 — DSNS domain engine

**Branch:** `epic/04-dsns-domain-engine`
**Depends on:** EPIC-01 (the Flutter project, analysis options, CI, test harness). Nothing else — this
epic imports zero Flutter, so it can be built in parallel with EPIC-02.

> **Contract:** per `CONTRACTS.md` §1 this epic is the **sole owner** of `Milligrams`, `LocalDate`,
> `DayState` and `TaperMethod`. `CalendarDate` and `DoseMg` do not exist anywhere in the codebase, and
> `lib/core/dose.dart` (a half-milligram store EPIC-03 previously declared) is deleted from EPIC-03.
> **EPIC-03 now depends on this epic** because it formats `Milligrams`; it owns only the projection
> (`formatDose`/`parseDose`), never a dose type. EPIC-05 maps drift rows onto the fact records defined
> here and must not redeclare `TaperMethod`.

## Where we are now

EPIC-01 has created the Flutter project: `pubspec.yaml`, `analysis_options.yaml` on
`very_good_analysis`, `lib/` with the feature-first skeleton (`lib/core/`, `lib/data/`,
`lib/features/`, `lib/routing/`, `lib/theme/`, `lib/l10n/`), a `test/` tree, and a CI workflow that
runs `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos` and `flutter test`.
`lib/core/` currently holds the `Result`/`Failure` types and the **pure** `Clock` seam at
`lib/core/time/clock.dart` (`package:clock` only). `clockProvider` deliberately lives **outside**
`lib/core/`, in `lib/providers.dart` (`CONTRACTS.md` §1), so the purity gate in task 8 is a real gate
rather than one with a Riverpod-shaped hole in it.

There is no domain code. Nothing in the repo knows what DSNS is, what a block is, how many days a step
runs, how a dose decomposes into tablets, or what a flare does. `SPEC.md` §3 and §6 describe it in
prose; this epic turns that prose into executable, exhaustively tested Dart.

## Why this epic exists

The schedule generator is the product. Everything else — five screens, four locales, a theme, a
database — is presentation of what this engine computes. If the engine is wrong, a 74-year-old takes
the wrong number of tablets on a Tuesday, and no amount of visual polish redeems that. `SPEC.md` §10
opens with "a 52-day step generates correctly and matches the block table byte for byte" for exactly
this reason.

It is also the architectural spine (`SPEC.md` §6, *Why this matters architecturally*). Because
`generateSchedule` is **pure** — dates in, days out, no I/O, no clock, no database, no Flutter — flare
rollback is incapable of corrupting history: a flare appends a fact and the schedule is re-derived.
That property only holds if the purity is real and enforced, not merely intended. So this epic ships a
test that fails the build if anything under `lib/core/` ever imports Flutter, Riverpod or drift
(task 8, `CONTRACTS.md` §2).

Building it before persistence (EPIC-05) and before any screen means the storage schema is designed
around what the generator actually needs as input, rather than the generator being bent around a
schema someone guessed at. `DayPlan` is never stored; it is what comes out of here.

## What we will have when it is done

A pure-Dart library under `lib/core/` that, given a plan, its steps, its flares and its holds, returns
the exact list of days a patient will live — **every date in range, with no holes**: step days with
their block and position, steady-state days between steps and after the taper finishes, hold days, each
with its dose, whether it is a new-dose or old-dose day, and either a concrete tablet composition
(`1 × 5mg · 4 × 1mg`) or an explicit "this dose cannot be made from what you hold" flag. All three
stored methods generate — DSNS, percentage and fixed mg — so the Plan screen's segmented control has no
dead segments. Plus: a suggested step size that has an answer at **every** dose including the ten steps
below 5 mg, with the honest note about both divergence regimes; cumulative-load and adherence
arithmetic; `stepStatusFor` so "Start next step" can ever be enabled; and a test suite that proves the
block table, the 26/26 split, composition correctness and flare determinism without a single mock.

## Skills to load

| Skill | What it governs here |
|---|---|
| `dart3-idioms-and-coding-standards` | Sealed hierarchies for failures and day states, exhaustive `switch` expressions, `const` constructors, no `dynamic`, extension types where they earn it |
| `error-handling-typed-results` | `Result<T, F extends Failure>` on every fallible entry point; unachievable dose is a value, never an exception |
| `seeded-determinism-and-golden-vectors` | The committed golden vector for a full 52-day step; seeded `Random` in property tests; "regenerates identically every time" as a test, not a hope |
| `value-objects-money-and-units` | `Milligrams` as integer hundredths — never `double` arithmetic on a dose; `TabletStrength`, `LocalDate` |
| `testing-strategy` | The unit/property/golden split, naming, and what belongs in CI's fast lane |
| `naming-conventions` | `DsnsBlock`, `DayPlan`, `generateSchedule` — domain words, no `Manager`/`Helper`/`Util` |
| `dartdoc-conventions` | Every public symbol documented; the block table reproduced in the dartdoc of `DsnsPattern` so it is readable at the call site |
| `async-safety` | Nothing here is async, and that is the point — state it, and keep `Future` out of the domain API surface |

## Tasks

### 1. Units and the shared domain types: `Milligrams`, `TabletStrength`, `LocalDate`, `DayState`

- **What** — Immutable value objects that make the rest of the engine unable to express a wrong
  thing, plus the two small enums every other epic reads.
- **Where** — `lib/core/units/milligrams.dart`, `lib/core/units/tablet_strength.dart`,
  `lib/core/time/local_date.dart`, `lib/core/day_state.dart`, barrel `lib/core/units/units.dart`.
- **Tests first (TDD)** — `test/core/units/milligrams_test.dart`, `test/core/time/local_date_test.dart`,
  `test/core/day_state_test.dart`; all pure `package:test`, no `flutter_test` import.
  Write and watch fail, in this order:
  1. `Milligrams.fromHundredths(950).toDisplayString() == '9.5'`, `(25) == '0.25'`, `(900) == '9'`,
     `(1000) == '10'` — trailing zeros trimmed, no locale separators, no thousands group.
  2. round-trip: `Milligrams.parse(m.toDisplayString()).value == m` for every `m` from 0.25 mg to
     60 mg in 0.25 steps; `==` on the integer `hundredths`, never `closeTo`.
  3. parse rejections: `'9.005'`, `''`, `'-1'`, `'9,5'`, `'abc'` all return `Err(UnitFailure)`;
     `'9.50'` returns 950 hundredths and `'.5'` returns 50.
  4. the arithmetic goldens a `double` implementation fails: `10mg - 9.9mg` has
     `hundredths == 10` exactly, `0.1mg + 0.2mg` has `hundredths == 30`, and
     `Milligrams.fromHundredths(10) * 3` has `hundredths == 30`.
  5. `half()` on 50 hundredths → `Ok(25)`; on 25 hundredths (odd) → `Err`, never a rounded 12 or 13.
  6. `LocalDate(2026,3,28).addDays(1) == LocalDate(2026,3,29)` and
     `LocalDate(2026,10,24).addDays(1) == LocalDate(2026,10,25)` — the two European DST edges;
     plus `(2028,2,28).addDays(1) == (2028,2,29)` and `(2026,12,31).addDays(1) == (2027,1,1)`.
  7. seeded fuzz, `Random(20260421)`, 3,000 iterations, against an independent oracle built on
     `DateTime.utc` day arithmetic: `LocalDate.parse(d.toIso8601()) == d` and
     `d.addDays(n).difference(d) == n` for `n` in −400…400, with `d` and `n` echoed in `reason:`.
  8. `toUtcMidnight()` returns `isUtc == true` at hour 0 for a sample of dates. The *ban* on
     constructing a local instant is a review and `tool/check_bans.sh` matter, not something this
     test can assert — say so in the test's doc comment rather than faking a check.
  9. an exhaustive `switch` over all four `DayState` members with no `default` arm, so adding a
     fifth member stops the test compiling.
- **Details** —
  `Milligrams` wraps `final int hundredths` (0.01 mg resolution). **No `double` anywhere in dose
  arithmetic.** Rationale: halves of a 0.5 mg tablet give 0.25 mg, so tenths are not enough, and
  `0.1 + 0.2 != 0.3` is not acceptable in a dosing app. API: `const Milligrams.fromHundredths(int)`,
  `Milligrams.parse(String)` returning `Result<Milligrams, UnitFailure>`, `operator +`, `-`,
  `operator *(int)`, `half()` (asserts even hundredths → `Result`), `compareTo`, `isZero`,
  `toDisplayString()` producing `9`, `9.5`, `0.25` (trailing zeros trimmed; **no locale formatting
  here** — that is `intl`'s job in the presentation layer, EPIC-03/08).
  `TabletStrength` = `Milligrams strength` + `bool splittable` is **not** stored here; splitting is a
  plan-level flag (`allowHalves`), per `SPEC.md` §4.4. So `TabletStrength` is a thin extension type
  over `Milligrams` that guarantees `> 0`.
  `LocalDate` is `(int year, int month, int day)` with `addDays(int)` implemented via
  `DateTime.utc(y, m, d).add(Duration(days: n))` — **UTC only**, because UTC has no DST and this is
  exactly the trap `SPEC.md` §7 names. It has `compareTo`, `difference(LocalDate) → int days`,
  `weekday`, `toIso8601()` (`yyyy-MM-dd`), `LocalDate.parse`, and `LocalDate.fromDateTime(DateTime)`
  which takes the **local** Y/M/D fields. It deliberately has no time-of-day and no `toDateTime()`
  returning a local instant.
  **Display bridge, and it is the only one:** `DateTime toUtcMidnight()`, dartdoc'd as *"exists solely
  so `intl`'s `DateFormat` and `shamsi_date`'s `Jalali.fromDateTime` can read the Y/M/D fields.
  Constructing a **local** instant from a `LocalDate` is banned — it is how a Persian date or a
  `MMMEd` label ends up one day off east of UTC."* EPIC-03's four formatter branches take a
  `LocalDate` and call this; they never take a `DateTime`.
  `DayState` — **`enum DayState { taken, missed, today, upcoming }`, exactly four members**
  (`CONTRACTS.md` §1). It is the *row log state* the palette and the greyscale golden are about.
  A dose change is **not** a fifth member: it is a separate `bool isNewDose` carried on `DayPlan`
  (task 6) and rendered with the `stateNewDose` slot, because a day is routinely both `today` and a
  new-dose day. `DoseKind { newDose, oldDose }` (task 6) is the domain-level concept and is a
  different thing from `DayState`; say so in both dartdocs.
  > **Contract:** `CONTRACTS.md` §1 — `DayState` is owned here, not in EPIC-02. EPIC-02's task 6
  > declaration and the `DayStatePalette` extension must switch over these four members.
- **Acceptance** — `Milligrams` has no `double` field or parameter; a test asserts
  `(0.1+0.2)`-style drift is impossible by construction. `LocalDate.addDays` crossing a DST boundary
  (e.g. 2026-03-28 → 2026-03-29) yields the next calendar day. **Dart cannot change the process's
  local zone in-process**, so the zone-sensitive assertions are proven by a CI step that re-runs the
  date suites under a second zone — `TZ=Europe/Berlin flutter test test/core/time/` — added to
  EPIC-01's workflow by this epic. `switch` over `DayState` compiles with no `default` arm.

### 2. The block table as data

- **What** — The eleven-block DSNS pattern from `SPEC.md` §3.1, versioned.
- **Where** — `lib/core/dsns/dsns_pattern.dart`.
- **Tests first (TDD)** — `test/core/dsns/dsns_pattern_test.dart`, pure `package:test`.
  Write and watch fail, in this order:
  1. the `SPEC.md` §3.1 table typed out as an 11-row `const` literal in the test —
     `(new, old, length, cumulative)` = `(1,6,7,7) (1,5,6,13) (1,4,5,18) (1,3,4,22) (1,2,3,25)
     (1,1,2,27) (2,1,3,30) (3,1,4,34) (4,1,5,39) (5,1,6,45) (6,1,7,52)` — diffed row for row
     against `DsnsPattern.v1().blocks`, **including the running cumulative column**.
  2. `totalDays == 52`, `totalNewDays == 26`, `totalOldDays == 26`, as three separate `expect`s so a
     failure names which one broke.
  3. `leadsWithNew` is `true` for indexes 1–6 and `false` for 7–11, asserted per block.
  4. `blocks_7_to_11_all_have_exactly_one_old_day` — `oldDays == 1` for indexes 7…11.
  5. `crossover_produces_two_consecutive_old_days` — block 6 is `(new 1, old 1)` and block 7 is
     `(old 1, new 2)`, so block 6's last day and block 7's first day are both old. Asserted on the
     block shapes here; task 6 asserts it again on the emitted day sequence.
  6. `DsnsPattern.forVersion(1)` → `Ok`; `forVersion(0)` and `forVersion(2)` →
     `Err(UnknownPatternVersion(0))` / `(2)`, carrying the requested version back.
- **Details** —
  ```dart
  final class DsnsBlock {
    const DsnsBlock({required this.index, required this.newDays, required this.oldDays});
    final int index;      // 1..11
    final int newDays;
    final int oldDays;
    int get length => newDays + oldDays;
    /// The single day always LEADS its block (SPEC.md §3.1). In blocks 1–6 the
    /// leading day is the NEW dose; in blocks 7–11 it is the OLD dose.
    bool get leadsWithNew => index <= 6;
  }
  ```
  `DsnsPattern` holds `int version` and `List<DsnsBlock> blocks`, with `const DsnsPattern.v1()`
  giving `(1,6) (1,5) (1,4) (1,3) (1,2) (1,1) (1old,2new) … (1old,6new)` — day counts
  `7,6,5,4,3,2,3,4,5,6,7`. Add `assert` in a `const`-friendly test (not in the constructor body) that
  `totalDays == 52`, `totalNewDays == 26`, `totalOldDays == 26`.
  **Block 6 is `1 new, 1 old` and block 7 is `1 old, 2 new`, so the crossover produces two consecutive
  old-dose days. This is correct and deliberate — `SPEC.md` §3.1 says so explicitly. Put that sentence
  in the dartdoc and in a test name, so a future refactor that "fixes" it fails loudly.**
  (The earlier form `newDays == 1 && oldDays > 1 || index <= 6` parsed as
  `(newDays == 1 && oldDays > 1) || (index <= 6)` and was correct, but its first clause can never fire
  above index 6 — blocks 7–11 all have `oldDays == 1`. The assertion that blocks 7–11 have
  `oldDays == 1` belongs in the pattern test, which is where it now lives.)
  `patternVersion` is what `Step.patternVersion` (EPIC-05) freezes; `DsnsPattern.forVersion(int)`
  returns `Result<DsnsPattern, DomainFailure>` and currently knows only version 1.
- **Acceptance** — Reproducing the `SPEC.md` §3.1 table from `DsnsPattern.v1()` and diffing it against
  a literal table in the test passes row for row, including the cumulative column. A separate test
  asserts blocks 7–11 all have `oldDays == 1`.

### 3. Typed failures

- **What** — The sealed failure hierarchy the whole engine returns.
- **Where** — `lib/core/dsns/dsns_failure.dart` (extends the `Failure` base from EPIC-01).
- **Tests first** — *Scaffold.* A sealed hierarchy of data-only failures has no behaviour to assert,
  and the property that matters — every `switch (failure)` compiles with **no `default` arm** — is a
  compile-time guarantee held by `flutter analyze --fatal-infos`, not something an `expect` can
  check. Write `test/core/dsns/dsns_failure_exhaustiveness_test.dart` as the witness: one exhaustive
  `switch` returning a tag per member, which stops compiling the moment a member is added and left
  unhandled. The failures' **payloads** get their real assertions where they are produced —
  `UnachievableDose` in task 4, `TargetAboveStart`/`NoStrengthsHeld` in task 5,
  `MissingMethodParameter`/`PlanNotStarted` in task 6.
- **Details** — `sealed class DomainFailure implements Failure` with:
  `UnachievableDose(Milligrams target, List<Milligrams> strengths, bool allowHalves)`,
  `NoStrengthsHeld()`, `TargetAboveStart(Milligrams start, Milligrams target)`,
  `NonPositiveStep(Milligrams step)`, `DoseOutOfRange(Milligrams dose)` (guards the composition DP —
  see task 4), `UnknownPatternVersion(int version)`, `PlanNotStarted(LocalDate startDate)`,
  `MissingMethodParameter(TaperMethod method)` (a `percentage` plan with a null percentage, or a
  `fixedMg` plan with a null fixed step — task 6 generates all three methods, so the enum arm that
  cannot be honoured is a typed value, never an unhandled `switch`).
  Every one carries the data needed to write a human sentence; **none of them carries a pre-built
  English string** — localisation is EPIC-03's, and the mapping happens in the presentation layer.
- **Acceptance** — `switch (failure)` over `DomainFailure` compiles without a `default` arm anywhere in
  the codebase.

### 4. Tablet composition solver

- **What** — Given a target dose, the strengths held and whether halves are allowed, return the
  composition minimising total tablets, then splits — or `UnachievableDose`.
- **Where** — `lib/core/dsns/tablet_composer.dart`.
- **Tests first (TDD)** — `test/core/dsns/tablet_composer_test.dart`, pure `package:test`.
  Write and watch fail, in this order:
  1. the `SPEC.md` §3.3 worked example: `[5,1]`, halves on, 6.5 mg → `counts == [(5mg,1),(1mg,1)]`,
     `half == (1mg)`, `totalTablets == 3`, `splitCount == 1`.
  2. `minimises_tablets_before_splits` — `[2.5,1]`, halves on, 4 mg →
     `1 × 2.5mg + 1 × 1mg + ½ × 1mg` (`totalTablets == 3`, `splitCount == 1`), and explicitly
     **not** `4 × 1mg`. This is the test that fails against a zero-half-first solver, which is the
     whole reason the rule was corrected — write it before the DP exists.
  3. the third sort key, `largestHalvedStrength desc`, on a genuine tie: `[5,2,1]`, halves on,
     6.5 mg has two candidates at `(3 tablets, 1 split)` — `½ × 5mg + 2 × 2mg` and
     `1 × 5mg + 1 × 1mg + ½ × 1mg`. Assert the first is returned.
  4. deterministic reconstruction among equal-cost paths (largest strength / lowest index wins):
     `[4,2,1]`, halves off, 4 mg → `1 × 4mg`, not `2 × 2mg` and not `4 × 1mg`.
  5. `[5,1]`, halves **off**, 6.5 mg → `Err(UnachievableDose(6.5mg, [5,1], false))` — never 6 mg,
     never 7 mg. Assert the payload's three fields, because the presentation layer writes its
     sentence from them.
  6. `[]` → `Err(NoStrengthsHeld)`. 100.00 mg composes; 100.01 mg → `Err(DoseOutOfRange)` —
     both sides of the guard.
  7. at most one half: over every dose 0.25–30 mg in 0.25 steps with `[5,1]` + halves,
     `splitCount <= 1` on every reachable dose.
  8. **seeded fuzz against an independent oracle** — `Random(20260421)`, 1,000 iterations, random
     strength subsets of `{0.5,1,2,2.5,5,10,20,25}`, random `allowHalves`, random target
     0.25–60 mg. The oracle is a brute-force bounded enumeration written in the test file (nested
     loops over counts `0…target ~/ strength`, plus the one optional half) — never the DP under
     test. Assert: `Σ strength × count [+ half] == target` **in hundredths**; the composer's
     `(totalTablets, splitCount)` equals the oracle's minimum under `(tablets asc, splits asc)`;
     and the composer returns `UnachievableDose` **exactly** when the oracle finds nothing. Echo
     strengths, halves and target in `reason:` so each failure is its own minimal repro.
  9. determinism: composing the same target twice returns equal compositions element for element.
- **Details** —
  `SPEC.md` §3.3: `dose = Σ (strengthᵢ × countᵢ) [+ one optional half tablet]`. **v1 allows at most
  one half tablet in a composition** — that is what the formula says and what people actually do; a
  solver that returns "½ × 5mg + ½ × 1mg" is technically cheaper and practically absurd.
  Algorithm: unbounded coin-change DP over integer hundredths.
  1. Sort strengths descending, deduplicated. `NoStrengthsHeld` if empty.
  2. Guard `target.hundredths > 10000` (100 mg) → `DoseOutOfRange`; this bounds the DP table and the
     highest realistic PMR/GCA starting dose is 60 mg.
  3. `minTablets[0..target]`, `int` array filled with a sentinel; `choice[i]` records the strength
     index used, always the **lowest index** (largest strength) among equal-cost options, which makes
     the reconstruction deterministic — required by `seeded-determinism-and-golden-vectors`.
  4. **Enumerate all candidates, then rank — never stop at the first reachable one.** Run the DP once
     against the whole target (the zero-half candidate) and, when `allowHalves`, once per strength `s`
     with even `hundredths` against `target - s.hundredths ~/ 2`. Collect every reachable candidate,
     then select by **`(totalTablets asc, splitCount asc, largestHalvedStrength desc)`** — total
     tablets first, splits second, exactly the order `SPEC.md` §3.3 states normatively. Return
     `UnachievableDose` only when the candidate set is empty.
     **This is a correction, and it matters.** The earlier rule was "try zero-half first, fall back to
     halves only if unreachable", which silently made split-avoidance the *primary* key. Counterexample
     with real UK strengths `[2.5, 1]`, halves on, target 4 mg: zero-half is reachable as 4 × 1 mg, so
     the old rule stopped there — while `1 × 2.5 + 1 × 1 + ½ × 1` is **two whole tablets and one half**,
     strictly fewer objects to count out at a kitchen table. The breakdown is the second-largest thing
     on the Today screen and is read every morning for 780 days; handing someone four separate tablets
     when three will do is the optimiser working against them.
  5. Return `TabletComposition(List<TabletCount> counts, TabletCount? half)` where
     `TabletCount(Milligrams strength, int count)`; `totalTablets`, `splitCount` (0 or 1), and a
     `describe()` that yields the ordered parts *as data* (`[(1, 5mg), (4, 1mg), (0.5, 1mg)]`) for the
     presentation layer to format per `SPEC.md` §4.1 — the domain never builds `"1 × 5mg · 4 × 1mg"`.
  Worked example from the spec must hold: strengths `[5, 1]`, halves allowed, target `6.5` →
  `1 × 5mg + 1 × 1mg + ½ × 1mg`.
- **Acceptance** — Every dose from 0.25 mg to 30 mg in 0.25 steps is either composed exactly (sum of
  parts equals target, asserted in hundredths) or returns `UnachievableDose`. **No test and no code
  path rounds.** With `allowHalves: false` and strengths `[5, 1]`, `6.5 mg` returns
  `UnachievableDose`, never `6 mg` or `7 mg`. **Named test for the ordering rule:**
  strengths `[2.5, 1]`, halves on, target `4 mg` → `1 × 2.5mg + 1 × 1mg + ½ × 1mg`
  (`totalTablets == 3`, `splitCount == 1`) and **not** `4 × 1mg`. A second row: `[5, 1]`, halves on,
  target `6.5 mg` → `1 × 5mg + 1 × 1mg + ½ × 1mg` (the `SPEC.md` §3.3 worked example, unchanged).

### 5. Step-size suggestion — including the ten steps the strict rule cannot answer

- **What** — `suggestStep(currentDose, targetDose, strengths, allowHalves) →
  Result<StepSuggestion, DomainFailure>`.
- **Where** — `lib/core/dsns/step_size.dart`.
- **Tests first (TDD)** — `test/core/dsns/step_size_test.dart`, pure `package:test`.
  Write and watch fail, in this order:
  1. `suggestStep(10mg, target 0, [5,1], halves)` → `suggested 1.0mg`, `tenPercent 1.0mg`,
     `communityPracticeDiffers false`.
  2. `suggestStep(9mg, …)` → `suggested 0.5mg`, `tenPercent 0.9mg`, `differs true` — the
     `CONTRACTS.md` §6 correction to `SPEC.md` §4.4, so `9mg → 8.5mg`, never `9mg → 8mg`.
  3. the remaining rows of the **Acceptance** table asserted on all three fields —
     7.5 mg → `(0.75, 0.5, true)`, 5 mg → `(0.5, 0.5, **false**)`, 4 mg → `(0.4, 0.5, true)`,
     2 mg → `(0.2, 0.5, true)`, 1 mg → `(0.1, 0.5, true)`, 0.5 mg → `(0.05, 0.5, true)`. The two
     `false` rows are as load-bearing as the six `true` ones: a fallback that fires everywhere is
     as wrong as one that never fires.
  4. `allowHalves: false`, `[5,1]`, target 0: 4 mg / 2 mg / 1 mg all → `suggested 1.0, differs true`;
     0.5 mg → `suggested 0.5` (clamped to the gap).
  5. clamping: `suggestStep(10mg, target 9.5mg, [5,1], halves)` → `suggested 0.5mg` (the strict
     answer 1.0 mg exceeds the gap) with `tenPercent` still `1.0mg`. Pin
     `communityPracticeDiffers == false` here and dartdoc why: the 10% rule *was* satisfiable, the
     clamp is a separate concern. `CONTRACTS.md` §6 fixes the clamp, not the flag; this test is
     where the flag's answer stops drifting.
  6. `currentDose == targetDose` → `Ok` with `suggested == Milligrams.zero`; `strengths: []` →
     `Err(NoStrengthsHeld)`; `targetDose > currentDose` → `Err(TargetAboveStart(start, target))`
     carrying both doses.
  7. `nextDose`: `(10, 1, 0) → 9`; `(0.5, 1, 0) → 0` — clamps at target, never negative;
     `(9, 0.5, 8.5) → 8.5`.
  8. **seeded fuzz against an independent oracle** — `Random(20260421)`, 1,000 iterations over
     random `current` 0.5–60 mg, random `target` in `[0, current]`, random strengths and halves.
     Oracle: reuse task 4's brute-force enumerator (independent of both `suggestStep` and the DP)
     to list every achievable increment, and assert `suggested` is the largest such increment
     ≤ `tenPercent` when one exists and the smallest overall when none does; that
     `tenPercent.hundredths == current.hundredths ~/ 10`; and that
     `0 < suggested <= current - target` on every non-complete row. Echo every input in `reason:`.
- **Details** —
  > **Contract:** the payload and the fallback are `CONTRACTS.md` §6, verbatim:
  > ```
  > StepSuggestion {
  >   Milligrams suggested;      // never exceeds (current - target), never exceeds current
  >   Milligrams tenPercent;     // reported so the UI can show the honest sentence
  >   bool communityPracticeDiffers;
  > }
  > ```
  > Three fields, no more. (A reviewer proposed a fourth, `communityPractice`, carrying "the smallest
  > achievable increment ≥ the strict value". `CONTRACTS.md` §6 settles the shape at three fields and
  > the contract wins; the Plan screen renders `suggested` in the `from → to` pair and both `suggested`
  > and `tenPercent` in the banner, and the user overrides when their rheumatologist said otherwise.)

  `SPEC.md` §3.2: *largest achievable increment ≤ 10% of currentDose*, where achievable means
  "composable from the held strengths" — reuse `TabletComposer.isAchievable`. Compute
  `ceilingHundredths = currentDose.hundredths ~/ 10` (integer, floor of 10% — floor, so we never
  suggest more than 10%) and take the maximum achievable increment ≤ that ceiling.

  **The case the strict rule has no answer for, and it is most of the taper.** Below 5 mg no achievable
  increment ≤ 10% exists at all: with strengths `[5, 1]` + halves the smallest achievable increment is
  0.5 mg, while 10% of 4 mg is 0.40 mg, of 2 mg is 0.20 mg, of 1 mg is 0.10 mg and of 0.5 mg is 0.05 mg.
  The maximum over an empty set is undefined, and `SPEC.md` §3.4 puts **ten of the fifteen steps —
  520 of the 780 days — in exactly that range**. So:

  - **If no achievable increment ≤ 10% exists, return the *smallest* achievable increment and set
    `communityPracticeDiffers: true`.** `tenPercent` is still reported so the Plan screen renders the
    honest sentence rather than a silent substitution.

  **Two divergence regimes, both honest, both surfaced in the Plan screen's banner** — say both in the
  dartdoc, because the copy is written from it:
  - **10 mg – 5 mg** — 10% permits a *smaller* step than community practice actually uses (at 9 mg,
    10% is 0.9 mg so the rule returns 0.5 mg while the community steps 1 mg).
  - **below 5 mg** — 10% permits *no achievable step at all*, and the fallback above is what makes a
    suggestion exist.

  **Clamping, always, in this order:** the returned `suggested` never exceeds `currentDose - targetDose`
  and never exceeds `currentDose` (`SPEC.md` §7 — "step size larger than the remaining gap clamps to
  the target", and a step is never generated to a negative dose). If `currentDose == targetDose` the
  taper is complete: return `Result.ok` with `suggested == Milligrams.zero` and a dartdoc'd note that
  the caller renders "target reached" rather than a next step, and `startNextStep` refuses. If
  `strengths` is empty, `NoStrengthsHeld`. If `targetDose > currentDose`, `TargetAboveStart`.

  **`SPEC.md` §4.4's worked example is wrong under this rule and is corrected here** (`CONTRACTS.md`
  §6): with `[5, 1]` + halves at 9 mg the function returns `suggested: 0.5mg`, `tenPercent: 0.9mg`,
  `communityPracticeDiffers: true`, so the preview reads **`9mg → 8.5mg, suggested step 0.5mg`** with
  the banner shown — not `9mg → 8mg`. The user can override to 1 mg; `SPEC.md` §3.2 says the suggestion
  is a default, never a lock, and the step actually used comes from the `Step` record. **EPIC-11's task
  4 preview and its acceptance rows must be updated to these figures.**

  `nextDose(from, step, target) = max(from - step, target)` lives here too and is what EPIC-05's
  `savePlan`, `startNextStep` and `recordFlare` call.
- **Acceptance** — Table test with strengths `[5, 1]` + halves, target 0, asserting `suggested`,
  `tenPercent` **and** `communityPracticeDiffers` on every row:

  | current | tenPercent | suggested | differs | why |
  |---|---|---|---|---|
  | 10 mg | 1.0 | **1.0** | **false** | 10% is exactly achievable — assert the banner is **absent** |
  | 9 mg | 0.9 | **0.5** | **true** | largest achievable ≤ 0.9 |
  | 7.5 mg | 0.75 | **0.5** | **true** | largest achievable ≤ 0.75 |
  | 5 mg | 0.5 | **0.5** | **false** | exactly achievable — assert the banner is **absent** |
  | 4 mg | 0.4 | **0.5** | **true** | fallback: nothing ≤ 0.4 is achievable |
  | 2 mg | 0.2 | **0.5** | **true** | fallback |
  | 1 mg | 0.1 | **0.5** | **true** | fallback |
  | 0.5 mg | 0.05 | **0.5** | **true** | fallback, and clamped to the 0.5 mg gap to target |

  Plus: strengths `[5, 1]` with `allowHalves: false` — the floor is 1 mg, so 4 mg / 2 mg / 1 mg all
  return `suggested: 1.0, differs: true` and 0.5 mg (gap 0.5) clamps to `0.5`. Plus: a step larger than
  the gap to target clamps to the target exactly. Plus: `currentDose == targetDose` returns zero with
  no suggestion.

### 6. `DayPlan` and the generator

- **What** — The pure function at the centre of the app.
- **Where** — `lib/core/dsns/day_plan.dart`, `lib/core/dsns/schedule_generator.dart`.
- **Tests first (TDD)** — `test/core/dsns/schedule_generator_test.dart` and
  `test/core/dsns/step_status_test.dart`, pure `package:test`, with `withClock(Clock.fixed(t), …)`
  wherever a "today" is needed (never `DateTime.now()`). Fixture unless stated: plan 2026-04-01,
  10 mg → target 0, `[5,1]`, halves on, DSNS, one step 10 → 9.
  Write and watch fail, in this order:
  1. `until: null` yields 52 `DayPlan`s. `days[0]` = 2026-04-01, `dose 9mg`, `doseKind newDose`,
     `kind step`, `blockIndex 1`, `dayInBlock 1`, `dayInStep 1`, `isHoldDay false`;
     `days[1..6]` are 10 mg `oldDose`; `days[7]` is 9 mg `newDose` opening block 2 — the single day
     **leads**.
  2. `two_consecutive_old_days_at_the_crossover` — `dayInStep 27` (block 6's last day) and
     `dayInStep 28` (block 7's first day) are both 10 mg `oldDose`.
  3. 26 `newDose` and 26 `oldDose` days; block lengths in emission order are
     `7,6,5,4,3,2,3,4,5,6,7`; dates are contiguous with no gap and no repeat.
  4. holds: `HoldEvent(stepId, fromDate: 2026-04-10, extraDays: 3)` inserts three days immediately
     after 04-10 repeating its `dose`, `blockIndex`, `dayInBlock` and `dayInStep` with
     `isHoldDay true`; the step spans 55 days; `dayInStep` still reaches exactly 52 counting
     non-hold days only; the day that was 2026-04-11 is now 2026-04-14.
  5. truncation by flare: a flare on `dayInStep 20` inserts a step whose `startDate` is the flare
     date, so the running step contributes exactly 19 days, and every day before the flare is
     **identical field for field** to the pre-flare generation.
  6. `abandoned_steps_still_generate_their_lived_days` — the truncated step from case 5 with
     `status: abandoned` still emits its 19 days; cycling `status` through `pending`, `active`,
     `completed` and `abandoned` changes nothing in the output.
  7. steady state between steps: a step realised through 2026-05-22 with no successor and
     `until: 2026-06-30` emits `kind: steadyState` for 05-23…06-30 at that step's `toDose`, with
     `doseKind newDose`, `blockIndex`/`dayInBlock`/`dayInStep` all `null`, `isHoldDay false`, and
     `stepIndex` = the step it follows.
  8. after the final step: a plan that has reached `targetDose` emits `steadyState` at the target
     for every day up to `until` — never an empty list, which is the state `SPEC.md` §7's "target
     reached" has to render.
  9. `until` semantics and guards: `until: null` stops at the last step's end (the golden vector's
     contract); `until` before `plan.startDate` → `Err(PlanNotStarted(startDate))`;
     `targetDose > startingDose` → `Err(TargetAboveStart)`.
  10. `percentage`: `percentage: 10` on a 20 mg `fromDose` with `[5,1]` + halves gives a 2 mg step
      rounded down to an achievable increment; every day of the hold period is that step's
      `toDose`, `doseKind newDose`, `blockIndex == null`, `dayInStep` running 1…52. A plan with
      `method: percentage, percentage: null` → `Err(MissingMethodParameter(TaperMethod.percentage))`
      — not a throw, and above all not a silent DSNS schedule.
  11. `fixedMg`: same shape with `fixedStep: 1mg`; `fixedStep: null` →
      `Err(MissingMethodParameter(TaperMethod.fixedMg))`.
  12. determinism: two calls with identical inputs compare equal element for element.
  13. `stepStatusFor`, clock pinned per case: a step starting 2026-04-01 with no holds is `pending`
      on 03-31, `active` on 04-01 and 05-22, `completed` on 05-23 (`startDate + 52`); with a 3-day
      hold it is `active` on 05-25 and `completed` on 05-26; a step whose `StepFacts.status` is
      already `abandoned` reports `abandoned` on every one of those dates.
- **Details** —
  ```dart
  enum DayKind { step, steadyState }

  final class DayPlan {
    const DayPlan({
      required this.date, required this.stepIndex, required this.kind,
      required this.blockIndex, required this.dayInBlock, required this.dayInStep,
      required this.dose, required this.doseKind, required this.composition,
      required this.isHoldDay,
    });
    final LocalDate date;
    final int stepIndex;      // 0-based index into the plan's steps
    final DayKind kind;       // step | steadyState — see the steady-state rule below
    final int? blockIndex;    // 1..11 on DSNS step days; NULL on steady-state days and on
                              // percentage/fixedMg days, which have no blocks
    final int? dayInBlock;    // 1-based on DSNS step days; NULL otherwise
    final int? dayInStep;     // 1..52 on step days, EXCLUDING hold days (hold days repeat the
                              // host day's value); NULL on steady-state days
    final Milligrams dose;
    final DoseKind doseKind;  // enum { newDose, oldDose }
    final Result<TabletComposition, DomainFailure> composition;
    final bool isHoldDay;
    /// A day is routinely BOTH `today` and a new-dose day, so this is a flag, never a
    /// `DayState` member (CONTRACTS.md §1). Presentation reads it for the `stateNewDose` slot.
    bool get isNewDose => doseKind == DoseKind.newDose;
  }
  ```
  Signature, exactly as `SPEC.md` §6 states it:
  ```dart
  Result<List<DayPlan>, DomainFailure> generateSchedule({
    required TaperPlanFacts plan,
    required List<StepFacts> steps,
    required List<FlareEvent> flares,
    required List<HoldEvent> holds,
    LocalDate? until,   // optional right bound; see the `until` rule below
  });
  ```
  `TaperPlanFacts`, `StepFacts`, `FlareEvent`, `HoldEvent` and **`enum TaperMethod { dsns, percentage,
  fixedMg }`** are **plain domain records and enums defined here** (`lib/core/dsns/facts.dart`),
  mirroring `SPEC.md` §6 field for field. EPIC-05 maps drift rows onto them and its
  `TaperMethodConverter` maps *this* enum; the domain never sees a drift class, and the data layer
  never declares a domain type (`CONTRACTS.md` §8). `TaperPlanFacts` carries `method`, the nullable
  `percentage`, and a nullable `fixedStep` for the two non-DSNS methods.

  Rules:
  - Steps are processed in `startDate` order. A step lays down its shape from `plan.method` (see
    "All three methods generate" below); for `dsns` that is `pattern.blocks` in order, and within a
    block the single day leads (task 2). `dayInStep` runs 1…52 over non-hold days.
  - **The generator ignores `StepFacts.status` entirely.** Truncation is derived from `startDate`
    ordering alone; an `abandoned` step still contributes every day it actually spanned, because those
    days *were lived* and the Schedule's past rows and the Progress staircase are built from them.
    `status` exists for the UI and for `startNextStep`, never for generation. A test named
    `abandoned_steps_still_generate_their_lived_days` pins this, and the flare property test's fixture
    sets `status: abandoned` on the truncated step so the "days before the flare are unchanged"
    assertion is actually testing the abandoned path.
  - **A step's realised length is `min(52 + Σ holdExtraDays, days until the next step's startDate)`.**
    This one rule makes flare rollback non-destructive: a flare inserts a new step starting on the
    flare date, which truncates the running step at that date. Nothing is deleted, nothing is
    rewritten, and days before the flare regenerate byte for byte because their inputs did not change.
  - **Steady-state days — every date in range gets a `DayPlan`, with no holes.**
    > **Contract:** `CONTRACTS.md` §5. This is a blocker fix, not a refinement.

    `SPEC.md` §3.1 ends a step with *"Then the new dose every day, and that dose becomes the 'old' dose
    of the next step."* Those days were missing from the model entirely, so **every date after a step's
    realised length and before the next step's `startDate` had no `DayPlan` — and so did every date
    after the final step**. Steps are user-initiated (`SPEC.md` §4.4 "start-next-step action when a step
    completes"): a patient who finishes day 52 on a Friday and taps *Start next step* on Monday has
    three days the app cannot render, and after the taper reaches target the hole never closes.

    So `generateSchedule` emits, for **every date in range**:
    - **Step days** — `kind: DayKind.step`, `blockIndex: 1..11`, `dayInStep: 1..52 + holds`.
    - **Steady-state days** — after a step's realised length and before the next step's `startDate`:
      `kind: DayKind.steadyState`, `blockIndex: null`, `dayInBlock: null`, `dayInStep: null`,
      `isHoldDay: false`, `dose` = that step's `toDose`, `doseKind: DoseKind.newDose` (it *is* the new
      dose — that is the sentence this implements), `stepIndex` = the step it follows.
    - **After the final step** — steady-state at that step's `toDose`, indefinitely. When the plan has
      reached `targetDose` this is what makes `SPEC.md` §7's "target reached — the taper ends cleanly"
      renderable instead of an empty list.

    `until` is redefined accordingly, and the dartdoc says so: `until` is the **right bound of
    generation**, and `null` means *the end of the last step* (backwards-compatible for the golden
    vector). Callers that need days beyond the last step — which is every caller that renders Today —
    pass an explicit `until`; EPIC-06's `derivedScheduleProvider` passes `max(lastStepEnd, today) +
    60 days` so the Today and Schedule screens always have a day to draw.
  - **All three methods generate — no dead segments.**
    > **Contract:** `CONTRACTS.md` §8. `TaperMethod` is a stored column and the Plan screen offers all
    > three, so this epic implements all three rather than shipping two segments that silently produce
    > a DSNS schedule the patient did not choose.

    `generateSchedule` switches exhaustively on `plan.method`:
    - **`dsns`** — the eleven-block, 52-day alternating calendar above. Unchanged.
    - **`percentage`** — step size = `plan.percentage`% of the step's `fromDose`, rounded **down** to
      the largest achievable increment (task 4's `isAchievable`), then the new dose **every day** for
      the hold period. `MissingMethodParameter(percentage)` if `plan.percentage` is null.
    - **`fixedMg`** — step size = `plan.fixedStep`, then the new dose **every day** for the hold
      period. `MissingMethodParameter(fixedMg)` if `plan.fixedStep` is null.

    Percentage and Fixed differ **only** in how the step *size* is computed; both produce the simple
    "new dose every day" shape, so they share one code path that takes a step size. Their days are
    `kind: DayKind.step` with `blockIndex: null`, `dayInStep: 1..holdPeriod`, `doseKind: newDose`
    throughout; the hold period defaults to 52 days so the "day N of 52" context line and the
    step-completion rule are uniform across methods. Steady-state and truncation apply identically.
  - `HoldEvent(stepId, fromDate, extraDays)` inserts `extraDays` days immediately after `fromDate`
    that repeat `fromDate`'s dose, `blockIndex`, `dayInBlock` and `dayInStep`, with `isHoldDay: true`,
    and shifts the rest of the step forward by `extraDays` (`SPEC.md` §5.2 — hold does not abandon
    the step, and v1 does **not** repeat blocks; that is v2 item 4).
  - `FlareEvent(date, revertToDose)`: the flare's step has `fromDose == revertToDose` and
    `startDate == flare.date`. The generator does not invent it — EPIC-05's repository appends both
    the `FlareEvent` and the new `Step` row in one transaction. The generator's only job is to honour
    the truncation rule above.
  - Composition is computed per day from the **plan's current strengths**. Consequence, and it is the
    right one per `SPEC.md` §5.2: changing strengths mid-taper recomposes all days, past included, in
    the *derived* view — but past `DoseLog.actualMg` rows are facts and are never touched, so the
    Schedule's past rows render from the log, not from a recomputed composition. Presentation epics
    must join, not overwrite. Say it in the dartdoc.
  - Guards: `PlanNotStarted` if `until` precedes `plan.startDate`; `TargetAboveStart` if
    `targetDose > startingDose`.
  - The generator is **O(days)** and allocation-conscious: compositions are memoised per distinct dose
    inside one call (a step has at most two distinct doses, so this is a two-entry map).
  - **`stepStatusFor(StepFacts step, List<HoldEvent> holdsForStep, LocalDate today) → StepStatus`** —
    a pure function in the same file, because nothing else in the plan computes step completion and
    EPIC-11's *Start next step* is otherwise permanently disabled. **One rule, chosen and written
    down:** a step is `completed` when `today >= step.startDate.addDays(52 + Σ extraDays)`; `active`
    when `today >= startDate` and not yet completed; `pending` when `today < startDate`. A step whose
    `StepFacts.status` is already `abandoned` (a flare truncated it) reports `abandoned` unchanged —
    that one *is* read from the fact, because abandonment is an event, not a date computation.
    EPIC-05 exposes this through the snapshot rather than persisting a derived status, and EPIC-11
    task 5 gates its button on this single function instead of on its own parenthetical two-rule
    definition. Non-DSNS methods use their hold period in place of 52.
- **Acceptance** — Calling `generateSchedule` twice with identical inputs returns lists that compare
  equal element for element. **Coverage property: generating over `until = lastStep.startDate + 200
  days` yields exactly one `DayPlan` for every date in `[plan.startDate, until]` — no gaps, no
  duplicates** (this is the steady-state blocker's regression test; see task 10). No `DateTime.now()`,
  no `Future`, no `import 'package:flutter/...'` anywhere in `lib/core/dsns/`. A `percentage` plan and a
  `fixedMg` plan each generate their own shape and never fall through to DSNS; a `percentage` plan with
  a null percentage returns `MissingMethodParameter`, not a crash.

### 7. Cumulative load and adherence

- **What** — The arithmetic behind the Progress screen (`SPEC.md` §4.3).
- **Where** — `lib/core/dsns/cumulative.dart`.
- **Tests first (TDD)** — `test/core/dsns/cumulative_test.dart`, pure `package:test`, `withClock`
  for every "today". Write and watch fail, in this order:
  1. `cumulativeTakenMg([10mg taken, 9mg taken, 9mg not taken]) == 19mg`; an empty list and an
     all-untaken list both return `Milligrams.zero`. Assert in hundredths.
  2. `plannedCumulativeMg` over the golden step's 52 days == `26 × 9mg + 26 × 10mg == 494mg`,
     hand-computed in the test rather than read back from the function.
  3. `daysOnSteroids(2026-04-01, 2026-04-01) == 1` (inclusive, not 0);
     `(2026-04-01, 2026-04-30) == 30`; `(2028-02-27, 2028-03-01) == 4` across the leap day.
  4. `adherence_never_counts_a_day_that_has_not_happened` — 780 `DayPlan`s, 341 taken logs, `today`
     pinned to day 350: `Adherence(takenCount: 341, plannedCount: 350)`, **not** 780. Move the
     clock back one day and `plannedCount` is 349. Assert the return carries no streak, no
     percentage and no "days missed" field.
  5. `a_flare_preserves_the_cumulative_total` — reuse task 6 case 5's day-30 flare fixture and
     assert `cumulativeTakenMg` is identical before and after the flare is appended, because a
     flare only appends facts and never edits a `DoseLog`.
  6. conservation invariant (`testing-strategy` rule 8): over a seeded fuzz of 200 generated
     schedules, `plannedCumulativeMg(days)` equals the sum of the per-day doses in hundredths —
     parts sum to the whole — with the same equality mirrored as a runtime `assert` inside the
     function itself.
- **Details** — `cumulativeTakenMg(List<DoseLogFacts>) → Milligrams` sums `actualMg` where
  `taken == true`. `plannedCumulativeMg(List<DayPlan>)`. `daysOnSteroids(LocalDate start, LocalDate
  today) → int` = `today.difference(start) + 1`, inclusive, calendar days.
  `adherence(logs, dayPlans, LocalDate today) → Adherence(takenCount, plannedCount)` phrased for the
  gentle copy *"taken 341 of 350 days"* — **`plannedCount` counts only `DayPlan`s with `date <= today`**,
  because an unqualified count includes the future and reads "taken 341 of 780 days" on day 350 of a
  two-year taper. The domain returns two integers and **never a streak, a percentage-as-judgement or a
  "days missed" headline** (`SPEC.md` §4.3). A flare preserves the cumulative total because it only
  appends facts — add a test named for that sentence.
  **These three functions are the single source of the Progress screen's numbers.** EPIC-10 task 3
  calls them and keeps only the localized *formatting* in its `_project`; it must not re-derive the
  arithmetic in the presentation layer, where the purity gate does not reach and where it would drift
  from the CSV/PDF export (EPIC-13).
- **Acceptance** — A fixture spanning a flare at day 30 has a cumulative total exactly equal to the
  sum of its logs, before and after the flare is applied. A test named
  `adherence_never_counts_a_day_that_has_not_happened`.

### 8. Purity gate

- **What** — A test that fails if the domain ever grows a framework dependency.
- **Where** — `test/core/no_flutter_imports_test.dart`.
- **Tests first (TDD)** — the deliverable *is* a test, so what gets written first is its **self-test**:
  plant fixture files under a temp root in `setUp` (`addTearDown` removes it) and assert the walker's
  report. Pure `package:test` + `dart:io`. Write and watch fail, in this order:
  1. one planted violation per banned pattern — `package:flutter/material.dart`,
     `package:flutter_riverpod/flutter_riverpod.dart`, `package:hooks_riverpod/hooks_riverpod.dart`,
     `package:riverpod/riverpod.dart`, `package:drift/drift.dart`,
     `package:flutter_test/flutter_test.dart`, `dart:ui` — each in its own fixture file, each
     asserted to be reported **with file path and line number**. Seven cases; the bare
     `package:riverpod` one is the hole the four-pattern draft left open, so write it first.
  2. accumulation: three violations across three files produce **one** failure listing all three,
     not a throw on the first.
  3. the encoded exception: `package:timezone/timezone.dart` under
     `lib/core/notifications/foo.dart` is **not** reported; the identical import under
     `lib/core/dsns/foo.dart` **is**.
  4. near-misses that must stay green — the walker matches import directives, not substrings:
     `package:flutter_lints` named in a `//` comment, the literal string
     `'package:flutter/material.dart'` inside a Dart string, and a clean file whose *path* contains
     `drift`.
  5. the live gate: running the walker over the real `lib/core/` reports zero violations.
- **Details** — Walk `lib/core/` with `dart:io`, read each `.dart`, accumulate every violation and
  fail once with all of them, naming file and line.
  > **Contract:** the banned list is `CONTRACTS.md` §2, and it is broader than the draft's four
  > patterns because the draft had a hole exactly the shape of the dependency it was pointed at:
  > `package:riverpod` is **not** a substring of `package:flutter_riverpod`, so a `flutter_riverpod`
  > import under `lib/core/` passed the gate green.

  Banned under `lib/core/**`: `package:flutter/`, `package:flutter_riverpod`, `package:hooks_riverpod`,
  `package:riverpod`, `package:drift`, `package:flutter_test`, `dart:ui`.
  **One exception, and it is deliberate:** `lib/core/notifications/**` may import `package:timezone`
  (EPIC-12), because a scheduling core without `TZDateTime` cannot express "08:00 local on this date".
  The exception is **encoded in the gate** — an allowlist of one path prefix for one package — rather
  than left for EPIC-12 to discover as a red build and weaken on the spot.
  The gate covers **all** of `lib/core/`, which is only safe because `clockProvider` now lives in
  `lib/providers.dart` (`CONTRACTS.md` §1) and `DayState` (task 1) is a plain enum. Cheap, fast, and it
  is the only thing standing between "pure by design" and "pure until someone needed `debugPrint`".
- **Acceptance** — A **self-test** plants each banned import in a temp file under a fixture root and
  asserts the walker reports it, and plants `package:timezone` under `lib/core/notifications/` and
  under `lib/core/dsns/` and asserts the first passes and the second fails. Adding
  `import 'package:flutter/material.dart';` to any file under `lib/core/` turns CI red with a message
  naming the file and line.

### 9. Golden vectors

- **What** — A committed, human-readable dump of a full step, asserted byte for byte.
- **Where** — `test/core/dsns/golden/step_10mg_to_9mg.json`, `test/core/dsns/golden_vector_test.dart`.
- **Tests first (TDD), in its strong form** — the committed JSON is **hand-derived from `SPEC.md`
  §3.1 before the generator runs**, never dumped from the implementation: a golden captured from the
  code under test only pins whatever that code happened to do. `test/core/dsns/golden_vector_test.dart`,
  pure `package:test`. Write and watch fail, in this order:
  1. the 52 hand-written rows deserialise, and `generateSchedule` over the fixture (plan 2026-04-01,
     10 → 9 mg, target 0, `[5,1]`, halves, DSNS, one step, `until: null`) equals them element for
     element — compared on the serialised map so a failure prints the offending row, not "lists
     differ".
  2. row 1 is `{date: 2026-04-01, kind: step, block: 1, dayInBlock: 1, dayInStep: 1, mg: 9,
     doseKind: newDose, tablets: [[1, 5mg], [4, 1mg]]}`; rows 2–7 are 10 mg `oldDose` with
     `tablets: [[2, 5mg]]`; the file holds exactly 26 `newDose` and 26 `oldDose` rows.
  3. `kind` and `doseKind` are separate keys on every row — a row is `kind: step` **and**
     `doseKind: oldDose` — so no future refactor can collapse the two axes into one.
  4. serialisation stability: re-serialising the generated list reproduces the committed bytes
     exactly — stable key order, two-space indent, trailing newline. This is what makes an
     unexplained diff in a PR reviewable at all.
  `tool/regen_golden_vectors.dart` exists for *intentional* changes only; it is never how this file
  is first created.
- **Details** — Per `seeded-determinism-and-golden-vectors`: fixture = plan starting 2026-04-01 at
  10 mg, target 0, strengths `[5, 1]`, halves allowed, DSNS method, one step 10 → 9. Serialise the 52
  `DayPlan`s as a JSON array of `{date, kind, block, dayInBlock, dayInStep, mg, doseKind, tablets}`
  — `kind` is `step`/`steadyState` and `doseKind` is `newDose`/`oldDose`; they are different axes and
  the golden file must show both, with stable
  key order and two-space indent, and assert equality against the committed file. Regenerate only via
  `dart run tool/regen_golden_vectors.dart`, and **a diff to this file in a PR must be explained in
  the PR body** — an unexplained change to it means the schedule a patient lives has changed.
- **Acceptance** — The JSON's first row is 2026-04-01 at 9 mg (`newDose`, block 1, day 1 — the single
  day leads), rows 2–7 are 10 mg, and the file's 52 rows contain exactly 26 of each kind.

### 10. Property tests

- **What** — The invariants from `SPEC.md` §10, proven across the whole input space we care about.
- **Where** — `test/core/dsns/schedule_properties_test.dart`.
- **Tests first (TDD) — and these are tests task 6 is written *against*.** The file is numbered
  separately for organisation, but it belongs in task 6's **red** step, not after its green.
  Pure `package:test`, `Random(20260421)` pinned and echoed in every `reason:`.
  Write and watch fail, in this order:
  1. 1,000 iterations over dose pairs from 0.5–60 mg, random strength subsets of
     `{0.5,1,2,2.5,5,10,20,25}` and random `allowHalves`: exactly 52 non-hold days; exactly 26 old
     and 26 new; block lengths `7,6,5,4,3,2,3,4,5,6,7`; the single day leads every block; blocks
     6→7 give two consecutive old days; dates contiguous with no gaps or repeats; generating twice
     is identical.
  2. flare determinism: for `flareDay in 1..52`, apply a flare that day, regenerate 50 times, assert
     all 50 runs identical **and** every day before the flare date unchanged from the pre-flare
     generation. The truncated step's fixture sets `status: abandoned`, so this exercises the
     ignore-`status` rule instead of passing vacuously.
  3. **the coverage property — the regression test for the steady-state blocker**
     (`CONTRACTS.md` §5): with `until = lastStep.startDate.addDays(200)`, every date in
     `[plan.startDate, until]` has **exactly one** `DayPlan`. The oracle is an independent date walk
     built from `LocalDate.addDays` in the test, compared as a multiset against the emitted dates so
     a gap *and* a duplicate each fail naming the offending date. Three fixtures: (a) the last step
     still running, (b) the last step ended 40 days ago with no successor — the "finished Friday,
     tapped Monday" case, (c) target reached, where every day past the end is `steadyState` at
     `targetDose`.
  4. one loop each for `percentage` and `fixedMg`: dates contiguous; dose descends monotonically and
     clamps at `targetDose`, never below it and never negative; every day is `doseKind: newDose`;
     no day carries a `blockIndex`.
- **Details** — Seeded `Random(20260421)` (pinned, printed on failure). 1,000 iterations over dose
  pairs drawn from 0.5–60 mg with random strength sets from `{0.5, 1, 2, 2.5, 5, 10, 20, 25}` and a
  random `allowHalves`. For each:
  - the step is exactly **52 days** (excluding hold days),
  - exactly **26 old** and **26 new** dose days,
  - block lengths match `7,6,5,4,3,2,3,4,5,6,7`,
  - the single day leads every block, and blocks 6→7 produce two consecutive old days,
  - dates are contiguous with no gaps and no repeats,
  - regeneration is identical (generate twice, compare).
  Plus a dedicated loop: for `flareDay in 1..52`, apply a flare on that day, regenerate 50 times, and
  assert every run is identical **and** that days before the flare date are unchanged from the
  pre-flare generation. **The truncated step's fixture sets `status: abandoned`**, so the assertion
  exercises the "generator ignores `status`" rule rather than passing vacuously.
  Plus the **coverage property, which is the regression test for the steady-state blocker**
  (`CONTRACTS.md` §5): generate with `until = lastStep.startDate.addDays(200)` and assert **every date
  in `[plan.startDate, until]` has exactly one `DayPlan`** — no gaps and no duplicates — across three
  fixtures: a plan whose last step is still running, a plan whose last step ended 40 days ago with no
  successor (the "finished Friday, tapped Monday" case), and a plan that has reached target (every day
  past the end is `steadyState` at `targetDose`).
  Plus one loop each for `percentage` and `fixedMg`: dates contiguous, dose descends monotonically to
  the target and clamps there, every day is `doseKind: newDose`, and no day carries a `blockIndex`.
- **Acceptance** — The suite runs in under 5 s in CI's fast lane and reports the seed on failure.

## Definition of done

- [ ] Every TDD task's tests were written first and observed failing before its implementation
- [ ] `lib/core/units/`, `lib/core/time/`, `lib/core/dsns/`, `lib/core/day_state.dart` exist; the purity gate covers all seven banned packages of `CONTRACTS.md` §2 with the one encoded `package:timezone` exception, and its self-test proves it catches each
- [ ] `Milligrams`, `LocalDate`, `DayState` and `TaperMethod` are declared here and nowhere else; no `CalendarDate`, no `DoseMg`, no `lib/core/dose.dart`
- [ ] `DsnsPattern.v1()` reproduces `SPEC.md` §3.1 including the cumulative column
- [ ] Doses are integer hundredths end to end; no `double` in any dose path
- [ ] `TabletComposer` never rounds; it minimises **total tablets first, then splits**, proven by the `[2.5, 1] → 4mg` test; unachievable doses return `UnachievableDose` with the data to explain it
- [ ] `suggestStep` returns the suggestion **and** the strict-10% value **and** the divergence flag, **has an answer at every dose below 5 mg** via the smallest-achievable-increment fallback, and clamps to `current - target`
- [ ] `generateSchedule` is pure, synchronous, returns `Result`, and **emits exactly one `DayPlan` for every date in range** — step days, steady-state days between steps, and steady-state at target after the last step
- [ ] All three `TaperMethod` arms generate; the Plan screen has no dead segment and no method silently produces a DSNS schedule
- [ ] `stepStatusFor` is the single definition of step completion; EPIC-05 exposes it and EPIC-11 gates *Start next step* on it
- [ ] Golden vector committed; property tests cover 52 days, 26/26, flare determinism, the 200-day no-gaps coverage property, and the two non-DSNS methods
- [ ] Public API fully dartdoc'd, block table reproduced in `DsnsPattern`'s doc
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
