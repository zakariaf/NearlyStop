# NearlyStop — epic plan

Fifteen epics take this repo from "markdown and mockups" to a shipped app. One branch, one PR and one
merge per epic. Read this file before starting any epic; read `../SPEC.md` before writing any code.

> **`CONTRACTS.md` is the arbiter.** The epics were drafted in parallel and diverged at every seam —
> two dose types, two date types, two repository shapes, three spellings of the elevation slots.
> `CONTRACTS.md` settles each of those once: the canonical types and who owns them, the purity gate,
> the single `TaperRepository` API, the provider architecture, the generator's steady-state days, step
> sizing below 5mg, token slot names, formatting digits, backup ids, notifications. **Where an epic
> disagrees with `CONTRACTS.md`, `CONTRACTS.md` wins** — read it before starting any epic, and change
> it only as a deliberate act that updates every affected epic in the same commit.

## The workflow — every epic, no exceptions

```
main
 └── epic/NN-slug
       1. implement the epic's tasks in order
       2. /simplify        → fix every finding      (quality: reuse, simplification, efficiency)
       3. /code-review     → fix every finding      (correctness: the bug hunt)
       4. open PR          → description per the template below
       5. wait for CI      → green only. never merge on red, never on pending
       6. merge to main
```

**Both gates run before the PR is opened, not after.** `/simplify` is quality-only and does not hunt
bugs; `/code-review` is the bug hunt. They answer different questions, so running one is not running
the other.

### PR description template

```markdown
## What and why
<the change, and the problem it solves>

## Closes
EPIC-NN tasks 1–7

## Visual parity            (UI epics only)
<side-by-side against design/reference/…, light + dark, LTR + RTL. Attach the contact sheet.>

## Tests
<what was added; what the property/golden tests now pin>

## Deferred
<anything deliberately not done, and why>
```

## The epics

| # | Epic | Branch | Depends on |
|---|---|---|---|
| 01 | Foundation, tooling & CI | `epic/01-foundation-and-ci` | — |
| 02 | Daybreak theme & tokens | `epic/02-daybreak-theme` | 01 |
| 03 | Localization & RTL (4 locales) | `epic/03-localization-and-rtl` | 01, 02, 04 |
| 04 | DSNS domain engine | `epic/04-dsns-domain-engine` | 01 |
| 05 | Persistence & repositories | `epic/05-persistence` | 01, 04 |
| 06 | App shell, routing, state | `epic/06-app-shell` | 02, 03, 05 |
| 07 | Daybreak component library | `epic/07-component-library` | 02, 06 |
| 08 | Today screen | `epic/08-today-screen` | 06, 07 |
| 09 | Schedule screen | `epic/09-schedule-screen` | 06, 07, 08 |
| 10 | Progress screen & chart | `epic/10-progress-screen` | 06, 07 |
| 11 | Plan, Settings & Welcome | `epic/11-plan-settings-welcome` | 06, 07 |
| 12 | Local notifications | `epic/12-local-notifications` | 05, 06, 11 |
| 13 | Data portability | `epic/13-data-portability` | 05, 10, 11, 12 |
| 14 | Accessibility, perf & design review | `epic/14-a11y-and-review` | 08–13 |
| 15 | Release & store shipping | `epic/15-release` | 14 |

```
01 ─┬─ 02 ─┬─ 03 ─┬─ 06 ─── 07 ─┬─ 08 ─── 09 ────────┐
    │      │      │             ├─ 10 ────────┬──────┤
    └─ 04 ─┴─ 05 ─┘             └─ 11 ─── 12 ─┴─ 13 ─┤
                                                     └─ 14 ─── 15
```

The graph is acyclic — every edge runs from a lower number to a higher one — and it draws the spine;
the table above is authoritative where they differ in detail (05→13 and 06→08 are real edges, shown
here transitively through 12 and 07).

**04 runs in parallel with 02**, and only with 02. It is pure Dart with no Flutter imports and no
theme dependency, so it does not wait for the theme — but **03 now waits for 04**, because
`formatDose(Milligrams, Locale)` projects EPIC-04's canonical type and EPIC-03 must not define a dose
type of its own (`CONTRACTS.md` §1). Drafting 03 and 04 as parallel branches is what produced two dose
value objects at two different resolutions, one of which could not represent 0.25 mg.

After that: **08 → 09 is serial**, and **10, 11 fan out from 07 in parallel** with each other and with
08. **13 waits on 12**, because its restore path calls `syncNotifications()` and
`NotificationGateway.cancelAll()` — scheduling 13 before 12 means the restore path cannot compile.

## Repo conventions

Small things that cost a day each when two epics answer them differently.

| Thing | The answer | Why |
|---|---|---|
| Gate scripts | **`tool/`**, never `scripts/` | One directory. Two directories means two scripts with the same name and diverging rule sets. |
| Gate entry point | **`tool/check_bans.sh`** | One accumulate-and-fail-once script, created in EPIC-01 and **extended** by 02 (raw values), 07 (component patterns), 14 (a11y/RTL) and 15 (network). Later epics append rule groups; they do not create new scripts. |
| ARB files | `lib/l10n/arb/app_*.arb` | This is what `l10n.yaml`'s `arb-dir` points at. |
| App entry | `lib/app.dart`, `lib/bootstrap.dart` | Not `lib/app/`; `tool/check_structure.sh` flags the nested form. |
| Test support | `test/support/harness.dart`, goldens under `test/golden/` | One name each. |
| Shared fixture | `test/fixtures/seeded_taper.dart` | *Prednisolone, current 10mg, target 0mg, strengths 5mg + 1mg, halves on, DSNS, active step 10 → 9.5, day 14 of 52, clock pinned to 2025-04-16.* Every golden, parity capture and design-review sweep cell reads it. |

## SPEC §11 open decisions — settled, with owners

SPEC §11 lists six questions "to settle before you write code". All six are settled; this is where the
answers live, so nobody relitigates one inside a task.

| § | Question | Decision | Owner |
|---|---|---|---|
| 11.1 | Platform | **Flutter**, both stores, offline-only | EPIC-01 |
| 11.2 | Prednisolone vs prednisone defaults | A small const strength table keyed by store region, seeded on first run and **editable** — explicitly not a drug database (SPEC §2) | EPIC-11 task 3 |
| 11.3 | Does the first step start today? | **Today by default**, with a date picker to choose otherwise | EPIC-11 task 3 |
| 11.4 | Reminder copy | **"Your plan for today"** — never an instruction to take medication, and never a dose value in the notification body | EPIC-12 task 7 |
| 11.5 | Store category | **Medical** — more accurate than Health & Fitness, and the extra review scrutiny is accepted deliberately | EPIC-15 task 11 |
| 11.6 | Name of the daily action | **"Taken"** — honest over soft; "Done" hides what was done. Revisit only before EPIC-08 merges; after that it is a copy change across four ARBs, goldens and parity sheets | EPIC-08 |

## Visual parity

`design/reference/daybreak-screens-{light,dark}-{en,fa}.png` are the visual contract, captured from
`design/daybreak-screens.html` with headless Chrome at 2× DPR. Every UI epic compares its screen against
the matching frame, in light and dark, LTR and RTL. The method and the standard live in the
`daybreak-visual-parity` skill.

**Pixel-identical is not the standard and never will be.** Chrome and Flutter shape text, antialias
edges, dither gradients and compute shadow falloff differently. Parity is defined as: token values,
layout structure, element order, state signals and copy match **exactly**; measured spacing and
dimensions match **within tolerance**; rasterisation differences are **expected**. If the reference
itself is wrong, the HTML changes first and the PNGs are regenerated in their own commit — the
implementation is never the place a design decision gets made.

## Languages

| Direction | Locales |
|---|---|
| LTR | English `en`, German `de` |
| RTL | Persian `fa`, Kurdish Sorani `ckb` |

**`flutter_localizations` ships 116 locales. `de` and `fa` are among them; `ckb` is not.** Kurdish
Sorani therefore needs a custom `LocalizationsDelegate` supplying the Material/Cupertino/Widgets
strings — the practical route is delegating framework strings to `ar` or `fa` while the app's own ARB
carries every app string in ckb. EPIC-03 owns this. Budget for it; it is not free.

Two parity risks that are easy to miss: **German is the longest-string locale** and is where layouts
overflow, and **ckb needs a script pass** distinct from `fa` despite sharing the Perso-Arabic script.

**A locale nobody can select is not shipped.** Three separate pieces make the four locales reachable,
and they live in three epics, so none of them is optional: EPIC-05's `localeTag` column, EPIC-11's
**Language picker** in Settings writing it (System · English · Deutsch · فارسی · کوردیی ناوەندی, each
rendered in its own script), and EPIC-15's OS declarations — `android:localeConfig` with
`res/xml/locales_config.xml`, and `CFBundleLocalizations` — which are what make the per-app language
row appear in Android and iOS settings. Without the picker, `localeTag` is a dead column; without the
declarations, a Sorani speaker with an English phone can never reach the Sorani build from outside the
app.

## Skill index

Which epics load which skill. 44 skills are installed; `ads-and-iap-monetization` is deliberately
unused — this app has no monetization.

This table is a projection of the epics, not a second source of truth: it is generated from every
`## Skills to load` table and was verified row-for-row against them. If you add a skill to an epic,
add the epic to its row here in the same commit.

| Skill | Epics |
|---|---|
| accessibility-as-code | 02, 03, 07, 08, 09, 10, 11, 14, 15 |
| adaptive-layout | 06, 07, 08, 09, 10, 11, 14 |
| app-startup-and-bootstrap | 06, 12, 15 |
| async-safety | 04, 05, 06, 12, 13 |
| ci-pipeline-and-gates | 01, 03, 15 |
| codegen-and-toolchain | 01, 03, 05 |
| custom-canvas-and-gestures | 02, 07, 10 |
| dart3-idioms-and-coding-standards | 01, 04 |
| dartdoc-conventions | 01, 04 |
| data-export-and-restore | 13, 15 |
| daybreak-bilingual-type | 02, 03 |
| daybreak-components | 07, 08, 09, 10, 11, 14 |
| daybreak-tokens | 02, 03, 07, 08, 09, 10, 11 |
| daybreak-visual-parity | 07, 08, 09, 10, 11, 14 |
| dependency-hygiene | 01, 15 |
| design-review-workflow | 14 |
| design-system-structure | 02 |
| error-handling-typed-results | 04, 05, 06, 12, 13 |
| flutter-architecture | 06 |
| flutter-conventions-index | 01 |
| flutter-performance | 09, 10, 14, 15 |
| forms-and-input | 11 |
| i18n-rtl-l10n | 03, 06, 08, 09, 10, 11, 12, 13, 14 |
| lint-and-style-config | 01, 02 |
| local-notifications-scheduler | 12 |
| motion-and-haptics | 02, 07, 08, 14 |
| naming-conventions | 01, 04 |
| navigation-and-routing | 06, 11 |
| persistence-drift | 05, 13 |
| project-structure-and-packages | 01 |
| release-and-store-shipping | 15 |
| run-codegen | 05 |
| run-goldens-rebaseline | 14 |
| run-migration | 05 |
| scaffold-feature-module | 06, 08 |
| seeded-determinism-and-golden-vectors | 04, 13 |
| service-boundary-and-native | 05, 06, 12, 13 |
| state-management-riverpod | 06, 08, 09, 10, 11, 12 |
| testing-strategy | 01, 03, 04, 05, 12, 13 |
| ui-states-and-feedback | 06, 07, 08, 09, 11, 13 |
| value-objects-money-and-units | 03, 04, 05 |
| widget-composition | 07, 08, 09 |
| widget-golden-and-a11y-testing | 02, 07, 08, 09, 10, 11, 14 |

## Two rules that outrank everything else

**The Schedule screen is never a 7-column month grid.** A calendar grid re-creates exactly the confusion
the app exists to remove — *"what's happening on the other 4 days?"* is the most-asked question in this
patient community. The block grouping is the product. EPIC-09 tests for this.

**The schedule is a pure function, never stored.** Persist facts only — plan, steps, dose logs, flares,
holds. `generateSchedule(plan, steps, flares, holds) → [DayPlan]` derives the rest. This is what makes
flare rollback incapable of corrupting history, and what makes the domain testable without mocks.
EPIC-04 and EPIC-05 both depend on holding this line.
