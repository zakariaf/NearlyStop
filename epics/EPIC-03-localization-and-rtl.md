# EPIC-03 — Localization & RTL, four locales

**Branch:** `epic/03-localization-and-rtl`
**Depends on:** EPIC-01, EPIC-02, EPIC-04

## Where we are now

EPIC-01 set `flutter: generate: true` in `pubspec.yaml` and created an empty `lib/l10n/`. There is no
`l10n.yaml`, no ARB file, and no generated `AppLocalizations`. `lib/app.dart` builds a `MaterialApp`
with a theme and a placeholder `Scaffold` and passes **no** `localizationsDelegates`, no
`supportedLocales`, and no `locale`.

EPIC-02 shipped `daybreakTextTheme(DaybreakScript script)`, which already contains the entire Persian
transform — `height += 0.14`, negative tracking clamped to `0`, display hand-set to 58/1.15 — and it
already resolves `fontFamily`/`fontFamilyFallback` from a script argument. Nunito and Vazirmatn are
bundled and licence-registered. **Nothing decides which script to pass.** Today every build gets
`DaybreakScript.latin`, so the Persian half of the work EPIC-02 did is unreachable.

`tool/check_bans.sh` already rejects `EdgeInsets.only(left:)`, `Alignment.centerLeft`,
`TextAlign.left` and `Icons.arrow_back`, so the directional-geometry discipline is enforced from
before the first screen exists.

**EPIC-04 shipped the domain value objects this epic projects.** `Milligrams`
(`lib/core/units/milligrams.dart`, integer **hundredths**) is the one and only dose type, and
`LocalDate` (`lib/core/time/local_date.dart`, a calendar `(y, m, d)` with no time and no zone) is the
one and only date type. This epic **creates neither** — it owns the localized *projection* of both and
nothing else.
> **Contract:** CONTRACTS.md §1 — the dependency line above says `01, 02, 04` for exactly this
> reason. EPIC-03 was previously drafted as parallel to EPIC-04 and defined its own
> `lib/core/dose.dart` in half-milligrams; that file is deleted from this epic (see task 5) because
> half-milligrams cannot represent 0.25mg, which is half of a 0.5mg tablet and a dose this app can
> genuinely produce. The README dependency graph carries the same change.

**A note on SPEC §8.** The specification lists "Localisation beyond one language" as out of v1, and
§9 item 8 puts it in v2. The epic plan deliberately supersedes that: four locales ship in v1. Every
other line of SPEC — the domain rules, the data model, the edge cases — remains authoritative.

## Why this epic exists

Two of the four shipped locales are right-to-left, and RTL is not a translation task. It is a layout
discipline that has to be correct **by construction** before there is any layout to fix. Retrofitting
mirrored geometry onto five built screens means auditing every padding, every `Row`, every icon and
every gradient by hand, and the failure mode is invisible to everyone who tests in English. The gate
is already in place; this epic makes the locales that exercise it real.

It also exists because of one specific, verified constraint that is easy to hand-wave and expensive to
discover late. `flutter_localizations` ships Material, Cupertino and Widgets translations for 116
locales. `de` and `fa` are among them. **`ckb` — Kurdish Sorani — is not.** Without a custom
`LocalizationsDelegate`, a `ckb` build throws at startup from
`GlobalMaterialLocalizations.delegate.isSupported` returning false, and even if it did not, every
framework-supplied string (the date-picker labels, "Cancel", the text-selection menu, the
`TextField` hints) would silently fall back to English inside an otherwise-Kurdish app. This is not
free, it is not one line, and budgeting for it is the point of naming it here.

Third: numerals. A Persian or Kurdish user must never see `9mg` in Latin digits, and the app must
never confuse the Persian digit block (U+06Fx) with the Arabic one (U+066x) — they are different
characters. More dangerously, a Persian soft keyboard produces `1٫5`, and a normalizer that folds
digits but not separators turns that into `15`. **On a dose field that is a ten-fold error**, which
in a steroid-tapering app is the single worst bug the codebase could contain.

## What we will have when it is done

The app runs in English, German, Persian and Kurdish Sorani. Persian and Kurdish builds mirror
completely — padding, row order, chevrons, the sunrise gradient — while the clock, pill and check
glyphs stay put. Persian and Kurdish render Persian-Indic numerals everywhere a user can see a
number. Persian dates render in the Jalali calendar. Every string lives in an ARB file, a missing key
is a compile error, and CI fails a PR that adds a key to one locale and not the others. German is
checked against a declared per-key character budget so the longest-string locale cannot silently
overflow a button that has not been built yet.

## Skills to load

| Skill | What it governs for this epic |
|---|---|
| `i18n-rtl-l10n` | The whole contract: ARB/gen-l10n workflow, `nullable-getter: false`, ICU plural/select, directional-only geometry, `numberFormatFor`, `normalizeToAscii`, FSI/PDI isolation, canonical UTC storage |
| `daybreak-bilingual-type` | The per-script cascade, the +0.14 lift EPIC-02 built, no tracking and no uppercase on Perso-Arabic, `tabularFigures` verification, Jalali via `shamsi_date` |
| `daybreak-tokens` | The directional gradient geometry the mirroring rides on; nothing new is added to the palette here |
| `accessibility-as-code` | Unclamped text scaling in every locale; semantics labels are ARB strings, never literals |
| `value-objects-money-and-units` | The projection half of the discipline. The value object itself is EPIC-04's `Milligrams`; this epic only formats and parses it |
| `testing-strategy` | The locale matrix as a test dimension; parity and round-trip properties |
| `codegen-and-toolchain` | `flutter gen-l10n` output location, whether it is committed, and the freshness gate |
| `ci-pipeline-and-gates` | Adding the ARB-parity and i18n-ban gates to the existing workflow |

## Tasks

### 1. `l10n.yaml` and the four ARB files

- **What** — Configure gen-l10n and author the template plus three translations.
- **Where** — `l10n.yaml`, `lib/l10n/arb/app_{en,de,fa,ckb}.arb`, `lib/l10n/gen/`.
- **Details** —
  ```yaml
  arb-dir: lib/l10n/arb
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  output-class: AppLocalizations
  output-dir: lib/l10n/gen
  synthetic-package: false
  nullable-getter: false
  preferred-supported-locales: [en]
  ```
  **`nullable-getter: false` is load-bearing**: it makes `AppLocalizations.of(context)` non-null, so a
  missing or mistyped key is a **compile error** rather than a silently empty widget. Never call
  `AppLocalizations.of` above the `Localizations` scope — that means never in `main()` or `bootstrap()`
  before `runApp`, and never in a Riverpod provider body. **The sanctioned route outside a widget is
  `lookupAppLocalizations(resolvedLocale)`, wrapped once by EPIC-06's `appLocalizationsProvider`
  (CONTRACTS.md §4)**; the notifiers in EPIC-08/09/10 read that, so gen-l10n must emit
  `lookupAppLocalizations` (it does, with `synthetic-package: false`) and this epic's PR should say so.
  Because `output-dir` is inside `lib/`, the generated files are committed and must be in the
  analyzer's `exclude` list (they already are, from EPIC-01 task 4). CI gets a freshness gate:
  `flutter gen-l10n && git diff --exit-code -- lib/l10n/gen/`.
  Author the template `app_en.arb` first, with `@key` metadata carrying a typed `placeholders` block
  and a `description` written for a translator who has never seen the app. Then mirror **every** key
  into `de`, `fa` and `ckb` with real translations.
  Count-bearing strings are ICU `plural`, never a ternary and never concatenation — `"day 14 of 52"`,
  `"taken 341 of 350 days"`, `"1 × 5mg"` all have word orders that differ per language and cannot
  survive splicing.
  Seed the ARB with the strings the six screens already need, read off
  `design/daybreak-screens.html`: the disclaimer body and its single button, the Today context line
  (`Step 3 of 15 · 10mg → 9mg · day 14 of 52`), the Taken action, the block header
  (`Block 3 of 11 — one day at 9mg, then 4 days at 10mg`), the day-state words
  (taken / missed / today / new dose), the Progress stats, the Plan field labels, the Settings rows,
  and the Today VoiceOver sentence from SPEC §5.4 — *"Today, 9 milligrams: one 5 milligram tablet,
  four 1 milligram tablets. Not yet taken."* — as an ICU message with typed placeholders, because a
  semantics label is a user-facing string like any other.
- **Acceptance** — `flutter gen-l10n` produces `AppLocalizations` with four locales; the getter is
  non-null; a deleted key fails `flutter analyze`.

### 2. `supportedLocales`, resolution, and the one function both sides read

- **What** — Wire the delegates and make the resolved locale a single source of truth that the theme
  and the `MaterialApp` cannot disagree about.
- **Where** — `lib/l10n/app_locales.dart`, `lib/app.dart`.
- **Details** — `supportedLocales` is
  `[Locale('en'), Locale('de'), Locale('fa'), Locale.fromSubtags(languageCode: 'ckb', scriptCode: 'Arab')]`.
  Direction is **never** hardcoded — no root `Directionality(TextDirection.rtl)`. RTL follows the
  resolved locale through `GlobalWidgetsLocalizations`; a hardcoded root hides every physical-side bug
  and breaks LTR islands.
  **The ordering problem, stated plainly:** `MaterialApp.theme` is evaluated *before* `Localizations`
  resolves, so `localeResolutionCallback` cannot be the thing that tells the theme which script to
  use. Solve it by resolving once ourselves, in a pure function both consumers call:
  ```dart
  /// Pure. Both [MaterialApp.locale] and the theme builder read this, so they
  /// can never disagree about which script is being rendered.
  Locale resolveAppLocale(List<Locale> preferred) =>
      basicLocaleListResolution(preferred, kSupportedLocales);
  ```
  Handle the aliases a real device will produce: `ku`, `ckb-IQ`, `ckb-IR`, `fa-AF` (Dari), and a
  script-tagged `ckb-Arab-IQ`. Match on `languageCode` first, ignore `countryCode`, and fall back to
  `en`. `basicLocaleListResolution` alone will not map `ku` → `ckb`; add that alias explicitly and
  test it.
  For a "follow the system" setting, read `WidgetsBinding.instance.platformDispatcher.locales` and
  re-resolve on `didChangeLocales`. **EPIC-06 wraps this pure function in `resolvedLocaleProvider` and
  `appLocalizationsProvider` (CONTRACTS.md §4)** — the settings override, the OS-locale change and the
  only sanctioned way to reach `AppLocalizations` outside a widget all live there, not here. This epic
  ships the pure function and a `ValueNotifier`-backed placeholder so the screens are reachable in all
  four locales today. The theme reads the same resolved locale through `scriptFor` (task 4), so
  `buildDaybreakTheme(brightness, scriptFor(locale), highContrast: …)` and `MaterialApp.locale` can
  never disagree.
- **Acceptance** — A test asserts `resolveAppLocale` and `MaterialApp`'s effective locale agree for
  every entry in the alias table. Launching with the device set to German shows German.

### 3. The `ckb` localizations delegate — the part that is not free

- **What** — Supply Material, Cupertino and Widgets framework strings for Kurdish Sorani, which
  `flutter_localizations` does not ship.
- **Where** — `lib/l10n/ckb_material_localizations.dart`, `lib/app.dart`.
- **Details** — Verify the constraint before writing code, so the PR carries evidence rather than a
  claim: `GlobalMaterialLocalizations.delegate.isSupported(const Locale('ckb'))` returns `false`, and
  `kMaterialSupportedLanguages` does not contain `ckb`. Assert exactly that in a test — if a future
  Flutter release adds `ckb`, that test goes red and tells you to delete this file.
  **The practical route:** do not hand-translate ~70 framework strings. Write three delegates whose
  `load()` returns the **`fa`** instance from the global delegates, while the app's own ARB carries
  every app string in genuine Kurdish Sorani:
  ```dart
  class CkbMaterialLocalizationsDelegate
      extends LocalizationsDelegate<MaterialLocalizations> {
    const CkbMaterialLocalizationsDelegate();
    @override
    bool isSupported(Locale locale) => locale.languageCode == 'ckb';
    @override
    Future<MaterialLocalizations> load(Locale locale) =>
        GlobalMaterialLocalizations.delegate.load(const Locale('fa'));
    @override
    bool shouldReload(_) => false;
  }
  ```
  Repeat for `CupertinoLocalizations` and `WidgetsLocalizations`. Delegate **order matters**: put the
  three `ckb` delegates *before* the global ones in `localizationsDelegates` so they win for `ckb` and
  are inert for everything else.
  **What this buys and what it costs, honestly:**
  - Buys: correct `TextDirection.rtl` (the `fa` `WidgetsLocalizations` supplies it), Perso-Arabic
    framework strings that a Sorani reader can act on, and a working date picker and text-selection
    menu.
  - Costs: framework strings read as *Persian*, not Kurdish. Shared script, different language.
    `MaterialLocalizations.localeName` reports `fa`. Persian and Kurdish differ in several of these
    words. This is a deliberate v1 trade — it is stated in the code's doc comment, in the PR, and it
    is the reason app-owned strings must cover everything a user reads to make a decision. Anything
    important enough for the taper is an ARB string we control, never a framework string.
  - Not fixable by a `-u-` extension or a locale alias: the framework's data tables simply have no
    `ckb` entry.
- **Acceptance** — A `ckb` build launches, mirrors RTL, shows the app's own strings in Kurdish and
  framework chrome in Perso-Arabic. The `isSupported` tripwire test passes today and will fail loudly
  when upstream adds the locale.

### 4. Locale → script → theme

- **What** — Connect the resolved locale to `daybreakTextTheme`, closing the loop EPIC-02 left open.
- **Where** — `lib/theme/daybreak_theme.dart`, `lib/l10n/app_locales.dart`, `lib/app.dart`.
- **Details** — `DaybreakScript scriptFor(Locale l) => switch (l.languageCode) { 'fa' || 'ckb' =>
  DaybreakScript.perso, _ => DaybreakScript.latin };`. The cascade must end in the **other bundled
  face**, never a system font: `fa`/`ckb` get `fontFamily: 'Vazirmatn'` with
  `fontFamilyFallback: ['Nunito']` (for the Latin runs inside Kurdish — "NearlyStop", "mg"), and
  `en`/`de` get `'Nunito'` with `['Vazirmatn']`. Nunito has no Perso-Arabic coverage; Persian falling
  through it tofus or lands on whatever the OS happens to have, and the mockup's `system-ui, Tahoma`
  tail was a browser affordance that does not carry over.
  The Persian delta stays exactly where EPIC-02 put it — **one theme-level transform, never a
  per-widget override**. If a screen in a later epic needs `height: 1.74` "for Persian", the answer is
  that the theme already did it and the widget is reading the wrong slot.
  **`ckb` takes the same transform as `fa`** because it is the same script with the same joining,
  ascender and diacritic behaviour. It still needs its own visual pass — vocabulary and word length
  differ, so a layout that fits in Persian is not proven to fit in Kurdish.
  **Never letter-space and never uppercase a Perso-Arabic string.** The `overline` slot from EPIC-02
  is `en`/`de` only; in `fa`/`ckb` it degrades to plain caption at tracking 0, and the emphasis is
  carried by the word chosen in the ARB. Casing lives in the ARB string; nothing calls
  `.toUpperCase()` at render.
- **Acceptance** — A widget test in each locale asserts the resolved `fontFamily` and that the `fa`
  body `height` is the `en` value + 0.14. An `fa` render contains zero tofu glyphs.

### 5. Numerals: format at the edge, normalize before every parse

- **What** — One formatter per locale, one normalizer, and the **localized projection of EPIC-04's
  `Milligrams`**. This epic defines no dose type of its own.
- **Where** — `lib/l10n/number_formats.dart`, `test/l10n/numerals_test.dart`.
- **Details** —
  > **Contract:** CONTRACTS.md §1 — **`lib/core/dose.dart` is not created by this epic and
  > `DoseMg` does not exist.** The canonical dose type is EPIC-04's `Milligrams`, integer hundredths.
  > EPIC-03 owns only `formatDose(Milligrams, Locale) → String` and
  > `parseDose(String, Locale) → Result<Milligrams, UnitFailure>`, both in
  > `lib/l10n/number_formats.dart`. A second dose type at half-milligram resolution would truncate
  > 0.25mg — SPEC §3.3's "one unforgivable bug" — and would put the conversion at exactly the seam the
  > UI reads.
  ```dart
  NumberFormat numberFormatFor(Locale l) => switch (l.languageCode) {
        'fa' => NumberFormat.decimalPattern('fa'),   // ۰۱۲۳۴۵۶۷۸۹ — U+06Fx (arabext)
        'ckb' => NumberFormat.decimalPattern('fa'),  // intl has NO ckb number symbols; borrow fa
        'de' => NumberFormat.decimalPattern('de'),   // 1.234,5 — comma decimal
        _ => NumberFormat.decimalPattern('en'),
      };

  /// maximumFractionDigits: 2 — NOT 1. `1` rounds 0.25 to '0.3' and 1.25 to '1.3',
  /// and both are reachable (half a 0.5mg tablet; half a 2.5mg tablet).
  /// minimumFractionDigits: 0 — so 9 renders '9', not '9.00'.
  NumberFormat doseFormat(Locale l) => numberFormatFor(l)
    ..maximumFractionDigits = 2
    ..minimumFractionDigits = 0;

  String formatDose(Milligrams mg, Locale l) =>
      doseFormat(l).format(mg.hundredths / 100);
  ```
  > **Contract:** CONTRACTS.md §10 — `maximumFractionDigits: 2`, `minimumFractionDigits: 0`. The
  > 72px dose numeral is the most-read pixel in the product; the domain is built out of integer
  > hundredths specifically so it cannot round, and the presentation layer must not undo that.
  `intl` emits native digits from the locale's **symbol data**, not from a `-u-nu-` extension — it
  drops the unicode `-u` extension during fallback, so tagging the locale does nothing. Locales `intl`
  has no symbols for fall back to Latin **silently**; that is why `ckb` is pinned to `fa`, which shares
  the same digit block and separators, and why the test in this task asserts the emitted digit block
  rather than trusting the mapping.
  Persian is **not** Arabic: `٤٥٦` (U+066x) is the Arabic block and is wrong for `fa` and `ckb`.
  Never write a digit map by hand — `'۰۱۲۳۴۵۶۷۸۹'[d]` gets the separator wrong.
  Ship `normalizeToAscii` from `i18n-rtl-l10n` **verbatim**, and understand precisely what it does: it
  folds U+0660–0669 and U+06F0–06F9 to ASCII digits, maps `٫` (U+066B) to `.` and drops `٬` (U+066C).
  It is a **digit** normalizer, not a **separator** normalizer — it does nothing with ASCII `,` or
  `.`, so `double.parse(normalizeToAscii('7,5'))` throws. Say that in the doc comment, because the
  previous draft of this task instructed both "verbatim" and "must handle German", which cannot both
  be satisfied.
  **Parsing is therefore locale-aware, not `double.parse`:**
  ```dart
  Result<Milligrams, UnitFailure> parseDose(String raw, Locale l) {
    // Digits first (Perso-Arabic → ASCII), separators second (intl's own symbol data).
    final n = numberFormatFor(l).parse(normalizeToAscii(raw));   // throws → InvalidNumber
    ...  // reject negative, non-finite, and > the plan's ceiling; round to hundredths exactly once
  }
  ```
  `numberFormatFor(locale).parse` reads the decimal and grouping separators from `intl`'s symbol data,
  so German `7,5` → 7.5 and English `1,234.5` → 1234.5 without a hand-rolled rule. **Never**
  `double.parse` on user text, never `int.parse(rawText)`, and never strip-non-digits — on `1.234,5`
  that is a thousand-fold error.
  **The round-trip property test runs in 0.25mg steps**, not 0.5: format in each locale, normalize,
  parse, assert the same `Milligrams` comes back. Pin the hostile cases explicitly:
  `formatDose(Milligrams(25), en) == '0.25'`; `formatDose(Milligrams(125), fa)` renders four Persian
  characters (`۱٫۲۵`), not two; `1٫5` parses to 1.5 and **never** 15; German `7,5` parses to 7.5 and
  never 75; and negative assertions that `1٫5` and `7,5` never yield 15 or 75 in any locale.
  0.5-step ranges never generate a quarter-milligram value, which is exactly why the rounding bug
  above survived the previous draft's tests.
- **Acceptance** — Round-trip test green for all four locales across 0.25–60mg in 0.25 steps.
  `formatDose(Milligrams(25), en) == '0.25'`. A test asserts an `fa` formatted dose contains a
  character in U+06F0–06F9 and **no** ASCII digit and no U+066x character. `lib/core/dose.dart` does
  not exist and `grep -rn 'DoseMg' lib/` is empty.

### 6. Dates: Jalali for `fa`, an honest decision for `ckb`

- **What** — Localized date rendering for the Schedule and Today headers, off canonical instants.
- **Where** — `lib/l10n/date_formats.dart`, `pubspec.yaml`, `lib/bootstrap.dart`.
- **Details** — Add `shamsi_date: ^1.0.0` (VERIFY the current version). It is a **dependency, not an
  exercise**: the Jalali leap cycle has irregular exceptions, and a hand-rolled converter is right for
  a year and then quietly wrong somewhere inside a 780-day taper. Audit its transitive tree before
  committing — it must be pure Dart with no network path.
  **All taper arithmetic runs on `LocalDate`** (EPIC-04) — block boundaries, the 52-day step, the
  alternating days, the 780-day horizon. `clockProvider` supplies *today* as a `LocalDate`; it is
  **never** used to compute a day index. Jalali is a projection applied in the last widget before the
  pixels.
  > **Contract:** SPEC §7 and CONTRACTS.md §1. The word "epoch" is deleted from this task and from the
  > Definition of done: a day index computed from elapsed seconds is precisely the DST bug SPEC §7
  > forbids, and it contradicted this paragraph's own next sentence — dates, not durations.
  **The display bridge, stated so nobody invents a local-instant one.** Every formatter below takes a
  `LocalDate`, not a `DateTime`, and reaches `DateFormat`/`Jalali` through EPIC-04's
  `LocalDate.toUtcMidnight()` — a `DateTime` in UTC that exists **only** so those APIs can read the
  Y/M/D fields. Constructing a *local* instant from a `LocalDate` is banned: it is how a Jalali date or
  an `MMMEd` label ends up one day off for everyone east of UTC, on the screen where the patient checks
  which day they are on. **This asks EPIC-04 for `toUtcMidnight()` on `LocalDate` with that dartdoc;
  if it has not landed, add it there, not here.**
  Call `initializeDateFormatting()` from `package:intl/date_symbol_data_local.dart` in `bootstrap()`
  before `runApp`, or `DateFormat('de')` throws on first use.
  **`ckb` has no `intl` date symbols**, so `DateFormat('ckb')` throws. The decision for v1, and the
  reason for it:
  - `en` → `DateFormat.MMMEd('en').format(date.toUtcMidnight())`, Gregorian.
  - `de` → `DateFormat.MMMEd('de').format(date.toUtcMidnight())`, Gregorian.
  - `fa` → `Jalali.fromDateTime(date.toUtcMidnight()).formatter`, with the day number passed through
    `numberFormatFor(locale)` so digits stay in one block.
  - `ckb` → **Gregorian, with weekday and month names taken from the app's own ARB** as two ordered
    lists (`ckbWeekdayNames`, `ckbMonthNames`), and digits from the `fa` formatter.
  Borrowing `ar` date symbols for `ckb` was rejected: `ar` emits U+066x digits, which would put two
  different digit blocks in one date string. Borrowing `fa` was rejected because most Sorani speakers
  are in Iraqi Kurdistan and use the Gregorian calendar — showing them a Jalali date would be wrong,
  not merely unidiomatic. This is a real trade with a real cost (ARB-maintained month names) and it is
  written into the file's doc comment.
- **Acceptance** — Each locale renders the same `LocalDate` correctly; a test pins one known date per
  locale. No date string mixes digit blocks. `DateFormat` is never constructed with `'ckb'`. A CI step
  reruns the date suite under a second zone — `TZ=Pacific/Auckland flutter test test/l10n/` — and
  asserts byte-identical output in all four locales; Dart has no in-process API to change the local
  zone, so the zone is set by the environment or the assertion is not real.

### 7. Bidi isolation and the tablet-breakdown string

- **What** — One FSI/PDI helper at the view layer, applied to the mixed-script runs this app actually
  produces.
- **Where** — `lib/l10n/bidi.dart`.
- **Details** — The app's real mixed-direction problem is the tablet breakdown — `1 × 5mg · 2 × 1mg ·
  ½ × 1mg` — which is a run of numbers and a Latin unit inside a Perso-Arabic sentence, and it
  reorders wrongly without isolation. Same for the context line `10mg → 9mg` and for the drug name,
  which is free text the user typed and may be Latin inside a Kurdish UI.
  Prefer known-direction isolates over FSI: first-strong mis-guesses on a leading `½` or a leading
  digit. Never the legacy `LRE/RLE/LRO/RLO` embeddings.
  The isolated value is always an **ARB placeholder**, never a hard-spliced substring. Isolate
  characters (U+2066–U+2069) must never reach the database, the CSV/PDF export (EPIC-13), or a search
  — strip at the boundary.
- **Acceptance** — An `fa` and a `ckb` widget test of the tablet-breakdown string renders in the
  intended order. A test asserts no isolate character survives a round trip through the export
  formatter.

### 8. The German longest-string pass

- **What** — Catch German overflow before there is a screen to overflow, and give the UI epics a
  budget to build against.
- **Where** — `lib/l10n/arb/app_en.arb` (`x-maxChars` metadata), `test/l10n/string_budget_test.dart`.
- **Details** — German is reliably the longest-string locale here: *"Einnahme bestätigen"* against
  *"Taken"*, *"Nächsten Schritt beginnen"* against *"Start next step"*, *"Tablettenstärken"* against
  *"Tablet strengths"*. It is where a fixed-width button or a single-line chip breaks first.
  For every key that lands in a **width-constrained** slot — button label, tab label, chip, block-header
  kicker, app-bar title — add `"x-maxChars": <n>` to its `@` metadata in the template, derived by
  measuring the slot in `design/daybreak-screens.html`. `string_budget_test.dart` fails when any
  locale's string for a budgeted key exceeds it, naming the key, the locale, the budget and the actual
  length. Keys with no budget are unconstrained by design.
  **State the limit honestly:** a character budget is a proxy, not a measurement. It cannot see font
  metrics, and it says nothing at 200% text scale. The real check is the golden matrix in the UI
  epics — {en, de, fa, ckb} × {light, dark} × textScale {1.0, 1.3, 2.0} — and the layouts that absorb
  it (a `Row` reflowing to a `Column` keyed off
  `MediaQuery.textScalerOf(context).scale(17)`, buttons with a `minimumSize` floor and no fixed
  height). This budget is a cheap early tripwire, and the epic should say so rather than imply it
  proves anything about pixels.
  Absolutely no `FittedBox`, no `TextOverflow.ellipsis` and no `MediaQuery.withClampedTextScaling` as
  a fix — those turn a loud test failure into a truncated instruction on a 78-year-old's phone.
- **Acceptance** — The budget test is green; lengthening a German button label past its budget turns
  it red with a message naming the key.

### 9. `tabularFigures` verification, and the honest fallback

- **What** — Prove the bundled faces actually carry tabular figures for the digit blocks in use.
- **Where** — `tool/verify_tnum.sh`, `lib/theme/daybreak_typography.dart`.
- **Details** — EPIC-02 declared `FontFeature.tabularFigures()` on `doseNumeral` because the 72px
  number the user reads every morning must not shift between 9mg and 10mg. That declaration is only
  true if the shipped file has the feature. Verify with `fontTools` (`ttx -t GSUB`) against the exact
  `.ttf` files in `assets/fonts/`, not from memory: **Vazirmatn's `۰-۹` are not guaranteed to be
  covered by the same feature record as its Latin digits.**
  If the Persian block is uncovered, measure the widest Persian digit once with a `TextPainter` at the
  display size and reserve that width in the hero layout. **Never substitute `FittedBox`** — it
  shrinks the one number that must never shrink.
  Record the finding in a comment beside the `doseNumeral` slot with the date and the font version it
  was checked against, so the next font bump knows to re-check.
- **Acceptance** — `verify_tnum.sh` prints the covered blocks per face; the code path chosen matches
  what it printed; a widget test renders `9`, `10`, `۹` and `۱۰` at display size and asserts the
  numeral's left edge (start edge) does not move.

### 10. CI gates: ARB parity and the i18n bans

- **What** — Make the ARB contract and the RTL discipline machine-checked.
- **Where** — `tool/check_arb_parity.sh`, `tool/check_bans.sh`, `.github/workflows/ci.yml`.
- **Details** — Copy `check_arb_parity.sh` and `check_i18n_bans.sh` from
  `.claude/skills/i18n-rtl-l10n/scripts/` and fold the latter's patterns into the single
  `tool/check_bans.sh` from EPIC-01 rather than running two scripts.
  Parity checks: every key in the template exists in `de`, `fa` and `ckb`; every `{placeholder}` name
  matches; ICU branch **shapes** match (branch bodies differ, structures must not); no extra keys. A
  key present in the template but missing in a locale ships the template language silently, and a
  renamed placeholder breaks that translation at runtime — neither is visible in review.
  Add the gen-l10n freshness gate: `flutter gen-l10n && git diff --exit-code -- lib/l10n/gen/`.
  Add one grep the skill does not ship, specific to this app: reject a hand-written
  digit-substitution table — a Dart string or list literal containing a Perso-Arabic digit or the
  U+066B/U+06F0 separators — so nobody re-implements `NumberFormat` by hand.
  **Scope it so it cannot trip on itself or on legitimate data**, which the previous wording could not
  do: match only inside `lib/`, **excluding `lib/l10n/`** (the ARB files carry Persian and Kurdish
  translations by definition, and `number_formats.dart` documents the digit block in a comment), and
  excluding `tool/` — the gate's own pattern list contains every needle it searches for, so a
  repo-wide scan is red on arrival. Anchor the match to a quoted literal, not to a bare character, and
  strip comments first, as EPIC-01 task 6 requires of every rule.
  Each gate gets its contract in a comment, as in EPIC-01, and every pattern is **appended to
  `tool/check_bans.sh`** — the single entry point — rather than shipped as a second script.
- **Acceptance** — Deleting one key from `app_de.arb` turns CI red naming the key and the file.
  Renaming a placeholder in `app_fa.arb` does the same. The digit-table grep fails on a planted
  `const _fa = ['۰','۱','۲'];` in `lib/features/`, and **passes on the clean tree** — including
  `lib/l10n/arb/app_fa.arb` and `tool/check_bans.sh` themselves.

## Definition of done

- [ ] `l10n.yaml` with `nullable-getter: false`; four ARB files with identical keys, placeholder names
      and ICU branch shapes; generated output committed and excluded from analysis and coverage
- [ ] `supportedLocales` covers en/de/fa/ckb; `resolveAppLocale` is the single resolution function
      both the theme and `MaterialApp` read, with `ku`/`ckb-IQ`/`ckb-IR`/`fa-AF` aliases tested
- [ ] The three `ckb` delegates ship, ordered before the global delegates; the
      `isSupported('ckb') == false` tripwire test documents the upstream gap and will fail when it
      closes; the Persian-framework-strings trade is written in the doc comment and the PR
- [ ] `scriptFor(locale)` drives `daybreakTextTheme`; each cascade ends in the other bundled face; no
      per-widget Persian override anywhere; no tracking and no uppercase on any `fa`/`ckb` string
- [ ] `numberFormatFor` pins `ckb` to `fa` symbols with a test asserting the emitted digit block; an
      `fa` render contains no ASCII digit and no U+066x character
- [ ] No dose type is defined here: `lib/core/dose.dart` does not exist, `DoseMg` appears nowhere, and
      `formatDose(Milligrams, Locale)` / `parseDose(String, Locale) → Result<Milligrams, UnitFailure>`
      in `lib/l10n/number_formats.dart` are the whole of this epic's dose surface
- [ ] `doseFormat` uses `maximumFractionDigits: 2` / `minimumFractionDigits: 0`;
      `formatDose(Milligrams(25), en) == '0.25'` and the Persian rendering of 1.25 are both pinned
- [ ] `normalizeToAscii` (digits only) runs before every numeric parse and separators come from
      `numberFormatFor(locale).parse`, never `double.parse`; the round-trip property test covers
      0.25–60mg in 0.25 steps in all four locales, including `1٫5` → 1.5 and German `7,5` → 7.5, with
      negative assertions that neither becomes 15 or 75
- [ ] Dates: Jalali for `fa` via `shamsi_date`, Gregorian for `en`/`de`, Gregorian with ARB-supplied
      names for `ckb`; `initializeDateFormatting()` called in `bootstrap`; every formatter takes a
      `LocalDate` and reaches `DateFormat`/`Jalali` through `toUtcMidnight()`; taper arithmetic runs on
      `LocalDate`, never on elapsed seconds, and the suite passes under a second `TZ`
- [ ] One bidi helper at the view layer; isolates never reach storage or export
- [ ] `x-maxChars` budgets declared for every width-constrained key and enforced for German, with the
      proxy-not-measurement limit stated
- [ ] `tabularFigures` coverage verified against the shipped font files, with the measured-width
      fallback implemented if a block is uncovered
- [ ] `check_arb_parity.sh`, the i18n bans and the gen-l10n freshness gate are folded into
      `tool/check_bans.sh`, wired into CI and green; the digit-table grep excludes `lib/l10n/` and
      `tool/` so it cannot trip on the ARB files or on its own pattern list
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, parity evidence, tests added,
      deferrals
- [ ] CI green
- [ ] Merged to `main`
