# EPIC-01 — Foundation, tooling & CI

**Branch:** `epic/01-foundation-and-ci`
**Depends on:** nothing — this is the first epic

## Where we are now

The repository is documents and mockups. At root: `SPEC.md`, `idea-shortlist.md`,
`idea-research-notes.md`, `50-apps-challenge-slides.html`, a four-line `.gitignore`
(`.DS_Store`, `*.log`, `.idea/`, `.vscode/`), `design/` (six HTML files plus
`design/reference/daybreak-screens-{light,dark}-{en,fa}.png`), `epics/README.md`, and
`.claude/skills/` with 44 skills.

There is **no Flutter app**. No `pubspec.yaml`, no `lib/`, no `test/`, no `android/`, no `ios/`, no
`.github/`. Nothing in the repo compiles, and there is no gate that could tell you if it did.

## Why this epic exists

Every other epic assumes a package that builds, an analyzer that fails on an info, and a CI run that
blocks a merge. None of that exists yet, and none of it can be retrofitted cheaply — a lint promoted
to error after 4,000 lines are written is a week of cleanup, and a `pubspec.lock` added late means
every earlier "it worked on my machine" was unverifiable.

It also exists because the app's promises are structural, not behavioural. "Zero network calls,"
"no telemetry," "no `google_fonts`," "no raw hex outside `lib/theme/`," "no `DateTime.now()`" are all
properties of the *source graph*. A passing test cannot prove an import is absent; a grep can. The
static-gate scaffolding has to be in place before the first import lands, so that the first violation
is a red build rather than an archaeology exercise fourteen epics later.

Finally, the scaffolding has to be created **in place**. `flutter create` in a non-empty directory
will happily overwrite `.gitignore` and drop a `README.md`, and this repo's `design/` and `.claude/`
directories are the design contract and the entire skill library. Losing either is not recoverable
from the scaffold.

## What we will have when it is done

`flutter pub get && flutter analyze && flutter test` runs clean from a fresh clone on a machine that
has never seen this project. The app builds and launches to a placeholder screen on Android and iOS.
Opening a pull request runs a pinned CI workflow whose every job maps to a named contract, and a red
job blocks the merge. A new contributor is pointed at `.claude/skills/flutter-conventions-index`
before they write a line.

## Skills to load

| Skill | What it governs for this epic |
|---|---|
| `flutter-conventions-index` | The house rules the whole repo inherits; the file `CONTRIBUTING.md` points at |
| `project-structure-and-packages` | Single-package, feature-first tree: `lib/features/` over `core/ data/ services/ routing/ theme/ l10n/`, thin `main.dart`, mirrored `test/` |
| `lint-and-style-config` | `analysis_options.yaml` on a version-pinned `very_good_analysis` include, silence-bugs promoted to error, generated-file excludes |
| `dependency-hygiene` | Caret ranges in `pubspec.yaml`, committed `pubspec.lock`, the SDK version record, the refuse-by-policy dependency gate |
| `dart3-idioms-and-coding-standards` | Language level, `sealed`/pattern usage, what the promoted lints are actually protecting |
| `naming-conventions` | File, directory, class and provider naming so the structure stays greppable |
| `dartdoc-conventions` | The doc-comment bar for `lib/core/` public API, applied from the first file |
| `ci-pipeline-and-gates` | `.github/workflows/ci.yml`: pinned runner + toolchain, format/analyze/test, static greps, coverage-as-report |
| `codegen-and-toolchain` | Where generated code will live and the freshness-gate shape EPIC-05 will fill in |
| `testing-strategy` | `test/` layout, `flutter_test_config.dart`, the per-file coverage floor vs the global report |

## Tasks

### 1. Scaffold the Flutter app without clobbering the repo

- **What** — Generate the Flutter project in a scratch directory and copy it into the repo root,
  merging rather than overwriting the files that already exist.
- **Where** — creates `pubspec.yaml`, `lib/main.dart`, `android/`, `ios/`, `.metadata`; edits
  `.gitignore`.
- **Tests first** — *Scaffold.* Generating a project and merging it into a directory asserts nothing
  about this app's behaviour; a test here would only prove `flutter create` works. Verified by the
  Acceptance below (`git status` clean under `design/`, `.claude/`, `epics/`; `flutter run` boots the
  counter app) and by the CI job task 5 wires up.
- **Details** —
  ```bash
  flutter create --org com.buzzjective --project-name nearlystop \
                 --platforms=android,ios --template=app /tmp/ns_scaffold
  rsync -a --exclude '.gitignore' --exclude 'README.md' --exclude 'test/' \
        /tmp/ns_scaffold/ /path/to/E05/
  ```
  Application id / bundle id is `com.buzzjective.nearlystop` — record it here because EPIC-15 must
  use the identical string for both store listings, and changing it after a store upload is
  impossible. **Android and iOS only**: no `web/`, `macos/`, `linux/`, `windows/`. Those platforms
  are not shipping, and a dead `web/` directory would put an unused `dart:html` code path inside the
  no-network audit surface.
  Do **not** lock orientation in `AndroidManifest.xml` or `Info.plist` — SPEC §5.4 requires landscape
  ("people prop tablets on a kitchen table"), which is the default and must stay that way.
  `.gitignore`: take Flutter's template, **delete the `pubspec.lock` line** (this is an application,
  and the committed lock is what makes a stranger's clone resolve the versions that were tested —
  `dependency-hygiene` rule 2), and re-append the repo's existing four entries. Never ignore
  `design/reference/*.png`.
- **Acceptance** — `git status` shows no deletion or modification under `design/`, `.claude/`,
  `epics/`, or the root markdown files. `flutter run` puts the default counter app on a device.
  `pubspec.lock` is tracked.

### 2. Lay down the feature-first directory skeleton

- **What** — Create the empty-but-real tree every later epic writes into, with a `.gitkeep` or a
  first real file per directory so the shape is visible in review.
- **Where** — `lib/main.dart`, `lib/bootstrap.dart`, `lib/app.dart`, `lib/providers.dart`,
  `lib/core/`, `lib/core/time/clock.dart`, `lib/core/result.dart`, `lib/data/`, `lib/services/`,
  `lib/routing/`, `lib/theme/`, `lib/l10n/`, `lib/features/`, and the mirror under `test/`.
- **Tests first (TDD)** — the directory tree itself is *Scaffold* (a `.gitkeep` cannot be wrong in a
  way a test catches). `lib/core/result.dart` is not. Write `test/core/result_test.dart` first, pure
  `package:test` — and note that this file importing neither `flutter_test` nor `package:flutter/` is
  itself the purity claim task 6 gates. Write and watch fail, in this order:
  1. `switch (Ok<int, StubFailure>(7)) { Ok(:final value) => value, Err() => -1 }` → `7`
  2. the same switch over `Err<int, StubFailure>(StubFailure('boom'))` reaches the `Err` arm and
     yields a failure whose `message` is `'boom'`
  3. the void arm: `Ok<void, StubFailure>(null)` constructs, matches the `Ok` arm, and exposes no
     value — **there is no `Unit`**, asserted in the same run by a `Process.run` grep for `\bUnit\b`
     under `lib/`, so EPIC-12/13's `Result<Unit, F>` cannot land by accident
  4. equality is by value: two `Err(StubFailure('boom'))` are `==`, `Ok(7)` and `Ok(8)` are not —
     this is what makes every later `expect(result, Ok(...))` in EPIC-04/05 mean anything
  Exhaustiveness (a `switch` missing an arm) and the `F extends Failure` bound are **compile**
  failures, not test failures: prove each once on a deliberately broken sample, watch
  `flutter analyze --fatal-infos` go red, delete it — the same never-trust-green ritual as task 4.
- **Details** — `main.dart` is three lines: `void main() => bootstrap();`. `bootstrap.dart` is the
  composition root — for now it calls `WidgetsFlutterBinding.ensureInitialized()` and
  `runApp(const ProviderScope(child: NearlyStopApp()))`; EPIC-02 adds `LicenseRegistry`, EPIC-06 adds
  the error net and provider overrides. `app.dart` holds a plain `MaterialApp` with a placeholder
  `Scaffold` home — EPIC-02 attaches the theme, EPIC-03 attaches the localization delegates, EPIC-06
  replaces it with `MaterialApp.router`.
  Create `lib/core/result.dart` now with the `Result<T, F extends Failure>` type and the `Failure`
  base. The void arm is spelled `Result<void, F>` throughout the codebase; **there is no `Unit`
  type** — say so in the file's dartdoc, because EPIC-12 and EPIC-13 currently write `Result<Unit, F>`
  and must be read as `Result<void, F>`.
  **Split the clock into a pure seam and a provider.** `lib/core/time/clock.dart` holds the `Clock`
  abstraction over `package:clock` and **imports nothing else** — no Riverpod, no Flutter.
  `lib/providers.dart` (outside `lib/core/`) holds `final clockProvider = Provider<Clock>(...)`.
  Both are imported by EPIC-04 and EPIC-05, and putting them down now means the `DateTime.now()`
  grep gate in task 6 has somewhere legitimate to point.
  > **Contract:** CONTRACTS.md §1 and §2 — `Clock` is `lib/core/time/clock.dart`, `package:clock`
  > only, no Riverpod; `clockProvider` lives in `lib/providers.dart` **outside** the purity-gated
  > tree. A `clockProvider` inside `lib/core/` makes EPIC-04's purity gate either red on arrival or
  > (if written against `flutter_riverpod`, whose URI contains neither `package:flutter/` nor
  > `package:riverpod`) green on the exact violation it exists to catch. **EPIC-05 task 7's
  > "re-exported from EPIC-01" must point at `lib/providers.dart`, not `lib/core/clock.dart`.**
  **No `utils/`, `helpers/`, `common/`, `misc/` or `shared/` directory, ever.** A feature folder never
  imports another feature folder.
- **Acceptance** — `tool/check_structure.sh` (copied from
  `.claude/skills/project-structure-and-packages/scripts/`) passes. `lib/core/` imports nothing from
  `package:flutter`, `package:riverpod`, `package:flutter_riverpod` or `package:hooks_riverpod` —
  including `lib/core/time/clock.dart`, which is the file most likely to acquire one.

### 3. `pubspec.yaml` — the dependency spine, caret ranges only

- **What** — Declare only what EPIC-01–03 actually need; later epics add their own and own the audit.
- **Where** — `pubspec.yaml`.
- **Tests first** — *Scaffold.* Declaring dependencies has no behaviour to assert; a test that `intl`
  resolves is a test that pub works. Verified by `flutter pub get` resolving from a cold cache,
  `bash tool/audit-deps.sh` clean, and a committed `pubspec.lock`. The refusal list
  (`google_fonts`, `firebase_*`, `sentry_flutter`, `http`/`dio`, `dynamic_color`) becomes a **gate**
  in task 6, which is where it gets its both-arms test — a promise in a comment is not a gate.
- **Details** —
  ```yaml
  environment:
    sdk: ^3.7.0            # VERIFY against the Flutter version you pin in task 5
  dependencies:
    flutter: { sdk: flutter }
    flutter_localizations: { sdk: flutter }
    flutter_riverpod: ^3.0.0
    riverpod: ^3.0.0       # lib/core/ and lib/data/ import this directly; only the widget
                           # layer uses flutter_riverpod. VGA's depend_on_referenced_packages
                           # makes the undeclared import an analyzer error under --fatal-infos.
    go_router: ^17.0.0     # current major is 17 (14 → 17 changed StatefulShellRoute/redirect);
                           # EPIC-06 must check its builder signatures against 17.x
    intl: ^0.20.2          # flutter_localizations pins intl 0.20.2 exactly; ^0.19.0 will not resolve
    clock: ^1.1.1
    meta: ^1.15.0
  dev_dependencies:
    flutter_test: { sdk: flutter }
    very_good_analysis: ^10.0.0   # VERIFY the resolved version — see task 4
    riverpod_lint: ^3.0.0
  flutter:
    uses-material-design: true
    generate: true          # turns on gen-l10n; EPIC-03 adds l10n.yaml
  ```
  Deliberately **not** here: `drift` (EPIC-05 owns it), `shamsi_date` (EPIC-03),
  `flutter_local_notifications` + `timezone` (EPIC-12), `share_plus`/PDF (EPIC-13). Each of those
  gets a transitive audit in its own epic rather than a blanket add now.
  **Refused by policy, permanently:** `google_fonts`, `firebase_*`, `sentry_flutter`, any analytics
  or crash SDK, `http`/`dio`, `dynamic_color`. These open a network path or a telemetry path in an
  app whose store listing will claim neither. Task 6 makes the refusal a gate, not a promise.
  Record the exact tested Flutter version in `.flutter-version` at root (a bare version string) so
  CI and a stranger read the same file. **Verify before task 5 that `subosito/flutter-action@v2`
  accepts a bare version file** — its `flutter-version-file` input parses structured files
  (`pubspec.yaml`'s `environment` block, `.fvmrc` JSON), not a file containing only `3.44.6`. If it
  does not, read the file in a step (`echo "version=$(cat .flutter-version)" >> $GITHUB_OUTPUT`) and
  pass `flutter-version:`, or switch the pin to `.fvmrc`.
  > **Contract:** CONTRACTS.md §14 — `intl: ^0.20.2`. The installed `flutter_localizations` pins
  > `intl` exactly, so a wider range fails version solving on the first `flutter pub get` in the repo.
- **Acceptance** — `bash tool/audit-deps.sh` (copied from `dependency-hygiene/scripts/` — the skill
  ships `audit-deps.sh` with a hyphen and `audit_deps.py`; there is no `audit_deps.sh`, and `dart run`
  does not execute shell scripts) is clean; `pubspec.lock` is committed in the same commit as the
  `pubspec.yaml` change.

### 4. `analysis_options.yaml` — strict, and verified to actually be on

- **What** — Build on the version-pinned `very_good_analysis` include, promote the
  silence-producing bug classes to error, exclude generated code.
- **Where** — `analysis_options.yaml`, `tool/verify_include_pin.sh`.
- **Tests first (TDD)** — `analysis_options.yaml` itself is *Scaffold*; `tool/verify_include_pin.sh`
  is a gate, and **every gate script ships a self-test with both arms asserted**. Write
  `tool/verify_include_pin_selftest.sh` first (plain bash, run in CI and locally; each case plants a
  scratch file, runs the gate, asserts the exit code, greps the message, deletes the file). Write and
  watch fail, in this order:
  1. against a scratch options file naming
     `package:very_good_analysis/analysis_options.99.0.0.yaml` → exit **1**, stdout naming the
     missing filename and the resolved `very_good_analysis-*/lib/` directory it looked in
  2. against the real file, whose include filename exists in the resolved package → exit **0**
  3. the never-trust-green arm, scripted rather than done by hand: plant `print('x');` in a scratch
     `lib/` file, assert `flutter analyze --fatal-infos` exits non-zero **and names `avoid_print`**,
     delete it, assert analyze exits 0 again. A rule set that has never been seen to fail is a
     comment — and an unresolved `include:` produces exactly that, silently.
  4. the same both-arms treatment for `plugins: riverpod_lint`: plant a known riverpod-lint violation,
     assert the analyzer names the riverpod rule, delete it. If the pinned SDK does not support the
     first-party plugin protocol this case is what tells you, and the deferral gets recorded rather
     than a decorative `plugins:` block shipped.
- **Details** — Start from `.claude/skills/lint-and-style-config/examples/analysis_options.yaml`.
  ```yaml
  include: package:very_good_analysis/analysis_options.10.0.0.yaml   # filename must EXIST
  analyzer:
    exclude: [ '**/*.g.dart', '**/*.freezed.dart', '**/*.drift.dart', 'lib/l10n/gen/**' ]
    errors:
      unawaited_futures: error
      discarded_futures: error
      empty_catches: error
      use_build_context_synchronously: error
      cancel_subscriptions: error
      close_sinks: error
      avoid_dynamic_calls: error
      exhaustive_cases: error
      avoid_print: error
  plugins:
    riverpod_lint: ^3.0.0     # first-party plugin system; NEVER add custom_lint
  ```
  **The trap that makes this whole file a no-op:** if
  `analysis_options.10.0.0.yaml` does not exist in the *resolved* `very_good_analysis`, you get one
  `include_file_not_found` warning and analysis runs with **zero rules** — a green build that checks
  nothing. Verify with `ls ~/.pub-cache/hosted/pub.dev/very_good_analysis-*/lib/` and wire
  `tool/verify_include_pin.sh` as a CI step. After the check passes, confirm a **known** violation
  still errors (add a `print('x')`, watch it fail, delete it). Never trust green.
  **The `plugins:` key gets the same VERIFY treatment as the `include:` filename.** The first-party
  analyzer plugin protocol is recent, `riverpod_lint` historically shipped as a `custom_lint` plugin
  (which this task bans outright), and an unrecognised top-level key is either a silent no-op or an
  analyzer error under `--fatal-infos`. Confirm against the resolved `riverpod_lint` on the pinned
  SDK, and prove it the same way: plant a known riverpod-lint violation, watch it fail, delete it. If
  the protocol is not supported on the pinned SDK, drop the block and record the deferral — a
  decorative plugin declaration is worse than none.
  Do not restate `strict-casts`/`strict-inference`/`strict-raw-types` — VGA already sets them, and a
  restated block drifts.
  Suppressions are line-scoped with a same-line reason. `// ignore_for_file:` on a promoted rule is
  banned outright.
- **Acceptance** — `flutter analyze --fatal-infos --fatal-warnings` exits 0 on the scaffold;
  `verify_include_pin.sh` exits 0; a deliberately-added `print()` fails analysis.

### 5. The CI workflow — one file, every gate named

- **What** — `.github/workflows/ci.yml` with pinned runner and toolchain and one job per contract.
- **Where** — `.github/workflows/ci.yml`, `tool/ci_gates.sh`.
- **Tests first** — *Scaffold.* A workflow file has no behaviour a Dart test can reach, and asserting
  "GitHub runs my YAML" is asserting the framework. Every gate it calls is tested where it is built:
  task 4's include pin, task 6's ban and purity walkers, task 7's coverage floor. Verified by the
  first PR — `verify` and `build` both green on the scaffold, and a deliberately misformatted file
  turning the run red. That red arm is observed once, deliberately, not assumed.
- **Details** — Skeleton from `ci-pipeline-and-gates/references/workflow-skeleton.md`.
  ```yaml
  name: ci
  on: { push: { branches: [main] }, pull_request: }
  concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }
  permissions: { contents: read }
  jobs:
    verify:
      runs-on: ubuntu-24.04            # pinned, never -latest
      timeout-minutes: 20
      steps:
        - uses: actions/checkout@v4                # VERIFY current major
        - uses: subosito/flutter-action@v2         # v2 is current; there is no v3
          with: { channel: stable, flutter-version-file: .flutter-version, cache: true }
        - run: flutter pub get
        - run: bash tool/verify_include_pin.sh
        - run: dart format --output=none --set-exit-if-changed .
        - run: flutter analyze --fatal-infos --fatal-warnings
        - run: bash tool/check_bans.sh
        - run: bash tool/check_core_purity.sh
        - run: flutter test --test-randomize-ordering-seed random --coverage --reporter expanded
        - run: bash tool/coverage_floor.sh
    build:
      needs: verify
      runs-on: ubuntu-24.04
      steps: [ …, { run: flutter build apk --debug } ]
  ```
  Contract per gate, stated in a comment above each step: format → *whitespace is not a review
  topic*; analyze → *an info is a warning that will be ignored next week*; `check_bans.sh` → *the
  offline/no-telemetry/no-raw-token promises*; randomized test order → *free detection of inter-test
  state leakage*; build → *the app still compiles for a real target*.
  **Not yet present, and say so in a comment:** the codegen and drift-schema freshness gates. They are
  `git diff --exit-code` over generator output and land in EPIC-05 with `build_runner`. Adding an
  empty gate now that asserts nothing is worse than a named TODO.
  Never `continue-on-error: true` on a gate. CI verifies; it never blesses — no `--update-goldens`,
  no `dart format --fix`, no committing regenerated output.
  **Honest limits, written into the workflow file as a comment:** CI cannot prove real-font
  rendering, on-device notification delivery, VoiceOver phrasing, or that the app makes no network
  calls at runtime. The airplane-mode clean-install check (SPEC §10) is a manual release artifact,
  owned by EPIC-15.
- **Acceptance** — A PR against `main` runs `verify` and `build`; both green on the scaffold. A
  deliberately misformatted file turns the run red.

### 6. The static ban gate

- **What** — One accumulate-and-fail-once script holding the invariants no test can see, wired into
  CI and runnable locally.
- **Where** — `tool/check_bans.sh`, `tool/check_core_purity.sh`.
  > **Contract:** `tool/` is **the** script directory for this repo and `tool/check_bans.sh` is
  > **the** entry point CI calls. Later epics *extend* it (EPIC-02 raw values, EPIC-03 ARB parity and
  > i18n bans, EPIC-07 component patterns, EPIC-12 the plugin-import gate, EPIC-14 the a11y patterns);
  > **no epic creates a second gate under `scripts/`**, and no epic re-litigates a pattern this task
  > already ships. State that rule here so the four epics that currently say `scripts/` have somewhere
  > to be corrected against.
- **Tests first (TDD)** — `tool/check_bans_selftest.sh` and `tool/check_core_purity_selftest.sh`,
  plain bash, both wired into CI. Every rule is asserted in **both** directions — a gate that has
  never been seen to fail is a comment. Each case plants a file under a scratch path, runs the gate,
  asserts the exit code, greps the message, deletes the file. Write and watch fail, in this order:
  1. `check_bans.sh` on the clean tree → exit **0**, no output
  2. planted `import 'package:http/http.dart';` in `lib/features/_scratch.dart` → exit **1**, output
     naming `lib/features/_scratch.dart:<line>` and the *zero network calls* reason
  3. planted `EdgeInsets.only(left: 8)` in the same file → exit **1**, naming the RTL reason
  4. **both planted at once → exit 1 exactly once, with both offenders listed.** This is the
     accumulate-and-fail-once contract, and it is the case a per-rule `exit 1` silently breaks.
  5. `DateTime.now()` in `lib/features/_scratch.dart` → exit **1**; the same call in
     `lib/core/time/clock.dart` → exit **0** (the one legitimate site)
  6. `Icons.arrow_back` → exit **1**; `Icons.adaptive.arrow_back` → exit **0** — anchored to the
     structure, not matched as a substring
  7. `// ignore_for_file: unawaited_futures` → exit **1**; a line-scoped
     `// ignore: unawaited_futures — reason` → exit **0**
  8. every needle appearing inside a **stripped comment** in a `lib/` file → exit **0**, and
     `tool/check_bans.sh` itself (which contains every needle by construction) → exit **0**. A gate
     red on its own source is a gate nobody keeps.
  9. `check_core_purity.sh` on the clean tree → exit **0**
  10. planted `import 'package:flutter_riverpod/flutter_riverpod.dart';` in
      `lib/core/time/clock.dart` → exit **1**, naming path and line
  11. the same, **one separate case each**, for `package:flutter/material.dart`,
      `package:riverpod/riverpod.dart`, `package:hooks_riverpod/hooks_riverpod.dart`,
      `package:drift/drift.dart`, `package:flutter_test/flutter_test.dart` and `dart:ui`.
      `package:riverpod` is not a substring of `package:flutter_riverpod`; one loose pattern passes
      one of these six and leaves a hole the exact shape of the rest.
  12. planted `import 'package:timezone/timezone.dart';` in `lib/core/notifications/_scratch.dart` →
      exit **0**, and the identical import in `lib/core/dsns/_scratch.dart` → exit **1**. Only the
      second case proves the exception is *scoped* rather than a hole.
- **Details** — Strip comments first (a rule's own explanation contains its needle), anchor each
  pattern to a structure (an import URI, not a bare word), collect every offender, print all of them
  with a reason a stranger would understand, exit 1 once. Rules shipped in this epic:
  | Pattern | Contract |
  |---|---|
  | `import 'package:(http\|dio\|firebase_\|google_fonts\|sentry)` | zero network calls, zero telemetry, bundled fonts |
  | `DateTime.now()` outside `lib/core/time/clock.dart` | every date comes from `clockProvider`; DST and the 780-day horizon depend on it |
  | `EdgeInsets.only(\s*(left\|right):` , `Alignment.center(Left\|Right)`, `Positioned(\s*(left\|right):`, `TextAlign.(left\|right)` | RTL correctness by construction (four locales, two of them RTL) |
  | `Icons.arrow_(back\|forward)\b` | use `Icons.adaptive.*` |
  | `// ignore_for_file:` naming any rule promoted to error in task 4 | suppressions are line-scoped |
  **The purity gate ships here, not in EPIC-04.** `tool/check_core_purity.sh` walks `lib/core/**` and
  fails on any line matching an import of `package:flutter/`, `package:flutter_riverpod`,
  `package:hooks_riverpod`, `package:riverpod`, `package:drift`, `package:flutter_test`, or
  `dart:ui`. Match the four riverpod spellings separately — `package:riverpod` is **not** a substring
  of `package:flutter_riverpod`, and a gate that misses the wrapper package is a gate with a hole
  exactly the shape of the dependency it was pointed at.
  **One exception, encoded in the script rather than discovered later:** `lib/core/notifications/**`
  may import `package:timezone`. A scheduling core without `TZDateTime` cannot express "08:00 local on
  this date". `package:timezone` stays banned everywhere else under `lib/core/` and is separately
  gated outside `lib/core/` by EPIC-12 (which restricts `flutter_local_notifications` and
  `flutter_timezone` — *not* `timezone` — to the single gateway file).
  The script ships with a **self-test**: plant an offending import in a scratch file under
  `lib/core/`, assert the walker reports it by path and line, delete it. A purity gate that has never
  been seen to fail is a comment.
  > **Contract:** CONTRACTS.md §2. EPIC-04 task 8 **extends this script's file list**, it does not
  > create a second walker; `lib/core/time/clock.dart` and `lib/core/day_state.dart` are inside the
  > gated tree and must stay Flutter- and Riverpod-free.
  Two more gates land later and get their patterns appended in their own epics:
  `check_raw_values.sh` (EPIC-02) and `check_arb_parity.sh` (EPIC-03). Copy them from the skill
  `scripts/` directories rather than reinventing them.
  **A gate must never trip on itself.** The scanner's own pattern list contains every needle by
  construction, so exclude `tool/` from the scanned paths and scope each rule to the tree it governs
  (`lib/`, or a named subtree) rather than the whole repo.
  Each pattern must clear the three-criteria bar — textually decidable, silent when broken, one line
  to break. A pattern that fails the bar belongs in code review, not here.
- **Acceptance** — The script fails on a planted `import 'package:http/http.dart';` and on a planted
  `EdgeInsets.only(left: 8)`, naming both in one run, and passes on the clean tree.
  `check_core_purity.sh` fails on a planted `import 'package:flutter_riverpod/flutter_riverpod.dart';`
  in `lib/core/time/clock.dart`, and **passes** on `import 'package:timezone/timezone.dart';` in
  `lib/core/notifications/scratch.dart` — both directions asserted, because only the second proves the
  exception is real rather than accidental.

### 7. The test harness and the honest coverage story

- **What** — `test/` mirroring `lib/`, a `flutter_test_config.dart`, one real test, and a per-file
  coverage floor that is not a global percentage.
- **Where** — `test/flutter_test_config.dart`, `test/core/result_test.dart`,
  `tool/coverage_floor.sh`.
- **Tests first (TDD)** — `test/flutter_test_config.dart` is *Scaffold* (an empty hook cannot be
  wrong in a way a test catches; EPIC-02 gives it a body) and `test/core/result_test.dart` already
  exists from task 2. The new behaviour is `tool/coverage_floor.sh`, driven by
  `tool/coverage_floor_selftest.sh` against hand-written `lcov.info` fixtures under
  `tool/fixtures/lcov/` — ten lines each, no `flutter test` run inside the self-test. Write and watch
  fail, in this order:
  1. empty floor list, any fixture → exit **0**
  2. floor list naming `lib/core/dsns/step_size.dart` at 100, fixture reporting 12/12 lines → exit **0**
  3. same floor, fixture reporting 7/12 → exit **1**, message naming the path, `58.3%` and the `100%`
     floor
  4. **a listed path absent from `lcov.info` entirely → exit 1, naming the missing path.** Never a
     skip: this is the case a rename would otherwise use to disarm the floor silently, on the two
     files SPEC §10 says a bug is unrecoverable in.
  5. a fixture containing `lib/l10n/gen/app_localizations.dart` and `lib/data/db.g.dart` → both
     stripped before evaluation, using the **same globs** as the analyzer `exclude` in task 4 (assert
     the globs are read from one place, not retyped in two)
  6. an untested `lib/` file present at 0/40 lines → **reported, not gated**, and counted in the
     denominator: the aggregate percentage over the fixture *drops* when it is included. That drop is
     the coverage-lies-upward fix, asserted as a number rather than described in a comment.
- **Details** — `flutter_test_config.dart` exports `testExecutable` and will call `loadAppFonts()`
  once EPIC-02 bundles Nunito and Vazirmatn; for now it is the hook, documented as such. Goldens must
  never render with Ahem — Perso-Arabic shaping and Persian digits would never be exercised.
  **Coverage is a published report, never a global gate.** `flutter test --coverage` omits files no
  test imports, so an untested file contributes zero *denominator* lines and a single well-tested file
  can report ~100%. Fix the upward lie by including untested `lib/` files in `lcov.info`, then strip
  `**/*.g.dart`, `**/*.drift.dart` and `lib/l10n/gen/**` using the **same globs** as the analyzer
  excludes in task 4.
  `coverage_floor.sh` enforces a **file-level** floor on a short, named list of files where a bug is
  unrecoverable — seeded empty now, and filled in by the epics that create them, at the paths those
  epics actually use:
  `lib/core/dsns/schedule_generator.dart`, `lib/core/dsns/tablet_composer.dart`,
  `lib/core/dsns/step_size.dart` (all EPIC-04 — the domain is **not** a feature module, so
  `lib/features/taper/domain/…` is wrong and would silently match nothing),
  `lib/data/taper_repository.dart` and the drift migration (EPIC-05).
  Everything else is reported and not gated.
  **A listed path that is absent from `lcov.info` is a failure, not a skip**, and the message names
  the missing path. A floor keyed to a path that no longer exists is the "green build that checks
  nothing" failure mode this epic argues against two tasks earlier, and a rename would otherwise
  disarm the floor on the two files SPEC §10 says a bug is unrecoverable in.
- **Acceptance** — `flutter test --coverage` produces an `lcov.info` that lists every `lib/` file;
  `coverage_floor.sh` exits 0 with an empty list, exits 1 when a listed file drops below its floor,
  and exits 1 naming the path when a listed file is missing from `lcov.info` entirely.

### 8. Repo furniture: PR template, contributing note, CODEOWNERS-free

- **What** — The PR template the per-epic workflow assumes, and a short contributing note that routes
  a contributor to the skills instead of restating them.
- **Where** — `.github/pull_request_template.md`, `CONTRIBUTING.md`, `README.md`.
- **Tests first** — *Scaffold.* A PR template, a contributing note and a README are prose. The one
  claim in them a machine could reach ("`CONTRIBUTING.md` restates no rule that lives in a skill") is
  a review judgement, not an assertion. Verified by opening a PR and seeing the template pre-filled.
- **Details** — The PR template is verbatim the block in `epics/README.md`: **What and why · Closes ·
  Visual parity (UI epics only) · Tests · Deferred**. `CONTRIBUTING.md` is deliberately thin: the
  per-epic workflow (branch → implement → `/simplify` → `/code-review` → PR → green CI → merge), the
  statement that both quality gates run *before* the PR is opened, and a pointer to
  `.claude/skills/flutter-conventions-index` as the front door. Do not duplicate any rule that lives
  in a skill — a second copy is a copy that will drift.
  `README.md`: what NearlyStop is, the non-negotiables from SPEC §2 in one table, how to run and test,
  and an explicit "this app makes zero network calls" line that the store listing will reuse.
- **Acceptance** — Opening a PR pre-fills the template. `CONTRIBUTING.md` contains no rule that also
  exists in a skill file.

## Definition of done

- [ ] Every TDD task's tests were written first and observed failing before its implementation
- [ ] `flutter create` output merged in place; `design/`, `.claude/`, `epics/` and the root markdown
      files are untouched in `git status`
- [ ] Android + iOS only; app id `com.buzzjective.nearlystop`; orientation unlocked
- [ ] Feature-first tree present; `lib/core/` imports no Flutter and no Riverpod; no junk-drawer
      directory
- [ ] `Clock` is in `lib/core/time/clock.dart` (`package:clock` only); `clockProvider` is in
      `lib/providers.dart`, outside the purity-gated tree; `Result<void, F>` is the void arm and no
      `Unit` type exists
- [ ] `pubspec.yaml` uses caret ranges only, with `intl: ^0.20.2`, `go_router: ^17.0.0` and a direct
      `riverpod` dependency; `pubspec.lock` committed; `.flutter-version` recorded and proven to work
      with the pinned `flutter-action` input
- [ ] `analysis_options.yaml` includes a `very_good_analysis` file that provably exists, and a
      planted `print()` still fails analysis
- [ ] `flutter analyze --fatal-infos --fatal-warnings` and `dart format --set-exit-if-changed` clean
- [ ] `tool/check_bans.sh` fails on planted violations of every shipped pattern and passes on `main`;
      `tool/` is the only script directory and `check_bans.sh` the only CI entry point for greps
- [ ] `tool/check_core_purity.sh` bans Flutter/Riverpod/drift/`dart:ui` under `lib/core/**`, allows
      `package:timezone` under `lib/core/notifications/**` only, and its self-test proves both arms
- [ ] `flutter test --coverage` green with randomized ordering; `lcov.info` includes untested files
      and excludes generated code with the analyzer's globs; `coverage_floor.sh` names
      `lib/core/dsns/*` and `lib/data/taper_repository.dart` and **fails** on a missing listed path
- [ ] CI workflow pins `ubuntu-24.04` and `subosito/flutter-action@v2`; every gate carries its
      contract in a comment; the missing codegen gate is named as a TODO owned by EPIC-05
- [ ] PR template and `CONTRIBUTING.md` in place, routing to `flutter-conventions-index`
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, parity evidence, tests added,
      deferrals
- [ ] CI green
- [ ] Merged to `main`
