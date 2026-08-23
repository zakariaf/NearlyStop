# EPIC-09 · Frame 3 parity — Schedule

**Reference:** frame 3, "Schedule (blocks, not a calendar)", cropped from all four committed
sheets at CSS rect `[883, 516, 390, 844]` → PNG `+1766+1032`, 780×1688 at 2× DPR.

| | Reference | App |
|---|---|---|
| light · en | `ref--03-schedule--light-en.png` | `app--03-schedule--light-en.png` |
| light · fa | `ref--03-schedule--light-fa.png` | `app--03-schedule--light-fa.png` |
| dark · en | `ref--03-schedule--dark-en.png` | `app--03-schedule--dark-en.png` |
| dark · fa | `ref--03-schedule--dark-fa.png` | `app--03-schedule--dark-fa.png` |
| 200% · en | — (no reference; judged against itself) | `app--03-schedule--light-en-200.png` |
| greyscale | — (a pass, not a frame) | `app--03-schedule--greyscale.png` |

The app captures are the committed goldens: 390×720 at DPR 1, against the seeded fixture
(Prednisolone 10mg → 9mg, 5mg + 1mg tablets, halves on, clock pinned to 2026-04-16). The
reference crops are 780×1688 at DPR 2 and include the phone chrome, the status bar and the tab
bar; the app captures are the screen body only. Compare proportions and order, not pixels —
`daybreak-visual-parity` sets that standard and Chrome and Flutter will never agree on a
rasterised glyph.

## Tier 1 — must match exactly

| Row | Verdict |
|---|---|
| "Schedule" title, trailing chevron as a 44pt bordered circle with `shadow-1` | ✅ fixed this epic; it was a bare glyph |
| Block header: tinted card, `radiusLg`, hairline, leading glyph tile | ✅ `BlockHeader`, EPIC-07 |
| Current block's header uses the primary tint and `border-current-block` | ✅ |
| Header line sizes: title `--fs-body` (17), summary `--fs-label` (15) | ✅ fixed this epic; both were one step too large |
| Row order: header → rows in date order → next header | ✅ |
| Middle column is `.sday` over `.stab`; trailing column is `.sdose` over `.sstate` | ✅ fixed this epic; the breakdown was in the trailing column |
| Tablet separator is a comma (U+060C in Perso-Arabic) | ✅ fixed this epic; it was a middot |
| State word uppercase + `.06em` tracking in Latin, neither in `fa`/`ckb` | ✅ fixed this epic |
| A glyph beside the state word as well as in the marker | ✅ fixed this epic |
| Today row: 2px `stateToday` border, `elevation.level2` | ✅ |
| Missed row: dashed border and word in `stateMissed`, never `danger` | ✅ asserted in both themes |
| Trailing column end-aligned | ✅ |
| **No cell is a calendar square** | ✅ two gates: `no_calendar_grid_test.dart` and a `check_bans.sh` rule |

## Tier 2 — measured, ±2 logical px

| Measurement | Reference | App |
|---|---|---|
| List inset from the screen edge | `s5` = 20 | 20 |
| Row internal padding | `s3` / `s4` = 12 / 16 | 12 / 16 |
| Gap between rows | `s2` = 8 | 8 (`s1` above + `s1` below) |
| Row min height | 64 | 64 |
| Marker diameter | 26 | 28 (EPIC-07's fixed marker; stated there) |
| Header padding | `s4` = 16 | 16 |
| Header radius | `radiusLg` | `radiusLg` |
| Chevron button | 44 × 44 | 44 × 44 |

## Accepted divergences

1. **The first frame opens on the current block, with no previous-block tail above it.** The
   reference frame shows block 2's tail, block 3's header and block 4's header — more than one
   viewport from a standing start. EPIC-09 task 4's acceptance is explicit and machine-checked:
   `controller.offset == 0.0` on the first frame with the current block's header inside the top
   120px. `center:` puts offset zero at the current block, so history lives at negative offsets
   and is one drag away. The reference frame is a scrolled state.

2. **The day-state markers are EPIC-07's abstract shape vocabulary** — filled disc, hollow ring,
   ring-with-core, dashed ring — rather than the reference's glyph-inside-a-circle. That was
   EPIC-07's documented decision with its own goldens, and the epic says a component's tokens are
   settled there and not here. The reference's second channel is restored a different way: the
   state glyph now sits beside the state word, which is where a greyscale reader looks anyway.

3. **The block header's leading tile carries one glyph for every block**, where the reference uses
   a calendar for past blocks and a sunrise for the current one. EPIC-07's `BlockHeader.leadingGlyph`.
   The current block is still distinguished by tint, border and position.

4. **`de` and `ckb` have no reference frame.** They are judged against themselves for overflow and
   line count: `schedule_adaptive_test.dart` covers German at 200% just over the two-pane
   breakpoint, which is where the longest strings in the app meet the narrowest list.

## Passes run

- light/dark × en/fa at 1.0 and 2.0 — nine committed goldens
- greyscale — every state still answerable from shape and word
- `de` at 200%, two-pane and single-pane
- landscape phone (844×390): summary dropped, title kept, header still pinned
- 1024×768: two panes, one column of rows
