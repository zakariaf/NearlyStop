# Releasing NearlyStop

Written for somebody who has never shipped this app. Follow it in order; the
order is the point.

---

## ⚠️ Two things are deliberately NOT done yet

**1. The bundle identifier is going to change.** It is
`com.buzzjective.nearlystop` throughout the tree today, and the owner has said
it will be replaced before anything is published. Every place it appears is
listed under *Bundle identifier inventory* below, and
`tool/check_bundle_id.sh` prints them, so the change is a mechanical sweep
rather than a hunt. **Do not upload anything under the current identifier** —
a bundle ID is permanent on both stores once a build is accepted under it.

**2. Nothing has been submitted to either store**, by instruction. Everything
short of submission is done and is described here. Section 12 is the part that
has never been run.

---

## 0. The two rules that bite

- **The build number only goes up.** `+N` in `pubspec.yaml` is Play's
  `versionCode` and Apple's `CFBundleVersion`.
- **A burned number is burned forever.** A build that was *uploaded at all* —
  even to Play internal or a TestFlight group, even if it failed processing —
  has spent its number. Bump; never retry the same one. Play's ceiling is
  2,100,000,000, so keep a plain incrementing integer and do not encode a date
  in it.

`version: 1.0.0+1` in `pubspec.yaml` is the **only** version source. Nothing is
hardcoded in `build.gradle.kts` or `Info.plist`, and
`tool/check_bans.sh` fails the build if anything ever is — with a must-fail
fixture per platform in `test/tool/check_bans_test.dart`, because a gate nobody
proved can fail is decoration.

## 1. Preconditions

- [ ] `main` is green in CI at the commit you are about to release.
- [ ] `docs/design-review/2026-08-24-signoff.md` reads **SIGNED OFF**.
- [ ] Working tree clean.
- [ ] `CHANGELOG.md` has the release's section written.

## 2. Bump

Edit `version:` in `pubspec.yaml`. Nothing else.

## 3. Build, obfuscated, with the symbols split out

```bash
flutter clean            # mandatory if the tree last built for the simulator
flutter pub get
V=1.0.0+1
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/$V
flutter build ipa       --release --obfuscate --split-debug-info=build/symbols/$V \
                        --export-options-plist=ios/ExportOptions.plist
```

`flutter clean` is not optional before an iOS release build: a tree that last
built for the simulator embeds a simulator framework slice and Apple rejects
the upload (90087 / 91169). `tool/check_ipa_slices.sh` catches it before the
upload is spent.

## 4. Archive the symbols BEFORE anything is uploaded

`build/symbols/<version>/` decodes crash traces from **that exact binary** and
nothing else. A rebuild produces different symbols and decodes nothing. Copy
the directory somewhere durable and off this machine, keyed by version, and
keep it for as long as the version is installable — see
`docs/release/crash-policy.md` for the retention rule.

## 5. Verify on real hardware

Not an emulator. R8, tree-shaking and obfuscation run only in release, so this
is the first moment a reflective plugin failure can appear — watch
`flutter_local_notifications` scheduling and drift opening the database.

- [ ] Install the `.aab` via Play internal app sharing or `bundletool`.
- [ ] Install the iOS build from TestFlight.
- [ ] Walk the daily loop: open → read the dose → tap Taken.
- [ ] Force-stop mid-taper and relaunch. Nothing lost.
- [ ] Airplane mode, everything off, and complete the whole flow
      (`docs/release/v1.0.0-gate.md`, line 10).

**There is no install-over-the-previous-build step at v1.0.0** and its absence
is recorded rather than skipped: the app ships schema v1, so no earlier
artifact exists whose upgrade would migrate anything, and an install-over from
a same-schema build would be a false pass on the highest-consequence line in
the gate. **From v1.0.1 onward the previous *store* build is the artifact to
install over, and this step returns to the list.**

## 6. Measure

`docs/release/budgets.md`. A regression past the recorded numbers is a release
blocker, not a note.

## 7. Reconcile the declarations

`docs/release/privacy-declarations.md` — every line names the file or test that
proves it. If a dependency changed since the last release, re-run
`bash tool/audit-deps.sh` first.

## 8. Two CI lanes, and which checks what

| Lane | Runs | Checks |
|---|---|---|
| **PR CI** (`ci.yml`) | every push | the whole test suite, every gate script, and the locale declarations. Records but does not fail on `INTERNET` — profile builds legitimately carry it |
| **Release** (manual dispatch) | on demand, secrets injected | the full merged-manifest assertion against a real signed release build: the whole permission set, and `INTERNET` **absent** |

## 9. Upload to internal tracks

Play **internal** track and TestFlight. Smoke-test from the **store** install,
not the local one — store delivery re-signs and re-compresses the artifact, so
they are not the same bytes.

## 10. Read the store back

Do not trust the tool that wrote it. Query for:

- [ ] price and territory availability
- [ ] screenshots attached per display type, with no strays
- [ ] metadata complete in every listing locale
- [ ] App Privacy published (account-holder only can do this)
- [ ] Play's health-apps declaration submitted

There are no in-app purchases, so the Paid Applications Agreement is **not** a
blocker. Stated so nobody goes looking for it.

## 11. Tag

Tag the exact commit, attach the notes, and keep the artifact and the symbol
archive with the tag.

## 12. Roll out — NOT DONE, by instruction

Play: internal → closed → production at **5% → 20% → 50% → 100%**.
iOS: phased release.

**Write the halt criterion down before the rollout starts.** A threshold
decided while watching a graph is not a criterion. The one for this app:

> Halt below 99.5% crash-free sessions over the first 48 hours, **or** on any
> single report of a lost plan — which is the worst possible bug in this
> product (SPEC §2).

Note honestly: **an App Store release cannot be halted or rolled back**, only
superseded by another build through review. That is exactly why the hardware
verification in step 5 happens before the upload.

---

## Bundle identifier inventory

Run `bash tool/check_bundle_id.sh` to print these live. As of this writing the
identifier `com.buzzjective.nearlystop` appears in:

| File | What | Note |
|---|---|---|
| `android/app/build.gradle.kts` | `namespace`, `applicationId` | |
| `android/app/src/main/kotlin/com/buzzjective/nearlystop/MainActivity.kt` | the `package` line **and the directory path itself** | the directories have to be renamed too, not just the declaration — this is the one the hand-written list missed, and the reason this script exists |
| `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` ×3 for Runner, ×3 for RunnerTests | the test target's is `<id>.RunnerTests` and derives from it |
| `tool/run_simulator.sh` | the `BUNDLE` it launches | |

**Nothing in Dart source hardcodes it**, and no manifest or plist does either.
EPIC-13 chose the `.ndjson` / `application/x-ndjson` route for backups rather
than a custom extension, so there is **no exported UTI keyed to the bundle ID**
to update — that decision is recorded in EPIC-13 task 1 and is why
`Info.plist` carries no `UTExportedTypeDeclarations` entry. Had it gone the
other way, the UTI would be a seventh place to change and a greyed-out file in
the iOS Files picker if it were missed.

## Signing material

Never in the repo, now or in history. `tool/check_release_hygiene.sh` checks
the working tree and the whole of `git log --all`.

- **Android.** Generate an upload keystore outside the repo.
  `android/key.properties` (gitignored) carries `storeFile`, `storePassword`,
  `keyAlias`, `keyPassword`. Gradle falls back to debug signing when it is
  absent so a local debug build still works, and **fails the release build
  loudly** rather than shipping a debug-signed artifact.
  **Enrol in Play App Signing.** A lost *upload* key is recoverable through
  support; a lost *app signing* key on an unenrolled app means the listing can
  never be updated again.
- **iOS.** The App Store Connect API key (`.p8`) lives in a secret store.
  `ios/ExportOptions.plist` carries the method and the team id; the team id in
  the committed file is a placeholder and must be replaced with the real one.

CI injects both from repository secrets at build time, never from the tree.
