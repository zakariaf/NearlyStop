# EPIC-10 · Frame 4 parity — Progress

**Reference:** frame 4, "Progress", cropped from all four committed sheets at `+60+2966`, 780×1688
(row 2, column 1 of the 3×2 sheet, at 2× DPR).

| | Reference | App |
|---|---|---|
| light · en | `ref--04-progress--light-en.png` | `app--04-progress--light-en.png` |
| light · fa | `ref--04-progress--light-fa.png` | `app--04-progress--light-fa.png` |
| dark · en | `ref--04-progress--dark-en.png` | `app--04-progress--dark-en.png` |
| dark · fa | `ref--04-progress--dark-fa.png` | `app--04-progress--dark-fa.png` |
| 200% · en | — | `app--04-progress--light-en-200.png` |
| greyscale | — | `app--04-progress--greyscale.png` |

App captures are the committed goldens at 390×720, DPR 1, screen body only; the reference crops are
780×1688 at DPR 2 and include the phone chrome. Compare proportion and order, not pixels.

## Tier 1 — must match exactly

| Row | Verdict |
|---|---|
| "Progress" title | ✅ |
| Chart card: wash fill, `radiusLg`, hairline, `elevation.level2`, `s4` padding | ✅ |
| Overline "Your dose over time", upper case + tracking in Latin, neither in `fa`/`ckb` | ✅ cased by the ARB, never `.toUpperCase()` |
| Four gridlines in `border`, y labels 15/12/9mg, x labels at the two ends | ✅ |
| The staircase: flat treads, vertical risers, earliest date at the reading start edge | ✅ asserted as vertices, in both directions |
| Flare marks: ring + glyph, on the line | ✅ |
| Hold marks: a bracket — a different SHAPE, not a colour variant | ✅ (the reference frame has no hold to show; SPEC §4.3 requires it) |
| Today: filled dot in a ring | ✅ |
| Event line with its glyph: "2 flares recorded" | ✅ clauses drop when a count is zero |
| Start line: sunrise glyph + "Started 12 September 2024 at 15mg" | ✅ |
| Three stats: value, inline unit, label in words; the third full width | ✅ |
| Encouragement: `tintSuccess` fill, `success` border, 28pt sun | ✅ |
| "Export for my doctor", 56 tall, enabled | ✅ |
| **Never a `GridView`** for the stat grid | ✅ asserted |

## Tier 2 — measured

| Measurement | Reference | App |
|---|---|---|
| Plot height | 176 (`viewBox 0 0 320 176`) | 176 |
| Card padding | `s4` = 16 | 16 |
| Card radius | `radiusLg` | `radiusLg` |
| Stroke width | 3 | 3 |
| Flare ring | 9r, 2.5 stroke | 9r, 2.5 |
| Today marker | 6r, 3 ring | 6r, 3 |
| Stat grid gap | `s3` = 12 | 12 |

## Accepted divergences

1. **The stroke is `primaryDeep`, not the reference SVG's coral ramp.** The stroke is the only mark
   carrying this screen's information and has no text of its own, so WCAG 2.1 SC 1.4.11 asks it for
   3:1 against the card. `primary` measures 2.76:1 on the light wash. The fill underneath keeps the
   coral → amber ramp, because decoration carries no such rule. Pinned by a unit test that walks the
   token's own stops against the wash's worst stop, in both themes.

2. **The plot's bottom gutter is 32, not the SVG's ~22.** The today marker is a 6px circle centred
   on the baseline, and a gutter sized for the labels alone put half of it through "Apr 2026".

3. **End markers are pulled inside by their radius.** The path still spans edge to edge — the
   staircase is the data — but a ring centred on the last day loses half of itself to the canvas
   edge, and the today marker is the one mark a reader looks for.

4. **No overline on the stat cards.** The reference's `.stat` is a value and a label; EPIC-07's
   component had added a third line, and its semantics sentence left the NUMBER out entirely.

5. **`de` and `ckb` have no reference frame** and are judged against themselves: no truncation and
   no overflow at 1.0 and 2.0, asserted in `progress_blocks_test.dart`.

## Passes run

- light/dark × en/fa at 1.0 and 2.0 — nine committed goldens
- greyscale — the flare ring and the hold bracket still tell each other apart
- 1.51 / 1.8 / 2.0 — the chart is replaced by the history list, nothing raised
- 839 / 841 — stacked, then side by side
