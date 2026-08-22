---
name: daybreak-visual-parity
description: >-
  Proves a built NearlyStop screen against the EXTERNAL Daybreak reference —
  design/reference/daybreak-screens-{light,dark}-{en,fa}.png, the 2600x4760 headless-Chrome contact
  sheets of all six frames — by a three-tier standard instead of pixel identity: token values,
  element order, state signals, copy and mirrored RTL geometry match exactly; measured spacing,
  component size and sampled flat fills match within a stated tolerance (±2 logical px, ΔE00 ≤ 2);
  glyph rasterisation, antialiasing, gradient banding, shadow falloff and platform chrome are
  declared legitimate differences. Covers the sed+Chrome recapture, the crop-rect dump, Flutter
  capture at 390x844 @ DPR 2 (debugDisableShadows, loadAppFonts, pinned clock), the paired
  side-by-side sheet, the screen x {light,dark} x {LTR,RTL} matrix plus the no-reference
  de/ckb/200%-scale passes, and fix-the-implementation-never-the-reference. Use when building or
  reviewing a Daybreak screen against the reference PNGs, regenerating them, cropping a frame,
  capturing Flutter screenshots to compare, writing a UI epic's PR parity evidence, or judging
  whether a visual difference is a defect or a renderer difference.
---

# daybreak-visual-parity

The reference PNGs are the **contract**; this skill is how an implementation is proven against them.
Chrome and Skia cannot produce identical pixels, so parity here is defined **structurally and
measurably** — exact on every value a human decided, tolerant on everything a rasteriser decided —
and every parity claim carries a measured assertion behind the eyeball.

Scope boundary, cite don't restate: `widget-golden-and-a11y-testing` owns **goldens**, which are
self-referential (a screen against its own past) and can never detect a screen that never matched the
design. `design-review-workflow` owns the one **end-of-build QA pass** over the release build. This
skill owns the middle: **implementation vs external reference, once per UI epic, before the PR.**

Read `references/capture-and-compare.md` for the exact commands, the crop-rect dump, the file-naming
convention, the full matrix table and the full tolerance table.

## Non-negotiable rules

1. **Pixel identity is not the standard, and "pixels differ" is never a finding.** Chrome and
   Flutter's Impeller/Skia disagree on text shaping and hinting, antialiasing, gradient dithering
   and shadow-blur maths — permanently. WHY: a gate that demands the impossible is switched off the
   first week, and then nothing is checked at all. Judge against the three-tier table below.
2. **Everything a human decided matches EXACTLY: token values, layout structure and element order,
   state signals (shape + glyph + label), copy, and mirrored geometry in RTL.** WHY: these are the
   design, not a rendering of it — a 22px radius where the reference says 24, or a chevron that did
   not flip in Persian, is a defect at any zoom level and is trivially provable.
3. **Everything a rasteriser decided is compared within a stated tolerance, never by eye alone:**
   ±2 logical px on measured spacing and component dimensions, ΔE00 ≤ 2 on a sampled flat fill.
   WHY: an unstated tolerance turns every review into an argument; a stated one turns "close enough"
   into a number the next person can re-measure.
4. **Fix the implementation, never the reference.** If the reference itself is wrong, that is a
   **design change**: edit `design/daybreak-screens.html` first, regenerate **all four** PNGs with
   the documented command, and commit that on its own with the rationale. WHY: a reference quietly
   re-shot to match a shipped bug destroys the only external check the project has.
5. **The mockup's phone chrome is not the app.** The 54px fake status bar, the 46px bezel radius,
   the two device-shell rings and the drawn home indicator are HTML furniture. Crop to the content
   box and compare that. WHY: comparing against mockup furniture generates a page of false findings
   and hides the real ones underneath.
6. **Capture the implementation at the reference's own geometry — 390x844 logical, DPR 2 (780x1688
   px).** WHY: `.phone` is a fixed `390x844` box; capturing at 360 or 412 compares two different
   layouts and every spacing measurement is meaningless.
7. **Four captures per screen minimum — {light, dark} x {LTR/en, RTL/fa} — and the side-by-side
   sheet goes in the PR description of every UI epic.** WHY: the PR is where parity is reviewable by
   someone who was not in the loop; a merged UI epic with no parity image never had a second reader.
8. **`de` and `ckb` have no reference frame and must not be faked into one.** `de` inherits the `en`
   reference structurally and adds a **longest-string** overflow pass; `ckb` inherits the `fa`
   reference structurally and adds a **script/glyph + numeral** pass. WHY: German is where the
   layout breaks and Sorani is where the font falls back to tofu — the two failure modes the
   two-locale mockup cannot show.
9. **200% text scale is a parity dimension with no reference image.** It is judged against the
   component's declared degradation order (`daybreak-components` rule 6), not against a PNG. WHY:
   the audience is 60–80; the reference was drawn at 1.0 and proves nothing about the scale most of
   these users actually run.
10. **Every parity claim is backed by a measured check in code** — assert the token values the widget
    actually resolved, and spot-measure the key rects. WHY: a screenshot cannot assert; a
    side-by-side that "looks right" has caught exactly zero of the value drifts this skill exists to
    catch, and an automated pixel diff cannot settle it either (rule 1).
11. **A golden is not parity evidence.** `matchesGoldenFile` compares a screen to its own blessed
    past. WHY: bless a screen that never matched Daybreak and it stays wrong forever, green.
    See `widget-golden-and-a11y-testing`; use goldens to hold parity *once achieved*.

## The honest standard — three tiers

| Tier | What | Test | Tolerance |
|---|---|---|---|
| **Exact** | colour hex per token, radius, spacing step, type size / weight / line-height | assert the resolved token in a widget test | 0 |
| **Exact** | element order, nesting, which component appears where | read both, or assert widget order | 0 |
| **Exact** | state signal = shape + glyph + label together | `isSemantics` + shape assertion | 0 |
| **Exact** | copy (every localized string, per locale) | ARB vs mockup `data-en` / `data-fa` | 0 |
| **Exact** | RTL mirroring: chrome, chevrons, gradient origin, insets | RTL capture + directional geometry assertion | 0 |
| **Tolerance** | measured spacing, component width/height, offsets | `getRect` in a widget test | ±2 logical px |
| **Tolerance** | corner radius measured off a screenshot | crop + eyeball at 4x | ±1 logical px |
| **Tolerance** | a **flat fill** sampled at a region centre | pixel sample, both images | ΔE00 ≤ 2 (or ≤ 3/255 per channel) |
| **Tolerance** | gradient sampled at its midpoint | pixel sample | ΔE00 ≤ 3 |
| **Differs** | glyph rasterisation, hinting, subpixel positioning | — | not compared |
| **Differs** | antialiased edges, gradient banding/dither | — | not compared |
| **Differs** | shadow blur falloff and spread | assert the token instead | not compared |
| **Differs** | status bar, home indicator, mockup bezel | cropped out | not compared |

Text colour is **not** sampled off a screenshot — every glyph pixel is a blend with the background.
Assert the token value instead. Same for any 1px hairline.

## Capturing the reference

The four PNGs already exist. The command below reproduces them byte-for-byte-ish; the mockup's
theme and language are driven by the **final line** of the inline script, patched with `sed`:

```bash
SRC=design/daybreak-screens.html
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for theme in light dark; do for lang in en fa; do
  tmp="$(mktemp -t daybreak).html"
  sed "s/setTheme('light'); setLang('en');/setTheme('$theme'); setLang('$lang');/" "$SRC" > "$tmp"
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --window-size=1300,2380 \
    --screenshot="design/reference/daybreak-screens-$theme-$lang.png" "file://$tmp"
done; done
```

`1300x2380` CSS px x DPR 2 = the committed **2600x4760**. The grid is
`repeat(auto-fit, minmax(300px, 1fr))` and `.phone` carries `transform: scale(--phone-scale)` — at
1300 the scale is exactly 1 and the grid is 3x2. **Any other window size changes the column count
and the scale, and invalidates every crop rect.** The mockup pulls its webfonts over the network; a
sheet captured offline silently falls back to system faces — verify Nunito/Vazirmatn rendered before
trusting a regenerated reference (`daybreak-bilingual-type`).

Each sheet is a **contact sheet of all six frames**, so a per-screen comparison means either
comparing against the frame in place or cropping it. `references/capture-and-compare.md` documents
the rect dump (the same headless run, `--dump-dom`, rects serialised into `document.title`) and a
zero-dependency crop that re-uses Chrome itself — neither ImageMagick nor Pillow is installed here.

## Capturing the implementation

Two lanes, both legitimate, neither one a substitute for the other:

- **Widget-test lane (`flutter_test` + `matchesGoldenFile`)** — cheap, hermetic, runs in CI. Honest
  limits: `AutomatedTestWidgetsFlutterBinding` sets `debugDisableShadows = true`, so shadows render
  flat unless you clear it; without `loadAppFonts()` every glyph is an Ahem box; there is no platform
  status bar; `alchemist` improves the ergonomics but is still a *golden* tool, i.e. self-referential.
- **Device lane (`integration_test`, or the simulator)** — real rasterisation, real bundled fonts,
  real shadows, real chrome. `IntegrationTestWidgetsFlutterBinding.takeScreenshot` needs
  `convertFlutterSurfaceToImage()` and a `test_driver` script on Android; on the iOS simulator
  `xcrun simctl io booted screenshot` is the reliable route.

```dart
@Tags(['parity'])
library;

const _viewport = Size(390, 844); // the mockup's .phone content box, 1:1

Future<void> captureParity(
  WidgetTester tester, {
  required String name,       // '02--today'
  required Brightness brightness,
  required Locale locale,
}) async {
  tester.view
    ..devicePixelRatio = 2.0
    ..physicalSize = _viewport * 2.0; // physical px — 780x1688
  addTearDown(tester.view.reset);
  debugDisableShadows = false;        // else Daybreak's warm shadows render as slabs
  addTearDown(() => debugDisableShadows = true);

  await tester.pumpWidget(ProviderScope(
    overrides: parityFixtureOverrides, // pinned clock + seeded taper: no drifting content
    child: App(themeMode: brightness.themeMode, locale: locale),
  ));
  await tester.pump();

  await expectLater(
    find.byType(App),
    matchesGoldenFile('parity/app/$name--${brightness.name}--${locale.languageCode}.png'),
  );
}
```

`setUpAll(loadAppFonts)` is mandatory in this lane. Content must be **seeded and clock-pinned**
(`clockProvider`, `seeded-determinism-and-golden-vectors`) so the only difference between a capture
and the reference is the UI.

## Comparing

The primary artefact is a **paired side-by-side sheet, and a human must look at it** — reference
crop left, app capture right, identical basenames in `parity/ref/` and `parity/app/`. Build it by
pointing the same headless Chrome at a generated `sheet.html`; add a third column with
`mix-blend-mode: difference` if useful, and read it for **shifted blocks only** — it lights up on
every antialiased edge and every glyph, by design (rule 1).

Back it with assertions that a screenshot cannot make:

```dart
testWidgets('dose hero matches Daybreak reference values', (tester) async {
  await tester.pumpApp(overrides: parityFixtureOverrides);
  final context = tester.element(find.byType(DoseHeroCard));

  // Exact tier: the values a human decided.
  expect(DaybreakColors.of(context).surface, const Color(0xFFFFF9F2));
  expect(DaybreakShapes.of(context).card, 24.0);
  expect(Theme.of(context).textTheme.displayLarge!.fontSize, 72.0);

  // Tolerance tier: measured geometry, ±2 logical px.
  final card = tester.getRect(find.byKey(const ValueKey('dose_hero')));
  expect(card.width, moreOrLessEquals(390 - 2 * 20, epsilon: 2));
  expect(card.left, moreOrLessEquals(20, epsilon: 2));
});

testWidgets('Schedule mirrors in RTL', (tester) async {
  await tester.pumpApp(locale: const Locale('fa'), overrides: parityFixtureOverrides);
  final chevron = tester.getRect(find.byKey(const ValueKey('block_0_chevron')));
  expect(chevron.center.dx, lessThan(390 / 2)); // leading edge is the LEFT in RTL
});
```

## The matrix

Per screen, against the reference: **{light, dark} x {LTR/en, RTL/fa} = 4 paired captures.** Six
screens = 24 pairs for the whole app; a UI epic owns only its own screens. Three further passes have
**no reference image** and are judged against rules, not pixels:

| Pass | Rides on | What it proves |
|---|---|---|
| `de` longest-string | the `en` cell | German string length does not overflow, wrap badly, or ellipsize |
| `ckb` script | the `fa` cell | Sorani glyphs render (no tofu), joining is correct, numerals are right |
| 200% text scale | light/LTR + dark/RTL | declared degradation order holds; nothing clipped or clamped |

`en` vs `de` differ only in string length; `fa` vs `ckb` only in script. That is exactly why each
needs its own targeted pass rather than a fourth full sweep.

## On a mismatch

1. **Exact-tier miss** → implementation defect. Fix the widget or the token; never widen the tier.
2. **Tolerance-tier miss** → re-measure both sides at the same DPR before filing; if it holds, fix.
3. **Differs-tier observation** → not a finding. Record it once in the PR if it will surprise a
   reader ("shadow reads softer in Flutter"), and move on.
4. **The reference is wrong** → stop. Edit the HTML, regenerate all four PNGs, commit separately,
   then redo the comparison against the new contract (rule 4).
5. **Blocked on something the reference never showed** (a state, a locale, an error case) → it is not
   a parity question; take it to `daybreak-components` and `ui-states-and-feedback`.

## Anti-patterns

- **"Pixel-perfect" as an acceptance criterion**, or a per-pixel diff threshold as the gate — rule 1;
  it fails on font hinting alone and gets disabled.
- **Re-shooting the reference so it matches the build** — deletes the contract; a design change is a
  deliberate, separate, all-four-PNGs commit.
- **Comparing against the mockup's fake status bar, bezel radius, or home indicator** — a page of
  findings about HTML furniture.
- **Capturing at 360x800 or 412x915 "because that's a real phone"** — different layout, meaningless
  measurements. Parity is at 390x844; device breadth belongs to `adaptive-layout`.
- **A golden run submitted as parity evidence** — self-referential; it proves only that the screen
  did not change.
- **Eyeballing a side-by-side and calling it done** — no assertion, no record, no repeatability.
- **Sampling a text pixel to check ink colour** — every glyph pixel is a blend; assert the token.
- **Skipping RTL because "the layout is symmetric"** — the mirroring bugs are in gradient origin,
  chevrons and directional insets, none of which are symmetric.
- **Treating `de`/`ckb` as covered by `en`/`fa`** — the two locales the mockup omits are the two that
  break, one by length and one by script.
- **Comparing screens with live content** — an unpinned clock or unseeded taper makes every cell a
  different day and every diff noise.
- **Deferring parity to the design review** — that pass is once per app, at the end, on the release
  build; by then a wrong screen has been built on for weeks.

## Definition of done

- [ ] Every screen this epic touches has 4 paired captures — {light, dark} x {en/LTR, fa/RTL} — with
      identical basenames under `parity/ref/` and `parity/app/`.
- [ ] Reference crops came from the committed PNGs (or from a documented, separately committed
      regeneration); the mockup's status bar, bezel and home indicator are cropped out.
- [ ] App captures were taken at 390x844 logical / DPR 2, with `loadAppFonts()`, a pinned clock and
      seeded fixtures, and `debugDisableShadows = false` in the widget-test lane.
- [ ] A side-by-side sheet exists, a human has looked at it, and it is **pasted into the PR
      description**.
- [ ] Exact-tier checks are asserted in code: resolved token colours, radii, type sizes; element
      order; state signal shape+glyph+label; copy against the ARB.
- [ ] Tolerance-tier checks are measured with `getRect` at ±2 logical px, and any sampled fill is
      recorded with its ΔE.
- [ ] RTL cell proves mirrored geometry with a directional assertion, not just a screenshot.
- [ ] `de` longest-string pass and `ckb` script pass run on the epic's screens; 200% text-scale pass
      holds the declared degradation order.
- [ ] Every mismatch is resolved as implementation-fixed, tolerance-verified, differs-tier-recorded,
      or reference-changed-in-its-own-commit — nothing left as "looks close".

## Related skills

- See `widget-golden-and-a11y-testing` for the harness, `useDevice`/`pumpApp`, `loadAppFonts`, the
  overflow matrix and the golden lanes this skill's captures reuse — goldens hold parity once
  achieved; they never establish it.
- See `design-review-workflow` for the single end-of-build QA pass over the release build; its
  "parity or better" lens consumes what this skill produced per epic, and does not replace it.
- See `daybreak-tokens` for the exact-tier values (hexes, radii, spacing ramp, motion) and
  `daybreak-bilingual-type` for the type scale, the bundled faces and the Persian line-height lift
  that a parity diff will otherwise blame on rasterisation.
- See `daybreak-components` for the recipes each frame is assembled from and their declared
  degradation order — the standard the 200% pass is judged against.
- See `i18n-rtl-l10n` for the directional geometry and numeral rules the RTL cells verify, and
  `accessibility-as-code` for the floor (never clamp the scaler, colour-never-alone) that outranks
  any parity finding.
- See `run-goldens-rebaseline` for the sanctioned ritual when an accepted visual change moves
  committed images, and `adaptive-layout` for the device-breadth question parity deliberately does
  not answer.
- See `seeded-determinism-and-golden-vectors` for the pinned clock and seeded fixtures every capture
  depends on.

## References

- `references/capture-and-compare.md` — commands, crop-rect dump, naming, full matrix and tolerance tables.
- Chrome headless screenshots (`--screenshot`, `--window-size`, `--force-device-scale-factor`): https://developer.chrome.com/docs/chromium/headless
- Flutter API — `matchesGoldenFile` (OS/font/renderer sensitivity): https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html
- Flutter API — `debugDisableShadows`: https://api.flutter.dev/flutter/rendering/debugDisableShadows.html
- Flutter — integration testing & screenshots (`convertFlutterSurfaceToImage`, `takeScreenshot`): https://docs.flutter.dev/testing/integration-tests
- `alchemist` — golden lanes and `loadAppFonts`: https://pub.dev/packages/alchemist
- CIE ΔE 2000 colour-difference definition: https://en.wikipedia.org/wiki/Color_difference#CIEDE2000
- MDN — `mix-blend-mode: difference`: https://developer.mozilla.org/en-US/docs/Web/CSS/mix-blend-mode
