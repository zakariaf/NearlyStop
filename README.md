# NearlyStop

An offline, account-free Flutter app that lays out an **alternating-day steroid
taper** for people coming off long-term prednisolone.

People with polymyalgia rheumatica or giant cell arteritis taper over two to
five years. The safe community method — *"Dead Slow and Nearly Stop"* — is an
eleven-block calendar in which the new dose arrives on progressively closer
days, runs **52 days for a single 1mg step**, and deliberately ignores that a
week has seven days in it. NearlyStop arranges the plan the patient and their
doctor already agreed, and tells them what to swallow this morning.

**It never recommends a dose.** The app arranges; the clinician decides.

## Non-negotiables

| Rule | Why |
|---|---|
| 100% offline, no account, no server, no sync | The account is the documented failure mode of the main competitor |
| No drug database | The user picks their own tablet strengths from a list they edit |
| Never recommends a dose | The legal and ethical line |
| Local notifications only | No push infrastructure |
| No LLM, **zero network calls of any kind** | Deterministic arithmetic |
| Data must survive app updates | These plans run for years; losing one is the worst possible bug |
| Never round a dose silently | An unachievable dose is flagged. This is the one unforgivable bug |
| Accessibility is correctness | The audience is overwhelmingly 60–80 years old |

**This app makes zero network calls.** No analytics, no crash reporting, no
telemetry, no font CDN. `tool/check_bans.sh` fails the build on an import that
could open a socket, and the claim is verified in airplane mode from a clean
install before every release.

## Run it

```bash
flutter pub get
flutter run
```

## Test it

```bash
flutter test
```

The full pre-PR gate sequence is in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Where things are

| Path | What |
|---|---|
| `SPEC.md` | The product spec: domain rules, screens, data model, edge cases |
| `epics/` | The 15-epic implementation plan; `CONTRACTS.md` is the arbiter |
| `design/` | The Daybreak design system and the reference screenshots |
| `.claude/skills/` | 44 skills — the conventions this repo is built to |
| `lib/core/` | Pure Dart: no Flutter, no Riverpod, no drift. Gated |
| `tool/` | The gate scripts, each with a self-test asserting both arms |

Application id / bundle id: `com.buzzjective.nearlystop`. Android and iOS only.
