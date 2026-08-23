# EPIC-11 · Frames 1, 5 and 6 parity — Welcome, Plan, Settings

**Reference:** frames 01 (Welcome), 05 (Plan) and 06 (Settings), cropped from all four committed
sheets. Rects re-dumped from `design/daybreak-screens.html` at `--window-size=1300,2380`, never
hard-coded:

| # | Frame | CSS rect `[x, y, w, h]` | PNG crop (×2) |
|---|---|---|---|
| 01 | Welcome | `[27, 516, 390, 844]` | `+54+1032`, 780×1688 |
| 05 | Plan | `[455, 1494, 390, 844]` | `+910+2988`, 780×1688 |
| 06 | Settings | `[883, 1494, 390, 844]` | `+1766+2988`, 780×1688 |

| | Reference | App |
|---|---|---|
| 01 light · en | `ref--01-welcome--light-en.png` | `app--01-welcome--light-en.png` |
| 01 light · fa | `ref--01-welcome--light-fa.png` | `app--01-welcome--light-fa.png` |
| 01 dark · en | `ref--01-welcome--dark-en.png` | `app--01-welcome--dark-en.png` |
| 01 dark · fa | `ref--01-welcome--dark-fa.png` | `app--01-welcome--dark-fa.png` |
| 05 light · en | `ref--05-plan--light-en.png` | `app--05-plan--light-en.png` |
| 05 light · fa | `ref--05-plan--light-fa.png` | `app--05-plan--light-fa.png` |
| 05 dark · en | `ref--05-plan--dark-en.png` | `app--05-plan--dark-en.png` |
| 05 dark · fa | `ref--05-plan--dark-fa.png` | `app--05-plan--dark-fa.png` |
| 06 light · en | `ref--06-settings--light-en.png` | `app--06-settings--light-en.png` |
| 06 light · fa | `ref--06-settings--light-fa.png` | `app--06-settings--light-fa.png` |
| 06 dark · en | `ref--06-settings--dark-en.png` | `app--06-settings--dark-en.png` |
| 06 dark · fa | `ref--06-settings--dark-fa.png` | `app--06-settings--dark-fa.png` |
| 200% · en | — | `app--0{1,5,6}--light-en-200.png` |
| `de` | — | `app--0{1,5,6}--light-de.png` |
| `ckb` | — | `app--0{1,5,6}--light-ckb.png` |
| language picker · fa | — | `app--06-settings--language-picker-fa.png` |

App captures are the committed goldens, DPR 1, screen body only; the reference crops are 780×1688 at
DPR 2 and include the phone chrome and the tab bar. Compare proportion and order, not pixels.

## Tier 1 — must match exactly

| Row | Verdict |
|---|---|
| **Frame 1** — sunrise seal above the heading, gradient-filled circle | ✅ `SunriseSeal`, the gradient's only appearance outside a primary action |
| Frame 1 — heading and paragraph centred, heading two steps up the ladder | ✅ `headlineMedium`, `TextAlign.center`, gate only |
| Frame 1 — "✓ I understand", full width, sunrise fill | ✅ `PrimaryPillButton(glyph: Icons.check)` |
| Frame 1 — drag handle at the top, no other chrome | ✅ |
| Frame 1 — the gate cannot be dismissed | ✅ `PopScope(canPop: false)`, asserted |
| **Frame 5** — card order: summary · strengths · method | ✅ asserted by `dy` order |
| Frame 5 — white card on the cream page, `radiusLg`, `level1` | ✅ `DaybreakCard`, shared with Settings |
| Frame 5 — card headings are upper-case overlines with tracking in Latin | ✅ cased by the ARB, never `.toUpperCase()`; zero tracking in `fa`/`ckb` |
| Frame 5 — "Medicine", "Current dose", "Target" in that order | ✅ |
| Frame 5 — strength chips: tinted fill, `primary` ring, tablet glyph, **biggest first** | ✅ |
| Frame 5 — "I can split tablets" with its state in a word beneath | ✅ "On"/"Off" |
| Frame 5 — three method segments, the chosen one a raised white tile | ✅ |
| Frame 5 — every method label whole, the long one wrapped | ✅ measured allocation, asserted in both directions |
| **Frame 6** — card order: reading/reminders · backup · about | ✅ |
| Frame 6 — every row's glyph in a 44pt tinted rounded square | ✅ `GlyphTile`, scales with the text |
| Frame 6 — "Daily reminder" with "On · 8:00" beneath, switch trailing | ✅ |
| Frame 6 — "Text size" with the size **in a word** trailing | ✅ "Normal / Large / Larger / Largest" |
| Frame 6 — "High contrast" with "Off" beneath | ✅ |
| Frame 6 — "BACKUP" overline inside the card, two outlined pills | ✅ |
| Frame 6 — "Read the disclaimer again" with a trailing chevron | ✅ |
| Frame 6 — the privacy footnote with its lock glyph | ✅ |
| Never `primary` for a label — it measures 2.76:1 in light | ✅ asserted by a render-tree walk on all three screens |

## Tier 2 — measured

| Measurement | Reference | App |
|---|---|---|
| Card radius | `radiusLg` | `radiusLg` |
| Card padding | `s4` = 16 | 16 |
| Card fill | `surface` (white) | `surface` |
| Overline tracking | +0.06em, Latin only | `DaybreakTypography.overline` |
| Glyph tile | 44 square, `radiusMd` | 44 × text scale |
| Row minimum height | 56 | 56 |
| Primary action height | 56 | `PrimaryPillButton.minHeight` = 56 |
| Seal diameter | 96 | 96 × text scale |
| Settings reading column | — | capped at 640 above `medium` |

## Accepted divergences

1. **The Plan summary card is a FORM, not three read-only rows.** The reference frame shows
   "Prednisolone / Medicine", "Current dose 10mg", "Target 0mg" with leading glyph tiles. The epic's
   task 3 requires the fields themselves — validated, localized, disposed — and there is nowhere else
   in the app a plan can be entered. Field labels and order match the reference's row labels and order
   exactly; the leading tiles are dropped, because a 44pt tile inside a text field doubles its height
   at the largest OS text size, on the screen where German already runs longest.

2. **The Welcome gate is a full-screen surface, not a sheet over a dimmed Today.** EPIC-06 owns the
   route and made it opaque deliberately: on a cold first run the redirect fires with nothing beneath
   it, and a translucent page renders a sheet over emptiness. The sheet's own shape — rounded top,
   drag handle, inset — is kept. The consequence visible in the capture is the empty band below the
   paragraph, which the reference fills with the screen behind.

3. **The text-size slider has Material's track, not the reference's gradient.** A gradient track needs
   a custom `SliderTrackShape`; the track carries no information the thumb position does not, and the
   two "A" size markers either side are present. Revisit in EPIC-14 if the design review asks.

4. **The tab bar is absent from every app capture.** The goldens capture the screen body; the shell is
   EPIC-06's and has its own parity evidence.

5. **The Settings screen carries a Language card and an About card the reference frame does not show.**
   Frame 6 is cut off below "Read the disclaimer again". Both are this epic's own scope (CONTRACTS §13
   and SPEC §5.5) and follow the same card and row recipes.

## No-reference passes

- **`de`** — the longest-string locale. "Vorhandene Stärken", "Nächster Schritt", "Erneut lesen" and
  "Am größten" all fit; the method control reflows to a list at 390pt because "Prozentsatz" cannot
  share a row with "Dead Slow and Nearly Stop"'s German name, which is the measured behaviour, not a
  threshold.
- **`ckb`** — its own script pass. Perso-Arabic joins intact, zero overline tracking, numerals in the
  U+06Fx block, direction mirrored throughout.
- **200%** — no clipping on any of the three; the Plan step pair wraps rather than truncating, and the
  Welcome seal and heading scroll with the body.
