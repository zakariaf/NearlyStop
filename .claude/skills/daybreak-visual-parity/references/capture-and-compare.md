# Capture and compare — the reproducible procedure

Everything here runs with what is already on the machine: Google Chrome, the Flutter SDK, and a
POSIX shell. **ImageMagick and Pillow are not installed** — every step below avoids them. If
`magick` *is* available on your machine, the one-line alternatives are noted.

---

## 0. The frames and their order

`design/daybreak-screens.html` lays out six `.phone` frames in one grid, in this order:

| # | Frame | Screen | Notes |
|---|---|---|---|
| 01 | Welcome | Welcome / disclaimer | modal sheet drawn over the Today screen |
| 02 | Today | Today | hero dose card, sunrise gradient, Taken action |
| 03 | Schedule | Schedule | block-grouped day list — never a month grid |
| 04 | Progress | Progress | dose staircase, stats, export |
| 05 | Plan | Plan | strengths, method, next step |
| 06 | Settings | Settings | backup, language, theme |

Use the two-digit number as the basename prefix so the sheets sort in screen order.

Each frame's HTML furniture is **not the app**: a 54px drawn status bar, `border-radius: 46px`,
`box-shadow: 0 0 0 11px var(--device-shell), 0 0 0 12px rgba(0,0,0,.22), …` (two bezel rings), and
the drawn home indicator. Crop to the content box; never file a finding about any of it.

---

## 1. Regenerating the reference PNGs

Only ever run this as a **deliberate design change**, in its own commit, regenerating all four.

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
SRC=design/daybreak-screens.html
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

for theme in light dark; do
  for lang in en fa; do
    tmp="$(mktemp -t daybreak).html"
    # The mockup's initial state is the LAST line of its inline script.
    sed "s/setTheme('light'); setLang('en');/setTheme('$theme'); setLang('$lang');/" "$SRC" > "$tmp"
    "$CHROME" --headless --disable-gpu --hide-scrollbars \
      --force-device-scale-factor=2 --window-size=1300,2380 \
      --screenshot="design/reference/daybreak-screens-$theme-$lang.png" "file://$tmp"
    rm -f "$tmp"
  done
done

# Expect 2600x4760 for all four.
for f in design/reference/*.png; do
  printf '%s ' "$f"; sips -g pixelWidth -g pixelHeight "$f" | tail -2 | tr -d '\n'; echo
done
```

### Why the window size is load-bearing

- `.grid` is `repeat(auto-fit, minmax(300px, 1fr))`. At 1300 CSS px it resolves to **3 columns x 2
  rows**; narrower and it reflows, which changes every crop rect.
- `:root { --phone-scale: 1 }`, dropping to `.86` under 561px and `.72` under 471px. `.phone` is
  `transform: scale(var(--phone-scale))`. **Only at ≥561px is a frame's rendered size its layout
  size of 390x844.**
- `--force-device-scale-factor=2` gives DPR 2, so `2600x4760` px = `1300x2380` CSS px. This matches
  the app capture's DPR exactly, which is what makes a measured comparison possible at all.

### Fonts

The mockup links its webfonts over the network. A capture taken offline falls back to system faces
and is silently invalid. Before trusting a regenerated sheet, confirm the Latin frames render Nunito
and the Persian frames render Vazirmatn (see `daybreak-bilingual-type`). The app itself bundles
these faces — `google_fonts` is banned in NearlyStop.

---

## 2. Dumping the per-frame crop rects

Rects change if the HTML changes, so derive them rather than hard-coding them. Same headless Chrome,
one extra `sed` that serialises the rects into `document.title`, then `--dump-dom`:

```bash
SRC=design/daybreak-screens.html
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
tmp="$(mktemp -t rects).html"
sed -e 's#</body>#<script>document.title=JSON.stringify(\
[].map.call(document.querySelectorAll(".phone"),function(p){var r=p.getBoundingClientRect();\
return [Math.round(r.left+scrollX),Math.round(r.top+scrollY),Math.round(r.width),Math.round(r.height)];}));\
</script></body>#' "$SRC" > "$tmp"

"$CHROME" --headless --disable-gpu --window-size=1300,2380 --dump-dom "file://$tmp" \
  | grep -o '<title>.*</title>'
```

Output is six `[x, y, w, h]` CSS-px rects in frame order. Multiply every number by **2** for the
PNG's pixel coordinates. `w`/`h` should read `390`/`844`; if they do not, the window size is wrong
(see §1) and the rects are unusable.

Measured against the current `design/daybreak-screens.html` at `--window-size=1300,2380` — re-dump
after **any** edit to the mockup, and treat these as a cross-check, not a constant:

| # | Frame | CSS rect `[x, y, w, h]` | PNG crop (x2) |
|---|---|---|---|
| 01 | Welcome | `[27, 516, 390, 844]` | `+54+1032`, 780x1688 |
| 02 | Today | `[455, 516, 390, 844]` | `+910+1032`, 780x1688 |
| 03 | Schedule | `[883, 516, 390, 844]` | `+1766+1032`, 780x1688 |
| 04 | Progress | `[27, 1494, 390, 844]` | `+54+2988`, 780x1688 |
| 05 | Plan | `[455, 1494, 390, 844]` | `+910+2988`, 780x1688 |
| 06 | Settings | `[883, 1494, 390, 844]` | `+1766+2988`, 780x1688 |

**Content-box crop.** To exclude the mockup's status bar, add `54` to `y` and subtract `54` from `h`
before scaling. Keep the same crop for the app capture only if the app capture also excludes its
status bar; the simpler and preferred route is to crop the reference to the content box and capture
the app in a widget test, which has no status bar at all.

---

## 3. Cropping without ImageMagick

Chrome is already a rasteriser. Generate a one-frame HTML and screenshot it:

```bash
crop() { # crop <src.png> <x> <y> <w> <h> <out.png>   (CSS px; src assumed DPR 2)
  local src="$1" x="$2" y="$3" w="$4" h="$5" out="$6"
  local tmp="$(mktemp -t crop).html"
  cat > "$tmp" <<HTML
<style>html,body{margin:0}
.v{width:${w}px;height:${h}px;overflow:hidden;position:relative}
img{position:absolute;width:1300px;left:-${x}px;top:-${y}px;image-rendering:auto}</style>
<div class="v"><img src="file://$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"></div>
HTML
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
    --hide-scrollbars --force-device-scale-factor=2 --window-size="$w,$h" \
    --screenshot="$out" "file://$tmp"
  rm -f "$tmp"
}
```

The `width:1300px` on the `<img>` re-states the sheet's CSS width so the DPR-2 source maps 1:1 back
to CSS px; the DPR-2 screenshot then re-emits it at source resolution. Verify one crop's pixel size
is `2w x 2h` before trusting the batch.

With ImageMagick, the same thing is:
`magick sheet.png -crop ${2w}x${2h}+${2x}+${2y} +repage out.png`.

---

## 4. Capturing the implementation

Viewport is fixed: **390x844 logical, DPR 2 → 780x1688 px.**

### Widget-test lane

```dart
setUpAll(loadAppFonts);   // else every glyph is an Ahem square

tester.view
  ..devicePixelRatio = 2.0
  ..physicalSize = const Size(390, 844) * 2.0;
addTearDown(tester.view.reset);
debugDisableShadows = false;                     // default is TRUE under the test binding
addTearDown(() => debugDisableShadows = true);
```

Honest limits of this lane: no platform status bar or home indicator (a feature here), no Impeller
raster path, and `matchesGoldenFile` writes files that are also *goldens* — keep parity captures in
`parity/app/` and out of the golden lanes' directories so `run-goldens-rebaseline` never blesses
them by accident.

### Device lane

- **Android:** `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, then
  `await binding.convertFlutterSurfaceToImage()` before `binding.takeScreenshot(name)`, driven from
  a `test_driver` script that writes the bytes out.
- **iOS simulator:** drive the app to the screen, then `xcrun simctl io booted screenshot out.png`.
  Set a standardised status bar first (`xcrun simctl status_bar booted override --time 9:41
  --batteryLevel 100 --cellularBars 4`) so shots differ only where the UI differs.

### Determinism

Every capture runs against a pinned `clockProvider` and a seeded taper fixture
(`seeded-determinism-and-golden-vectors`). An unpinned clock changes the highlighted day, the stats
and the "next step" copy, and turns every comparison into noise.

---

## 5. Naming

Identical basenames on both sides, so the compare sheet pairs by name and a missing pair is obvious:

```
parity/
  ref/NN--<screen>--<theme>--<locale>.png     # cropped from design/reference/
  app/NN--<screen>--<theme>--<locale>.png     # captured from the app
  sheet.html                                   # generated pairing page
  sheet--<theme>--<locale>.png                 # the artefact pasted into the PR
```

Examples: `02--today--light--en.png`, `03--schedule--dark--fa.png`. Direction is implied by locale
(`en`/`de` = LTR, `fa`/`ckb` = RTL) and is not a separate token — this matches
`design-review-workflow`'s `NN--<screen>--<theme>--<dir>` shape, with locale carrying the direction
because parity cares which script rendered.

Non-reference passes get an explicit suffix and live only in `app/`:
`08--today--light--de--longest.png`, `02--today--light--ckb.png`, `02--today--light--en--x2.png`.

---

## 6. The full matrix

Reference-backed cells — every one has a `ref/` counterpart:

| Screen | light/en | light/fa | dark/en | dark/fa |
|---|---|---|---|---|
| 01 Welcome | ✓ | ✓ | ✓ | ✓ |
| 02 Today | ✓ | ✓ | ✓ | ✓ |
| 03 Schedule | ✓ | ✓ | ✓ | ✓ |
| 04 Progress | ✓ | ✓ | ✓ | ✓ |
| 05 Plan | ✓ | ✓ | ✓ | ✓ |
| 06 Settings | ✓ | ✓ | ✓ | ✓ |

24 pairs for the whole app; a UI epic owns only its own rows.

No-reference passes — judged against rules, not against a PNG:

| Pass | Cells | Judged against | Fails when |
|---|---|---|---|
| `de` longest-string | every screen, light/LTR | `daybreak-components` degradation order | overflow, mid-word break, ellipsis on a value, clipped label |
| `ckb` script | every screen, light/RTL | `daybreak-bilingual-type`, `i18n-rtl-l10n` | tofu, broken joining, wrong numeral system, wrong framework strings |
| 200% text scale | one light/LTR + one dark/RTL per screen | declared degradation order | clipping, clamped scaler, tap target below 44 |
| grayscale | Schedule + Today, either theme | `daybreak-components` rule 3 | a day state is unreadable without colour |

`de` and `ckb` inherit the `en` and `fa` structures respectively; they never get their own reference
PNG, and no one should invent one by hand-editing a sheet.

---

## 7. Tolerances

| Property | Method | Tolerance | On failure |
|---|---|---|---|
| token colour (any slot) | assert resolved value in a widget test | exact | implementation defect |
| corner radius (declared) | assert the `BorderRadius` value | exact | implementation defect |
| type size / weight / height / tracking | assert the `TextStyle` field | exact | implementation defect |
| spacing step (declared) | assert the `DaybreakShapes` slot used | exact | implementation defect |
| element order / nesting | read both; assert widget order where it matters | exact | implementation defect |
| state signal (shape + glyph + label) | shape assertion + `isSemantics` | exact | implementation defect |
| copy | ARB string vs the mockup's `data-en` / `data-fa` | exact | copy or ARB defect |
| RTL mirroring | directional geometry assertion in an RTL pump | exact | implementation defect |
| measured spacing / component size | `getRect` in a widget test | ±2 logical px | re-measure, then fix |
| measured offset from screen edge | `getRect` | ±2 logical px | re-measure, then fix |
| radius measured off a screenshot | eyeball at 4x zoom | ±1 logical px | assert the token instead |
| flat fill sampled at region centre | pixel sample, both images | ΔE00 ≤ 2 (≈ ≤3/255 per channel) | check the token first |
| gradient sampled at midpoint | pixel sample | ΔE00 ≤ 3 | check both stops |
| text colour | **not sampled** — glyph pixels are blends | n/a | assert the token |
| 1px hairline colour | **not sampled** — antialiased | n/a | assert the token |
| glyph shaping / hinting / subpixel | not compared | n/a | not a finding |
| antialiased edges, gradient banding | not compared | n/a | not a finding |
| shadow blur falloff / spread | not compared; assert the token | n/a | not a finding |
| status bar, home indicator, bezel | cropped out | n/a | not a finding |

ΔE00 on a flat fill is a *sanity* check on the two rasterisers agreeing, not the primary gate — the
primary gate for any colour is the asserted token value.

---

## 8. The compare sheet

```bash
# sheet.html: pairs by basename, ref left, app right, difference overlay right-most.
{
  echo '<style>html,body{margin:0;background:#333;font:12px system-ui;color:#fff}
  .row{display:flex;gap:8px;padding:8px;align-items:flex-start}
  .col{width:390px}.col img{width:390px;display:block}
  .diff{position:relative;width:390px;height:844px;background:#000;isolation:isolate}
  .diff img{position:absolute;inset:0;width:390px}
  .diff img+img{mix-blend-mode:difference}</style>'
  for f in parity/ref/*.png; do
    b="$(basename "$f")"
    echo "<div class=row><div class=col>$b<br>REF<img src=\"ref/$b\"></div>"
    echo "<div class=col>APP<img src=\"app/$b\"></div>"
    echo "<div class=col>DIFF<div class=diff><img src=\"ref/$b\"><img src=\"app/$b\"></div></div></div>"
  done
} > parity/sheet.html
```

Read the DIFF column for **shifted or missing blocks**. It lights up on every antialiased edge and
every glyph by construction — that is expected, not a finding (SKILL rule 1). A block that glows as
a solid rectangle means a size or position mismatch worth measuring; text that glows as a fuzzy
outline means the two rasterisers drew the same words differently.

Screenshot the sheet for the PR:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
  --hide-scrollbars --force-device-scale-factor=1 --window-size=1240,6000 \
  --screenshot=parity/sheet--light--en.png "file://$PWD/parity/sheet.html"
```

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Reference PNG is not 2600x4760 | wrong `--window-size` or DPR | §1 exactly |
| Rect dump reports `w != 390` | window < 561px → `--phone-scale` < 1 | §1 exactly |
| Regenerated sheet's type looks wrong | offline capture, webfont fallback | recapture online, verify faces |
| App capture is boxes | `loadAppFonts()` not called | `setUpAll(loadAppFonts)` |
| App shadows look like solid slabs | `debugDisableShadows` defaults true | clear it in the capture helper |
| Everything is offset by a constant | comparing full frame vs content box | crop the status bar (§2) |
| Diff column is uniformly bright | different theme, locale, or seed | check the pairing, then the fixtures |
| Cells differ run to run | live clock or unseeded taper | pin `clockProvider`, seed the fixture |
