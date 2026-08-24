# EPIC-14 · The full parity matrix — 6 screens × {light, dark} × {en, fa}

24 pairs. Each UI epic compared its own screens; this is the first time all six
have been laid side by side and asked whether they read as one app.

**Reference crops.** From the four committed sheets in `design/reference/`,
2600×4760 at 2× DPR, 3 columns × 2 rows, frames numbered left to right and top
to bottom. Rects derived from the CSS grid rather than hand-measured:

| # | Frame | CSS `[x, y]` | PNG crop (×2), 780×1688 |
|---|---|---|---|
| 01 | Welcome | `[27, 516]` | `+54+1032` |
| 02 | Today | `[455, 516]` | `+910+1032` |
| 03 | Schedule | `[883, 516]` | `+1766+1032` |
| 04 | Progress | `[27, 1494]` | `+54+2988` |
| 05 | Plan | `[455, 1494]` | `+910+2988` |
| 06 | Settings | `[883, 1494]` | `+1766+2988` |

The mockup's HTML furniture is left in the crop — the drawn status bar, the
bezel, the home indicator — because that is how EPIC-09, EPIC-10 and EPIC-11
cropped theirs, and a matrix cropped differently from the sheets it is meant to
supersede is not comparable to them. The furniture has no counterpart in the
app captures and is a known, expected difference.

**App captures.** `test/a11y/parity_matrix_test.dart`, at 390×844 logical /
DPR 2 — the reference frame's own size, so nothing is scaled on either side —
with `loadAppFonts()` and the shared `test/fixtures/seeded_plan.dart` fixture.
The same fixture the overflow matrix and the semantics audit use, so a sheet
and a matrix cell show the same taper.

**Two fixture differences that are not defects.** The reference's Today shows a
15-step plan and an un-ticked yesterday; the seeded fixture has one step and a
complete history, so frame 02 reads "Step 1 of 1" and carries no backfill
banner. Comparing copy and geometry, not the numbers in them.

## What this matrix found

| # | Screen | Grade | Finding | Resolution |
|---|---|---|---|---|
| 1 | Today | FIX | The context line rendered `1 / 1` and `14 / 52` — four unlabelled numbers on the one line whose job is orientation. Against frame 02 **and** against the widget's own doc comment. | Fixed: it composes `stepOfTotal` / `dayOfStep` now. |
| 2 | Today | FIX | `stepOfTotal` and `dayOfStep` declared `int` placeholders, so a Persian sentence would have carried Latin digits. Found while fixing #1. | Fixed: `String` placeholders, numerals localized by the notifier as everywhere else. |
| 3 | Today | FIX | The Taken button had no check glyph; frame 02 draws one. | Fixed: `Icons.check`, excluded from semantics. |
| 4 | all | FIX | Every capture carried Flutter's red debug banner across the top-right — a difference a reviewer has to learn to ignore, in the one artefact whose purpose is comparison. | Fixed: the harness turns it off, like the app's own `MaterialApp`. |
| 5 | Today | NOTE | The button reads "Mark as taken"; the reference reads "Taken". | Kept. EPIC-08 chose the imperative deliberately — "Taken" alone on an un-tapped button is ambiguous between a statement and a command, and the ARB records the reason. |
| 6 | Today | NOTE | The reference draws concentric decorative rings behind the numeral; the app draws one arc. | Recorded. Decorative only, carries no state, and `SunriseArcPainter` is the shipped interpretation. Not worth a repaint at this stage. |
