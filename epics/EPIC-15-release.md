# EPIC-15 — Release & store shipping

**Branch:** `epic/15-release`
**Depends on:** EPIC-14

## Where we are now

`main` holds a feature-complete app: six screens, four locales, the DSNS engine with its property
tests, a drift database with a migration test, local notifications, backup/restore and PDF/CSV export.
EPIC-14 finished with `docs/design-review/YYYY-MM-DD-signoff.md` committed and reading **SIGNED OFF**,
`docs/a11y/contrast-budget.md` regenerated, `docs/perf/schedule-profile.md` recorded, and the full
24-pair parity matrix in the merged PR. CI is green on the release commit.

What does not exist yet is anything to do with the **artifact**. `pubspec.yaml` still says
`version: 1.0.0+1` from the day EPIC-01 created it and no build has ever been produced with it.
`android/key.properties` does not exist; the project has never been signed with anything but the debug
key. `ios/ExportOptions.plist` does not exist. The launcher icon is still Flutter's default blue `F`.
`flutter_native_splash` **is** already a dev dependency configured with the Daybreak `bg` colours —
EPIC-06 added it for its no-flash cold start — but it has never been regenerated against a real mark.
There is no `PrivacyInfo.xcprivacy`, no committed expected-permission
list, no `android:localeConfig`, no `CFBundleLocalizations`, no `store/` directory, no listing copy in
any language, no screenshots, and no release documentation. Nothing has ever been run in release mode
on real hardware, so R8, tree-shaking and obfuscation have never touched this code.

> **Contract:** `epics/CONTRACTS.md` settles three things this epic would otherwise re-open.
> §12: EPIC-12 does **not** declare `SCHEDULE_EXACT_ALARM` — the expected permission set below is the
> agreed one, not a demand on a merged epic. §13: the Settings **About card** and the **Language
> picker** are EPIC-11's, built with their ARB keys, goldens and parity cells; this epic adds no
> user-facing control. §11: the app ships **schema v1 at v1.0.0**, so there is no on-device upgrade
> path to exercise here.

**This epic ships no new UI.** Everything user-visible — including the "Send diagnostic report" row —
was built and signed off in EPIC-11 and EPIC-14. The only pixels this epic changes are the launcher
icon and the splash mark, and both force a re-shoot of the affected EPIC-14 sweep cells (task 4).

## Why this epic exists

CI proves the code; only a release proves the artifact. Everything that has never run here runs for the
first time in this epic: R8 shrinking (which is where reflective plugin failures surface), obfuscation
(which makes every future crash report unreadable unless the symbols are archived with the build),
signing with a real upload key, and store delivery's own re-signing and re-compression.
A green pipeline is not a shippable app, and saying so plainly is part of the job. The one thing this
epic honestly **cannot** prove is the upgrade path — v1.0.0 has no predecessor — so it says so in the
gate file and names the fixture tests that stand in for it, rather than ticking a line it did not run.

This app also has an unusually strong privacy story and an unusually risky category. The privacy half is
easy and should be stated loudly: no account, no server, no analytics, no crash SDK, no network
permission at all — the Data Safety form and the App Store nutrition labels are close to empty, and they
are **provable from the repo** rather than asserted. The risky half is the framing. Apple reviews
medical apps with greater scrutiny, and App Review Guideline 1.4.1 requires apps that *calculate
medication dosages* to come from a drug manufacturer, hospital, university, health insurer or an
equivalent approved entity. NearlyStop is not a dosage calculator — SPEC §2 makes "never recommends a
dose" a non-negotiable — but a store listing that says "works out your taper for you" would recast it
as one and earn a rejection that no code change fixes. The listing, the screenshots, the disclaimer and
the reviewer note have to carry that distinction deliberately.

Finally, this epic converts SPEC §10 from a wish list into a gate. Ten conditions, including the
airplane-mode verification, become a tracked file that must be ticked against a fresh run before the
tag is cut.

## What we will have when it is done

A signed, obfuscated release artifact for both stores, built from one tagged commit, with its symbol
archive stored off-machine; store listings, screenshots and privacy declarations that match what the
code actually does; a first version live on a staged Play rollout and an iOS phased release, with a
written halt criterion and someone watching it. Plus the two artifacts that make the next release
cheap: `docs/release/v1.0.0-gate.md` (SPEC §10, ticked against real runs) and
`docs/release/RELEASING.md` (the ordered ritual, so version 1.0.1 does not rediscover any of this).

## Skills to load

| Skill | What it governs here |
|---|---|
| `release-and-store-shipping` | The whole ritual: `version: x.y.z+N` as the only source, signing material never in the repo, `--obfuscate --split-debug-info` with archived symbols, merged-manifest permission audit, store declarations provable in the repo, size/cold-start budgets, staged rollout. |
| `ci-pipeline-and-gates` | The green-before-release precondition, the pinned runner and toolchain, and adding the new policy gates (permissions, no-INTERNET, release hygiene) as named gates. |
| `dependency-hygiene` | Proving no dependency — directly or transitively — opens a network path, reports crashes, or collects identifiers; the committed lock; the audit before a dep changes a store declaration. |
| `accessibility-as-code` | The accessibility claims made in the listing must be ones EPIC-14 actually verified; nothing new is claimed here. |
| `data-export-and-restore` | The export/backup behaviour the privacy copy describes, and the "you choose when a file leaves the app" wording that keeps the claim honest. |
| `app-startup-and-bootstrap` | The two error handlers that write the local crash log, and why there is no `runZonedGuarded` and no crash SDK. |
| `flutter-performance` | The profile-mode discipline behind the recorded size and cold-start budgets. |

## Tasks

### 1. Version, changelog and the release ritual document

- **What** — Fix the versioning scheme, write the changelog, and write down the ordered ritual.
- **Where** — `pubspec.yaml`, `CHANGELOG.md`, `docs/release/RELEASING.md` (new).
- **Tests first** — *Scaffold.* A version string, a changelog and a written ritual have no behaviour;
  the rules that bite (the build number only goes up, a burned number is burned) are process, not code,
  and a test asserting `pubspec.yaml` parses asserts that YAML works. Verified by the single-source
  grep — no `versionName`, `versionCode`, `CFBundleShortVersionString` or `CFBundleVersion` literal in
  any platform file — appended as a rule group to `tool/check_bans.sh` and running in CI. Give that rule
  a must-fail fixture when you add it, the same as every other rule in that script.
- **Details** — `version: 1.0.0+1` in `pubspec.yaml` is the **only** version source: `1.0.0` becomes
  `versionName` / `CFBundleShortVersionString`, `+1` becomes `versionCode` / `CFBundleVersion`. Nothing
  is hardcoded in `build.gradle.kts` or `Info.plist`; overrides happen only via
  `--build-name`/`--build-number`. Document the two rules that bite: the build number only ever goes up,
  and **a failed or merely uploaded-to-internal build burns it forever** — bump, never retry. Play's
  `versionCode` ceiling is 2,100,000,000, so keep a plain incrementing integer rather than encoding a
  date. `RELEASING.md` records the ordered ritual (preconditions → bump → build with obfuscation →
  archive symbols → verify on hardware → measure budgets → reconcile declarations → upload to
  internal/TestFlight → read store state back → tag → staged rollout).
- **Acceptance** — `RELEASING.md` is followable by someone who has never shipped this app; a grep proves
  no version string exists in any platform file.

### 2. Android signing without secrets in the repo

- **What** — Real upload signing, Play App Signing enrolment, and no credential ever tracked.
- **Where** — `android/app/build.gradle.kts`, `android/key.properties` (**gitignored**), `.gitignore`,
  `.github/workflows/release.yml` (new, manual-dispatch only).
- **Tests first** — *Scaffold.* Generating a keystore, enrolling in Play App Signing and adding
  `.gitignore` entries have no assertable behaviour, and the one branch that does — Gradle failing the
  release build when `key.properties` is absent — is proved by running it, not by a Dart test of Gradle.
  Verified by `flutter build appbundle --release` producing an upload-key-signed `.aab`, and by
  `tool/check_release_hygiene.sh` reporting no tracked credentials. That script is a gate, so it gets
  the same treatment as every gate here: add a fixture with a tracked `key.properties` and watch it turn
  red before trusting it, and run the `git log --all --name-only` history check once, by hand, because a
  credential committed and later deleted is exactly what a working-tree check misses.
- **Details** — Generate an upload keystore outside the repo. `key.properties` carries
  `storeFile`/`storePassword`/`keyAlias`/`keyPassword` and is read in Gradle with a guard so an absent
  file falls back to debug signing for local debug builds but **fails the release build loudly**. Enrol
  in Play App Signing: a lost *upload* key is recoverable through support, a lost *app signing* key on
  an unenrolled app means the listing can never be updated again. Add `*.jks`, `*.keystore`, `*.p12`,
  `*.p8`, `key.properties`, `**/service-account*.json` to `.gitignore` and verify with
  `git log --all --name-only` that none has ever been committed. CI injects them from repository
  secrets at build time, never from the tree. Confirm `targetSdk` is inside Play's rolling requirement
  window — this is a hard upload rejection with a deadline, checked while planning, not when it fails.
- **Acceptance** — `flutter build appbundle --release` produces an upload-key-signed `.aab`;
  `tool/check_release_hygiene.sh` (from the skill) reports no tracked credentials.

### 3. iOS signing, export options and device family

- **What** — Archive/export configuration and the universal-vs-iPhone decision.
- **Where** — `ios/ExportOptions.plist` (new), `ios/Runner/Info.plist`, `ios/Runner.xcodeproj` build
  settings, `ios/Podfile`.
- **Tests first** — *Scaffold.* Export options, a team id, a deployment target and a device-family
  setting are configuration; there is no behaviour to assert and no way to fail one usefully off-device.
  Verified by `flutter build ipa --release` producing an uploadable artifact and by
  `tool/check_ipa_slices.sh` passing before the upload is spent. The **one** declaration here that is
  assertable — `CFBundleLocalizations` — is deliberately not tested here: task 5 owns it, so the four
  locales are asserted once, in one place, against the ARB file list rather than against a list typed
  twice.
- **Details** — `ExportOptions.plist` with `method: app-store-connect`, the team id, and
  `uploadSymbols: true`. The App Store Connect API key (`.p8`) lives in a secret store, never in the
  repo. **Device family is a product decision:** SPEC §5.4 requires landscape because people prop
  tablets on a kitchen table, and EPIC-14 task 12's expanded-width axis verified the `NavigationRail`
  layout at those widths — so ship universal (`TARGETED_DEVICE_FAMILY = "1,2"`). That makes the 13″ iPad
  screenshot set **mandatory** (task 8); do not discover this at submission. Set a deployment target
  that matches the pinned Flutter version's floor and record it. Before any upload run
  `tool/check_ipa_slices.sh` — a tree that last built for the simulator embeds a simulator framework
  slice and Apple rejects it (90087/91169), which only a clean rebuild fixes.

  Two `Info.plist` entries that are easy to forget and expensive to miss:
  - **`CFBundleLocalizations`** = `en`, `de`, `fa`, `ckb`. Without it the OS believes the app is
    English-only: the per-app Language row in iOS Settings does not appear, so a Persian or Sorani
    speaker whose phone is set to English cannot reach their language from outside the app. See task 5
    for the Android half.
  - **The backup document type**, if EPIC-13 kept the `.nearlystop` extension: an
    `UTExportedTypeDeclarations` entry (identifier `com.<team>.nearlystop.backup`, conforming to
    `public.data`, `public.filename-extension` = `nearlystop`). Without it the user's own backup shows
    **greyed out and unselectable** in the Files picker, which makes import — the half of the feature
    that matters — dead on iOS. If EPIC-13 instead took the `.ndjson`/`application/x-ndjson` route,
    this entry is not needed; read EPIC-13 task 1 and do whichever it says, then say which in
    `RELEASING.md`.
- **Acceptance** — `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist` produces
  an uploadable IPA; the slice check passes before the upload is spent; `CFBundleLocalizations` lists
  exactly the four locales and is asserted by the policy test in task 5.

### 4. App icon and splash across densities

- **What** — Real launcher icons and a warm splash on both platforms, generated once and committed.
- **Where** — `assets/branding/`, `pubspec.yaml` (dev dependencies + config),
  `android/app/src/main/res/**`, `ios/Runner/Assets.xcassets/**`,
  `android/app/src/main/res/values/styles.xml`.
- **Tests first** — *Scaffold.* Bundling an icon and a splash mark is asset generation: a test that a
  PNG exists at a density asserts that the generator ran, which the committed diff already shows. There
  is no behaviour to catch — an icon that is ugly, clipped in the 72dp safe zone, or carries an alpha
  channel is caught by looking at it on a device, which is this task's own acceptance. Verified by the
  fresh-install check on both platforms and by the re-shot EPIC-14 sweep cells. Worth one committed
  check rather than a test: treat the generated native assets as codegen output, so a regeneration that
  produces a diff is a review item.
- **Details** — Add `flutter_launcher_icons` as a **dev** dependency. `flutter_native_splash` is
  already one — EPIC-06 task 1 added it and configured the light/dark background colours, because
  EPIC-06's no-flash cold-start acceptance depends on it and cannot wait nine epics. This epic
  regenerates its assets against the real mark and verifies density coverage; it does not introduce the
  package or re-decide the colours. Run both generators once, commit the generated native assets, and
  treat them as checked-in outputs (a regeneration that produces a diff is a review item, same
  discipline as codegen freshness). Icon design comes from
  Daybreak: the sunrise gradient with a single simple mark, **no text** — an icon with a word in it is
  illegible at 48dp and untranslatable across four locales. Android needs an adaptive icon
  (108dp foreground with the 72dp safe zone, a flat background layer) **and** a monochrome layer for
  Android 13+ themed icons. iOS needs a 1024×1024 with **no alpha channel** and no pre-baked rounded
  corners. Splash: background `#FFF9F2` light / `#241A20` dark from the same tokens (never white,
  never `#000`), the mark centred, and the Android 12+ splash-screen API branch configured so it does
  not double-flash. Verify the whole set on a device at every density rather than in the generator's
  preview.
- **Acceptance** — Fresh install on both platforms shows the real icon on the home screen and a warm
  splash that matches the app's first frame in both themes; no white or black flash. The splash is the
  only pixel change this epic makes to a signed-off surface, so **re-shoot the EPIC-14 sweep cells it
  touches** (cold-start video, first-frame stills, light and dark) into `docs/design-review/sweep/`,
  overwriting per EPIC-14 task 13's one-truth rule, and note the re-shoot in the release PR.

### 5. Permission set and locale declarations, asserted whole from the merged manifest

- **What** — Lock the shipped permission set to an explicit list, declare the four locales to both
  operating systems, and gate both in CI.
- **Where** — `test/policy/permissions_test.dart` (new), `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/main/res/xml/locales_config.xml` (new), `ios/Runner/Info.plist`,
  `.github/workflows/ci.yml`, `.github/workflows/release.yml`.
- **Tests first (TDD)** — `test/policy/permissions_test.dart` is a real test file and it is written
  **before** the declarations it asserts, against the current tree, where it fails for the right reason:
  `locales_config.xml` does not exist yet. Pure `package:test` parsing the merged manifest and the plist
  as XML. Write and watch fail, in this order:
  1. the Android permission set is asserted as one **set equality** against
     `{POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE}` — so a transitive plugin adding a node
     fails as loudly as a removed one, which a per-permission `contains` would not
  2. `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` each absent, as their own named expectations citing
     CONTRACTS §12, so the failure message says which contract broke
  3. `android.permission.INTERNET` absent from the **release** merged manifest, with the failure message
     stating that its presence in debug and profile is expected and correct — the message is part of the
     test, because the wrong fix here is silent and permanent
  4. `res/xml/locales_config.xml` lists exactly `en, de, fa, ckb` and `<application>` carries
     `android:localeConfig`
  5. `CFBundleLocalizations` equals the same four
  6. both lists are derived from the `lib/l10n/arb/app_*.arb` filenames rather than typed — write the
     failing case first by adding a throwaway `app_xx.arb` and confirming the test goes red
  7. the `NS*UsageDescription` key set in `Info.plist` is **empty** — an unused usage string is a claim
     that cannot be defended at review
- **Details** — Read the **merged** manifest
  (`build/app/intermediates/merged_manifests/<variant>/AndroidManifest.xml`), not the source file, and
  use `build/app/outputs/logs/manifest-merger-blame-report.txt` to see which dependency contributed each
  node. Assert the whole set with one expectation so a transitive plugin bump fails loudly.

  > **Contract:** the expected set is `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`
  > (contributed by `flutter_local_notifications`) — and **no `SCHEDULE_EXACT_ALARM`, no
  > `USE_EXACT_ALARM`**. Per CONTRACTS.md §12, EPIC-12 does not declare them and schedules with
  > `AndroidScheduleMode.inexactAllowWhileIdle`: a daily "your plan for today" does not need
  > alarm-clock precision, and on Android 14+ the permission is denied by default anyway, so the
  > branch that used to depend on it was dead code that only bought Play policy scrutiny. This epic
  > therefore does **not** overrule a merged epic — the two agree at the source. Keep
  > `tools:node="remove"` only for exact-alarm nodes a *transitive plugin* merges in without asking,
  > and let the whole-set assertion be what catches anything else.

  Critically: assert **`android.permission.INTERNET` is absent** from the **release** merged manifest.
  Flutter adds it to the debug and profile manifests deliberately, so its absence in release is a hard,
  checkable proof of the zero-network claim — and its **presence in debug is expected**; say so in the
  test's failure message so nobody "fixes" the wrong variant.

  **Locale declarations.** Both OSes need to be told what the app speaks, or their per-app language
  pickers never appear and `localeTag` (EPIC-11's Language picker) is the only route to a non-device
  language:
  - Android: `res/xml/locales_config.xml` listing `en`, `de`, `fa`, `ckb`, referenced from
    `<application android:localeConfig="@xml/locales_config">`.
  - iOS: `CFBundleLocalizations` with the same four (task 3).
  Assert both in this test — the four values, in both files, matched against the ARB file list so
  adding `app_xx.arb` without declaring it fails.

  On iOS assert the exact set of `NS*UsageDescription` keys in `Info.plist` — expected to be **empty**,
  since notifications are requested via the authorization API and need no usage string; an unused usage
  string is a claim that cannot be defended.
- **Acceptance** — Two lanes, stated explicitly so the gate is never green by accident:
  - **PR CI** runs `flutter build apk --profile` (or `--release --no-shrink` with a CI-only signing
    fallback) and asserts the locale declarations and the `NS*UsageDescription` set; it records but
    does not fail on `INTERNET`, which profile builds legitimately carry.
  - **`release.yml`** (manual dispatch, secrets injected) runs the full assertion against the merged
    manifest of the real signed release build, including `INTERNET` absent and the whole permission
    set.
  Document which lane checks what in `RELEASING.md`. Adding a network-capable plugin turns the release
  lane red naming the permission and the contributing dependency.

### 6. Privacy declarations, provable from the repo

- **What** — Data Safety, nutrition labels and `PrivacyInfo.xcprivacy`, each backed by evidence.
- **Where** — `ios/Runner/PrivacyInfo.xcprivacy` (new), `docs/release/privacy-declarations.md` (new),
  `store/` copy.
- **Tests first** — *Scaffold for the declarations; the audit behind them is a gate.* A store form and a
  privacy manifest are documents, and transcribing a plugin's declared reason codes is a read, not a
  behaviour. Verified by `tool/audit_deps.sh` over `dart pub deps --json`, which is where the assertable
  part lives: it must fail on a **transitive** hit, not just a direct one, so seed a dependency with a
  banned transitive package and watch it go red before trusting the clean result. The claim that no
  socket opens is asserted by task 13's static gate and task 5's INTERNET assertion — cite those from
  `privacy-declarations.md` rather than restating them here.
- **Details** — The declaration is: **no data collected, no data shared, no account, no tracking.**
  Evidence, not assertion — run the `dependency-hygiene` transitive audit (`dart pub deps --json` +
  `tool/audit_deps.sh`) and record the result: no analytics, no crash SDK, no ads, no attribution,
  no identifier collection at any hop. `PrivacyInfo.xcprivacy` sets `NSPrivacyTracking` false, an empty
  `NSPrivacyTrackingDomains`, an empty `NSPrivacyCollectedDataTypes`, and an `NSPrivacyAccessedAPITypes`
  array containing **only** the required-reason APIs the binary actually reaches — enumerate these by
  reading each plugin's own bundled privacy manifest (drift/`sqlite3_flutter_libs`, `path_provider`,
  `shared_preferences` if used, `share_plus`, `file_selector`, `package_info_plus`, `printing`,
  `flutter_local_notifications`) and transcribing their
  declared reasons; do not reason about them from memory, and do not declare a reason code for an API
  nothing calls. Play Data Safety: nothing collected, nothing shared, and answer the deletion question
  with the in-app delete-plan flow. **No absolute privacy claims** anywhere in listing or onboarding —
  ban "nothing ever leaves your device", because export through the share sheet is a real path the user
  can take. State the mechanism instead: *"Your taper is stored only in this app on this device. The app
  has no internet permission and makes no network calls. Exports leave only when you choose to share
  them."*
- **Acceptance** — Every declaration line in `privacy-declarations.md` names the file or test that
  proves it; the permission test in task 5 is one of them.

### 7. Crash reporting decision that respects zero telemetry

- **What** — Decide, document, and implement how a crash becomes readable without any SDK.
- **Where** — `docs/release/crash-policy.md` (new), `lib/core/diagnostics/crash_log.dart`,
  `lib/bootstrap.dart`.

  > **Contract:** **no Settings UI is built here.** The "Send diagnostic report" row lives in EPIC-11
  > task 7's About card (CONTRACTS.md §13), with its ARB keys in all four locales, its semantics label,
  > its golden and its frame-6 parity cell — because EPIC-14 signs off Settings' parity, semantics,
  > tap targets and 200% reflow *before* this epic starts, and a control added afterwards would ship
  > unlocalized, unlabelled for VoiceOver and unmeasured, on the accessibility-critical screen for the
  > accessibility-critical audience. This epic owns the **policy, the handlers, the file and the
  > symbolication** behind that row, and nothing on screen. If EPIC-11 merged without the row, that is
  > a defect filed against EPIC-11, not work absorbed here.

- **Tests first (TDD)** — `test/core/diagnostics/crash_log_test.dart`, pure `package:test` over a temp
  directory with `withClock(Clock.fixed(…))` and an injected `PackageInfo`. The log is the one piece of
  real behaviour in this epic besides task 13, and its failure mode — leaking a patient's dose history
  into a file they then mail to a stranger — is exactly what a test is for. Write and watch fail, in
  this order:
  1. an appended entry carries the error, the stack, `1.0.0+1` and the platform, and parses back out
  2. the cap: append entries totalling twice the documented ceiling → the file is `<=` the ceiling, the
     **newest** entry is intact and the oldest are gone. Boundary case at exactly the ceiling appends
     nothing extra
  3. seeded fuzz, 500 random entry sizes appended in a loop: the file never exceeds the ceiling. A crash
     loop filling a phone is the scenario, and one example does not cover it
  4. **no user content**: seed the plan with drug name `Prednisolone`, dose 9.5mg, note `felt rough`,
     date 2025-04-16; force an error; assert the log contains none of those literals and matches no
     `\d+(\.\d+)? ?mg` pattern anywhere
  5. `diagnosticReport()` returns `null` when no log exists, an `XFile` when it does, and calls
     `ShareGateway` **zero** times on its own — the share happens only from the user's tap
  6. ordering: an error thrown before `runApp` is captured, proving both handlers are installed as the
     first statements of `bootstrap()` and that no `runZonedGuarded` is involved
  7. `git diff --stat` shows no file under `lib/features/settings/presentation/` — a gate on the PR, not
     a test, and it belongs in the description
- **Details** — **No crash SDK. No Sentry, no Crashlytics, no telemetry core.** They are data
  collection under both stores' rules, they would change the declaration, and they contradict SPEC §5.3.
  The substitute: the two error handlers installed first in `bootstrap()` (`FlutterError.onError` and
  `PlatformDispatcher.instance.onError`, no `runZonedGuarded`) append the error, the stack, the app
  version+build (`package_info_plus`) and the platform to a **capped rolling** local file in the app's
  support directory — cap it by bytes with a documented ceiling and drop oldest, so a crash loop cannot
  fill a phone. Expose it as `Future<XFile?> diagnosticReport()`, which EPIC-11's About row calls and
  hands to the same `ShareGateway` as export; the share sheet opens **only when the user taps** it, and
  nothing is ever sent automatically. The file must contain no plan content, no dose values, no notes
  and no dates from the taper; assert that with a test that seeds a plan, forces a crash and greps the
  log for the seeded values. Because release builds are obfuscated, a user-mailed trace is decoded
  locally with `flutter symbolize -i crash.txt -d build/symbols/1.0.0+N/app.android-arm64.symbols` —
  which only works if task 9 archived the symbols, and only against *that exact build*; say that in
  `crash-policy.md` next to the retention rule for the archive.
- **Acceptance** — A deliberately triggered release-mode crash produces a log EPIC-11's existing About
  row can share, the log contains none of the seeded plan's values, and it symbolizes against the
  archived symbols. No file under `lib/features/settings/presentation/` is modified by this epic —
  a `git diff --stat` in the PR proves it.

### 8. Store listings and screenshots in four locales

- **What** — Listing copy, categories, and screenshots generated from the real app.
- **Where** — `store/listing/{en,de,fa,ckb}/`, `store/screenshots/`, `tool/store_screenshots.sh`.
- **Tests first** — *Scaffold.* Listing copy, keywords and screenshot sets are content and store state;
  there is no behaviour, and the thing that actually goes wrong — a display type silently collided into
  the wrong slot, a stray image left attached — is caught by **reading the store back after upload**,
  which is this task's acceptance and cannot be simulated locally. Two mechanical properties are worth
  a check rather than a memory: every listing locale directory holds all five required files, non-empty;
  and the required display-type dimensions are the exact ones listed here (notably not 1284×2778). The
  copy's framing is task 11's, and its banned-phrase check is written there.
- **Details** — Write title, subtitle, short and full description, and keywords per locale, sourced from
  the same wording as the ARB so the listing and the app agree. **Store-locale support is not the same
  as app-locale support, and this is where honesty is needed:** Play supports German and Persian listing
  localizations; Kurdish Sorani is very likely unavailable on both stores, and Persian may not be
  available in App Store Connect at all. Verify against the current supported-localization lists at
  submission time; where a locale is unavailable, ship the English listing for that market, say in the
  description that the app itself speaks English, German, Persian and Kurdish Sorani, and **never** let
  a missing store locale reduce what the app supports. Screenshots come from the **real app**, driven by
  the same seeded fixtures and pinned clock as the EPIC-14 sweep, with a standardized status bar, so
  successive runs differ only where the UI differs. Required sets: iPhone 6.7″ **1290×2796** and 6.5″
  **1242×2688**, iPad 13″ **2064×2752** (mandatory because of the universal device family) — and do
  **not** ship 1284×2778, which `fastlane deliver` collides into the 6.5″ slot where the ten-image cap
  then silently drops files. Play needs phone shots plus a 1024×500 feature graphic, and tablet sets if
  tablet support is declared. Capturing is not uploading: after upload, **query the store** for what is
  attached per display type and delete strays. A screenshot run leaves the iOS tree built for the
  simulator — `flutter clean` before the release build that follows.
- **Acceptance** — Every required display type has an uploaded set verified by read-back; every listing
  locale is complete; the screenshots show the app's real seeded taper, not mockups.

### 9. Build, obfuscate, archive symbols, verify on hardware

- **What** — Produce the actual artifacts and prove them on real devices.
- **Where** — `build/symbols/1.0.0+N/` (archived off-machine), `docs/release/v1.0.0-gate.md`.
- **Tests first** — *Scaffold, plus one gate written first.* Building, obfuscating and archiving symbols
  produce artifacts, not behaviour, and the R8/reflection failures this task exists to surface appear
  only in a release binary on hardware — an emulator green run would be the "green test over a
  structurally-untestable path" that is worse than an admitted gap. The hardware walk-through is a named
  manual pass, recorded with device and date. The **one** thing to write first is the debug-affordance
  gate, because it is code: append the rule group to `tool/check_bans.sh` rejecting any dev menu entry
  point, fixture-seeding call and `eraseDatabaseOnSchemaChange` in `lib/`, seed one violation, watch it
  go red, then remove it. "Proved by a grep gate, not by memory" only holds if the grep was proved too.
- **Details** —
  ```bash
  flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/1.0.0+1
  flutter build ipa       --release --obfuscate --split-debug-info=build/symbols/1.0.0+1 \
                          --export-options-plist=ios/ExportOptions.plist
  ```
  **Archive the symbol directory off-machine before anything is uploaded** — a rebuilt binary produces
  different symbols and decodes nothing. Then verify the exact artifacts on real, cheap, target-class
  hardware: install the `.aab` via Play internal app sharing or `bundletool`, and the TestFlight build
  on an iPhone; walk the daily loop (open → read the dose → tap Taken), and force-stop and relaunch
  with a plan mid-taper, confirming nothing is lost.

  > **Contract:** there is **no upgrade-over-a-previous-build step at v1.0.0**, and its absence is
  > recorded, not quietly skipped. Per CONTRACTS.md §11 the app ships **schema v1** at v1.0.0 (the
  > artificial v2-with-a-dead-column is gone), so no earlier artifact exists whose install-over would
  > migrate anything — an install-over from a same-schema build would produce a false pass on the
  > highest-consequence line in the gate. The migration harness is proven instead by
  > EPIC-05's `stepByStep` test against the generated v2 fixture and EPIC-13's `upgradePayload` ladder
  > against a v1-header payload, both in CI. Cite those two tests by name in
  > `docs/release/v1.0.0-gate.md` and cite EPIC-14's sign-off record rather than re-running them here.
  > **From v1.0.1 onward the previous *store* build is installed over, and this step returns** — put
  > that sentence in `RELEASING.md` so the next release does not have to rediscover it.

  R8 and tree-shaking only run in release, so this is the first moment a reflective plugin failure can appear;
  pay particular attention to `flutter_local_notifications` scheduling and to drift opening the database
  under an obfuscated build. Confirm no debug affordance is reachable: no dev menu, no fixture seeding,
  no `eraseDatabaseOnSchemaChange` — proved by a grep gate, not by memory.
- **Acceptance** — Both artifacts install and run cleanly on real hardware and survive a force-stop
  mid-taper; the symbol archive exists off-machine with the artifacts; the debug-affordance gate is
  green; the gate file records the upgrade step as deferred to v1.0.1 with the two fixture tests named
  in its place.

### 10. Size and cold-start budgets

- **What** — Measure and record the two numbers every future release is compared against.
- **Where** — `docs/release/budgets.md` (new).
- **Tests first** — *Scaffold.* This task records two measurements taken on one device; there is nothing
  to assert first, and a size or cold-start assertion in CI would measure the runner, not the phone.
  Verified by `budgets.md` holding today's numbers, the device they came from, and the rule that a
  future regression past them is a blocker rather than a note — which is what turns a measurement into
  a gate for the *next* release.
- **Details** — `flutter build appbundle --release --analyze-size` for bytes broken down by library and
  asset — expect the bundled Nunito and Vazirmatn faces to be a visible share, and confirm the subsetting
  actually happened. `flutter run --profile --trace-startup` on a real floor device for
  `start_up_info.json` (engine init, first frame). Record both against the SPEC's own reality: cold start
  matters here because the app is opened once a morning, every morning, for ~780 days, and the only
  launch-path `await` should be opening the database. Any future regression past these numbers is a
  release blocker, not a note.
- **Acceptance** — `budgets.md` holds today's measured numbers, the device they came from, and the rule
  for the next release.

### 11. Medical-app framing that survives review

- **What** — Position the app so review understands what it is and is not.
- **Where** — `store/listing/**`, `store/review-notes.md` (new). **Read-only** with respect to the app:
  the Welcome sheet copy and the Settings About card already exist (EPIC-11); this task verifies their
  wording holds the line and files a defect against EPIC-11 if it does not — it does not edit them here,
  because their ARB keys, goldens and parity cells were signed off in EPIC-14.
- **Tests first (TDD, for the half a machine can hold)** — `test/policy/listing_copy_test.dart`, pure
  `package:test` over `store/listing/**` and `lib/l10n/arb/*.arb`. Write and watch fail, in this order:
  1. seed one violation first — put "calculates your dose" in the English listing and confirm the test
     goes red naming the file and the phrase. A banned-phrase list that has never matched anything is
     indistinguishable from a broken one
  2. zero hits across all four listing locales and all four ARBs against the banned list —
     *calculate/calculates*, *recommends*, *optimises the dose*, *works out your taper*, *tells you what
     to take* — with the `de`, `fa` and `ckb` equivalents authored **with the translator** and committed
     beside the test, never guessed
  3. the disclaimer sentence in `app_en.arb` is byte-identical to the sentence quoted in
     `store/review-notes.md`, so the listing and the app cannot drift apart
  4. every listing locale has all five required files, non-empty
  **Honestly:** a grep cannot judge framing. It catches the sentences someone already knows are wrong;
  reading the whole listing against Guideline 1.4.1 is a human pass and stays this task's acceptance.
- **Details** — Category **Medical** on both stores (SPEC §11.5) — it is the accurate category and it
  invites more scrutiny, which is the trade being made deliberately. Google Play's health-apps
  declaration form applies to this category; complete it. The load-bearing risk is Apple's Guideline
  1.4.1: apps that **calculate medication dosages** must come from a manufacturer, hospital, university,
  health insurer or equivalent approved entity. NearlyStop must therefore never be described as
  calculating, recommending, or optimising a dose. The true description — and the one that matches the
  code — is that it **lays out a schedule the patient and their doctor already agreed**, using the
  patient-community DSNS pattern, and that the suggested step size is an editable default the user
  overrides on their doctor's instruction (SPEC §3.2). Every listing sentence, every screenshot caption
  and the app's own first-run disclaimer must hold that line. The disclaimer appears as a modal on first
  run with a single "I understand", and stays re-readable from Settings → About (SPEC §4.0); it is not
  buried in a legal page nobody opens. `store/review-notes.md` explains to a reviewer with a fresh
  install: what DSNS is and that it is a patient-community method, that the app contains no drug
  database and no interaction checking, that all dose values are entered by the user, that there is no
  account and no network, and where the disclaimer appears.
- **Acceptance** — No sentence anywhere in the listing, screenshots or app copy claims the app decides a
  dose; the reviewer note is written for someone with no history; the disclaimer's two placements are
  verified on a clean install.

### 12. SPEC §10 definition-of-done as the release gate

- **What** — Turn SPEC §10 into a tracked checklist ticked against fresh runs.
- **Where** — `docs/release/v1.0.0-gate.md` (new).
- **Tests first** — *Scaffold.* The gate file is a checklist over evidence that already exists; it
  creates no behaviour, and every line it ticks is either a test written first in an earlier epic or a
  run performed here. What it must not do is tick from memory, so the discipline that replaces a test
  is citation: each line names a test by file and case, a screenshot, a recorded run, or a section of
  EPIC-14's sign-off. A line with no citation is an untested line, and reads as one. The migration line
  carries the v1.1 deferral sentence verbatim rather than a tick.
- **Details** — Each line is ticked against a run performed for this release, never from memory of
  earlier epics: a 52-day step matches the block table exactly; the property test proves 52 days and
  26/26 old/new for every dose pair; tablet composition is correct for every reachable dose and flags
  the unachievable ones; a flare at an arbitrary day regenerates and preserves cumulative history; kill
  the app mid-taper and reopen with nothing lost; the export produces a PDF a rheumatologist could read
  (print one and look at it); every screen is usable at the largest OS text size in both themes **and
  in high contrast** (EPIC-14's four-theme contrast run and its composed-ceiling axis are the
  evidence); VoiceOver reads the Today screen as a sentence. The migration line reads: *"the migration
  harness is proven against a generated v2 schema fixture (EPIC-05) and a v1-header backup payload
  (EPIC-13); v1.0.0 ships schema v1, so there is no on-device upgrade path — first exercised at
  v1.1."* The tenth line is its own task below.

  Where EPIC-14 already ran something, **cite its record rather than re-running it** — the sign-off
  names the commit, and a second uncontrolled run is not more evidence, it is a second answer. What
  must be fresh here is anything that only exists in the release artifact: the airplane-mode run, the
  permission assertion, the size and cold-start numbers, and the printed PDF.
- **Acceptance** — Every line ticked with the date and the evidence (test name, file, screenshot, or
  the EPIC-14 sign-off section) next to it; no line ticked from memory.

### 13. Airplane-mode verification of zero network calls

- **What** — Prove the central claim of the product, by running it.
- **Where** — `docs/release/v1.0.0-gate.md` (final line), `test/policy/no_network_test.dart` (new),
  `tool/check_bans.sh` (a network rule group appended — one script, per `epics/README.md`),
  `integration_test/no_network_test.dart` (new).
- **Tests first (TDD)** — this is the one place in the epic with a genuine red-first loop, and it is the
  product's central claim. `test/policy/no_network_test.dart` (pure `package:test`) plus an
  `integration_test` that makes the airplane-mode run reproducible instead of ceremonial. Write and
  watch fail, in this order:
  1. the ban rule group, negative fixture first: a file importing `package:http` turns
     `tool/check_bans.sh` red naming the rule; then one fixture each for `dio`, `google_fonts`,
     `HttpClient`, `WebSocket` and `Socket`. Only then remove the fixtures and expect green
  2. `dart pub deps --json` contains no banned package at **any** depth — write the transitive case
     first, because a direct-dependency check passes on exactly the failure that matters
  3. the runtime assertion, and it is the important one: an `integration_test` that installs
     `HttpOverrides.global` with a `createHttpClient` that **throws**, then drives the whole flow —
     first-run disclaimer, create a plan, Today, tap Taken, Schedule, Progress, generate and share an
     export, set a reminder, back up, restore. Any network call anywhere fails the test with a stack
     naming its caller. Write it before the release build exists; it will run against debug and that is
     fine — it is asserting that no code path reaches a socket, not that a permission is missing
  4. the release-manifest INTERNET check is task 5's; assert it once, there, and cite it here
  **Honestly:** iOS has no permission-level equivalent of Android's absent INTERNET, so on iOS the proof
  is layers 2 and 3 plus the on-device airplane-mode run, recorded with device, OS and date. The
  automated layers make that run a confirmation rather than the only evidence.
- **Details** — Three layers, all required. **Static:** a ban-gate rule group rejecting `package:http`,
  `dio`, `google_fonts`, `HttpClient`, `WebSocket` and `Socket` anywhere in `lib/`, plus the transitive
  dependency audit from task 6. **Manifest:** the release merged manifest contains no
  `android.permission.INTERNET` (task 5) — on Android this makes a network call impossible, not merely
  absent. **Runtime:** install the **release** artifact from a clean state on a real device, put the
  device in airplane mode with Wi-Fi and cellular off, and complete the full flow — first-run disclaimer,
  create a plan, view Today, tick Taken, browse Schedule, view Progress, generate and share an export,
  set a reminder, back up and restore. Nothing may fail, hang, or show an offline message, because there
  is nothing to be offline from. Note honestly that iOS has no permission-level equivalent of Android's
  INTERNET absence, so on iOS the proof is the dependency audit plus the airplane-mode run.
- **Acceptance** — The airplane-mode run is recorded with device, OS and date, and every step passed; the
  static gate runs in CI.

### 14. Tag, upload, read the store back, and roll out in stages

- **What** — Ship it, and watch it.
- **Where** — git tag `v1.0.0`, GitHub release with notes, store consoles.
- **Tests first** — *Scaffold.* Tagging, uploading and staging a rollout are operations on store state,
  not code; nothing here can be asserted before it happens, and the failure modes — a stray screenshot,
  an unpublished privacy answer, a territory left off — are caught by **reading the store back** rather
  than by trusting the tool that wrote it. Verified by that read-back checklist against fresh queries,
  and by the halt criterion being written down **before** the rollout starts, since a threshold decided
  while watching a graph is not a criterion.
- **Details** — Preconditions: clean tree, CI green on the release commit, the EPIC-14 sign-off present,
  notes written. Upload to the Play **internal** track and to TestFlight, then smoke-test from the store
  install — store delivery re-signs and re-compresses the artifact, so a local install is not the same
  artifact. Then **read store-side state back** rather than trusting the tool that wrote it: price and
  territory availability, screenshots attached per display type with no strays, metadata complete in
  every listing locale, App Privacy published (account-holder only), and the health-apps declaration
  submitted. There are no in-app purchases here, so the Paid Applications Agreement is not a blocker —
  state that explicitly so nobody goes looking. Tag the exact commit, attach the notes and keep the
  artifact and symbol archive with the tag. Roll out: Play internal → closed → production at
  **5% → 20% → 50% → 100%**, with a written halt criterion decided before the rollout starts (e.g. halt
  below 99.5% crash-free sessions over the first 48 hours, or on any report of a lost plan — the worst
  possible bug per SPEC §2). iOS uses phased release; note honestly that **an App Store release cannot be
  halted and rolled back**, only superseded by another build through review, which is exactly why the
  hardware verification in task 9 happens before the upload.
- **Acceptance** — `v1.0.0` tagged; both stores show the release; the read-back checklist is ticked
  against fresh queries; the rollout is staged with the halt criterion recorded in the release notes.

## Definition of done

- [ ] Every TDD task's tests were written first and observed failing before its implementation
- [ ] `version: 1.0.0+N` lives only in `pubspec.yaml`; no version hardcoded in any platform file
- [ ] No keystore, `key.properties`, `.p8` or service-account JSON tracked, now or in history; Play App Signing enrolled
- [ ] Icons and splash generated for every density on both platforms; adaptive + monochrome on Android, alpha-free 1024 on iOS; the EPIC-14 sweep cells the splash touches re-shot and overwritten
- [ ] Permission set asserted whole against the **merged** release manifest — `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, nothing else; no exact-alarm node from any source; `android.permission.INTERNET` proved absent in release and expected-present in debug
- [ ] Four locales declared to both OSes: `res/xml/locales_config.xml` + `android:localeConfig`, and `CFBundleLocalizations`; both asserted against the ARB file list
- [ ] No file under `lib/features/**/presentation/` changed by this epic; the diff proves it
- [ ] Data Safety, nutrition labels and `PrivacyInfo.xcprivacy` reconciled against a transitive dependency audit; every claim names its evidence; no absolute privacy claim anywhere
- [ ] Crash policy implemented and documented: no SDK, capped rolling local log, `diagnosticReport()` behind EPIC-11's existing About row, no user content, symbolizable
- [ ] Listings complete for every store locale the stores actually support, with the unsupported ones handled honestly
- [ ] Screenshots generated from the real app for every required display type and verified by read-back
- [ ] Artifacts built `--release --obfuscate --split-debug-info`; symbols archived off-machine before upload
- [ ] Release artifacts installed, force-stopped mid-taper and relaunched on real cheap hardware; the upgrade-over-previous step recorded as **deferred to v1.0.1** with EPIC-05's and EPIC-13's fixture migration tests named in its place
- [ ] Size and cold-start budgets measured on a floor device and recorded
- [ ] Medical framing verified: nothing claims the app decides a dose; disclaimer on first run and in Settings; reviewer note written
- [ ] `docs/release/v1.0.0-gate.md` — every SPEC §10 line ticked against a fresh run, with evidence
- [ ] Airplane-mode run completed on a clean release install; static and manifest network gates green in CI
- [ ] Tagged, uploaded, store state read back, staged rollout started with a written halt criterion
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, tests added, deferrals — and, under **Visual parity**, the re-shot launcher-icon and splash cells rather than "n/a": this epic changes no screen, but it does change the first thing the user sees
- [ ] CI green
- [ ] Merged to `main`
