# Note for App Review / Play Review

Written for somebody opening this app for the first time with no history.

## What the app is

NearlyStop lays out a **steroid taper that a patient and their doctor have
already agreed**, and tells the patient what to swallow each morning.

People coming off long-term prednisolone — usually for polymyalgia rheumatica
or giant cell arteritis — taper over two to five years. The widely used
patient-community method is called **"Dead Slow and Nearly Stop" (DSNS)**. It
is not "take 1mg less": it is an eleven-block pattern in which the new, lower
dose is taken on progressively closer days, runs 52 days for a single 1mg
step, and deliberately ignores the seven-day week. Patients try to map that
onto a wall calendar, lose their place, and cut too fast — which causes a
flare that costs them months.

The app arranges that pattern and answers one question a day.

## What the app is NOT — Guideline 1.4.1

**It does not calculate, recommend, decide or adjust a medication dose.**

We are aware of Guideline 1.4.1 and have designed against it deliberately:

- **No drug database.** The app ships no medication data of any kind. The drug
  name is a free-text field the user types.
- **No interaction checking**, no contraindications, no clinical logic.
- **Every value is the user's.** Current dose, target dose, start date and the
  tablet strengths they hold are all entered by the user, from a plan they
  agreed with their doctor.
- **The step size is an editable default.** The app pre-fills a suggested step
  because typing one every time is a burden on a 78-year-old; the field is
  editable and the user changes it on their doctor's instruction. Changing it
  is a normal, expected action, not an override buried in an advanced screen.
- The DSNS **pattern** is arithmetic over the user's own numbers — which day
  the lower dose falls on — in exactly the way a paper calendar would be. It
  never chooses what that dose is.

The app also contains **no dose-safety warnings**, because inventing them would
be the clinical judgement it deliberately does not make. The one thing it does
flag is arithmetic the user can check themselves: when a dose cannot be built
from the tablet strengths they said they hold, it says so rather than silently
rounding.

## Where the disclaimer appears

Two places, both reachable without hunting:

1. **On first run**, as a modal the user cannot get past without acknowledging
   it, with a single "I understand".
2. **Settings → About → "Read the disclaimer again"**, permanently.

The sentence, verbatim:

> NearlyStop arranges the plan you and your doctor agreed. It does not give medical advice. Always follow your doctor's instructions.

## Privacy

There is nothing to review here, and that is the point:

- **No account and no sign-in.** There is no user identity of any kind.
- **No server.** There is no backend, and none is planned.
- **No analytics, no crash SDK, no ads, no attribution.**
- On **Android** the release build declares **no `INTERNET` permission at
  all** — a network call is not merely absent, it is impossible.
- The taper lives in one SQLite file in the app's own container.
- Data leaves only when the user picks a file out of the share sheet
  themselves: a backup, or a PDF/spreadsheet for their doctor.
- **Settings → Open source** opens `github.com/zakariaf/NearlyStop` in the
  system browser. It is the app's only outbound link, it carries nothing but
  the URL, and it uses `LaunchMode.externalApplication` — never an in-app
  webview, which is enforced by a build gate rather than by convention. The
  app is open source so that the claims above can be checked rather than
  taken on trust.

## How to try it

1. Open the app. Accept the disclaimer.
2. **Plan** tab → enter any drug name, a current dose (e.g. 10), a target
   (e.g. 0), and the tablet strengths (e.g. 5 and 1). Save.
3. **Today** shows the dose for today and the tablets it is made from. Tap
   "Mark as taken".
4. **Schedule** shows the 52-day step grouped into its eleven blocks.
5. **Progress** → "Export for my doctor" produces a PDF.

No network is required at any point. Airplane mode is a fine way to try it — the only thing that will not work is the Settings → Open source link,
which hands the URL to the browser and needs the phone to be online.

## Category

**Medical**, on both stores. It is the accurate category and we chose it
knowing it invites more scrutiny.
