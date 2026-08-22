# NearlyStop — product specification

An offline, account-free planner for people coming off long-term steroids using the patient-community **"Dead Slow and Nearly Stop" (DSNS)** method.

It answers one question every morning — *what do I swallow today?* — and one question every few weeks — *am I doing this right?* It lays out a plan the patient and their doctor already agreed. It never recommends a dose.

**Platform-agnostic.** Nothing below assumes Flutter, Swift or React Native.

---

## 1. Who it is for

People with polymyalgia rheumatica (PMR) or giant cell arteritis (GCA) tapering prednisolone over two to five years, overwhelmingly aged 60–80, plus the spouse or adult child who helps them. Realistic reachable audience: tens of thousands worldwide.

Two consequences that drive every decision below:

- **Accessibility is a v1 requirement, not polish.** Large type, high contrast, real VoiceOver/TalkBack labels, generous tap targets. If a 78-year-old cannot read the Today screen at arm's length, the app has failed regardless of how correct the maths is.
- **They will not create an account** to read their own pill schedule, and they have no reason to put a chronic illness on someone's server.

---

## 2. Non-negotiables

| Rule | Why |
|---|---|
| 100% offline, no account, no server, no sync | Ethos of the series, and the account is the documented failure mode of the main competitor |
| No drug database | The user picks their own tablet strengths from a list they edit. Avoids licensed content entirely |
| Never recommends a dose | Legal and ethical line. The app arranges a plan the user enters |
| Local notifications only | No push infrastructure |
| No LLM, no network calls of any kind | Deterministic arithmetic. Also the video's hook against the "AI taper" competitor |
| Data must survive app updates | These plans run for years. Losing them is the worst possible bug |

---

## 3. The domain rules

This section is the whole product. Get it right and the rest is layout.

### 3.1 The DSNS pattern

One **step** = reducing by one increment (e.g. 10mg → 9mg). Each step runs **eleven blocks**, once each, in this order:

| Block | Pattern | Days | Cumulative |
|---|---|---|---|
| 1 | 1 day new, 6 days old | 7 | 7 |
| 2 | 1 day new, 5 days old | 6 | 13 |
| 3 | 1 day new, 4 days old | 5 | 18 |
| 4 | 1 day new, 3 days old | 4 | 22 |
| 5 | 1 day new, 2 days old | 3 | 25 |
| 6 | 1 day new, 1 day old | 2 | 27 |
| 7 | 1 day old, 2 days new | 3 | 30 |
| 8 | 1 day old, 3 days new | 4 | 34 |
| 9 | 1 day old, 4 days new | 5 | 39 |
| 10 | 1 day old, 5 days new | 6 | 45 |
| 11 | 1 day old, 6 days new | 7 | **52** |

Then the new dose every day, and that dose becomes the "old" dose of the next step.

**52 days per step. 26 days at the old dose, 26 at the new.** In the first half you take the new dose on exactly one day per block and the gap between those days shrinks (6, 5, 4, 3, 2, 1). At the midpoint the roles invert: the old dose becomes the single occasional day and the new-dose runs grow (2, 3, 4, 5, 6).

**Ordering within a block.** The counts are canonical; whether the single day leads or trails its block is our choice. Decision for v1: **the single day always leads.** Block 6 (`1 new, 1 old`) therefore ends on an old day and block 7 (`1 old, 2 new`) opens on one, producing two consecutive old days at the crossover. This is accepted and correct — do not "fix" it by reordering, and do not let a future refactor silently change it.

**Blocks run once each in v1.** Some patients hold longer at a block when symptoms grumble. v1 supports this through *Hold* (§5.2), not by repeating blocks automatically.

### 3.2 Step size

```
suggestedStep = largest achievable increment ≤ 10% of currentDose
achievable increments = sums/halves of the tablet strengths the user holds
```

In practice this gives 1mg steps at 10mg and above, and 0.5mg steps at 5mg and below — which matches what the community actually does. **Between 10mg and 5mg the strict 10% rule and common practice diverge** (10% of 9mg is 0.9mg, but people still step 1mg). So the suggested step is a *default the user can override*, never a lock. Their rheumatologist may have said something different, and that instruction wins.

### 3.3 Tablet composition

Given a target dose and the strengths held, find counts minimising **(a)** total tablets, then **(b)** number of split tablets.

```
dose = Σ (strengthᵢ × countᵢ)  [+ one optional half tablet if splitting allowed]
```

Example with 5mg, 1mg held and halves allowed: `6.5mg → 1 × 5mg + 1 × 1mg + ½ × 1mg`.

If a dose is **not achievable** with the held strengths, say so plainly on the day cell rather than rounding silently. Silent rounding in a dosing app is the one unforgivable bug.

### 3.4 Scale, so the UI is designed for the right thing

From 10mg to zero, at 1mg steps down to 5mg then 0.5mg steps:

```
10 → 5  :  5 steps × 52 days  = 260 days
 5 → 0  : 10 steps × 52 days  = 520 days
                        total ≈ 780 days ≈ 2.1 years
```

**This app is opened daily for two years.** Design for the thousandth open, not the first. Onboarding is a one-time cost; the Today screen is the product.

---

## 4. Screens

**Five screens**, plus one first-run modal.

### 4.0 First run — disclaimer (modal, once)

One short screen: this app arranges a plan you and your doctor agreed, it does not give medical advice, always follow your doctor's instructions. Single "I understand" button. Re-readable later from Settings. Not a screen in the tab bar.

### 4.1 Today *(home)*

The screen that matters. Opened ~780 times.

- **Today's dose in very large type** — readable at arm's length without glasses
- **Tablet breakdown as physical counts**: `1 × 5mg · 2 × 1mg · ½ × 1mg`
- **One big Taken button.** Tapping it is the entire daily interaction
- Quiet context line: `Step 3 of 15 · 10mg → 9mg · day 14 of 52`
- A subtle marker of whether today is a new-dose or old-dose day (colour + label, never colour alone)
- Yesterday's state if it was never ticked, with one tap to backfill
- Secondary actions, not competing for attention: add a note, **Hold**, **Flare**

**Must feel perfect:** answering "what do I swallow this morning" in one glance, with no scrolling and no navigation.

### 4.2 Schedule

The generated plan for the current step.

**Design decision, and it is the product's core idea: do not render a month grid.** A 7-column calendar is exactly what defeats these patients — it is why "what's happening on the other 4 days?" is the most-asked question on the forum. Instead render a **vertical list of days grouped by block**, with a header per block:

```
Block 3 of 11 — one day at 9mg, then 4 days at 10mg
  Mon 14 Apr   9mg    1 × 5mg, 4 × 1mg      ✓
  Tue 15 Apr  10mg    2 × 5mg               ✓
  Wed 16 Apr  10mg    2 × 5mg               ·
  ...
```

- Today pinned and highlighted; scrollable backwards and forwards
- Each row: weekday, date, dose, tablets, state (taken / missed / future)
- Past steps browsable read-only
- Jump-to-today control

The block headers teach the structure. That is a feature, not decoration.

### 4.3 Progress

Why they keep going, and what the rheumatologist wants.

- Dose-over-time chart: the staircase from starting dose to today
- Cumulative total mg taken, and days on steroids since day one
- Flares and holds marked on the timeline
- Adherence, stated gently and never as a streak to break: `taken 341 of 350 days`
- **Export**: a clean PDF/CSV of dose history to print or hand over, generated locally and shared via the OS share sheet

### 4.4 Plan

Set up and adjust the taper. Used at setup, then every ~52 days.

- Drug name (free text, default "Prednisolone")
- Current dose, target dose
- Tablet strengths held — editable list, plus "I can split tablets"
- Method: **DSNS** (default), plain percentage, or fixed mg
- Start date
- Next step preview: `9mg → 8mg, suggested step 1mg (10% of 9mg is 0.9mg — your doctor's instruction wins)`, with the step editable
- Start-next-step action when a step completes

### 4.5 Settings

- Daily reminder on/off and time (one local notification)
- Text size and high-contrast toggle, on top of OS settings
- **Backup**: export/import the whole database as a file. This is the offline substitute for cloud sync and it is v1, not v2 — a lost two-year plan is unrecoverable otherwise
- Re-read the disclaimer; about; version

---

## 5. Features

### 5.1 Core loop — v1 must-have

1. Create a plan: drug, current dose, target, tablet strengths, start date
2. Generate the 52-day schedule for a step, correctly, per §3.1
3. Show today's dose and tablet breakdown
4. Tick a day as taken; backfill a missed day
5. Browse the schedule forward and back
6. Complete a step and roll into the next
7. Persist everything locally and survive app restart and app update

### 5.2 Adjustment — v1 must-have

This is where every competitor fails, so it is where we must not.

- **Flare** — go back to the last dose that worked. Regenerate the schedule forward from that dose. **Preserve all history and the cumulative total.** Record the flare as an event on the timeline
- **Hold** — stay at the current block/dose for N extra days without abandoning the step
- **Edit the plan mid-step** — the doctor changes the instruction by phone; the app must absorb that without losing what came before
- **Change tablet strengths mid-taper** — a prescription changes; all *future* days recompose, past logs stay exactly as they were recorded

### 5.3 Safety and trust — v1 must-have

- Disclaimer on first run, re-readable
- Never round a dose silently; flag unachievable doses
- Local-only, stated plainly in the UI and the store listing
- Export before anything destructive (e.g. deleting a plan)
- No analytics, no telemetry, no crash SDK that phones home

### 5.4 Accessibility — v1 must-have

- Dynamic type to the largest OS setting without clipping
- Contrast meeting WCAG AA; never colour alone to convey state
- VoiceOver/TalkBack labels that read naturally: *"Today, 9 milligrams: one 5 milligram tablet, four 1 milligram tablets. Not yet taken."*
- Tap targets ≥ 44pt/48dp
- Works in landscape (people prop tablets on a kitchen table)

---

## 6. Data model

Persist **facts only**. Everything else is derived.

```
TaperPlan
  id, drugName, startDate, startingDose, targetDose,
  tabletStrengths[], allowHalves, method, percentage?, createdAt

Step
  id, planId, index, fromDose, toDose, startDate,
  status: pending | active | completed | abandoned,
  patternVersion            // freeze the block table per step

DoseLog
  id, date (local date), plannedMg, actualMg, taken, takenAt?, note?

FlareEvent
  id, date, revertToDose, note?

HoldEvent
  id, stepId, fromDate, extraDays, note?

Settings
  reminderEnabled, reminderTime?, textScale, highContrast, disclaimerAcceptedAt
```

**`DayPlan` is never stored as truth.** It is produced by a pure function:

```
generateSchedule(plan, steps, flares, holds) -> [DayPlan]
```

Cache it for scroll performance if you like, but the cache must be disposable and rebuildable from the facts above.

### Why this matters architecturally

This is the spine of the episode. The schedule generator is **pure**: no I/O, no clock, no database — date in, days out. That gives you:

- Flare rollback that cannot corrupt anything, because it only appends a `FlareEvent` and re-derives
- Exhaustive unit tests with no mocks: assert block lengths sum to 52, assert 26/26 old/new, assert tablet composition, assert a flare at day 30 regenerates identically every time
- A domain layer with zero framework dependency, which is the transferable lesson whatever platform you pick

`patternVersion` on `Step` exists so that if the block table is ever corrected, historical steps still render exactly as the patient lived them.

---

## 7. Edge cases v1 must handle

"Really works" means these, specifically:

- **Dates, not durations.** Store local calendar dates. Never compute a day index from elapsed seconds, or DST will shift someone's dose
- **Time zone change** — flying does not reshuffle the schedule
- **Midnight rollover** while the app is open: Today must roll over
- **Missed days** — a day never ticked stays "missed" and does not block progress
- **Backdating** — ticking three days late must work; several competitor reviews complain about exactly this
- **Dose not achievable** with held strengths — flagged, never silently rounded
- **Half tablets** only offered when the user said they split
- **Target reached** — the taper ends cleanly rather than generating a step to a negative dose
- **Step size larger than the remaining gap to target** — clamp to the target
- **Deleting a plan** requires confirmation and offers an export first
- **App update** must migrate the database, with a migration test in CI

---

## 8. Explicitly out of v1

Cut these and say so on camera; each one is a whole episode's worth of scope:

- Symptom or pain tracking beyond one free-text note per day
- Multiple concurrent tapers, or any drug other than the single one being tapered
- Hyperbolic / liquid microtapering and dilution arithmetic
- Any drug database, interaction checking, or side-effect information
- Sharing with a clinician over a network; any account or sync
- Widgets, watch app, Live Activities
- Health-platform integration
- Localisation beyond one language
- Photo of the pill organiser
- Charts beyond the single dose-over-time staircase

---

## 9. Version two — the fancy things

Ordered by value, not by ease:

1. **Symptom log with overlay** — a 0–10 morning stiffness score plotted against the dose staircase. The single most-requested thing on the forum, and it makes flares legible in hindsight
2. **Widget / lock-screen complication** — today's dose and tablets without opening the app. High value for the daily user
3. **Carer mode** — export a read-only plan file a spouse or adult child can open in the same app on their phone. Still no server: a file, not sync
4. **Repeating blocks** — proper support for holding at a block N times rather than as a flat day extension
5. **Other taper methods** — hyperbolic reduction, liquid microtapering with dilution maths, for the antidepressant and benzodiazepine audiences
6. **Multi-drug** — tapering two things at once
7. **Health platform export** — Apple Health / Health Connect
8. **Localisation** — the PMR community is strongly represented in the UK, US, Canada, Australia, Germany and the Netherlands
9. **Print-optimised A4 sheet** — a wall-calendar-style printout for people who want paper alongside the app
10. **Themes and appearance**

---

## 10. Definition of done for v1

Ship when all of these are true:

- [ ] A 52-day step generates correctly and matches the block table byte for byte
- [ ] A property test proves every generated step is 52 days, 26 old / 26 new, for every dose pair
- [ ] Tablet composition is correct for every dose reachable with the default strengths, and flags the ones that are not
- [ ] Flare at an arbitrary day regenerates the schedule and preserves cumulative history
- [ ] Kill the app mid-taper, reopen, and nothing is lost
- [ ] Export produces a PDF a rheumatologist could actually read
- [ ] Every screen usable at the largest OS text size, in both light and dark
- [ ] VoiceOver reads the Today screen as a sentence a person would say
- [ ] A database migration test passes from v1.0 schema to v1.1
- [ ] Zero network calls — verified by running the whole app in airplane mode from a clean install

---

## 11. Decisions still open

Ones to settle before you write code, on camera if they make good content:

1. **Platform** — Flutter, Swift or React Native. Both stores are the stated goal, which argues for Flutter or RN
2. **Prednisolone vs prednisone defaults** — UK and US differ in tablet strengths. Suggest shipping a strength list the user edits, defaulting by store locale
3. **Does the first step start today or at the next block boundary?** Suggest: today, with the option to pick a start date
4. **Reminder copy** — must not read as an instruction to take medication. "Your plan for today" beats "Take your pills"
5. **Store category** — Medical vs Health & Fitness. Medical is more accurate and invites more review scrutiny
6. **Name of the daily action** — "Taken" is honest; "Done" is softer. Ask a real patient
