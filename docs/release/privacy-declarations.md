# Privacy declarations — every line with its evidence

**The declaration is: no data collected, no data shared, no account, no
tracking.**

Every line below names the file or test that proves it. A line with no evidence
is an assertion, and an assertion is what a store form is not for.

## Play Data Safety

| Question | Answer | Evidence |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | `tool/audit_deps.py` walks the resolved tree — self-tested by planting a banned package three hops down (`test/tool/audit_deps_test.dart`). No analytics, crash SDK, ads or attribution at any depth. |
| Is all user data encrypted in transit? | **Not applicable** | Nothing is in transit. The release manifest has no `INTERNET` permission — `test/policy/permissions_test.dart` |
| Do you provide a way for users to request data deletion? | **Yes, in the app** | Settings has no account to delete; Plan → Delete plan removes everything, behind `ExportGuard`. `test/features/plan/plan_screen_test.dart` |
| Data types collected | **None** | — |
| Data types shared | **None** | — |

## App Store nutrition labels

| Section | Answer |
|---|---|
| Data Used to Track You | **None** |
| Data Linked to You | **None** |
| Data Not Linked to You | **None** |

## `ios/Runner/PrivacyInfo.xcprivacy`

| Key | Value | Why |
|---|---|---|
| `NSPrivacyTracking` | `false` | No SDK that could track. Same evidence as Data Safety row 1. |
| `NSPrivacyTrackingDomains` | empty | Nothing is contacted. |
| `NSPrivacyCollectedDataTypes` | empty | Nothing is collected. |
| `NSPrivacyAccessedAPITypes` | **empty** | Transcribed, not reasoned — see below. |

### Why the accessed-API array is empty

Apple merges the app's manifest with every embedded framework's own. Each
plugin in this build was **read**, not remembered:

| Plugin | Version | Its own manifest declares |
|---|---|---|
| `flutter_local_notifications` | 22.3.0 | `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` |
| `share_plus` | 13.3.0 | empty array |
| `file_selector_ios` | 0.5.3+5 | empty array |
| `path_provider_foundation` | 2.6.0 | ships no manifest |
| `sqlite3_flutter_libs` | 0.5.42 | ships no manifest |
| `printing` | 5.15.0 | ships no manifest |

The app's **own** code reaches no required-reason API: it reads no file
timestamp, queries no disk space, reads no system boot time and writes no
UserDefaults. Declaring a reason code for an API nothing calls is a claim that
cannot be defended at review, so the array is empty rather than padded.

## The zero-network claim, in four layers

Not one check. Four, because any single one is a claim about what somebody
remembered to look at.

| Layer | What | Where |
|---|---|---|
| Static | `package:http`, `dio`, `google_fonts`, `HttpClient`, `WebSocket`, `Socket` banned anywhere in `lib/` — each with a must-fail fixture | `tool/check_bans.sh`, `test/tool/check_bans_test.dart` |
| Dependency | The **resolved** tree, not the pubspec. A banned package three hops down fails | `tool/audit_deps.py`, `test/tool/audit_deps_test.dart` |
| Runtime | Every `HttpClient` the process can create is made to throw, then all six screens are driven in two languages | `test/policy/no_network_test.dart` |
| Manifest | `INTERNET` absent from the **release** merged manifest — on Android this makes a network call impossible, not merely absent | `test/policy/permissions_test.dart` |

iOS has no permission-level equivalent of Android's absent `INTERNET`. There
the proof is layers 1–3 plus the airplane-mode run, which is **not yet done**
and is recorded as such in `docs/release/v1.0.0-gate.md`.

### Two dependencies that look like network and are not

Both are on `audit_deps.py`'s ALLOW list, each with a written justification
rather than a shrug:

- **`timezone` → `http`.** `flutter_local_notifications` needs `timezone`,
  which declares `http` as a regular dependency. Inside it, `package:http` is
  imported by exactly one file — `lib/browser.dart` — which fetches the IANA
  database over HTTP **in a web app**. This app has no web target and imports
  the bundled database, so no code path reaches it and it is tree-shaken out
  of the AOT snapshot.
- **`riverpod` → `test` → `web_socket_channel`.** Riverpod 3 ships
  `ProviderContainer.test()` in its main library, so the test runner's
  transport tree is reachable from `dependencies:` on every Riverpod app. No
  file under `lib/` imports any of it.

Neither is trusted on the strength of that reasoning. The enforced gates are
the four layers above, and both packages are caught by the runtime layer if
the reasoning is ever wrong.

## No absolute privacy claim, anywhere

**Banned everywhere in listing and onboarding: "nothing ever leaves your
device".** It is not true — export through the share sheet is a real path the
user can take, and a privacy claim that a user can personally disprove is
worse than a modest one.

The sanctioned wording states the mechanism instead:

> Your taper is stored only in this app on this device. The app has no internet
> permission and makes no network calls. Exports leave only when you choose to
> share them.

Used in that shape in all four listing locales (`store/listing/*/`).

## Crash reporting

No SDK. A capped, rolling, local file the user can read and choose to share.
Full reasoning, the cap, the retention rule and the symbolication command:
`docs/release/crash-policy.md`.
