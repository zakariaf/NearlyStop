# Schedule performance — what is measured, and what is not

**Status: structurally verified, not profiled.** No claim of frame time is made
here, because none was measured. That is the honest state and it is what the
epic asks for: *"no claim of performance is made that was not measured."*

## Measured, in CI

Laziness and rebuild scope are structural properties and are asserted as such —
these are green on every run:

| Claim | Test |
|---|---|
| One step is materialised, never the whole taper | `test/features/schedule/schedule_performance_test.dart` |
| Every row carries a stable, distinct key | same |
| No row asks for its own raster layer | same |
| The sliver delegates keep nothing alive off screen | same |
| A fling does not rebuild the whole list per frame | same |
| The schedule is derived **once** with Today, Schedule and Progress all alive | `test/a11y/one_derivation_test.dart` |
| Exactly one file in `lib/` calls `generateSchedule` | same |

The last two are new in EPIC-14 and are the ones nothing else could see: each
screen's own tests pump that screen alone, so a second derivation is invisible
until all three are up — which is the situation the app is always in.

## NOT measured

A **profile-mode trace on a floor device** — a cheap Android, a full 780-day
taper, DevTools recording a fast fling from today back to day one and forward
to the end, UI and raster thread numbers before and after, budget 16 ms.

It needs hardware this environment does not have. A frame-time assertion in CI
was deliberately not written in its place: it would be a flake, and a flaky
gate is switched off within a month.

**This lands in EPIC-15's release gate.** Until it is run, the app's
performance is *structurally sound and unmeasured*, and no store listing,
release note or sign-off may say otherwise.
