# EPIC-13 — Data portability

**Branch:** `epic/13-data-portability`
**Depends on:** EPIC-05 (persistence & repositories), EPIC-10 (Progress screen, which owns the Export
button), EPIC-11 (Settings, which owns the Backup card), **EPIC-12 (the restore publish step calls
`gateway.cancelAll()` + `syncNotifications()`)**

> **Contract:** the EPIC-12 edge is new. `epics/README.md` needs the same change — the dependency table
> row for 13 becomes `05, 10, 11, 12`, and the ASCII graph must draw 13 descending from 11/12 rather than
> hanging directly off 06.

## Where we are now

`AppDatabase` from EPIC-05 ships **schema v1** at v1.0.0, with a `MigrationStrategy` using `stepByStep`,
committed schema snapshots under `drift_schemas/`, and a migration test in CI. **Every one of the six
tables carries a `uid TEXT NOT NULL UNIQUE`** — a ULID minted at insert by the repository, alongside the
autoincrement rowid — and `DoseLog` carries a `date` stored as a `LocalDate`, not an instant. Both facts
matter here.

> **Contract:** CONTRACTS §11. The `uid` columns are **not** an assumption this epic makes about work
> nobody scheduled: they were added to EPIC-05's schema v1 precisely so the backup format has stable ids
> across an export/import round trip, with a `ulid` dependency in EPIC-05. This epic adds no column and
> owns no migration of its own. The column is named `uid`, not `ulid` and not `id`.

EPIC-10 shipped Progress with the dose staircase, the cumulative-mg and days-on-steroids stats, the
adherence line, and an **Export** action that currently calls a provider returning
`Err(NotImplementedYet)`. EPIC-11 shipped the Settings Backup card with **Export data** and **Import
data** buttons wired to the same stub, plus the delete-plan confirm sheet whose "Export first" button is
also stubbed. EPIC-12 shipped `syncNotifications()` and the `NotificationGateway` port.

Nothing in the repository can currently produce a file, and there is no `ShareGateway` — this epic
creates both ports from scratch (earlier drafts described a `lib/services/` placeholder that no epic
actually lands). There is no PDF dependency, no CSV writer, no envelope, no staging-database path.

## Why this epic exists

SPEC marks two different things v1-critical, and the fastest way to ship a disaster is to build one and
call it both.

**Export for my doctor** (SPEC §4.3) is a human artifact. A rheumatologist at a fifteen-minute follow-up
wants to see the staircase and the adherence, on paper or on a screen, without installing anything. It is
generated on the device and handed over through the OS share sheet — there is no server in this product
and there will not be one. It is lossy by design: formatted dates, localized numerals, a title block, no
internal ids.

**Backup and restore** (SPEC §4.5) is a machine artifact and it is the offline substitute for cloud sync.
These plans run 780 days. A phone in a sink, a factory reset, a new handset — without an exportable,
importable file the user's two years are simply gone, and SPEC §2 says data surviving is the worst
possible bug to get wrong. It must be exact, round-trippable, versioned, and refused when it comes from a
newer app than the one reading it.

Conflating them is the trap: the moment a CSV is restorable, a format built for a spreadsheet becomes the
only copy someone's records depend on. This epic keeps them strictly separate and makes restore refuse
the human artifacts outright.

## What we will have when it is done

From Progress, a user taps Export, chooses PDF or CSV, and hands their doctor a readable dose history.
From Settings, they tap Export data and get a `nearlystop-backup-YYYY-MM-DD.ndjson` file they can mail to
themselves or drop in Files; on a new phone they tap Import data, see a confirmation that names exactly what is about
to be replaced, and get their taper back with every log, flare and hold intact. Deleting a plan offers the
backup first. Every refusal — wrong file, corrupted file, newer schema — says which one it is.

## Skills to load

| Skill | What it governs for this epic |
|---|---|
| `data-export-and-restore` | The whole shape: backup ≠ export, the versioned envelope, the payload upgrade ladder, staging-then-swap restore, canonical values, RFC 4180 + formula-injection escaping, stream-and-rename, typed results. |
| `persistence-drift` | The WAL-safe snapshot **and publish** primitives (`wal_checkpoint(TRUNCATE)` + `VACUUM INTO` + sidecar handling + verify-by-reopen), the DAO layer the serializers read, and the `uid` columns EPIC-05 mints. |
| `service-boundary-and-native` | `ShareGateway` and `FilePickerGateway` as injected, throws-until-overridden ports with fakes, so no test touches a platform channel. |
| `error-handling-typed-results` | `ExportFailure` and `RestoreFailure` sealed families with one subtype per refusal reason, carrying codes and typed params, never localized strings. |
| `seeded-determinism-and-golden-vectors` | The fixed-seed plan + pinned clock that make the CSV golden vector and the byte-identical round-trip test possible. |
| `i18n-rtl-l10n` | Localized, RTL-correct PDF output; machine formats that never localize; the four-locale strings for the confirm and failure surfaces. |
| `testing-strategy` | Fakes over mocks, the hostile fixture, and which failures must each have their own test. |
| `async-safety` | Cancellation on dispose during a long export, `mounted` guards around the share sheet, no `BuildContext` across an await. |
| `ui-states-and-feedback` | Progress on the button not over the app, the confirm sheet that names the merge policy, and failure messages that state the reason. |

## Tasks

### 1. Gateways and dependencies

- **What** — Add the packages and the two injected ports.
- **Where** — `pubspec.yaml`, `lib/services/files/share_gateway.dart`,
  `lib/services/files/file_picker_gateway.dart`, `lib/services/files/fake_*.dart`.
- **Details** — `pdf` (pure-Dart document building), `printing` (share **and** print — a clinician handout
  is a thing people print), `share_plus` (the generic share sheet for CSV/backup), `file_selector`
  (Flutter-team maintained open dialog, lighter than `file_picker`), `crypto` (SHA-256), `convert`
  (`AccumulatorSink`, which is how a digest is read back out of a chunked conversion), and
  `package_info_plus` for the envelope's `appVersion` — the last one is added by **EPIC-11** for the
  Settings About card, so here it is a "already present, still audit it" line: EPIC-15 task 6's
  transitive privacy audit and `PrivacyInfo.xcprivacy` enumeration must include it. No cloud SDK, no
  analytics, nothing that opens a socket — `dependency-hygiene`'s network audit must stay clean and
  SPEC §10 requires a clean airplane-mode run from a fresh install. `ShareGateway` exposes
  `Future<Result<void, ShareFailure>> shareFile({required String path, required String mimeType, required
  String subject, Rect? originRect})` — `Result<void, F>` is EPIC-01's convention and there is no `Unit`
  type in this codebase; the `originRect` is not optional on iPad, where a share sheet without a source
  rect crashes. `FilePickerGateway.pickBackupFile()` returns a `Result<File, PickFailure>` and validates
  the **envelope**, never the extension or the name.
- **File naming — decided here, because a custom extension is not free.** The backup is
  **`nearlystop-backup-YYYY-MM-DD.ndjson`, shared and picked as `application/x-ndjson`**, not
  `.nearlystop`. A custom extension is unpickable on iOS unless the app declares a matching
  `UTExportedTypeDeclarations` UTI in `Info.plist`, and on Android an unregistered extension resolves to
  no MIME so the picker greys the file out — i.e. import, the half of the feature that matters, would be
  dead on the platform where a user most needs it, and the failure would only surface at EPIC-14's
  "export → wipe → import" step. NDJSON needs no platform declaration anywhere. The open dialog still
  uses a permissive type group (`XTypeGroup(extensions: ['ndjson'])` on iOS, `XTypeGroup()` / `*/*` on
  Android) and the **envelope**, not the name, is what actually decides whether the file is a backup.
- **Acceptance** — Both ports have fakes; no test in the repo mocks a `MethodChannel`.

### 2. The backup envelope and codec

- **What** — Define the only file shape restore accepts, and write it.
- **Where** — `lib/features/backup/domain/backup_envelope.dart`,
  `lib/features/backup/data/backup_writer.dart`, `lib/features/backup/data/backup_reader.dart`.
- **Details** — Header-first, so a truncated or foreign file is rejected by its first line rather than by
  a mid-parse exception: `formatVersion` (this envelope's own shape, starts at 1, bumps independently),
  `schemaVersion` (the `AppDatabase.schemaVersion` the payload was written from), `appVersion` (from
  `package_info_plus`, provenance only — never a compatibility check), `exportedAtUtc` (ISO-8601 UTC from
  `clockProvider`), `payloadSha256`.
  The file is **NDJSON**: line 1 is the header object, every subsequent line is
  `{"table":"dose_logs","row":{…}}`. This resolves the real tension between "header first" and "stream,
  never build a `String`" — the payload streams to a temp file through an `IOSink` while the same bytes
  are digested through
  `final out = AccumulatorSink<Digest>(); final input = sha256.startChunkedConversion(out); … input.close();
  final digest = out.events.single;` (note `sha256`, the top-level const instance — `Sha256()` has a
  private constructor and does not compile, and a chunked conversion needs the accumulator to read the
  digest back out). Then the header is written to a second temp file, the payload is appended, and the
  result is published by atomic `rename`. Every failure path deletes both temps and publishes nothing.
  Payload rows carry **canonical values only**: the `uid` string id from every table (never rowids —
  re-importing with autoincrement ids duplicates everything), doses as **integer hundredths of a
  milligram** in a field named `dose_hundredths_mg` (`9.5mg → 950`), dates as `yyyy-MM-dd` local calendar
  dates for `DoseLog.date` (SPEC §7: dates, not durations), instants as ISO-8601 UTC, enum **codes** not
  labels, and never a localized numeral.
  > **Contract:** CONTRACTS §1 — `Milligrams` is integer **hundredths** everywhere in the app, and
  > EPIC-05's columns store hundredths. The earlier "integer micrograms (`9.5mg → 9500`)" introduced a
  > second canonical integer unit differing by a factor of ten, in the one format whose entire job is to
  > round-trip exactly. Add a test asserting a known dose survives export→import unchanged in
  > `Milligrams.hundredths`.
  Tables exported, in dependency order: `taper_plans`, `steps`, `dose_logs`, `flare_events`,
  `hold_events`, `settings` — including `disclaimerAcceptedAt`, so a restored user who already accepted is
  not re-gated by EPIC-11's welcome redirect, and `localeTag`, so they land back in their own language.
  **Row order is specified, not incidental:** every table is serialized `ORDER BY uid ASC` (`dose_logs` by
  `(planId, date)` then `uid`), with the table order exactly as listed. Drift's `select()` without an
  `orderBy` returns whatever order SQLite chooses, which after a restore is not the source order — so
  without this the byte-identical round-trip test in task 8 is untestable. The payload is a deterministic
  function of the *data*, never of the storage.
- **Acceptance** — A 780-day fixture exports with peak memory flat; the temp directory is empty
  afterwards; the header parses standalone from the first line.

### 3. Restore — validate, stage, swap

- **What** — An all-or-nothing import that cannot damage the live database.
- **Where** — `lib/features/backup/data/restore_service.dart`,
  `lib/features/backup/domain/restore_failure.dart`.
- **Details** — The ladder, in order, each rung its own typed failure:
  1. Read line 1. Not JSON, or missing a version field → `RestoreFailure.notABackupFile()`.
  2. `formatVersion > kFormatVersion` → `unsupportedFormat`.
  3. `schemaVersion > AppDatabase.schemaVersion` → **`newerThanApp()` — refuse, never guess.** This is
     the rule that stops a user on an old build from silently mangling data written by a new one.
  4. Digest the payload bytes and compare to `payloadSha256`; mismatch → `corrupted()`.
  5. **Upgrade the payload, in memory, before any database sees it.** Define an upgrade ladder in the
     codec: `upgradePayload(N → N+1)` pure row transformers, keyed off the header's `schemaVersion` and
     run in sequence up to `AppDatabase.schemaVersion`.
     > **Contract:** CONTRACTS §11. The earlier plan — "open a staging DB and then run it forward through
     > `stepByStep`" — cannot work: a fresh drift database opened through `AppDatabase` runs
     > `onCreate → createAll()` at the *current* `schemaVersion` before a single row is inserted, so the
     > staging DB is already current, the old-shaped rows either fail on a renamed column or drop data
     > silently, and the migration step is a no-op because `user_version` is already right. The one case
     > the ladder exists for — restoring an older backup — is the case that approach cannot do. Moving
     > the version step into the codec is the fix. **Every future schema bump must add a payload upgrader
     > and a fixture**; that is a checklist line in EPIC-05's migration ritual, not folklore here.
  6. Open a **staging** database at `<support>/staging_restore.sqlite` (a fresh
     `NativeDatabase(File(...))`, therefore at the current schema) and import the now-current-shaped rows
     inside one transaction. Any row-level failure → close, delete the staging files, return
     `malformedPayload(table:, line:)`. The live database has not been opened for writing at any point.
  7. **Publish, WAL-safely.** The live database runs in WAL mode, so it is up to three files —
     `nearlystop.sqlite`, `-wal` and `-shm`. Renaming only the main file leaves the *previous* database's
     WAL and shared-memory sidecars beside the newly published file, and on reopen SQLite either replays
     foreign frames or refuses to open — silent resurrection of pre-restore rows, or an unopenable
     database, on the one code path whose entire purpose is that a two-year plan is never lost. The
     happy-path test would not catch it; a phone killed mid-write would. So, in order: run
     `PRAGMA wal_checkpoint(TRUNCATE)` on **both** databases → close every handle → move the live main
     file **and its `-wal` and `-shm`** into the rollback set (`<name>.rollback*`) → rename the staged
     main file into place and assert no stale sidecar remains beside it → reopen → `PRAGMA
     integrity_check` plus a row-count sanity read. If any of that fails, put the rollback set back
     (all three files) and return `publishFailed()`. Delete the rollback set only after a clean reopen.
     Producing the staged copy with `VACUUM INTO` gives a single clean file with no sidecars and is the
     better source for the rename.
  8. Invalidate every repository provider, then `gateway.cancelAll()` + `syncNotifications()` from
     EPIC-12 — restored pending notification ids came from another device and mean nothing here. This is
     the call that puts EPIC-12 in this epic's dependency list.
  **Merge policy for v1 is replace-all, and only replace-all.** Merge-by-id is a v2 problem; shipping an
  ambiguous one is worse than shipping one. The confirmation sheet says, in the same words as the code,
  that everything currently on this phone will be replaced by the file's contents, and shows the file's
  `exportedAtUtc` and plan summary so the user can tell which backup they picked.
- **Acceptance** — One test per subtype of `RestoreFailure` — `notABackupFile`, `unsupportedFormat`,
  `newerThanApp`, `corrupted`, `malformedPayload`, `publishFailed` (six, named rather than counted; the
  ladder's remaining rungs are actions, not refusals) — each asserting the typed failure **and** that the
  live database file is byte-unchanged. `PickFailure` (cancelled / unreadable) is a separate family from
  task 1 and is tested separately.

### 4. Export before anything destructive

- **What** — Make SPEC §5.3's rule a code path, not a habit.
- **Where** — `lib/features/backup/presentation/export_guard.dart`, plus the delete-plan sheet from
  EPIC-11 and the restore confirmation from task 3.
- **Details** — `ExportGuard` wraps a destructive callback on top of **EPIC-07's shared confirm sheet**
  (`lib/features/shared/confirm_sheet.dart` — EPIC-08's Hold/Flare, EPIC-11's delete-plan and this are its
  three consumers; do not invent a fourth private dialog here). The sheet's primary action is
  "Export first", its secondary is "Continue without a backup" (deliberately the tertiary-styled, less
  prominent one), and its dismissal does nothing — which is the shape EPIC-07's contract calls "the
  button itself never acts directly": a secondary action that runs first, returns, and only then
  proceeds. It is used by delete-plan and by replace-all restore
  — the two operations that can lose two years. Choosing "Export first" runs the backup export, shares
  it, and only then proceeds.
- **Acceptance** — A widget test proves the destructive callback is not invoked on dismissal, is invoked
  after a successful export, and is invoked after an explicit "continue without".

### 5. Doctor export — CSV

- **What** — A spreadsheet-readable dose history.
- **Where** — `lib/features/export/data/dose_history_csv.dart`.
- **Details** — Columns: `date`, `weekday`, `step`, `block`, `planned_mg`, `actual_mg`, `taken`,
  `tablets`, `note`, `event`. Written with RFC 4180 quoting — quote any field containing the delimiter, a
  quote, CR or LF, and double embedded quotes — **and** neutralised against formula injection: a field
  starting `=`, `+`, `-`, `@`, TAB or CR is prefixed with `'`. A patient note reading `-2 today` is a
  formula in Excel; a note is free text and this is a real vector. UTF-8 with a BOM, because Excel on
  Windows misreads UTF-8 without one and a doctor's laptop is Windows. Streamed through an `IOSink`,
  published by rename, shared through `ShareGateway` with `text/csv`.
- **Acceptance** — A hostile-note round trip through a real CSV parser; a golden vector CSV for the
  seeded fixture committed and diffed in CI.

### 6. Doctor export — PDF

- **What** — Something a rheumatologist could actually read (SPEC §10).
- **Where** — `lib/features/export/data/dose_history_pdf.dart`,
  `lib/features/export/data/pdf_theme.dart`.
- **Details** — Built with `pw.Document`. Page 1: a title block (drug, date range, current dose, target),
  the three headline stats (cumulative mg, days since day one, "taken 341 of 350 days" — never framed as
  a streak), and the dose staircase drawn as a `pw.CustomPaint` from the same `DayPlan` list the Progress
  chart uses, with flares and holds marked. Pages 2+: the day table, grouped by step, with a repeating
  header row (`pw.TableHelper`/`pw.Table` with `headerCount`). A footer on every page naming the app,
  the export date, and the sentence "Generated on the patient's device from a plan they entered. Not
  medical advice." — the same disclaimer the app shows, because this page will be read out of context.
  **Fonts must be embedded**, loaded via `pw.Font.ttf(await rootBundle.load('assets/fonts/…'))` — the
  bundled Nunito for Latin, bundled Vazirmatn for Arabic-script. `google_fonts` is banned in this app and
  the `pdf` package's built-in Helvetica has no Persian coverage at all.
  **Stated limitation:** the `pdf` package does bidi reordering and Arabic shaping, but Sorani-specific
  letterforms (ڕ ڵ ۆ ێ) depend entirely on the embedded font's shaping tables and are **not** guaranteed
  to render as well as they do in Flutter's text engine. Visually verify the `fa` and `ckb` PDFs on
  device; if `ckb` shapes badly, ship CSV as the `ckb` default and say so in the UI rather than handing a
  doctor a broken page. Sharing goes through `Printing.sharePdf` (which also gives Print, the thing SPEC
  §4.3 actually asks for) behind the `ShareGateway` port.
- **Acceptance** — A human reads the generated PDF for a 300-day fixture in en, de, fa and ckb; the
  staircase, the stats and the table are legible and correctly ordered in RTL; the disclaimer footer is on
  every page.

### 7. Wiring the UI

- **What** — Replace EPIC-10 and EPIC-11's stubs with the real providers.
- **Where** — `lib/features/export/presentation/export_sheet.dart`,
  `lib/features/backup/presentation/backup_actions.dart`, plus the two screens.
- **Details** — Progress's Export opens a small sheet offering **PDF** and **CSV** with one line each
  explaining who the format is for. Settings' Export data goes straight to the backup file and shares it.
  Settings' Import data opens `FilePickerGateway`, then the replace-all confirmation, then the restore.
  Long operations show progress **on their own control** — the button becomes a disabled spinner-labelled
  button, never a modal barrier over the app. Every failure renders the localized message derived from
  the typed failure's `code`; no `e.toString()` ever reaches a screen. The sharing surface states plainly
  that the file is unencrypted plain text, because it is, and SPEC §5.3's honesty rule and the store
  privacy claim both depend on that being said where the user can see it.
- **Acceptance** — All three stubs are gone; a failing export leaves the buttons enabled with a reason
  shown.

### 8. Tests

- **What** — The suite the skill requires, on a fixture designed to break things.
- **Where** — `test/features/backup/`, `test/features/export/`, `test/fixtures/hostile_plan.dart`.
- **Details** — The hostile fixture: a drug name with an apostrophe and a comma, notes containing double
  quotes, an embedded newline, an emoji, RTL text with bidi marks, a whitespace-only string, a null-vs-
  empty pair, a `=cmd()` note, a 0.5mg dose, a DST-ambiguous local instant, and a `DoseLog` on 29
  February. Required tests:
  - **Round trip byte-identical:** export → import into an empty DB → export again → identical bytes
    (with a fixed clock, so `exportedAtUtc` is stable — `seeded-determinism-and-golden-vectors` owns
    this). A companion test shuffles insertion order and asserts identical bytes, which is what task 2's
    `ORDER BY uid` buys.
  - **Idempotent re-import:** importing the same file twice yields the same state, not duplicates.
  - **Every refusal:** the six named subtypes from task 3, each asserting the typed failure and an
    unchanged live DB, plus `PickFailure` separately.
  - **Failure leaves no artifact:** force an `IOSink` failure mid-write; assert no publishable file exists.
  - **CSV escaping:** the `=cmd()`, `a,b"c\nd` and RTL cells survive a write→parse round trip.
  - **Payload upgrade ladder:** v1.0.0 ships schema **v1** (CONTRACTS §11), so no genuinely older payload
    exists yet — the ladder is exercised before it is needed, by registering a synthetic
    `upgradePayload(1 → 2)` transformer in test scope and restoring a generated v1 payload against a
    stubbed `schemaVersion` of 2, asserting the transformed rows land correctly. A payload at
    `schemaVersion + 1` is refused with `newerThanApp`. Note in the test file that this stands in for a
    real ladder step and must be replaced by the first genuine one at the first schema bump.
  - **WAL-safe publish:** create a live DB with a **non-empty `-wal`**, restore over it, reopen, and
    assert the database contains exactly the file's contents and that no stale `-wal`/`-shm` survives.
  - **Cumulative-total invariant:** SPEC §5.2 — the cumulative mg and adherence numbers after a restore
    equal the numbers before the export, exactly.
- **Acceptance** — All green in CI; the golden CSV vector is committed and any diff fails the build.

## Definition of done

- [ ] Backup and doctor-export are separate code paths; restore refuses a CSV or PDF outright
- [ ] Every backup carries `formatVersion`, `schemaVersion`, `appVersion`, `exportedAtUtc` and a payload
      SHA-256, in that header-first order
- [ ] Restore verifies the checksum, refuses a newer `schemaVersion` by name, and upgrades an older
      payload through the **codec's `upgradePayload(N → N+1)` ladder before insertion** — never by
      building a staging database at the payload's old version (CONTRACTS §11)
- [ ] Restore stages into a current-schema database, checkpoints and closes both, publishes main file
      **and sidecars** by rename with a complete rollback set, and reopens with an integrity check; a
      failure leaves the live database byte-unchanged and leaves no stale `-wal`/`-shm`
- [ ] Replace-all is the only merge policy and the confirmation states it in the same words as the code
- [ ] Delete-plan and replace-all restore both route through `ExportGuard` on EPIC-07's shared confirm
      sheet
- [ ] Machine formats carry canonical values and `uid` ids only, doses in **hundredths of a milligram**,
      rows in a specified order; no localized numeral, no formatted date, no rowid
- [ ] Writes stream to a temp file and publish by atomic rename; failures delete the temps
- [ ] CSV is RFC 4180 quoted, formula-injection escaped, and UTF-8 BOM prefixed
- [ ] The PDF embeds bundled fonts, renders in all four locales, and carries the disclaimer footer on
      every page; the `ckb` shaping limitation is verified and documented
- [ ] Share and file-pick go through injected gateways on explicit user action; nothing uploads, and
      airplane-mode from a clean install still passes
- [ ] Export and restore return typed `Result`s with one failure per refusal reason; no exception reaches
      a screen
- [ ] Round-trip (including the shuffled-insertion-order variant), idempotent re-import, all six named
      refusals, no-partial-artifact, CSV-escaping, payload-upgrade-ladder, WAL-safe-publish and
      cumulative-invariant tests pass on the hostile fixture
- [ ] The backup file is `nearlystop-backup-YYYY-MM-DD.ndjson` / `application/x-ndjson`, pickable on both
      platforms with no custom UTI, and identified by its envelope rather than its name
- [ ] `epics/README.md`'s dependency table and ASCII graph carry the 12 → 13 edge
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
