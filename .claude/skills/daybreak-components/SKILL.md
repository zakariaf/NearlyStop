---
name: daybreak-components
description: >-
  Specifies the NearlyStop Daybreak component recipes — the sunrise dose hero card and its
  token-snapshotting arc CustomPainter, the four day-state rows whose primary signal is shape
  (filled dot / hollow ring / ring-with-core / dashed circle) never colour, the Schedule block
  header that replaces a forbidden 7-column month grid, the primary-pill / secondary-tint /
  tertiary-text / destructive button ladder with its oversized Taken action, plus strength chips,
  the method segmented control, the 5-destination tab bar, the backfill banner, Progress stat
  blocks, the disclaimer sheet and empty states — each a named const widget class under
  lib/features/<feature>/presentation/widgets/ reading only Daybreak slots. Use when building or
  reviewing any NearlyStop screen (Today, Schedule, Progress, Plan, Settings, Welcome), a dose
  card, day row, taper block header, Taken button, strength chip, backfill prompt, stat tile,
  disclaimer sheet or empty state, painting a sunrise arc, or reaching for a calendar/month grid.
---

# daybreak-components

NearlyStop's UI is a small closed set of recipes: **if a screen needs a thing, it is one of the components below, built only from Daybreak token slots, and it is a named `const` widget class.** The audience is 60–80 years old and opens this app every morning for ~780 days, so a component is only correct when it survives 200% text scale, grayscale, RTL, and dark mode — legibility here is a correctness property, not a finish.

`daybreak-tokens` owns the slots and their values; `design-system-structure` owns *how* a token system is structured and the no-raw-values gate. **This skill owns what the app assembles out of them.** No component below may contain a hex, a raw radius, a raw duration, or a `fontSize` — every one is a slot read.

Slot names used throughout: `DaybreakColors.of(context)` (surfaces/ink/brand/semantic/tints/lines/states/gradients), `DaybreakElevation.of(context)` (`level1…level3`, `glow`), `DaybreakShapes.of(context)`, `DaybreakShapes.of(context)` (radii + spacing `s1…s9`), `DaybreakMotion.of(context)`. Text styles come from `Theme.of(context).textTheme` as mapped by `daybreak-bilingual-type`.

Worked examples: `examples/dose_hero_card.dart` (gradient card + arc painter + scale degradation), `examples/day_state_row.dart` (all four states with their shape signals).

## Non-negotiable rules

1. **Every component is a named `const` widget class in `lib/features/<feature>/presentation/widgets/` — never a `_buildX()` method.** WHY: a `Widget`-returning method has no `Element`, so it cannot be `const`, cannot take a `Key`, rebuilds with its parent, and `find.byType(DoseHeroCard)` cannot reach it in a golden or a11y test. `widget-composition` owns the mechanism; this skill states that *every recipe below* is subject to it.
2. **No raw aesthetic value in any component file.** Colour, radius, shadow, duration, curve, spacing and text size are slot reads. A genuinely new need is a **new slot in `lib/theme/`**, never a literal and never an `// ignore`. WHY: the whole Daybreak palette must stay diffable in one directory — a stray `Color(0xFFF97350)` in a feature widget is a dark-mode bug that ships light-mode ink into `#241A20`.
3. **Shape is the primary signal for day state; colour is derived last.** taken = **filled dot**, missed = **hollow ring**, today = **ring with a filled core**, upcoming = **faint dashed circle** — and each pairs a glyph *and* a localized text label with its colour. WHY: these users include cataract, deuteranopia and dark-adapted-at-6am readers; a printout, a grayscale screenshot and `invertColors` must all still answer "did I take it?".
4. **A 7-column month grid is forbidden on Schedule.** Days group under **block headers** (`Block 3 · 15 mg / 12.5 mg alternating · 21 days`), rendered as a `SliverList` of blocks, never a calendar. WHY: the block *is* the product's teaching idea — a taper is a sequence of blocks, not a month — and a calendar grid re-creates precisely the "which day is which dose?" confusion the app exists to remove.
5. **The dose numeral is `display`, weight 800, with `FontFeature.tabularFigures()`, and it never shrinks.** No `FittedBox`, no computed `fontSize`, no `ellipsis`. WHY: the number is the one thing the user opened the app for; tabular figures stop `12.5` → `15` jittering the layout on a taper step, and shrinking it to fit is the exact defect `accessibility-as-code` bans.
6. **State a degradation order for every dense component, and drop decoration before content.** The hero card sheds, in order: the sunrise arc → the horizontal `Row` (becomes a `Column`) → the supporting caption's second line. WHY: an unstated order means the first person to hit an overflow at 200% "fixes" it by clamping the scale.
7. **Text on the sunrise gradient must clear AA against *both* endpoint stops.** `onPrimary` sits on `sunrise`, and the pair is verified at the lightest **and** darkest stop, in both themes. WHY: a gradient is not one background; verifying against the nominal `primary` slot passes a test the pixel fails at the other end of the sweep.
8. **The 2.8:1 pair is decorative-only and must never carry text or a meaningful outline.** It is the sunrise arc stroke and nothing else. WHY: it was measured as decorative in the design source; promoting it to a label or a state ring silently ships sub-AA content.
9. **Painters snapshot tokens at the widget layer; `paint()` never touches `BuildContext`.** `SunriseArcPainter` takes `Color`/`double` fields and implements `shouldRepaint` against them. WHY: keeps `paint()` allocation-free and testable without a `MaterialApp`; see `custom-canvas-and-gestures`.
10. **Every tap target is ≥ 44×44 and single-tap; the Taken action is ≥ 88 tall and full-bleed within its card margins.** WHY: the primary daily action is performed by a 74-year-old with a tremor, half-awake, one-handed — 44 is the floor for a secondary control, not the target for the app's one important button.
11. **Selected/active state is never colour-only in chips, segments, or the tab bar.** Selected adds a filled glyph *and* a weight step (600→800) *and* a shape change (fill, indicator bar, or 2px `borderStrong` ring). WHY: the tab bar is the app's orientation device; a colour-only active tab leaves a colour-blind user with no idea which of five screens they are on.
12. **Warmth is load-bearing in dark mode.** Dark surfaces are the `bg`/`surface`/`surfaceRaised` slots (`#241A20` family) and shadows are warm-tinted (`rgba(8,4,6,…)`), never `Colors.black`. WHY: a cold #000 void reads as clinical and grim — the emotional brief is warm and encouraging, and a shadow is the one place a stray `Colors.black26` hides from review.
13. **Motion uses `fast`/`base`/`slow` slots through `resolveMotion(context, …)` and collapses to `Duration.zero` under reduced motion.** WHY: no component may be the reason a user who asked the OS to stop animations still sees one; `design-system-structure` owns the helper.

## Dose hero card

The Today screen's whole reason to exist: one gradient card, one number, one action.

```dart
final c = DaybreakColors.of(context);
final e = DaybreakElevation.of(context);
final sh = DaybreakShapes.of(context);

DecoratedBox(
  decoration: BoxDecoration(
    gradient: c.sunrise,                 // slot, not a LinearGradient literal
    borderRadius: BorderRadius.all(sh.radiusXl),
    boxShadow: e.glow,             // warm-tinted glow, the only place it is used
  ),
  child: …, // ink is c.onPrimary throughout — verified against BOTH gradient stops
)
```

| Part | Slot | Notes |
|---|---|---|
| Card fill | `c.sunrise` | The **only** component allowed the sunrise gradient. One per screen. |
| Card shadow | `e.glow` | Reserved for this card; every other surface uses `level1…3`. |
| Numeral | `textTheme.displayLarge` + `w800` + `tabularFigures` | `c.onPrimary`. Never shrinks. |
| Unit (`mg`) | `textTheme.titleLarge` + `w600` | Baseline-aligned, `c.onPrimary` at reduced opacity **only if** still ≥ 4.5:1. |
| Day caption | `textTheme.bodyLarge` | e.g. "Day 43 · high day". Wraps to two lines, never truncates. |
| Arc | `SunriseArcPainter` | Decorative, `ExcludeSemantics`, 2.8:1 stroke, dropped above 1.6× scale. |
| Taken action | primary pill, ≥ 88 tall | Its own `Semantics(button: true)`; see Buttons. |

The hero card is announced as **one** semantic container — `Semantics(container: true, label: l10n.todayDoseLabel(dose), …)` with the visual children under `ExcludeSemantics` — so a screen-reader user hears "Today, 15 milligrams, high day" once, not four fragments. Full widget, painter, and the `LayoutBuilder`/`textScalerOf` degradation ladder: `examples/dose_hero_card.dart`.

## Day-state row (Schedule)

Four states, four **shapes**. The shape is a `CustomPaint` marker of a fixed 28 logical px, so the row scans as a column of glyphs down the list edge.

| State | Shape | Glyph | Label | Colour slot |
|---|---|---|---|---|
| taken | filled disc | `Icons.check` | `l10n.dayStateTaken` | `c.stateTaken` |
| missed | hollow ring (2px stroke, no fill) | `Icons.remove` | `l10n.dayStateMissed` | `c.stateMissed` |
| today | ring + filled core (target) | `Icons.circle` | `l10n.dayStateToday` | `c.stateToday` |
| upcoming | dashed circle, faint | *(none)* | `l10n.dayStateUpcoming` | `c.inkFaint` |

`today` also carries **position and weight**: it is the row the Schedule scrolls to, its label is `w800`, and it sits on `c.surfaceRaised` with `e.level1` while every other row is flat on `c.surface`. A row whose dose differs from the previous day adds the `newDose` marker (`c.stateNewDose` + an "up/down" glyph + the word) — a dose change is exactly the moment this population makes mistakes. Full four-state widget and painter: `examples/day_state_row.dart`.

## Block header

```dart
class BlockHeader extends StatelessWidget {
  const BlockHeader({required this.title, required this.doseSummary, required this.dayCount, super.key});
  final String title, doseSummary, dayCount; // all pre-localized & pre-formatted by the Notifier
  …
}
```

Pinned as a `SliverPersistentHeader` above its days. Fill `c.surfaceSunken`, hairline `c.border` on the bottom edge only, radius `sh.radiusMd` on the top corners, title `textTheme.titleLarge` `w800`, summary `textTheme.label` in `c.inkMuted`. Completed blocks tint their fill `c.successTint` **and** prefix a check glyph **and** append the word — never the tint alone.

**Never a month grid.** No `GridView` of 7 columns, no `table_calendar`, no `CalendarDatePicker` on Schedule. The taper is a list of blocks; a calendar cell forces a dose into a square with no room for the state shape, the label, or 200% text — and it teaches the wrong mental model. Date *entry* (start date in Plan) may use a platform date picker; date *browsing* may not.

## Buttons

| Variant | Fill | Ink | Border | Min height |
|---|---|---|---|---|
| Primary pill | `c.sunrise` gradient, `sh.radiusPill` | `c.onPrimary` | none | 56 (Taken: **88**) |
| Secondary | `c.primaryTint`, `sh.radiusPill` | `c.primaryDeep` | `c.border` | 56 |
| Tertiary | transparent | `c.primaryDeep` | none | 48 |
| Destructive | `c.dangerTint`, `sh.radiusPill` | `c.danger` | `c.dangerFill` 1px | 56 |

Every variant: `Semantics(button: true, label: …)`, `HitTestBehavior.opaque`, single tap, no long-press-only path. Pressed state is a scale-to-0.98 over `motion.fast` **plus** `HapticFeedback.selectionClick()` — so the confirmation survives reduced motion, where the scale collapses to zero. Destructive actions (delete plan, reset history) always route through a confirm sheet; `ui-states-and-feedback` owns the confirm/undo contract.

The **Taken** action is deliberately outside this ladder's floor: 88 logical px tall, full width inside the hero card's margins, `w800` label, and its own `liveRegion` announcement on success. It is the only control on Today that a user must be able to hit without looking.

## The rest of the set

- **Chip (tablet strength).** `sh.radiusPill`, min 44×44, `c.surfaceRaised` fill / `c.border`. Selected = `c.primaryTint` fill **+ 2px `c.borderStrong` ring + a check glyph + `w800`**. Chips wrap (`Wrap`), never scroll horizontally — a horizontal strip hides options at 200%.
- **Segmented control (method picker).** A `Row` of equal segments on `c.surfaceSunken`, `sh.radiusMd`. The selected segment is a raised `c.surface` tile with `e.level1` and `w800` ink; unselected is `c.inkMuted` at `w600`. Ship it as a `Semantics(inMutuallyExclusiveGroup: true, selected: …)` group. Above 1.5× text scale it reflows to a vertical radio list — an equal-width `Row` of Persian method names cannot survive otherwise.
- **Tab bar (5 destinations).** `c.surface` with a top hairline `c.border`. Active = filled icon variant + `w800` label + a 3px `c.primary` indicator; inactive = outlined icon + `w600` + `c.inkMuted`. Labels are **always** visible (never icon-only, never `NavigationDestinationLabelBehavior.onlyShowSelected`) — an unlabelled icon strip is unusable for this audience. `adaptive-layout` owns the swap to a `NavigationRail` on wide screens.
- **Banner (backfill prompt).** "You haven't marked the last 3 days." `c.warningTint` fill, `sh.radiusLg`, 1px `c.warningFill` border, a warning glyph, body in `c.ink` (never `c.warning` — the semantic ink is for the glyph and border, the text stays high-contrast), and two tertiary actions. `liveRegion: true`. It is never a `SnackBar`: this prompt must survive a scroll and a backgrounding.
- **Stat block (Progress).** `c.surfaceRaised`, `sh.radiusLg`, `e.level1`. Numeral `textTheme.headlineLarge` `w800` tabular; overline label `w600` with the `+.06em` tracking slot — **and no `toUpperCase()`**, which is meaningless in Persian (`daybreak-bilingual-type` owns the letterform rules). Every stat block states its unit in words, never a bare number.
- **Modal sheet (disclaimer).** `c.surface`, `sh.radiusXl` on the top corners only, scrim `c.overlay`, drag handle `c.border`. The Welcome disclaimer is `isDismissible: false` + `enableDrag: false` and its primary action stays disabled until the scroll controller reaches the end — the medical disclaimer is a gate, not a decoration.
- **Empty state.** Centred: a decorative illustration under `ExcludeSemantics`, a `titleLarge` heading, one `bodyLarge` sentence in `c.inkMuted`, and exactly one primary action. Warm and encouraging wording — "Your plan starts here", never "No data".

## Composition

Every recipe above is a class: `DoseHeroCard`, `DayStateRow`, `BlockHeader`, `PrimaryPillButton`, `StrengthChip`, `MethodSegmentedControl`, `BackfillBanner`, `ProgressStatBlock`, `DisclaimerSheet`, `TaperEmptyState` — each `const`-constructible, each in `lib/features/<feature>/presentation/widgets/`, each taking **pre-formatted, pre-localized primitives and callbacks** and no `ref`, no drift row, no `DateTime`. The Notifier formats the dose, resolves the day state, and picks the label; the widget paints it. See `widget-composition`.

## Anti-patterns

- **A `_buildDoseCard()` / `_buildDayRow()` method on a screen `State`** — no `Element` boundary, unkeyable, unreachable from `find.byType` in the golden lane.
- **A `GridView` / `table_calendar` / month view on Schedule** — squares cannot hold a state shape, a label, and 200% text, and the grid teaches the mental model the app exists to replace.
- **A day state distinguished only by colour** (all four rendered as the same filled dot in four colours) — dies in grayscale, in `invertColors`, and for the screen reader.
- **`FittedBox`, `maxLines: 1`, `TextOverflow.ellipsis`, or a computed `fontSize` on the dose numeral or a state label** — turns a loud test failure into a wrong number on a device.
- **`Theme.of(context)` inside `SunriseArcPainter.paint()`** — snapshot the colours into painter fields; `paint()` never sees a `BuildContext`.
- **The sunrise gradient on a second surface** (a chip, a banner, an app bar) — it is the hero's identity; repeating it flattens the one signal Today has.
- **`Colors.black26` / `BoxShadow(color: Colors.black…)` anywhere** — Daybreak shadows are warm-tinted; a black shadow on `#FFF9F2` reads as a grey smudge and in dark mode it is invisible.
- **Text painted on the sunrise gradient without checking the light stop** — `#FFC46A` under `onPrimary` is a different ratio than `#F9633F`; verify both.
- **The 2.8:1 pair used for a state ring, a border, or a caption** — it is decorative-only, by measurement.
- **An icon-only tab bar, or `onlyShowSelected` labels** — the orientation device for a 78-year-old cannot be five unlabelled glyphs.
- **A `SnackBar` for the backfill prompt or a missed-dose warning** — it times out, and this user is reading slowly.
- **`toUpperCase()` on an overline or a button label** — no-ops in Persian and shouts in English.
- **A component reading `ref` or a drift row directly** — it stops being golden-testable in isolation.

## Definition of done

- [ ] Every rendered thing is one of the recipes above, as a named `const` widget class under `presentation/widgets/`.
- [ ] `scripts/check_raw_values.sh` clean — no hex, radius, duration, curve, or `fontSize` outside `lib/theme/`.
- [ ] All four day states carry shape + glyph + localized label; a grayscale golden still answers "was this taken?".
- [ ] Schedule contains no grid/calendar widget; days are grouped under pinned `BlockHeader`s.
- [ ] Dose numeral renders at `TextScaler.linear(2.0)` with no overflow, no clamp, no ellipsis; degradation order is implemented and commented.
- [ ] `onPrimary` verified ≥ 4.5:1 against both sunrise endpoints in light **and** dark (`daybreak-tokens` owns the contrast unit test).
- [ ] `SunriseArcPainter` takes a token snapshot; `shouldRepaint` compares every field; no `BuildContext` in `paint()`.
- [ ] Taken action ≥ 88 tall; every other target ≥ 44×44, single-tap, with `Semantics(button: true)`.
- [ ] Chips, segments, and tabs signal selection with glyph + weight + shape, not colour alone; tab labels always visible.
- [ ] Every animation reads a motion slot through `resolveMotion` and collapses to zero under `MediaQuery.disableAnimationsOf`.
- [ ] Goldens exist for each component across light/dark × en/fa × 1.0/2.0 text scale (`widget-golden-and-a11y-testing`).

## Related skills

- `daybreak-tokens` — the slot names, the exact Daybreak values, both `ColorScheme`s, and the contrast unit test every recipe here depends on.
- `daybreak-bilingual-type` — Nunito/Vazirmatn, the Persian line-height bump, tracking, tabular figures, and why overlines are never uppercased.
- `widget-composition` — the class-not-method rule, `const` discipline, dumb Views, and the directional/structural layout these recipes sit in.
- `ui-states-and-feedback` — loading/empty/error/undo contracts, and the confirm flow every destructive button routes through.
- `accessibility-as-code` — `Semantics` roles, never-colour-alone, never clamping `textScaler`, 44px targets, and contrast against the composited background.
- `adaptive-layout` — the wide-screen `NavigationRail` swap and the two-pane Schedule.
- `widget-golden-and-a11y-testing` — the golden lanes (light/dark × RTL × 2.0 scale) that hold these recipes still.
- `custom-canvas-and-gestures` — the painter contract the sunrise arc and the day-state markers implement.

## References

- Flutter API — `CustomPainter` / `shouldRepaint`: https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
- Flutter API — `LinearGradient`: https://api.flutter.dev/flutter/painting/LinearGradient-class.html
- Flutter API — `FontFeature.tabularFigures`: https://api.flutter.dev/flutter/dart-ui/FontFeature/FontFeature.tabularFigures.html
- Flutter API — `Semantics` (`container`, `button`, `selected`, `liveRegion`, `inMutuallyExclusiveGroup`): https://api.flutter.dev/flutter/widgets/Semantics-class.html
- Flutter API — `SliverPersistentHeader`: https://api.flutter.dev/flutter/widgets/SliverPersistentHeader-class.html
- Flutter API — `TextScaler` / `MediaQuery.textScalerOf`: https://api.flutter.dev/flutter/painting/TextScaler-class.html
- Material Design 3 — Navigation bar (labels and destinations): https://m3.material.io/components/navigation-bar/guidelines
- W3C WAI — WCAG 2.2 SC 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- W3C WAI — WCAG 2.2 SC 2.5.8 Target Size (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
