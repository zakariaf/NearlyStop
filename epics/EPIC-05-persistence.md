# EPIC-05 — Persistence & repositories

**Branch:** `epic/05-persistence`
**Depends on:** EPIC-01 (project, CI, `Result`/`Failure`, `clockProvider` in `lib/providers.dart`),
EPIC-04 (the domain facts records, value objects and `TaperMethod` this layer maps onto).

> **Contract:** `CONTRACTS.md` §3 — this epic ships **one** `TaperRepository` at
> `lib/data/taper_repository.dart`, and task 6 below is now the **full** API the screen epics call.
> `PlanRepository` and `StepRepository` do not exist; EPIC-11 must delete those names. Settings live
> behind a separate `settingsRepositoryProvider`, also shipped here.

## Where we are now

EPIC-04 landed a pure domain in `lib/core/`: `Milligrams` (integer hundredths), `LocalDate`,
`DayState`, `TaperMethod`, `DsnsPattern`, `TabletComposer`, `suggestStep`/`nextDose`, `stepStatusFor`,
`generateSchedule`, and the fact records `TaperPlanFacts`, `StepFacts`, `DoseLogFacts`, `FlareEvent`,
`HoldEvent` that the generator consumes. Nothing is stored. Kill the app and everything is gone; there
is no `pubspec` entry for drift, no database file, no repository, and `lib/data/` is empty apart from
EPIC-01's placeholder barrel.

## Why this epic exists

`SPEC.md` §2 puts "data must survive app updates" in the non-negotiables table with the plainest
possible justification: *these plans run for years, losing them is the worst possible bug.* A person
using this app is 400 days into a 780-day taper with no account, no server and no cloud backup. The
database on their phone is the only copy that exists until EPIC-13 gives them an export. That raises
the bar on the schema and on migrations far above the usual "we'll figure it out at v1.1".

It also has to hold the architectural line from `SPEC.md` §6: **persist facts only.** The temptation
here is real — a 780-day schedule is 780 rows, so why not store them and skip the generator? Because
then a flare has to rewrite history, an edit has to reconcile, and the two-year-old rows are a second
source of truth that can disagree with the first. `DayPlan` is never a table. What goes in the
database is what the patient and the doctor decided, plus what actually happened.

And the date handling is a correctness issue, not a style one (`SPEC.md` §7). A dose belongs to a
*calendar date*, not an instant. Store `2026-04-16` as a timestamp and a user who flies from London to
Sydney, or who crosses a DST boundary, gets their doses shifted by a day. Stored as a date string, the
schedule is invariant under travel and under clock changes, which is what the spec demands.

## What we will have when it is done

A drift database at **schema version 1** holding the six `SPEC.md` §6 entities — each with a stable
`uid` so an export/import round trip keeps its identity — a DAO layer, and one `TaperRepository` that
exposes a watched stream of everything the generator needs, re-emitting on every write, with typed
`Result` arms on every mutation and **the complete set of methods the five screen epics actually
call**. Kill the app mid-taper, reopen, and nothing is lost. Plus a migration harness whose ladder is
**exercised against a generated v2 fixture** before it is ever needed for real, without shipping a dead
column to get there.

## Skills to load

| Skill | What it governs here |
|---|---|
| `persistence-drift` | Table definitions, DAOs, `TypeConverter`s, transactions, stream queries, `beforeOpen` pragmas |
| `run-codegen` | The `build_runner` invocation and when to re-run it; generated files committed or not, consistently with EPIC-01 |
| `run-migration` | `drift_dev schema dump` / `generate steps`, the committed schema JSON, `SchemaVerifier` |
| `error-handling-typed-results` | Mapping `SqliteException` / `DriftWrappedException` onto a sealed `StorageFailure`; no drift type escapes this layer |
| `service-boundary-and-native` | `path_provider`, `sqlite3_flutter_libs`, and the `DatabaseLocation` seam that keeps tests off the filesystem |
| `async-safety` | `await`-across-`dispose`, stream subscription ownership, transaction scoping, no fire-and-forget writes |
| `testing-strategy` | In-memory database per test, the migration lane, what runs in CI's fast lane |
| `codegen-and-toolchain` | Pinned `drift`/`drift_dev`/`build_runner` versions, `build.yaml`, generated-code lint exclusion |
| `value-objects-money-and-units` | `Milligrams` ↔ INTEGER hundredths and `LocalDate` ↔ TEXT converters; **never** REAL for a dose |

## Tasks

### 1. Dependencies and toolchain

- **What** — Add drift and its native stack; pin versions.
- **Where** — `pubspec.yaml`, `build.yaml`, `analysis_options.yaml`, `.github/workflows/ci.yml`.
- **Details** — Runtime: `drift`, `sqlite3_flutter_libs`, `path_provider`, **`ulid`** (task 3 mints a
  `uid` on every row; `CONTRACTS.md` §11 requires it and EPIC-13's backup format assumes it exists —
  adding it at epic 13 would mean a schema migration invented in the export epic). This epic also
  confirms EPIC-01 declared **`riverpod`** itself and not only `flutter_riverpod`: task 7 imports
  `package:riverpod` directly, and `very_good_analysis`'s `depend_on_referenced_packages` makes an
  undeclared import a `--fatal-infos` failure. Dev: `drift_dev`,
  `build_runner`, `test`. `build.yaml` sets `drift_dev: { options: { store_date_time_values_as_text:
  true, named_parameters: true, sql: { dialect: sqlite, options: { modules: [] } } } }`.
  `analysis_options.yaml` excludes `**/*.g.dart` and `**/*.drift.dart` from analysis (they are already
  excluded from `very_good_analysis`'s expectations only if we say so). CI gains a step that runs
  `dart run build_runner build --delete-conflicting-outputs` and then `git diff --exit-code` — so a
  stale generated file fails the build rather than drifting silently. Generated files **are**
  committed; the alternative makes every clone need codegen before it can run tests.
- **Acceptance** — `flutter pub get && dart run build_runner build` succeeds on a clean checkout;
  CI's generated-code check is green.

### 2. Type converters

- **What** — Bridge the domain's value objects into SQLite columns without lying about precision.
- **Where** — `lib/data/db/converters.dart`.
- **Details** —
  - `MilligramsConverter extends TypeConverter<Milligrams, int>` — stores `hundredths`.
    **A dose is never a REAL column.** Floating point in a dosing database is how 9.0 becomes
    8.999999 and then renders as 8.99 on someone's phone.
  - `LocalDateConverter extends TypeConverter<LocalDate, String>` — ISO `yyyy-MM-dd`. Used for every
    *calendar* field: `TaperPlan.startDate`, `Step.startDate`, `DoseLog.date`, `FlareEvent.date`,
    `HoldEvent.fromDate`. `SPEC.md` §7: local dates, stored as dates, never timestamps.
  - Instants — `createdAt`, `takenAt`, `disclaimerAcceptedAt` — are genuinely moments in time and are
    stored as INTEGER `millisecondsSinceEpoch` **UTC**, read back with `DateTime.fromMillisecondsSinceEpoch(v, isUtc: true)`.
    Document the distinction at the top of the file in one paragraph; it is the single most likely
    place for a future contributor to do the wrong thing.
  - `StrengthListConverter extends TypeConverter<List<Milligrams>, String>` — SQLite has no list type;
    store a `,`-joined list of hundredths, sorted descending, deduplicated on write. Reject an empty
    list at the repository layer, not in the converter.
  - `TaperMethodConverter` maps **EPIC-04's** `enum TaperMethod { dsns, percentage, fixedMg }` from
    `lib/core/dsns/facts.dart`, storing `name`. **This layer does not declare the enum**
    (`CONTRACTS.md` §8): `TaperPlanFacts` names it and the generator branches on it, so a declaration
    in `lib/data/` would make the domain import the data layer and trip EPIC-04's purity gate.
    Unknown values on read throw, and the DAO turns that into `StorageFailure.corrupt` rather than
    crashing the app.
- **Acceptance** — Round-trip tests for every converter, including `0.25 mg`, a six-strength list, and
  a `LocalDate` on 29 February.

### 3. Tables

- **What** — The `SPEC.md` §6 model, as drift tables. Facts only.
- **Where** — `lib/data/db/tables.dart`.
- **Details** —
  ```
  TaperPlans     id INTEGER pk autoincrement · uid TEXT NOT NULL UNIQUE
                 drugName TEXT (default 'Prednisolone')
                 startDate TEXT(LocalDate) · startingDose INT(Milligrams) · targetDose INT(Milligrams)
                 tabletStrengths TEXT(List<Milligrams>) · allowHalves BOOL
                 method TEXT(TaperMethod) · percentage REAL? (only when method==percentage)
                 fixedStep INT? (Milligrams; only when method==fixedMg)
                 createdAt INT(utc ms)
  Steps          id pk · uid TEXT NOT NULL UNIQUE · planId → TaperPlans.id ON DELETE CASCADE
                 stepIndex INT
                 fromDose INT · toDose INT · startDate TEXT
                 status TEXT {pending,active,completed,abandoned} · patternVersion INT
                 UNIQUE(planId, stepIndex)
  DoseLogs       id pk · uid TEXT NOT NULL UNIQUE · planId → cascade
                 date TEXT · plannedMg INT · actualMg INT
                 taken BOOL · takenAt INT? · note TEXT?
                 UNIQUE(planId, date)          ← the backfill/idempotency key
  FlareEvents    id pk · uid TEXT NOT NULL UNIQUE · planId → cascade
                 date TEXT · revertToDose INT · note TEXT?
  HoldEvents     id pk · uid TEXT NOT NULL UNIQUE · stepId → Steps.id ON DELETE CASCADE
                 fromDate TEXT · extraDays INT · note TEXT?
                 CHECK(extraDays > 0)
  SettingsRows   id INT pk CHECK(id = 0)        ← single-row table
                 uid TEXT NOT NULL UNIQUE
                 reminderEnabled BOOL · reminderMinuteOfDay INT? · textScale REAL
                 highContrast BOOL · disclaimerAcceptedAt INT? · localeTag TEXT? · themeMode TEXT
  ```
  Notes that matter:
  - **`uid TEXT NOT NULL UNIQUE` on all six tables**, a ULID minted in the repository at insert.
    > **Contract:** `CONTRACTS.md` §11. EPIC-13's backup format is built on stable text ids
    > ("never rowids — re-importing with autoincrement ids duplicates everything") and no epic created
    > the column. It goes in **schema v1, now**, before the dump is taken — retrofitting stable ids onto
    > a database already holding a real user's 400-day taper is exactly the kind of migration this epic
    > exists to avoid.
  - **`stepIndex`, not `index`.** `INDEX` is a reserved SQLite keyword, and the composite unique is
    expressed as a hand-written `customConstraints` string that drift passes through verbatim, so
    `UNIQUE(plan_id, index)` is a syntax error at table creation. It maps to `StepFacts.index`. Do this
    **before** the v1 schema dump in task 8.
  - **`fixedStep`** is new: EPIC-04 generates all three `TaperMethod` arms (`CONTRACTS.md` §8), and
    `fixedMg` needs somewhere to keep its step. It is a `Milligrams` INTEGER, never a REAL.
  - **v1 holds at most one plan.** `TaperPlans` has no "active" flag and needs none: `watchActivePlan()`
    is `.watchSingleOrNull()` over `ORDER BY createdAt DESC LIMIT 1`, so zero rows (fresh install, and
    after a delete) is a well-defined `null` rather than a throw. `insertPlan` on a non-empty table
    returns `StorageFailure.Invariant` — EPIC-11's delete-then-recreate flow must delete first.
    `SPEC.md` §8 cuts multiple concurrent tapers from v1; this is that decision written into the schema
    instead of left to whichever of `getSingle()`/`getSingleOrNull()` the implementer reaches for.
  - `percentage` is the one genuine REAL in the schema and it is not a dose — it is the percentage for
    the non-DSNS method (`SPEC.md` §4.4).
  - `UNIQUE(planId, date)` on `DoseLogs` is what makes ticking idempotent and backfilling
    (`SPEC.md` §7) a plain upsert rather than a read-modify-write race.
  - `reminderTime` is stored as **minutes since local midnight**, not a `DateTime` — a reminder is a
    wall-clock time, and storing it as an instant is the same DST bug in a different hat (EPIC-12
    consumes it).
  - `textScale`/`highContrast`/`themeMode`/`localeTag` live here because they must be readable
    **before first paint** (EPIC-06, `SPEC.md` §4.5).
  - **No `DayPlan` table, no schedule cache table.** If EPIC-09 later needs a scroll cache it lives in
    memory and is rebuildable; the schema does not get to hold a second truth.
  - **v1 stores no tablet composition.** `DoseLog.actualMg` is the fact — what was swallowed — and it
    is frozen at tick time; the *breakdown* is always recomposed from the plan's current strengths.
    Consequence for EPIC-09, and it must be stated in its rows: a past taken row renders its **dose**
    from `actualMg` (never from a recomputed `DayPlan`), while its tablet breakdown is a present-tense
    recomposition. Freezing the composition would need a denormalised column; that is a v1.1 decision,
    recorded here so nobody assumes the column exists.
  - `beforeOpen`: `await customStatement('PRAGMA foreign_keys = ON');` — SQLite defaults it **off**
    per connection, so the cascades above are decorative without it.
- **Acceptance** — `schema.dart` generates; a test asserts `PRAGMA foreign_keys` returns 1 on an open
  connection, and that deleting a plan removes its steps, logs, flares and (via steps) holds. Every
  insert path mints a `uid`; a test asserts all six tables reject a duplicate `uid` and that no row can
  be written without one.

### 4. Database class, native wiring and the test seam

- **What** — `AppDatabase`, its connection, and the boundary that keeps tests off `path_provider`.
- **Where** — `lib/data/db/app_database.dart`, `lib/data/db/database_location.dart`.
- **Details** — `@DriftDatabase(tables: [...], daos: [...]) class AppDatabase extends _$AppDatabase`,
  **`schemaVersion => 1`** — the shipped schema is the task-3 tables at version 1 (`CONTRACTS.md` §11;
  the artificial v2 is gone, see task 8). Connection via `LazyDatabase(() async => NativeDatabase.createInBackground(
  await location.databaseFile()))` — background isolate so a large query cannot jank the Today screen.
  `abstract interface class DatabaseLocation { Future<File> databaseFile(); }` with
  `AppDocumentsDatabaseLocation` (uses `path_provider.getApplicationDocumentsDirectory()`, file
  `nearlystop.sqlite`) and, in tests, `AppDatabase.forTesting(NativeDatabase.memory())`. This is the
  `service-boundary-and-native` seam: no test ever needs a plugin binary.
  Add `AppDatabase.close()` wiring to `ref.onDispose` where the provider is created (task 7).
- **Acceptance** — A widget-free unit test opens an in-memory database, writes a plan and reads it
  back, with zero platform channels involved.

### 5. DAOs

- **What** — Four DAOs, each owning one aggregate's queries.
- **Where** — `lib/data/db/daos/plan_dao.dart`, `step_dao.dart`, `log_dao.dart`, `settings_dao.dart`.
- **Details** —
  - `PlanDao` — `watchActivePlan()` (`.watchSingleOrNull()`, `ORDER BY createdAt DESC LIMIT 1`; `null`
    on an empty table is the fresh-install and post-delete case and is **not** an error),
    `insertPlan(...)`, `updatePlan(...)`, `deletePlan(id)` (inside a `transaction`, cascading),
    `watchFlares(planId)`, `insertFlare(...)`.
  - `StepDao` — `watchSteps(planId)`, `insertStep(...)`, `nextStepIndex(planId)` (`max(stepIndex) + 1`,
    inside the caller's transaction — the flare and next-step paths both need it and a guess is a
    straight `UNIQUE(planId, stepIndex)` violation), `updateStatus(...)`, `watchHolds(planId)`
    (join through `Steps`), `watchHoldsForStep(stepId)`, `insertHold(...)`.
    **`updateStatus` has exactly two callers** — `recordFlare` (marks the truncated step `abandoned`)
    and `startNextStep` (marks the finished step `completed`). Every *other* read of "is this step
    done" goes through EPIC-04's pure `stepStatusFor`, exposed on the snapshot (task 6); the column is
    a record of events, not a derived cache that something has to keep fresh.
  - `LogDao` — `watchLogs(planId)`, `watchLogsBetween(planId, from, to)` (bounded query for the
    Schedule's viewport), and `upsertLog(...)` using
    `into(doseLogs).insertOnConflictUpdate(...)` against the `(planId, date)` unique index.
    `plannedMg` and `actualMg` are NOT NULL, so **every path that can create a row must supply
    `plannedMg`** — that is why the repository's `markTaken` and `setNote` take it (task 6).
  - `SettingsDao` — `watchSettings()` and `readSettingsOnce()` (the synchronous-path read for
    bootstrap), `ensureRowExists()` writing the defaults row on first open, and per-field updates.
  - Every DAO method returning a stream uses `.watch()`, never `.get()` in a polling loop. Drift's
    stream invalidation is **table-based**: a query joining `Steps` and `HoldEvents` re-emits when
    either table is written, which is precisely the behaviour the repository relies on in task 6.
    Say that in a comment, because it looks like magic otherwise.
- **Acceptance** — A test subscribes to `watchLogs`, writes a log, and receives a second emission
  without any manual invalidation.

### 6. `TaperRepository`

- **What** — The one object the rest of the app talks to. It converts rows → domain facts, exposes a
  watched snapshot, and returns typed `Result`s from every mutation.
- **Where** — `lib/data/taper_repository.dart`, `lib/data/mappers.dart`,
  `lib/data/storage_failure.dart`.
- **Details** —
  > **Contract:** the method set below is `CONTRACTS.md` §3 and it is now **complete** — the screen
  > epics were each written against a different, non-existent API (`watchToday`, `watchStep`,
  > `watchHistory`, `markDay`, `unmarkDay`, `addNote`, `PlanRepository.applyPlanEdit`,
  > `StepRepository.startNextStep`). Those names are gone. The repository returns **facts**;
  > `generateSchedule` runs once in EPIC-06's `derivedScheduleProvider` in the app layer, and the
  > per-screen projections are providers there, not repository methods (`CONTRACTS.md` §4). Nothing is
  > "cached in the repository layer".

  ```dart
  final class TaperSnapshot {                  // exactly generateSchedule's inputs, plus step status
    final TaperPlanFacts? plan;                // null on a fresh install and after deletePlan
    final List<StepFacts> steps;
    final List<DoseLogFacts> logs;
    final List<FlareEvent> flares;
    final List<HoldEvent> holds;
    /// EPIC-04's pure `stepStatusFor` applied per step at `clock.today()`. Derived, not stored;
    /// it is here so EPIC-11's "Start next step" has one definition of "completed" to gate on.
    final Map<int, StepStatus> statusByStepId;
  }
  Stream<Result<TaperSnapshot, StorageFailure>> watchSnapshot();
  ```
  Built by combining the DAO streams (`rxdart` is **not** a dependency — use a
  `StreamController` fed by a `Stream.multi`/`combineLatest` helper written locally, or drift's own
  ability to express the whole thing as one multi-table query; prefer the latter where it stays
  readable). Errors from the underlying streams are caught and mapped, never allowed to propagate as
  raw exceptions into a Riverpod provider.
  Mutations, **all** returning `Future<Result<void, StorageFailure>>`, all clock-injected, all minting
  a `uid` on every row they insert. This is the whole surface; no screen epic gets to invent more.

  ```dart
  Future<Result<void, StorageFailure>> markTaken(LocalDate date, {required Milligrams plannedMg});
  Future<Result<void, StorageFailure>> undoTaken(LocalDate date);
  Future<Result<void, StorageFailure>> setNote(LocalDate date, String? note,
                                               {required Milligrams plannedMg});
  Future<Result<void, StorageFailure>> recordFlare({required LocalDate on,
                                                   required Milligrams revertTo});
  Future<Result<void, StorageFailure>> recordHold({required int stepId, required LocalDate from,
                                                  required int extraDays});
  Future<Result<void, StorageFailure>> savePlan(TaperPlanDraft draft);
  Future<Result<void, StorageFailure>> updatePlanFacts(TaperPlanDraft draft);
  Future<Result<void, StorageFailure>> updateStrengths(List<Milligrams> strengths);
  Future<Result<void, StorageFailure>> startNextStep();
  Future<Result<void, StorageFailure>> deletePlan(int id);
  ```

  - **`markTaken(date, {plannedMg})`** — `plannedMg` is required because `DoseLogs.plannedMg` is NOT
    NULL and the upsert must be able to *create* the row; the caller has it on the `DayPlan` it is
    already rendering, which keeps the generator out of the data layer (`CONTRACTS.md` §3). `actualMg`
    is set to `plannedMg` — tapping *Taken* records taking the planned dose — and is then **frozen**,
    which is what lets EPIC-10 sum `actualMg` and EPIC-09 render a past row's dose honestly after the
    strengths change. `takenAt` uses `clock.now()`; the `date` is passed in, so **backfilling three
    days late works by construction** (`SPEC.md` §7) and no code path derives a date from
    `DateTime.now()`. (The draft's `actual` parameter is dropped in favour of the contract's signature;
    a "took a different amount" flow is not in v1.)
  - **`undoTaken(date)`** — sets `taken = false, takenAt = null` and **preserves the row and its
    note**. It is not a delete: deleting would silently destroy a note written on the same day.
  - **`setNote(date, note, {plannedMg})`** — an upsert on `(planId, date)`, so it needs `plannedMg` for
    the same NOT NULL reason. (`CONTRACTS.md` §3's prose says both `markTaken` and `setNote` need
    `plannedMg` while its signature block shows `setNote` without it; the prose is the operative half —
    without it the very first note on an un-ticked day violates the constraint.)
  - **`recordFlare({on, revertTo})`** — one transaction: insert the `FlareEvent(date: on)`, mark the
    running step `abandoned` (`StepDao.updateStatus`), and insert
    `Step(stepIndex: nextStepIndex(planId), fromDose: revertTo,
    toDose: nextDose(revertTo, suggestStep(revertTo, plan.targetDose, …).suggested, plan.targetDose),
    startDate: on, status: active, patternVersion: DsnsPattern.v1().version)`.
    **`stepIndex` is `max(existing) + 1`, never a guess** — an unspecified index here is a `UNIQUE`
    violation on the most emotionally loaded action in the app. **`startDate` is the flare date**, which
    is what triggers EPIC-04's truncation rule. **Nothing is deleted**, so cumulative history and the
    total are preserved by construction.
    *Note for EPIC-08:* `CONTRACTS.md` §3 drops the `step` argument the draft took, so the flare sheet
    chooses **`revertTo` only** (from the prior steps' doses, defaulting to the previous step's
    `fromDose`); the next step size comes from `suggestStep` and stays editable on the Plan screen.
  - **`recordHold({stepId, from, extraDays})`** — appends a `HoldEvent`. The step is **not** abandoned
    (`SPEC.md` §5.2); EPIC-04's generator extends it and shifts the remainder forward.
  - **`savePlan(TaperPlanDraft draft)`** — creates the plan **and, in the same transaction, its first
    step when the plan has none**:
    > **Contract:** `CONTRACTS.md` §7. Without this, no plan ever produces a schedule: `startNextStep`
    > needs a last step, `generateSchedule` over zero steps returns nothing, and a brand-new user's
    > Today/Schedule/Progress render empty forever. EPIC-11's task 1 acceptance changes from "appends
    > no `Step` rows" to "appends exactly **one** `Step` row when none exists, and none thereafter."
    ```
    Step(stepIndex: 0, fromDose: draft.currentDose,
         toDose: nextDose(draft.currentDose, draft.stepSize, draft.targetDose),
         startDate: draft.startDate, status: active,
         patternVersion: DsnsPattern.v1().version)
    ```
    `TaperPlanDraft` is **defined here**, in `lib/data/taper_repository.dart`: the plan's user-entered
    facts (`drugName`, `startDate`, `currentDose`, `targetDose`, `strengths`, `allowHalves`, `method`,
    `percentage?`, `fixedStep?`) plus `stepSize` — the suggested-or-overridden first step. EPIC-11's
    form builds one; it must not declare its own `PlanDraft`.
  - **`updatePlanFacts(draft)`** — `SPEC.md` §5.2's *"edit the plan mid-step"*, which had no owner
    anywhere in the plan. Updates the plan row in place, **appends no step and touches no `DoseLog`**;
    future days recompose on the next snapshot emission because the generator is pure.
  - **`updateStrengths(List<Milligrams>)`** — plan-level; **past `DoseLog` rows are untouched**
    (`SPEC.md` §5.2: future days recompose, past logs stay as recorded). Rejects an empty list with
    `Invariant`.
  - **`startNextStep()`** — one transaction: mark the finished step `completed`, then insert
    `Step(stepIndex: last.stepIndex + 1, fromDose: last.toDose,
    toDose: nextDose(last.toDose, suggestStep(last.toDose, plan.targetDose, …).suggested,
    plan.targetDose), startDate: last.startDate.addDays(52 + Σ extraDays for last), status: active)`.
    **The start date is the day the previous step actually ends, not the day the user tapped.** This is
    the one field that decides whether the steady-state gap and a swallowed hold ever happen: taking
    `clock.today()` opens a gap when the user taps three days late, and hard-coding
    `lastStart + 52` eats a hold's extra days when they tap early, which would make Hold do nothing —
    the exact thing `SPEC.md` §5.2 forbids. A computed start in the past is **correct**: its early days
    are immediately backfillable through the `(planId, date)` upsert. Refuses with
    `StorageFailure.Invariant` if `stepStatusFor(last) != completed` or the target is already reached.
  - **`deletePlan(id)`** — the repository does not prompt; EPIC-11's UI owns the confirm and the
    export-first flow (`SPEC.md` §5.3, §7).

  **Settings** live behind a **separate** provider, `settingsRepositoryProvider` (`CONTRACTS.md` §3),
  whose value type is `SettingsRepository` in `lib/data/settings_repository.dart`: `watchSettings()`,
  `readSettingsOnce()` (the pre-first-paint read) and one `Result`-returning setter per field.
  `CONTRACTS.md` §3 deletes `PlanRepository` and `StepRepository` outright — plans and steps are reached
  only through `TaperRepository` — and its ban on the name `SettingsRepository` targets EPIC-11's
  invented four-repository split; the same section mandates one separate settings surface, so EPIC-05
  ships exactly this one and EPIC-11 consumes it instead of declaring another.

  `sealed class StorageFailure implements Failure` = `NotFound`, `ConstraintViolation(String detail)`,
  `Corrupt(String detail)`, `Io(Object cause)`, `Invariant(String detail)`. Map from drift:
  `SqliteException` with `extendedResultCode` in the 1555/2067 family → `ConstraintViolation`;
  `DriftWrappedException` wrapping a `FormatException` from a converter → `Corrupt`.
  **No drift type — `Insertable`, `Value`, a generated row class — appears in this file's public
  signature.** The domain and the UI never learn that drift exists.
- **Acceptance** — Every public method returns `Result`; a test forces a unique-constraint violation
  (two logs, same date, direct DAO insert) and asserts a `ConstraintViolation` rather than a throw.
  Plus, one test per seam that another epic depends on:
  - `savePlan` on an empty database appends **exactly one** `Step` with `stepIndex: 0` and
    `startDate == draft.startDate`; calling it again returns `Invariant` and appends nothing.
  - Note survival: `setNote` on an un-ticked **future** date, then `markTaken`, then `undoTaken` —
    the note is present after all three and `taken` is false at the end.
  - `startNextStep` **tapped late** (three days after the step ended) and **tapped early** both produce
    `startDate == last.startDate + 52 + Σ holds`; a third test records a hold on step N, then calls
    `startNextStep`, and asserts the held days still generate (the hold is not swallowed).
  - `recordFlare` twice in a row produces `stepIndex` values that are strictly increasing and no
    `UNIQUE` violation, and `cumulativeTakenMg` over the resulting snapshot is unchanged by the flare.
  - `markTaken` on a date with no existing row succeeds and writes `actualMg == plannedMg`.

### 7. Providers

- **What** — Riverpod entry points, still framework-light (`package:riverpod`, not `flutter_riverpod`,
  in this layer).
- **Where** — `lib/data/providers.dart`.
- **Details** — `databaseProvider` (throws by default; **overridden at bootstrap in EPIC-06** with the
  already-opened instance, so no screen ever awaits the database opening),
  `taperRepositoryProvider`, `settingsRepositoryProvider`, and `clockProvider` re-exported from
  EPIC-01's `lib/providers.dart` — **not** from `lib/core/`, which is purity-gated (`CONTRACTS.md` §1).
  `ref.onDispose(db.close)` on the database provider. **No provider here builds a `DayPlan`**; the
  generator bridge is EPIC-06's `derivedScheduleProvider` in `lib/app/`, and the per-screen projections
  (`todayViewProvider`, `scheduleViewProvider(stepIndex)`, `progressViewProvider`) belong to EPIC-08,
  09 and 10 (`CONTRACTS.md` §4).
- **Acceptance** — `ProviderContainer(overrides: [databaseProvider.overrideWithValue(testDb)])`
  gives a fully working repository in a plain Dart test.

### 8. Migrations: ship v1, and prove the ladder against a generated v2 fixture

- **What** — Prove the upgrade ceremony works *before* an upgrade is needed, without shipping a dead
  column to have something to migrate.
- **Where** — `drift_schemas/` (committed dump), `lib/data/db/schema_versions.dart` (generated),
  `test/data/generated_migrations/` (generated), `test/data/migration_test.dart`,
  `lib/data/db/app_database.dart` (`MigrationStrategy`).
- **Details** —
  > **Contract:** `CONTRACTS.md` §11 — **ship schema v1 at v1.0.0.** The draft's plan to ship an
  > artificial v2 adding `DoseLogs.recordedSource TEXT?` is removed. It was also not executable in the
  > stated order: `schema dump` snapshots whatever the code currently declares, and by task 8 the code
  > was already at `schemaVersion 2` with the *v1* tables, so there was no point in the sequence at
  > which a correct `drift_schema_v1.json` could be produced.

  **Order matters, and this is the order.** Every step happens *after* task 3's tables are final —
  including `uid` on all six tables and the `index` → `stepIndex` rename — because a dump taken before
  them is a lie the migration ladder then has to carry forever.
  1. Tables final, `schemaVersion => 1` (task 4).
  2. `dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/` → commit
     `drift_schemas/drift_schema_v1.json`.
  3. `dart run drift_dev schema steps drift_schemas/ lib/data/db/schema_versions.dart` → commit.
     **This step is what the draft omitted**, and it is why the draft's `MigrationStrategy` could not
     compile: `stepByStep(from1To2: …)` is not a drift API. Verified against drift 2.34.3 — the runtime
     ships only `VersionedSchema.stepByStepHelper` in `package:drift/internal/versioned_schema.dart`;
     the typed `stepByStep(...)` wrapper and the `schema.doseLogs.<column>` accessors are *generated*
     by this command. At v1 the ladder is legitimately empty, which is the point: the ceremony,
     the generated file and the CI gate all exist and work before the first real migration.
  4. `dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/` → the
     `SchemaVerifier` helpers (a different artefact from step 3; the draft conflated them).
  5. Wire `MigrationStrategy(onCreate: (m) => m.createAll(), onUpgrade: (m, from, to) =>
     VersionedSchema.stepByStepHelper(step: migrationSteps())(m, from, to), beforeOpen: ...)` —
     `migrationSteps()` from the generated `schema_versions.dart`. `beforeOpen` does **one** thing:
     `PRAGMA foreign_keys = ON`. `validateDatabaseSchema()` moves **out** of `app_database.dart` and
     into the migration test: it is an extension in `package:drift_dev/api/migrations.dart`, a dev
     dependency, and importing it from `lib/` puts `drift_dev`, `analyzer` and `build` on the shipping
     app's compile path.
  6. **The fixture test that exercises the ladder.** `test/data/migration_test.dart` generates a
     synthetic **v2** schema in the test tree — v1 plus one additive nullable column — runs
     `SchemaVerifier` from v1 to it, and asserts `verifySelfIntegrity()` **and that every row survived
     with identical values** after inserting a plan + 60 dose logs + a flare + a hold at v1. The
     migration test that matters is the data-preservation one, not the "columns exist" one. The fixture
     lives only in `test/`; `drift_schemas/` holds v1 alone, so the app ships no dead column.
  7. **CI freshness gate**, same shape as task 1's codegen check: re-run steps 2–4 and
     `git diff --exit-code`, so `drift_schemas/`, `schema_versions.dart` and the generated migration
     helpers cannot silently drift apart.

  *Consequence for EPIC-14/15:* their "install the previous release and upgrade over it" step is
  impossible for a first release (`CONTRACTS.md` §11). It becomes a v1.1 gate; this fixture test is
  what covers `SPEC.md` §10's migration line at v1.0.0.
- **Acceptance** — `flutter test test/data/migration_test.dart` passes; CI runs it in its own lane;
  `drift_schemas/drift_schema_v1.json`, `lib/data/db/schema_versions.dart` and
  `test/data/generated_migrations/` are committed and the freshness gate is green. No file under
  `lib/` imports `package:drift_dev`.

### 9. Persistence integration test

- **What** — The `SPEC.md` §10 line "kill the app mid-taper, reopen, and nothing is lost", as a test.
- **Where** — `test/data/persistence_roundtrip_test.dart`.
- **Details** — Open a file-backed `NativeDatabase` in a temp directory, create a plan, run 120 days
  of logs including one flare and one hold, close the database, reopen it from the same file, rebuild
  the snapshot, feed it to `generateSchedule`, and assert the resulting `DayPlan` list is identical to
  the pre-close one and that `cumulativeTakenMg` is unchanged. This is the epic's headline test.
  **It is also the honest coverage for a claim three other epics make and cannot keep.** EPIC-08's
  "kill/relaunch shows the same state", EPIC-11's "an integration test kills and restarts the app" and
  EPIC-12's launch-from-notification test all assume an `integration_test/` lane that no epic creates —
  and `integration_test` cannot kill the host process anyway; it restarts the widget tree, which proves
  nothing about the database. Those three criteria should point here, at a close-and-reopen over the
  same file, and say so.
- **Acceptance** — Passes; deleting the temp directory is in `addTearDown`.

## Definition of done

- [ ] Six tables cover every `SPEC.md` §6 field; the deliberate additions (`uid`, `planId` foreign keys, `fixedStep`, `localeTag`/`themeMode`) are listed in the PR body with their reasons; no `DayPlan`/schedule table exists
- [ ] `uid TEXT NOT NULL UNIQUE` on all six tables, minted at insert, in **schema v1** — EPIC-13's backup format has the stable ids it assumes
- [ ] `Steps.stepIndex`, not `index`; the composite unique parses
- [ ] Every calendar date is a `TEXT` date; every instant is UTC ms; no dose is a REAL
- [ ] `PRAGMA foreign_keys = ON` verified; cascades proven by test
- [ ] `TaperRepository` ships **the full `CONTRACTS.md` §3 API** — `watchSnapshot`, `markTaken`, `undoTaken`, `setNote`, `recordFlare`, `recordHold`, `savePlan`, `updatePlanFacts`, `updateStrengths`, `startNextStep`, `deletePlan` — with typed `Result`s throughout; no screen epic has to invent a method
- [ ] `markTaken` and `setNote` take `plannedMg`; `undoTaken` preserves the row and its note
- [ ] `savePlan` inserts exactly one `Step` (index 0) when the plan has none, and none thereafter
- [ ] `startNextStep` sets `startDate = last.startDate + 52 + Σ holds` and `stepIndex = last + 1`; `recordFlare` sets `startDate = flare date` and `stepIndex = max + 1`
- [ ] `TaperMethod` is EPIC-04's; `lib/data/` declares no domain type
- [ ] No drift type appears in any signature outside `lib/data/db/`; nothing under `lib/` imports `drift_dev`
- [ ] Backfill is an upsert on `(planId, date)` and works for a date three days in the past
- [ ] **Schema v1 only.** `drift_schema_v1.json`, `schema_versions.dart` and the generated migration helpers committed and gated for freshness; the ladder is exercised by the v2 **fixture** test asserting full data preservation
- [ ] Close-and-reopen round-trip test regenerates an identical schedule and cumulative total
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
