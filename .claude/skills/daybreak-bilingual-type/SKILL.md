---
name: daybreak-bilingual-type
description: >-
  Owns NearlyStop's Daybreak typography and its English/Persian bilingual behaviour: the seven-step
  scale (display 72 / title 34 / heading 24 / body-lg 20 / body 17 / label 15 / caption 14) as a
  fully-assigned Material 3 TextTheme with em tracking converted to logical pixels, Nunito and
  Vazirmatn bundled in pubspec.yaml with OFL text registered via LicenseRegistry (google_fonts banned
  — the mockup's CDN link does not carry over), a locale-resolved fontFamily/fontFamilyFallback
  cascade ending in the other bundled face and never a system font, the +0.14 Persian line-height lift
  and negative-tracking reset as one TextTheme transform rather than per-widget overrides,
  Persian-Indic numerals via intl NumberFormat, tabular figures on the hero dose, Jalali dates via
  shamsi_date, directional mirroring of the sunrise gradient and chevrons but never the clock, pill or
  check glyph, and unclamped text scaling to 200%. Use when building or restyling the Today hero dose,
  Schedule day rows, taper block headers, a Progress stat, any TextStyle/TextTheme/StrutStyle/
  letterSpacing, adding a font asset, formatting a dose number or a Jalali date, or reviewing an
  fa/RTL screen or golden.
---

# daybreak-bilingual-type

Daybreak's type is **one scale rendered by two faces**, and the Persian rendering is a locale-aware
transform of the same tokens — never a second hand-tuned stylesheet. This skill owns the *values* and
NearlyStop's per-script rules; `design-system-structure` owns how a token system is structured and
`i18n-rtl-l10n` owns localization mechanics (ARB, gen-l10n, `Directionality`, `NumberFormat` plumbing,
bidi isolation). Cite them, don't restate them.

Read `references/type-scale.md` for the full per-role table in both scripts — size, weight, height,
tracking, the Latin→Persian delta, the `TextTheme` slot each role occupies, and where it is allowed.

## Non-negotiable rules

1. **Seven roles, no eighth.** display 72 · title 34 · heading 24 · body-lg 20 · body 17 · label 15 ·
   caption 14. A new size is a call-site opinion, not a new token. WHY: the spread from 72 to 17 is
   what carries the hierarchy for a 70-year-old reading at arm's length; every role inserted in the
   middle flattens it, and the flattening is invisible at the desk and fatal on the sofa.
2. **17 is the floor for anything a sentence lives in.** label 15 is field labels, chips and table
   cells; caption 14 is badges and tablet breakdowns *only*, never a full sentence. WHY: the audience
   is 60–80 and opens this every morning for ~780 days — presbyopia is the design constraint here,
   not a nice-to-have.
3. **Every one of the fifteen M3 `TextTheme` slots is assigned**, none left to Material's defaults.
   WHY: an unassigned `labelSmall` is 11px, and a `Chip` or `NavigationBar` will smuggle it into a
   screen that never declared it — a floor violation nobody wrote.
4. **`letterSpacing` is logical pixels, not `em` — convert at authoring time.** `-0.045em` at 72 is
   `letterSpacing: -0.045 * 72` = `-3.24`. WHY: pasting `-0.045` from the CSS mockup gives a 72×
   too-small value that looks like it worked; the display numeral silently keeps default tracking.
5. **Fonts are bundled; `google_fonts` is banned at runtime.** Nunito and Vazirmatn declared in
   `pubspec.yaml`, their OFL text shipped as an asset and registered via `LicenseRegistry`. WHY: the
   app promises offline and account-free — `google_fonts` ships an HTTP code path into the binary,
   and an unregistered OFL font makes the app's own licenses page a lie.
6. **The family cascade is locale-resolved and ends in the other bundled face — never a system font.**
   fa: `'Vazirmatn'` + fallback `['Nunito']`; en: `'Nunito'` + `['Vazirmatn']`. WHY: Nunito has no
   Perso-Arabic coverage, so Persian falling through it tofus or lands on whatever the OS happens to
   have; the mockup's `system-ui, Tahoma` tail is a browser affordance that does not carry over.
7. **The Persian delta is one `TextTheme` transform, never a per-widget override.** `+0.14` to every
   `height`, every negative `letterSpacing` clamped to `0`, display stepped 72→58 at height 1.15.
   WHY: Vazirmatn's ascenders, descenders and diacritics need the room, and one transform means a new
   role inherits the delta for free — forty overrides mean role 41 silently doesn't.
8. **Never letter-space Persian and never uppercase it.** Overline tracking (+0.06em…+0.12em) and any
   uppercase form are `en` only; in fa the overline is plain caption at tracking 0. WHY: Perso-Arabic
   is *joined* — tracking pulls the connecting strokes apart — and the script has no case; casing
   belongs in the ARB string anyway (`i18n-rtl-l10n`), never in a `.toUpperCase()` at render.
9. **Numerals come from `NumberFormat`, never manual digit substitution**, and **nothing user-facing
   stays Latin in fa** — not the dose, the day index, the step count or the percentage. WHY: a
   hand-rolled map gets the separator wrong (`1٫5` is 1.5, not 15) and confuses the Persian block
   (U+06Fx) with the Arabic one (U+066x).
10. **The hero dose renders with `FontFeature.tabularFigures()`.** WHY: proportional digits reflow the
    72px numeral between 9mg and 10mg — the one number the user checks each morning must not move.
11. **Jalali dates come from a conversion dependency, not arithmetic in this repo.** Use `shamsi_date`;
    store canonical UTC epoch and project at render (`i18n-rtl-l10n` rule 6). WHY: the Jalali leap
    cycle has irregular exceptions — a hand-rolled converter is right for a year, then quietly wrong
    somewhere inside a 780-day taper.
12. **All type-adjacent geometry is directional.** `EdgeInsetsDirectional`, `TextAlign.start`,
    `AlignmentDirectional` (including the sunrise gradient's `begin`/`end`), `Icons.adaptive.*`.
    WHY: one `EdgeInsets.only(left: 16)` puts the dose number's breathing room on the wrong side in
    Persian, and it is invisible to everyone who tests only in English.
13. **Text scales to 200% unclamped and the layout absorbs it.** No `withClampedTextScaling`, no
    `FittedBox`, no `TextOverflow.ellipsis` on a dose, a day label or a taper step. WHY: for this
    audience system text scale is not an edge case — a clamped hero and a truncated day row are the
    two ways this app becomes unusable for its actual users.
14. **Weight is a role property that honours `boldText`.** Step each role one stop under
    `MediaQuery.boldTextOf`; never hardcode a `fontWeight`. WHY: hardcoding throws the OS setting away
    for exactly the users most likely to have turned it on.

## The scale as a `TextTheme`

One builder, parameterised by script; tracking is authored in `em` and multiplied by size on the spot.

```dart
// lib/theme/daybreak_type.dart — the ONLY file allowed a fontSize or a font family string.
enum DaybreakScript { latin, perso }

TextStyle _role({
  required double size,
  required FontWeight weight,
  required double height,   // multiple of size, like CSS unitless line-height
  required double emTrack,  // authored in em; converted to logical px here
}) => TextStyle(
      fontSize: size, fontWeight: weight, height: height,
      letterSpacing: emTrack * size,   // rule 4: em → logical pixels
    );

TextTheme daybreakTextTheme(DaybreakScript script) {
  final fa = script == DaybreakScript.perso;
  double h(double latin) => fa ? latin + 0.14 : latin;      // rule 7: the lift
  double t(double em) => fa ? 0 : em;                        // rule 8: no Persian tracking

  // Display = the hero dose, Today only. Persian steps down to 58 @1.15 (see the reference).
  final display = _role(size: fa ? 58 : 72, weight: FontWeight.w800,
      height: fa ? 1.15 : 1.05, emTrack: t(-0.045));
  final title    = _role(size: 34, weight: FontWeight.w800, height: h(1.25), emTrack: t(-0.03));
  final heading  = _role(size: 24, weight: FontWeight.w800, height: h(1.25), emTrack: t(-0.02));
  final bodyLg   = _role(size: 20, weight: FontWeight.w400, height: h(1.55), emTrack: t(-0.01));
  final body     = _role(size: 17, weight: FontWeight.w400, height: h(1.60), emTrack: t(-0.01));
  final label    = _role(size: 15, weight: FontWeight.w700, height: h(1.40), emTrack: t(0.01));
  final caption  = _role(size: 14, weight: FontWeight.w800, height: h(1.45), emTrack: t(0.02));

  // Every slot assigned (rule 3) — nothing falls through to Material's 11px labelSmall.
  return TextTheme(
    displayLarge: display, displayMedium: title,  displaySmall: title,
    headlineLarge: title,  headlineMedium: title, headlineSmall: heading,
    titleLarge: heading,   titleMedium: bodyLg,   titleSmall: body,
    bodyLarge: bodyLg,     bodyMedium: body,      bodySmall: label,
    labelLarge: bodyLg.copyWith(fontWeight: FontWeight.w800), // button labels
    labelMedium: label,    labelSmall: caption,
  );
}
```

App-specific slots no M3 role covers — the dose numeral, the block-header overline, the day-state chip
— live on the Daybreak `ThemeExtension` beside the colour slots, never as call-site `TextStyle`s.

## Bundling Nunito and Vazirmatn

```yaml
# pubspec.yaml — variable files; FontWeight drives the wght axis (design-system-structure).
flutter:
  fonts:
    - family: Nunito
      fonts: [{ asset: assets/fonts/Nunito-VariableFont_wght.ttf }]
    - family: Vazirmatn
      fonts: [{ asset: assets/fonts/Vazirmatn-VariableFont_wght.ttf }]
  assets: [assets/fonts/OFL-Nunito.txt, assets/fonts/OFL-Vazirmatn.txt]
```

```dart
// bootstrap, before runApp — an unregistered OFL font makes the licenses page dishonest.
LicenseRegistry.addLicense(() async* {
  for (final f in const ['Nunito', 'Vazirmatn']) {
    yield LicenseEntryWithLineBreaks(
        [f], await rootBundle.loadString('assets/fonts/OFL-$f.txt'));
  }
});
```

Both faces are SIL OFL 1.1 — verify from the shipped file, not from memory. If you subset, keep
`--layout-features='*'` (dropping `GSUB`/`GPOS` destroys Perso-Arabic joining) and never let the
subsetter *instance* the font — a frozen `wght` kills rule 14's `boldText` response.

## The per-script cascade

```dart
// Resolved once, at the theme layer. Each stack ends in the OTHER bundled face — never system-ui.
ThemeData buildDaybreakTheme(Brightness b, Locale locale) {
  final fa = locale.languageCode == 'fa';
  return ThemeData(
    brightness: b,
    fontFamily: fa ? 'Vazirmatn' : 'Nunito',
    fontFamilyFallback: fa
        ? const ['Nunito']       // Latin runs inside Persian ("NearlyStop", "mg")
        : const ['Vazirmatn'],   // Persian runs inside English
    textTheme: daybreakTextTheme(fa ? DaybreakScript.perso : DaybreakScript.latin),
    // colorScheme + extensions: see daybreak-tokens
  );
}
```

The theme therefore depends on the locale — rebuild it from the resolved locale; `supportedLocales`
and delegate wiring stay in `i18n-rtl-l10n`.

## Numerals, the dose, and what stays Latin

```dart
// One formatter per locale (i18n-rtl-l10n owns the plumbing); doses carry at most one decimal.
NumberFormat doseFormat(Locale l) =>
    NumberFormat.decimalPattern(l.languageCode == 'fa' ? 'fa' : 'en')
      ..maximumFractionDigits = 1;

// Today's hero. Tabular figures so 9 → 10 does not reflow the 72px numeral.
final mg = doseFormat(locale).format(dose.milligrams);   // "7.5" / "۷٫۵"
Text(mg,
  style: theme.textTheme.displayLarge!
      .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
  semanticsLabel: l10n.doseSemantics(mg));
```

The unit, the separator and the word order come from the ARB message, never from concatenation — `9mg`
in English is `۹ میلی‌گرم` in Persian, with a space and a reversed reading order. Latin digits survive
only where the user never sees them: the drift database, exports, and any string that round-trips
through `normalizeToAscii` before a parse.

Honesty about `tnum`: verify with `fontTools` that the shipped builds carry tabular figures **for the
digit block in use** — Vazirmatn's `۰-۹` are not guaranteed to be covered by the same feature as its
Latin digits. If a block is uncovered, measure the widest digit once with a `TextPainter` and reserve
that width; never fake it with `FittedBox`.

## Jalali dates

```dart
// Schedule + Today headers. Store epoch, project at render.
String dayHeader(DateTime utcInstant, Locale locale) {
  final local = utcInstant.toLocal();
  if (locale.languageCode != 'fa') return DateFormat.MMMEd('en').format(local);
  final f = Jalali.fromDateTime(local).formatter;          // package:shamsi_date
  return '${f.wN} ${doseFormat(locale).format(int.parse(f.d))} ${f.mN}'; // «شنبه ۱۴ مرداد»
}
```

`shamsi_date` (or an equivalent maintained converter) is a **dependency, not an exercise**. Taper
arithmetic — block boundaries, alternating-day steps, the 780-day horizon — runs on canonical
`DateTime`/epoch via `clockProvider`, never on Jalali fields.

## RTL: what mirrors and what must not

| Mirrors in fa | Stays put in fa |
| --- | --- |
| Sunrise gradient direction (`AlignmentDirectional.topStart` → `bottomEnd`) | Clock glyph — a clock face reads the same everywhere |
| Chevrons / next-step arrows (`Icons.adaptive.arrow_forward`) | Pill / tablet glyph — an object, not a direction |
| Progress fill and the taper-block timeline | The check mark — a fixed-meaning symbol |
| Row leading/trailing slots, all padding | The sun in the Today hero — radially symmetric |

```dart
// The sunrise gradient, mirrored by construction. 138deg reads "from the leading top corner".
const LinearGradient(
  begin: AlignmentDirectional.topStart,   // NOT Alignment.topLeft
  end: AlignmentDirectional.bottomEnd,
  colors: [/* daybreak-tokens: sunrise stops */], stops: [0, .32, .68, 1],
);
```

## Scaling to 200%

- **Today's hero**: dose + unit is a `Wrap(crossAxisAlignment: WrapCrossAlignment.end)`, not a
  fixed-height baseline `Row`. At 2× the numeral becomes 144 and the unit drops to its own line; the
  card has intrinsic height inside a scroll view, so it grows downward instead of clipping.
- **Schedule day rows**: no `SizedBox(height:)`, no fixed `ListTile` extents. When
  `MediaQuery.textScalerOf(context).scale(17) > 27` the row lays out as a `Column` — a layout decision,
  never a font-size one.
- **Cross-script parity**: where a golden must line en up against fa, pin the line box with
  `StrutStyle(forceStrutHeight: true)` built from the **locale-resolved** height — a Latin-tuned
  strut shears Vazirmatn's descenders and diacritics.
- **The matrix**: {en, fa} × {light, dark} × textScale {1.0, 1.3, 2.0}, on real fonts, never Ahem.

## Anti-patterns

- **`import 'package:google_fonts/…'`, or reproducing the mockup's `<link>`** — the CDN was a
  prototype affordance; the app bundles or it breaks offline.
- **`letterSpacing: -0.045`** — an `em` used as pixels; 72× too small, and it looks like it worked.
- **A per-widget `height: 1.74` "for Persian"** — the lift is a theme transform; the per-widget override
  is the first of forty and the reason role 41 will be wrong.
- **Letter-spacing or `.toUpperCase()` on a Persian string** — breaks joining strokes; the script has
  no case, and casing lives in the ARB.
- **`'۰۱۲۳۴۵۶۷۸۹'[d]` or any manual digit map** — gets the `٫` separator wrong and confuses the Persian
  block (U+06Fx) with the Arabic one (U+066x). Use `NumberFormat`.
- **A dose numeral without `tabularFigures`** — 9mg→10mg shifts the hero the user reads every morning.
- **Hand-rolled Jalali conversion, or taper steps scheduled off Jalali fields** — the leap cycle bites a
  year in; schedule off the epoch.
- **`Alignment.topLeft` on the sunrise gradient, or `EdgeInsets.only(left:)` beside a dose** — the warm
  light falls from the wrong corner in Persian and nobody testing in English will see it.
- **Mirroring the clock, pill or check glyph** — `Icons.adaptive` is for direction-implying glyphs only.
- **`MediaQuery.withClampedTextScaling`, `FittedBox`, or `TextOverflow.ellipsis` on a dose or a day
  label** — turns a loud test failure into a truncated instruction on a 78-year-old's phone.
- **A hardcoded `fontWeight` at a call site, or an 11px `labelSmall` arriving through an unassigned
  `TextTheme` slot** — the first ignores `boldText`, the second breaks the 17px floor silently.
- **Goldens rendered with Ahem** — Perso-Arabic shaping and Persian digits are never exercised.

## Definition of done

- [ ] Every rendered `TextStyle` traces to a Daybreak role via `textTheme` or the Daybreak type
      extension; no `fontSize:`, `fontFamily:` or `letterSpacing:` outside `lib/theme/`.
- [ ] All fifteen `TextTheme` slots assigned, smallest 14 and badge-only; tracking authored in `em`
      and multiplied by size, with no bare `em` value used as pixels.
- [ ] Nunito + Vazirmatn declared in `pubspec.yaml`, OFL text shipped and `LicenseRegistry`-registered;
      `check_font_bundling.sh` clean; no `google_fonts` in the lockfile.
- [ ] `fontFamily`/`fontFamilyFallback` resolved from the locale, each stack ending in the other bundled
      face; an fa golden shows zero tofu and zero Latin-face Persian.
- [ ] The Persian delta (+0.14 height, tracking → 0, display 72→58 @1.15) applied once as a transform;
      no per-widget Persian overrides, no uppercase or positive tracking on any fa string.
- [ ] Every user-facing number and date in fa renders Persian-Indic digits via `NumberFormat` /
      `shamsi_date` (a fa golden contains no ASCII digit); taper arithmetic still runs on epoch.
- [ ] Hero dose uses `FontFeature.tabularFigures()`, or a measured fixed-width slot where the shipped
      face lacks `tnum` for that digit block — verified against the file, not assumed.
- [ ] All type-adjacent geometry directional; sunrise gradient uses `AlignmentDirectional`; clock, pill
      and check glyphs unmirrored.
- [ ] Golden matrix {en, fa} × {light, dark} × {1.0, 1.3, 2.0} passes on real fonts — no overflow, no
      clamp, no ellipsis.

## Related skills

- See `daybreak-tokens` for the colour, elevation, radius, spacing and motion values these styles sit on.
- See `daybreak-components` for the Today hero, schedule row, block header and chip recipes consuming these roles.
- See `i18n-rtl-l10n` for the ARB/gen-l10n workflow, `Directionality`, `normalizeToAscii`, bidi isolation
  and the directional-geometry gate this skill assumes.
- See `accessibility-as-code` for never-clamp-`textScaler`, `boldText`, semantics labels and the
  non-color-alone floor the day-state chips must also satisfy.
- See `design-system-structure` for two-tier tokens, the asserting `of(context)`, the no-raw-values
  gate, `FontWeight`-drives-`wght`, and the subsetting rules referenced above.
- See `widget-golden-and-a11y-testing` for the RTL/textScale golden lanes and loading real fonts in tests.

## References

- Flutter — Use a custom font (`pubspec.yaml`, `fontFamilyFallback`): https://docs.flutter.dev/cookbook/design/fonts
- Flutter API — `TextTheme` (M3 slot names): https://api.flutter.dev/flutter/material/TextTheme-class.html
- Flutter API — `TextStyle` (`height`, `letterSpacing` in logical pixels, `fontFeatures`, `StrutStyle`): https://api.flutter.dev/flutter/painting/TextStyle-class.html
- Flutter API — `LicenseRegistry`: https://api.flutter.dev/flutter/foundation/LicenseRegistry-class.html
- Flutter API — `TextScaler` / `MediaQuery.textScalerOf`: https://api.flutter.dev/flutter/painting/TextScaler-class.html · `FontFeature.tabularFigures`: https://api.flutter.dev/flutter/dart-ui/FontFeature/FontFeature.tabularFigures.html
- `intl` — `NumberFormat` / `DateFormat`: https://pub.dev/packages/intl
- `shamsi_date` — Jalali ↔ Gregorian conversion and formatters: https://pub.dev/packages/shamsi_date
- Vazirmatn (SIL OFL 1.1): https://github.com/rastikerdar/vazirmatn · Nunito: https://fonts.google.com/specimen/Nunito
- Unicode — Arabic block (Extended Arabic-Indic digits U+06F0–06F9): https://www.unicode.org/charts/PDF/U0600.pdf
- W3C WAI — WCAG 2.2 SC 1.4.4 Resize Text (200%): https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html
