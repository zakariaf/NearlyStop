# On-device pass — what was run, and what was not

**Date:** 2026-08-24
**Device:** iPhone 16 Pro simulator, iOS 18.0, debug build, Flutter 3.44.6
**Locales exercised:** `ckb` (Kurdish Sorani), `en`

This file exists so nobody reads a green suite as an on-device pass. It records
what was actually driven on a device and, more importantly, what was not.

## Run, and passed

| Step | Locale | Result |
|---|---|---|
| Cold launch from a clean install → disclaimer gate | en | Pass |
| Switch language to Kurdish, whole app | ckb | Pass — **after a fix**, see below |
| Settings renders, scrolls, reads RTL | ckb | Pass |
| Settings → Export data → OS share sheet | ckb | Pass. `NDJSON · 441 bytes`, Kurdish subject line |
| Progress renders the staircase and three stats | ckb | Pass |
| Progress → Export for my doctor → format sheet | ckb | Pass. Both options, both audience lines, the not-encrypted sentence |
| → PDF → OS share sheet | ckb | Pass. `PDF · 24 KB`, iOS offers Print and Markup, so it parses the file as a real PDF |
| The generated handout, opened and read | ckb | Pass — **after a fix**, see below |

## Two defects this pass found that the suite could not

1. **`Invalid locale "ckb-Arab"` killed Settings** the moment the language was
   switched. `intl` was handed the full language tag, and Sorani carries a
   script subtag. The suite could not see it because
   `initializeDateFormatting()` with no arguments — which every other test file
   calls — loads all 116 locales and registers a `fallback` entry that makes
   `verifiedLocale` succeed. The launch loads `en` and `de` only.
   Fixed in `formatTimeOfDay`; regression in
   `test/l10n/launch_locale_data_test.dart`, which loads exactly the two the
   launch loads.
2. **The Kurdish handout carried two `.notdef` boxes on every row.** The tablet
   breakdown is wrapped in U+2066/U+2069 so a Perso-Arabic screen does not
   reorder "1 × 5mg"; the embedded font has no glyph for a control character
   and `pdf` draws one rather than skipping it. Fixed by stripping isolates at
   the export boundary — which `bidi.dart` had already named as the rule.
   Regression in `test/features/export/dose_history_document_test.dart`.

## One observation, kept

**The PDF reorders the tablets column under RTL.** In a right-to-left
paragraph the bidi algorithm renders `2 × 5mg` as `mg5 × 2`. On screen an
isolate prevents this; in the PDF the isolate is the control character that
caused defect 2, so there is nothing to prevent it with. Left as the stated
`ckb` shaping limitation: the columns a clinician reads for the dose
(`planned`, `actual`) are ASCII and correct, the tablets column is
supplementary, and the fix is a per-cell text direction inside
`pw.TableHelper` — a layout change for a reader to judge, not a guess.

## NOT run — and these are gaps, not passes

| Step | Why not | Where it lands |
|---|---|---|
| **VoiceOver**, swipe-through of Today, verbatim transcript | The iOS Simulator's VoiceOver cannot be driven from this environment; a transcript nobody heard would be a fabrication | Release gate, EPIC-15 |
| **TalkBack** on a low-end Android | No Android hardware available here | Release gate, EPIC-15 |
| **Switch Access / Switch Control** | Same | Release gate, EPIC-15 |
| **Release build** sweep with a standardized status bar | The sweep in `sweep/` is shot from the widget harness instead; the trade is stated in `test/a11y/sweep_test.dart` | Release gate, EPIC-15 |
| **Profile-mode frame trace** of a 780-day Schedule fling on a floor device | Needs real hardware and DevTools | EPIC-15, and see `docs/perf/schedule-profile.md` |
| **Rotate every screen** mid-form and mid-scroll | Rotation is not scriptable from here; the expanded-width axis is covered as stills, which is not the same claim | Release gate, EPIC-15 |
| **Export → wipe → import on device**, including picking the file out of Files | The export half is run and passed above; the import half needs a file already in Files and a picker interaction | Release gate, EPIC-15 |
| Truncated / hand-corrupted backup fed to import, on device | Covered by six typed-refusal tests against real files; the device half is the picker, above | Release gate, EPIC-15 |
| Crash-log symbolization | Needs a release build with a dSYM | EPIC-15 |
