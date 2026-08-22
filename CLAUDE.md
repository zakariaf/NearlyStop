# NearlyStop

An offline, account-free Flutter app that lays out an **alternating-day steroid taper** for people
coming off long-term prednisolone.

## The idea, and why it exists

People with polymyalgia rheumatica (PMR) or giant cell arteritis taper prednisolone over **two to five
years**. The safe community method — *"Dead Slow and Nearly Stop"* — is not "take 1mg less". It is an
eleven-block calendar in which the new dose is taken on progressively closer days, runs **52 days for a
single 1mg step**, and deliberately ignores that a week has seven days in it. Then each day's dose has
to be built out of the tablets you actually hold: 6.5mg is one 5mg + one 1mg + half a 1mg.

Patients try to map a 52-day non-weekly pattern onto a wall calendar, lose their place, and cut too
fast — which causes a flare that costs months. The most-asked question in their forum is *"what's
happening on the other 4 days?"*, and a moderator's standing answer is: **"Forget 7 days in the week."**

That sentence is the product. The app arranges a plan the patient and their doctor already agreed, and
tells them what to swallow this morning. **It never recommends a dose.**

Users are **overwhelmingly 60–80 years old** and open this app every morning for roughly **780 days**.
Design for the thousandth open, not the first.

Full product spec: `SPEC.md`. How the app was chosen, with the field research: `idea-shortlist.md`.

## Repo state

There is **no Flutter app yet** — no `pubspec.yaml`, no `lib/`. EPIC-01 creates it. What exists:

| Path | What |
|---|---|
| `SPEC.md` | Product spec: domain rules, screens, data model, edge cases, v1/v2 split |
| `epics/` | The 15-epic implementation plan, `CONTRACTS.md`, and `README.md` (workflow + graph) |
| `design/` | The Daybreak design system: two HTML files + `reference/` screenshots |
| `.claude/skills/` | 44 skills — 40 vendored Flutter library, 4 app-specific |
| `idea-*.md` | The field research that selected this app |

## Rules that outrank everything else

1. **Zero network calls. No account, no server, no sync, no telemetry.** This is the product's premise,
   not a preference. Verified in airplane mode from a clean install before release. `google_fonts` is
   banned for this reason — fonts are bundled.
2. **The Schedule screen is never a 7-column month grid.** A calendar grid re-creates exactly the
   confusion the app exists to remove. Block grouping is the teaching device and it is the product.
   EPIC-09 has a test asserting no `GridView`/`SliverGrid`/`CalendarDatePicker` is ever built.
3. **The schedule is a pure function, never stored.** Persist facts only — plan, steps, dose logs,
   flares, holds. `generateSchedule(plan, steps, flares, holds) → List<DayPlan>` derives the rest.
   This is what makes flare rollback incapable of corrupting history.
4. **Accessibility is correctness, not polish.** Largest OS text size on every screen without clipping,
   WCAG AA verified by test, ≥44pt targets, never colour alone, reduced motion collapses to zero.
   The audience makes this non-negotiable.
5. **Never round a dose silently.** An unachievable dose is flagged. This is the one unforgivable bug.
6. **Never recommend a dose.** The app arranges; the clinician decides.

## How to work

**Read `epics/README.md` first.** It carries the workflow, the dependency graph, the PR template and
the skill index. **`epics/CONTRACTS.md` is the arbiter** — where any epic disagrees with it, it wins.

For each epic:

```
1. branch: epic/NN-slug
2. read the epic file, and load every skill in its "Skills to load" table
3. for each task, in order:
     RED      write the named failing test, run it, watch it fail for the right reason
     GREEN    the least code that passes
     REFACTOR clean up, tests stay green
4. /simplify     → fix every finding   (quality: reuse, simplification, efficiency)
5. /code-review  → fix every finding   (correctness: the bug hunt)
6. PR with the template in epics/README.md, including parity evidence for UI epics
7. CI green — never merge on red, never on pending
8. merge to main
```

Steps 4 and 5 run **before** the PR is opened. They answer different questions: `/simplify` is quality
only and does not hunt bugs; `/code-review` is the bug hunt. Running one is not running the other.

## TDD

**Every task with behaviour is written test-first.** The test exists, runs, and fails before the
implementation does. A test written afterwards passes on its first run, which proves nothing — it can
pass for reasons nobody checked. Watching it fail *for the right reason* is the entire value.

Tasks are tagged in the epics:

- **TDD** — has behaviour. Write the named tests, watch them fail, then implement.
- **Scaffold** — no behaviour to assert (creating the project, adding a dependency, bundling a font,
  declaring a permission). Verified by the gate it enables. Do not manufacture a test that asserts the
  framework works.

**TDD governs sequence. `testing-strategy` governs tier and shape** — the cheapest tier that can assert
the behaviour, `package:test` for pure domain code, a real `NativeDatabase.memory()` for the data layer
(never a mocked DAO), `ProviderContainer` for notifiers, seeded fuzz against an independent oracle for
universal claims. Read that skill before the first test of any epic.

Two honest exceptions: **UI parity is a gate, not a driver** — you cannot write a failing screenshot
comparison before the screen exists, so goldens are written alongside the widget while its *behaviour*
is driven test-first. And **a bug found later gets a red test first too**; that test is the only thing
stopping it coming back.

## Skills

44 skills in `.claude/skills/`. Each is a playbook for one area with non-negotiable rules,
anti-patterns and a definition of done. **When a skill governs the area you are working in, read it and
follow it — do not improvise a different approach.**

- **`flutter-conventions-index` is the front door.** Its routing table maps a task to the right skill.
- Each epic's **"Skills to load"** table names exactly what that epic needs. Load those.
- 40 are the general Flutter library (architecture, Riverpod, drift, i18n, a11y, testing, CI…).
- **4 are app-specific**, and they exist because the library deliberately excludes design-token values:

| Skill | Owns |
|---|---|
| `daybreak-tokens` | The palette, radii, spacing, warm shadow stack, sunrise gradient, motion — as `ThemeExtension`s |
| `daybreak-components` | The dose hero, day-state row, block header, button ladder, chips, tab bar |
| `daybreak-bilingual-type` | Nunito + Vazirmatn, the seven-step scale, the Persian line-height lift, numerals |
| `daybreak-visual-parity` | Comparing a built screen against the reference design, and the honest standard for it |

Canonical stack the skills assume: Flutter 3.2x · Dart 3.x · **Riverpod 3.x** (`Notifier`/`AsyncNotifier`/
`StreamNotifier`; the `AutoDispose*`/`*Family` base classes were removed) · go_router · Material 3 ·
drift · intl/gen-l10n · very_good_analysis · `package:clock` via `clockProvider` (never `DateTime.now()`)
· `Result<T, F extends Failure>` · feature-first layout.

## Design

**Daybreak** — warm cream ground, coral-to-amber sunrise gradients, soft diffuse shadows, large radii.
Every dose is one more step toward the morning you are heading for. The dark theme is a warm plum-brown
night that still glows, never a cold void.

`design/reference/daybreak-screens-{light,dark}-{en,fa}.png` are the **visual contract**, captured from
`design/daybreak-screens.html` at 2× DPR. Frames in order: 1 Welcome · 2 Today · 3 Schedule ·
4 Progress · 5 Plan · 6 Settings.

**Pixel-identical is not the standard and never will be** — Chrome and Flutter shape text, antialias and
blur shadows differently. Parity means: tokens, layout structure, element order, state signals and copy
match **exactly**; measured geometry matches **within tolerance**; rasterisation differences are
expected. `daybreak-visual-parity` owns the method. If the reference is wrong, the HTML changes first
and the PNGs are regenerated — the implementation is never where a design decision gets made.

One trap worth knowing: **`primary` #F97350 measures 2.76:1 and fails AA for text.** It is
decorative-only — fills, gradient stops, accents. Never a label, a meaningful icon, or a link.

## Languages

| Direction | Locales |
|---|---|
| LTR | English `en`, German `de` |
| RTL | Persian `fa`, Kurdish Sorani `ckb` |

**`flutter_localizations` ships 116 locales. `de` and `fa` are among them; `ckb` is not.** Kurdish
Sorani needs a custom `LocalizationsDelegate` supplying the Material/Cupertino/Widgets strings. EPIC-03
owns it. Budget for it.

German is the **longest-string** locale and is where layouts overflow. `ckb` needs its own script pass
despite sharing Perso-Arabic with `fa`.

## The epics

`epics/` — 15 epics, one branch and one PR each. Start at **EPIC-01**; the graph in `epics/README.md`
gives the order and the real dependencies.

```
01 foundation & CI    06 app shell          11 plan/settings/welcome
02 daybreak theme     07 component library  12 local notifications
03 localization/RTL   08 today screen       13 data portability
04 DSNS engine        09 schedule screen    14 a11y, perf & design review
05 persistence        10 progress screen    15 release & shipping
```

## Do not

- Do not add a dependency that opens a socket, or any analytics/crash SDK that phones home.
- Do not put a raw colour, radius, duration or font size outside `lib/theme/`.
- Do not use `DateTime.now()` — the clock is injected.
- Do not store `DayPlan` as truth; derive it.
- Do not merge on red or pending CI.
- Do not skip the red step because the implementation seems obvious.
