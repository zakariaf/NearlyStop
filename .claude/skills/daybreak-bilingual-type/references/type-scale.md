# The Daybreak type scale, in both scripts

Seven roles. Every value below is authoritative — it comes from `design/daybreak-system.html` §3, and
a number that disagrees with this table is a bug in the code, not a variant.

Two conventions before the tables:

- **`height` is a multiple of `fontSize`**, exactly like a unitless CSS `line-height`. Flutter's
  `TextStyle.height` and CSS agree here, so these numbers transfer verbatim.
- **`letterSpacing` is logical pixels**, and CSS tracking is `em`. Every `em` figure in this file must
  be multiplied by the role's size before it reaches a `TextStyle`. `-0.045em` at 72 is `-3.24`, not
  `-0.045`. This is the single most common way the mockup gets mistranslated.

## Latin (en) — Nunito

| Role | Size | Weight | height | Tracking (em) | Tracking (px) | M3 slot |
| --- | --- | --- | --- | --- | --- | --- |
| display | 72 | 800 | 1.05 | −0.045 | −3.24 | `displayLarge` |
| title | 34 | 800 | 1.25 | −0.030 | −1.02 | `displayMedium`, `displaySmall`, `headlineLarge`, `headlineMedium` |
| heading | 24 | 800 | 1.25 | −0.020 | −0.48 | `headlineSmall`, `titleLarge` |
| body-lg | 20 | 400 (800 on buttons) | 1.55 | −0.010 | −0.20 | `titleMedium`, `bodyLarge`, `labelLarge` |
| body | 17 | 400 (700 emphatic) | 1.60 | −0.010 | −0.17 | `titleSmall`, `bodyMedium` |
| label | 15 | 700 | 1.40 | +0.010 | +0.15 | `bodySmall`, `labelMedium` |
| caption | 14 | 600–800 | 1.45 | +0.020 | +0.28 | `labelSmall` |

The overline variant (the day-state chip, block-header kicker) is **caption at weight 800 with
+0.06em…+0.12em tracking and an uppercase string** — the string arrives already uppercased from the
ARB; nothing calls `.toUpperCase()` at render.

## Persian (fa) — Vazirmatn

Same roles, one transform: `height += 0.14`, every negative tracking → `0`, and display steps down.

| Role | Size | Weight | height | Tracking | Delta from Latin |
| --- | --- | --- | --- | --- | --- |
| display | **58** | 800 | **1.15** | 0 | size −14, height set explicitly (not +0.14) |
| title | 34 | 800 | 1.39 (~1.40) | 0 | height +0.14, tracking reset |
| heading | 24 | 800 | 1.39 (~1.45) | 0 | height +0.14, tracking reset |
| body-lg | 20 | 400 / 800 | 1.69 (~1.70) | 0 | height +0.14, tracking reset |
| body | 17 | 400 / 700 | 1.74 | 0 | height +0.14, tracking reset |
| label | 15 | 700 | 1.54 (~1.55) | 0 | height +0.14, tracking reset |
| caption | 14 | 600–800 | 1.59 (~1.60) | 0 | height +0.14, tracking reset |

**Display is the one hand-set exception.** `1.05 + 0.14 = 1.19` is loose for a single-line numeral, so
the Persian display is pinned at `58 / 1.15`. Every other role takes the uniform lift. The mockup's
per-row values (1.40, 1.45, 1.70, 1.74, 1.55, 1.60) are the arithmetic result rounded for CSS —
computing `+0.14` in Dart and *not* rounding is correct and matches within a rounding step.

**Why 58 and not 72.** Vazirmatn's Persian digits carry more ink and a taller x-height at the same
point size than Nunito's; `۹` at 72 optically outweighs `9` at 72 and crowds the unit label. 58 lands
them at the same perceived weight. This is an optical correction, not a fudge for overflow — the row
still has to survive 200% scaling on its own.

**Why the tracking resets.** Perso-Arabic is a joined script: letters connect along a baseline stroke.
Positive tracking snaps the joins visibly; negative tracking collides diacritics with the letters above
and below them. `0` is the only correct value, at every size. There is no Persian analogue of the
Latin display's optical tightening.

**Why no uppercase.** The script has no case. Any `text-transform: uppercase` or `.toUpperCase()` is a
no-op at best; applied to a mixed run it mangles the embedded Latin. The fa overline is plain caption
at tracking 0 — the *word* differs from the en overline, which is what carries the emphasis.

## Where each role is allowed

| Role | Allowed | Never |
| --- | --- | --- |
| display | The Today hero dose numeral, and nothing else | Any second screen, any list row, any modal |
| title | Screen titles; Progress stat values | Inside a card; more than once per screen |
| heading | Sheet titles, card headings, empty-state headings | Body copy, row labels |
| body-lg | Button labels (weight 800), lede paragraphs, schedule row dose | Dense metadata |
| body | Every sentence in the product; schedule row day label | Anything below this size that is a sentence |
| label | Field labels, chips, secondary buttons, table cells | A sentence, an explanation, a disclaimer |
| caption | Badges, tablet breakdowns (`1 × 5mg · 4 × 1mg`) | A full sentence — ever |

The two smallest roles are the ones that erode. `caption` at 14 is legible for a 3-word badge on a
tinted fill; the same 14 carrying "Take this an hour before food" is a failure for a 74-year-old, and
it will be shipped by someone who only ever saw it at 1.0× text scale on a 6.7" screen.

## Weight ladder and `boldText`

Daybreak uses four weights: 400, 600, 700, 800 — with 800 dominant on numerals and headings, which is
part of the warm-and-confident brief rather than an accident. Under `MediaQuery.boldTextOf(context)`,
step each role one stop:

| Declared | With `boldText` |
| --- | --- |
| 400 | 600 |
| 600 | 700 |
| 700 | 800 |
| 800 | 900 (synthesised on the `wght` axis; verify the shipped file's max) |

Apply the ladder in the same theme-level transform as the Persian lift, so a call site never sees it.
If the shipped variable font caps `wght` below 900, clamp to its maximum rather than letting Flutter
synthesise faux bold — synthesised bold smears Perso-Arabic joins.

## Tabular figures

| Surface | Feature | Note |
| --- | --- | --- |
| Today hero dose | `FontFeature.tabularFigures()` | Mandatory — 9 → 10 must not shift the numeral |
| Schedule row dose | `tabularFigures()` | Keeps the dose column aligned down the list |
| Progress stat values | `tabularFigures()` | Values tick during animation |
| Body copy containing a number | none | Proportional reads better in a sentence |

Verify `tnum` coverage per digit block with `fontTools` (`ttx -t GSUB`) against the exact files you
bundle. Vazirmatn's `۰-۹` may not be in the same feature record as its Latin digits; if the Persian
block is uncovered, measure the widest digit once with a `TextPainter` and reserve that width. Never
substitute `FittedBox`.

## Numerals and separators

| | en | fa |
| --- | --- | --- |
| Digits | `0-9` (U+0030–0039) | `۰-۹` (U+06F0–06F9, Extended Arabic-Indic) |
| Decimal separator | `.` | `٫` (U+066B) |
| Grouping separator | `,` | `٬` (U+066C) |
| Source | `NumberFormat.decimalPattern('en')` | `NumberFormat.decimalPattern('fa')` |

Persian is **not** Arabic-Indic: `٤٥٦` (U+066x) is the Arabic block and is wrong for fa. Never write a
digit map by hand — and normalize every numeric *input* back to ASCII before parsing
(`normalizeToAscii` in `i18n-rtl-l10n`). `1٫5` is 1.5; a digits-only normalizer turns it into 15, which
on a dose field is a ten-fold error.

## Dates

| | en | fa |
| --- | --- | --- |
| Calendar | Gregorian | Jalali (Solar Hijri) |
| Source | `DateFormat.MMMEd('en')` | `Jalali.fromDateTime(...)` from `shamsi_date` |
| Month names | intl CLDR | the package's Persian formatter (`f.mN`) |
| Storage | UTC epoch, always | UTC epoch, always |

Conversion is a dependency. Taper arithmetic — alternating-day blocks, step boundaries, the ~780-day
horizon — runs entirely on canonical `DateTime` via `clockProvider`, and the Jalali projection happens
in the last widget before the pixels.

## Text-scale checkpoints

The audience makes 200% a correctness target, not a stress test. What each role must survive:

| Role | 1.0× | 1.3× | 2.0× | Requirement at 2.0× |
| --- | --- | --- | --- | --- |
| display | 72 | 94 | 144 | Hero card grows; number and unit may stack; no clip, no ellipsis |
| title | 34 | 44 | 68 | Wraps to two lines; app bar grows or the title moves into the body |
| heading | 24 | 31 | 48 | Wraps freely inside its card |
| body-lg | 20 | 26 | 40 | Button height grows with the label; never a fixed 56 |
| body | 17 | 22 | 34 | Row reflows to a `Column`; day label never truncates |
| label | 15 | 20 | 30 | Chips wrap to a second line rather than shrinking |
| caption | 14 | 18 | 28 | Badge grows; the badge may drop below its row |

The switch from `Row` to `Column` in a schedule row is keyed off the *scaled metric*
(`MediaQuery.textScalerOf(context).scale(17)`), never off a hardcoded breakpoint and never off the raw
`textScaleFactor` — the platform scaler is non-linear on iOS and a raw factor no longer predicts the
rendered size.
