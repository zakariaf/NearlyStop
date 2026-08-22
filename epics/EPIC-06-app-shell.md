# EPIC-06 — App shell, routing, state & bootstrap

**Branch:** `epic/06-app-shell`
**Depends on:** EPIC-02 (Daybreak theme,
`buildDaybreakTheme(Brightness, DaybreakScript, {bool highContrast})`, the five `ThemeExtension`s),
EPIC-03 (`AppLocalizations`, four locales, the custom `ckb` delegate, `resolveAppLocale`, `scriptFor`),
EPIC-05 (`AppDatabase`, the single `TaperRepository`, `watchSnapshot()`, `settingsRepository`,
`databaseProvider`).

> **Contract:** `CONTRACTS.md` is the arbiter for everything this epic exposes to other epics —
> §1 (canonical types), §4 (which provider lives where, and who owns it), §5 (the generator covers
> every date), §9 (token slot names). Where a task below and `CONTRACTS.md` disagree, `CONTRACTS.md`
> wins.

## Where we are now

Four epics have produced parts that do not yet form an app. There is a pure domain (`lib/core/`), a
database and repository (`lib/data/`), a theme (`lib/theme/`) and localisations (`lib/l10n/`), but
`lib/main.dart` is still EPIC-01's `runApp(MaterialApp(home: Placeholder()))`. There is no router, no
provider graph, no shell, no tab bar, and nothing connects `watchSnapshot()` to `generateSchedule`.
No screen exists: `lib/features/` holds only the directory skeleton.

## Why this epic exists

Three things have to be true before any screen can be written, and none of them is a screen.

**The app must come up in the right theme, in the right language, on the right route, on the first
frame.** Our user is 78 and opens this at 6am in a dark bedroom. A white flash before the dark theme
loads is not a cosmetic defect for that person — it is the app shouting at them. `SPEC.md` §4.5 makes
theme, text size and high contrast user settings stored in the database, which means the database must
be open and read *before* `runApp`, not awaited inside a `FutureBuilder` that paints a spinner first.

**Someone has to bridge the pure generator to the UI.** `generateSchedule` is a synchronous function
over facts; the repository emits facts as a stream; the screens need "what is today's dose". That
bridge — snapshot stream × injected clock → `List<DayPlan>` — is one provider graph that every screen
epic depends on, and building it five times inside five screens is how the purity line gets crossed.
This epic ships **one** derivation, `derivedScheduleProvider`; the per-screen view states
(`todayViewProvider`, `scheduleViewProvider(stepIndex)`, `progressViewProvider`) are projections
*over* it, owned by EPIC-08/09/10, and are not built here.

**Nothing outside a widget can reach `AppLocalizations` yet.** Three screen epics format their strings
inside a pure `_project(..., l10n)` in a notifier, which sits above the `Localizations` scope where
`AppLocalizations.of(context)` is illegal. That seam is a shell concern too, and it is built here.

**The clock has to be a thing the app watches, not reads.** `SPEC.md` §7 requires midnight rollover
while the app is open, and requires that flying across time zones does not reshuffle the schedule.
Both are shell concerns: a timer to the next local midnight, and a lifecycle listener that
re-evaluates "today" on resume. A screen cannot own that.

## What we will have when it is done

A launchable app: cold start with no flash of the wrong theme, five labelled tab destinations that
keep their own navigation state, the Welcome disclaimer as a gate no one can dismiss past until they
accept it, `derivedScheduleProvider` handing any screen a `DayPlan` for **every** date in range,
`appLocalizationsProvider` handing any notifier its strings, and a shell that rolls over at
midnight and survives a time-zone change. The five destinations show honest placeholders that
EPIC-08–11 replace, and the tab bar is a temporary Material `NavigationBar` that EPIC-07 replaces with
the Daybreak component.

## Skills to load

| Skill | What it governs here |
|---|---|
| `flutter-architecture` | The layer boundaries — nothing in `presentation/` touches drift; the generator bridge lives in the app layer, not in a widget |
| `app-startup-and-bootstrap` | The exact cold-launch order, the crash sink, pre-first-paint settings restore, and what may not be awaited after `runApp` |
| `navigation-and-routing` | `StatefulShellRoute.indexedStack`, per-branch navigator keys, the modal Welcome route, `redirect` and `refreshListenable` |
| `state-management-riverpod` | `Notifier`/`AsyncNotifier`/`StreamNotifier` shapes, `UncontrolledProviderScope`, override-at-bootstrap, keeping the router out of `ref.watch` |
| `scaffold-feature-module` | The five feature directories and the placeholder screen shape each screen epic fills in |
| `service-boundary-and-native` | `path_provider` and lifecycle observation behind interfaces; nothing platform-specific in a provider body |
| `async-safety` | Timer and subscription disposal, `mounted` after `await`, no unawaited futures at startup |
| `error-handling-typed-results` | Turning `Result<TaperSnapshot, StorageFailure>` and the generator's `Result` into UI-consumable async state |
| `adaptive-layout` | `NavigationBar` below 600dp, `NavigationRail` above; landscape support per `SPEC.md` §5.4 |
| `ui-states-and-feedback` | The shell's persistent error region (never a `SnackBar`) and the localized unknown-route page |
| `i18n-rtl-l10n` | `localeListResolutionCallback`, the `ckb` delegate, and the `resolvedLocaleProvider` → `appLocalizationsProvider` seam |

## Tasks

### 1. Bootstrap

- **What** — `main()` in the order `app-startup-and-bootstrap` prescribes, with the settings read
  before the first frame.
- **Where** — `lib/main.dart`, `lib/app/bootstrap.dart`, `lib/core/diagnostics/crash_sink.dart`.
  **This epic settles the app-layer paths every later epic cites:** `lib/app/bootstrap.dart`,
  `lib/app/app.dart`, `lib/app/derived_schedule_provider.dart`, `lib/app/locale_providers.dart`, and
  `lib/providers.dart` for root seams (`clockProvider` per `CONTRACTS.md` §1, `databaseProvider`,
  `bootstrapSettingsProvider`). EPIC-01's `lib/bootstrap.dart` moves to `lib/app/bootstrap.dart` in
  this epic; EPIC-12's "`lib/app/bootstrap.dart`" reference is the correct one.
- **Tests first (TDD)** — `test/app/bootstrap_test.dart` (`flutter_test` widget) and
  `test/core/diagnostics/crash_sink_test.dart` (pure `package:test` — the sink is under `lib/core/`,
  so no `flutter_test` import; drive it over an injected temp directory).
  Write and watch fail, in this order:
  1. `bootstrap()` with a settings row `themeMode: dark`, then a **single** `tester.pump()` with no
     settle: a `Builder` records `Theme.of(context).brightness` on every build and the recorded list
     is exactly `[Brightness.dark]` — length 1, no light entry anywhere. This is the no-flash claim;
     asserting only the final frame would pass with a flash.
  2. Same shape with `highContrast: true`: frame one's `ColorScheme` equals
     `buildDaybreakTheme(Brightness.light, DaybreakScript.latin, highContrast: true).colorScheme`.
  3. Order: a bare-`implements` fake `DatabaseLocation` that records, at the moment it is first
     asked for a path, whether `FlutterError.onError` has already been replaced. Expect `true` —
     the crash sink is installed before the database is opened, not after.
  4. Corrupt database: the fake throws on open → `bootstrap()` completes without rethrowing,
     the container's settings are `AppSettings.defaults()`, and `bootstrapErrorProvider` holds a
     recoverable `StorageFailure`. Frame one still paints (no black screen).
  5. `main()` awaits exactly one thing before `runApp`: assert no `FutureBuilder` is constructed in
     the launch path (`find.byType(FutureBuilder)` empty on frame one).
  6. Crash sink, pure: writing `cap + 1` records to a cap-`cap` rotating log leaves exactly `cap`
     records with the **oldest** dropped and the file ≤ the byte cap; a `FlutterErrorDetails` with a
     stack serialises to a single line; writing to an unwritable directory returns a failure rather
     than throwing out of `FlutterError.onError`.
- **Details** — Order, and each step's reason:
  1. `WidgetsFlutterBinding.ensureInitialized()` — needed before `path_provider`.
  2. Install the crash sink **first thing after the binding**: `FlutterError.onError` and
     `PlatformDispatcher.instance.onError` both route into a local sink. **`SPEC.md` §5.3 bans any
     crash SDK that phones home**, so the sink writes a capped, rotating `diagnostics.log` in the
     app-support directory and nothing else. No Sentry, no Crashlytics, no zone that swallows.
  3. `final db = AppDatabase(AppDocumentsDatabaseLocation());` then
     `await db.settingsDao.ensureRowExists();` and `final settings = await db.settingsDao.readSettingsOnce();`
     — this is the only pre-`runApp` await, it is a single-row read on an already-warm connection, and
     it is what buys us no theme flash.
  4. Build a `ProviderContainer(overrides: [databaseProvider.overrideWithValue(db),
     bootstrapSettingsProvider.overrideWithValue(settings)])`.
  5. `runApp(UncontrolledProviderScope(container: container, child: const NearlyStopApp()))`.
  **No `FutureBuilder` anywhere in the launch path** and no splash-screen widget: the native splash
  covers step 3. **This epic adds `flutter_native_splash` as a dev dependency and configures it** with
  the Daybreak `bg` colour for light and dark, then commits the generated assets, so the hand-off is
  invisible from this epic onward rather than nine epics later — EPIC-15 task 4 keeps only the real
  icon artwork and the density verification and must not re-add the dependency. If step 3 throws
  (corrupt database), catch it, log it, and start
  with defaults plus a recoverable error state — never a black screen.
- **Acceptance** — A test that pumps the app with a settings row saying `themeMode: dark` asserts the
  **first** frame's `Theme.of(context).brightness` is dark. No frame is ever painted with the default
  theme.

### 2. Settings state

- **What** — Settings as live app state, seeded by the bootstrap value.
- **Where** — `lib/features/settings/application/settings_controller.dart`,
  `lib/providers.dart` (the `bootstrapSettingsProvider` seam).
- **Tests first (TDD)** — `test/features/settings/settings_controller_test.dart`, headless
  `ProviderContainer` (no widget pumped — `testing-strategy` rule 7), plus
  `test/core/settings/app_settings_test.dart` pure `package:test` for the value object.
  The settings repository is a bare-`implements` `FakeSettingsRepository` over a `StreamController`
  with a settable `nextResult`, so it can fail; never `mocktail`, never a mocked DAO.
  Write and watch fail, in this order:
  1. `container.read(settingsControllerProvider)` returns the `bootstrapSettingsProvider` value
     **synchronously, in the same microtask**, with a `watchSettings()` stream that never emits —
     `state.themeMode == ThemeMode.dark`, and the state type is `AppSettings`, not `AsyncValue`.
     This is the test that fails if anyone reaches for `StreamNotifier`.
  2. Emitting a new row on the controller pushes it into state: a `container.listen` records exactly
     `[bootstrapSettings, emittedSettings]` in that order.
  3. `setHighContrast(true)` writes through the repository (the fake records one call with `true`)
     and state is **unchanged** immediately after the await — it changes only when the stream emits.
     No optimistic mutation.
  4. A write the fake fails returns `Result.failure(StorageFailure.io)` and leaves state at the
     previous value; nothing throws.
  5. `container.dispose()` cancels the subscription — `controller.hasListener` is `false` afterwards
     and a post-dispose emission does not touch state.
  6. Pure `AppSettings`: value equality over all seven fields; seeded fuzz over 200 generated
     settings asserting `copyWith` of one field changes that field and **no** other (independent
     oracle: field-by-field comparison, not `copyWith` itself), with the seed in `reason:`.
     `localeTag == null` and `disclaimerAcceptedAt == null` are in the generated domain.
- **Details** — `SettingsController extends Notifier<AppSettings>` — **not** `StreamNotifier`. A
  `StreamNotifier`'s state starts as `AsyncLoading` and drift's `.watch()` never emits synchronously,
  so `requireValue` on frame one throws and the whole no-flash promise fails on its own acceptance
  test. Instead: `build()` returns `ref.watch(bootstrapSettingsProvider)` **synchronously** — frame
  one comes from the bootstrap value, never from the stream — and then `ref.listen`s
  `settingsRepository.watchSettings()`, pushing each emission into `state` and cancelling the
  subscription in `ref.onDispose`. `AppSettings` is a plain immutable class in `lib/core/settings/`
  (no drift types): `themeMode`, `localeTag`, `textScale`, `highContrast`, `reminderEnabled`,
  `reminderMinuteOfDay`, `disclaimerAcceptedAt`.
  Mutators return `Result` and write through the repository — never mutate local state optimistically
  and reconcile; the stream is the source of truth.
  **This is the only settings controller in the app.** EPIC-11 does not build a second one: it adds
  the mutators its rows need to *this* class and surfaces a failed write as `Result`-driven local
  state on the row, not as optimistic state that rolls back. Two owners of `themeMode`/`textScale` —
  values read before first paint — is two sources of truth for the theme.
- **Acceptance** — Toggling high contrast in a test rebuilds the app's `ThemeData` within one frame,
  and the value survives a `ProviderContainer` rebuild backed by the same database. A test pumps the
  app with a stream that never emits and asserts frame one still renders the bootstrap settings.

### 3. `NearlyStopApp`

- **What** — The `MaterialApp.router` and everything that wraps it.
- **Where** — `lib/app/app.dart`.
- **Tests first (TDD)** — `test/app/app_test.dart`, `flutter_test` widget. Assert on the **observable
  `ThemeData`/`MediaQuery`**, not on a spy: the independent oracle is a direct call to
  `buildDaybreakTheme(...)` with the arguments we claim were passed.
  Write and watch fail, in this order:
  1. Theme arguments, all three, as a table over `{light, dark} × {latin, persoArabic} ×
     {highContrast false, true}` — eight cells. For each, seed the settings and resolved locale, then
     `expect(Theme.of(ctx), equals(buildDaybreakTheme(brightness, script, highContrast: hc)))`.
     A dropped script argument fails cells 3–8; a dropped `highContrast` fails the four `true` cells.
  2. Resolved locale `fa` → `Directionality.of(ctx) == TextDirection.rtl` and the app's
     `bodyLarge.fontFamily == 'Vazirmatn'`; `en` and `de` → `ltr` and `'Nunito'`; `ckb` → `rtl` and
     `'Vazirmatn'`.
  3. Text scale composition: OS `textScaler` 2.0 × app multiplier 1.5 →
     `MediaQuery.textScalerOf(ctx).scale(10) == 30`. The product is unbounded.
  4. The app multiplier alone is bounded 0.9–1.5: settings `textScale: 2.0` with OS at 1.0 →
     `scale(10) == 15`; `textScale: 0.5` → `scale(10) == 9`.
  5. The OS value is never clamped down: OS 3.0, app 1.0 → `scale(10) == 30`. Pair it with a source
     assertion that `withClampedTextScaling` appears nowhere in `lib/` (one grep test, or the rule
     added to `tool/check_bans.sh`).
  6. `onGenerateTitle` returns the localized title: `en` and `de` produce different, non-empty
     strings, and neither is the hardcoded package name.
  7. `debugShowCheckedModeBanner` is `false`.
- **Details** — `ConsumerWidget` reading `settingsControllerProvider`, `resolvedLocaleProvider` and
  `routerProvider`.
  - The theme builder takes **three** arguments, not one (`CONTRACTS.md` §9):
    `theme: buildDaybreakTheme(Brightness.light, scriptFor(locale), highContrast: s.highContrast)`,
    `darkTheme:` the same with `Brightness.dark`, `themeMode:` from settings. The dropped script
    argument is the entire mechanism EPIC-03 uses to reach the Persian/Sorani type transform, and
    defaulting it to `latin` would silently disable it for half the shipped locales.
    `locale` here is `ref.watch(resolvedLocaleProvider)` — resolved by EPIC-03's **pure**
    `resolveAppLocale(storedTag, osLocales, supported)` *before* `MaterialApp` builds, because
    `theme:` is evaluated above the `Localizations` scope and cannot read it.
    `highContrast` selects EPIC-02's third `ColorScheme`/`DaybreakColors` pair at the ≥7:1 floor —
    it exists as of `CONTRACTS.md` §9 and is no longer a variant this epic assumes.
  - `locale:` from `resolvedLocaleProvider` (null `localeTag` = follow the OS), `supportedLocales`
    and `localizationsDelegates` from EPIC-03 including the custom `ckb` delegate,
    `localeListResolutionCallback` from EPIC-03 so `ckb` resolves rather than falling back to `en` —
    and so that its result is what feeds `resolvedLocaleProvider` (task 3b).
  - A `builder:` that applies the app's own text-scale multiplier **on top of** the OS setting:
    `MediaQuery.withClampedTextScaling` is **banned** for the OS value (`accessibility-as-code`: never
    clamp the user's OS choice down). The app's own multiplier is bounded to 0.9–1.5 because it is our
    control, not theirs, and the product of the two is left unbounded — screens must survive it
    (EPIC-07's 200% goldens are the proof). The `TextScaler` subclass that carries the multiplier is
    EPIC-11 task 8's `UserTextScaler`; **this `builder:` is its only mount point** — EPIC-11 supplies
    the class and the Settings slider, this epic supplies the place it is applied.
  - `debugShowCheckedModeBanner: false`; `title` from l10n via `onGenerateTitle`.
- **Acceptance** — Switching the OS to Persian with no stored `localeTag` produces `TextDirection.rtl`
  and Vazirmatn glyphs; setting `localeTag: 'ckb'` renders app strings in Sorani with framework strings
  from the delegated locale. A test asserts `buildDaybreakTheme` is called with the Persian script
  argument when the resolved locale is `fa`, and with `highContrast: true` when the setting is on.

### 3b. Locale resolution and `appLocalizationsProvider`

- **What** — The seam every notifier in EPIC-08/09/10 formats strings through.
- **Where** — `lib/app/locale_providers.dart`.

> **Contract:** `CONTRACTS.md` §4 — `resolvedLocaleProvider` and `appLocalizationsProvider` are owned
> by EPIC-06 and live in `lib/app/locale_providers.dart`. `appLocalizationsProvider` is the **only**
> sanctioned way to reach `AppLocalizations` outside a widget.

- **Tests first (TDD)** — `test/app/locale_providers_test.dart`, headless `ProviderContainer` with
  `platformDispatcher.localesTestValue` for the OS side.
  Write and watch fail, in this order:
  1. `localeTag: 'de'` → `resolvedLocaleProvider == const Locale('de')` and
     `appLocalizationsProvider.appTitle` is the German ARB string (not the English one).
  2. **Re-emission on a settings change:** on a live container, change `localeTag` `en → de`; a
     `container.listen(appLocalizationsProvider, …)` records exactly two values whose `localeName`s
     are `['en', 'de']`. No relaunch, no container rebuild. This is the test that fails if the
     provider is keyed on the launch locale.
  3. `localeTag == null`, OS locales `[fa_IR]` → resolves `fa`; swap the OS list to `[de_DE]` and
     invalidate → re-emits `de`, and the recorded sequence is `['fa', 'de']`.
  4. `localeTag: 'ckb'` → an app string comes back in Sorani, and `lookupAppLocalizations` throws for
     none of `kSupportedLocales` — loop all four tags.
  5. Two call sites, one answer (seeded fuzz, independent oracle): for 200 seeded
     `(storedTag, osLocaleList)` pairs drawn from supported tags, unsupported tags, `null`, and
     empty/multi-entry OS lists, assert `resolvedLocaleProvider` equals a direct call to
     `resolveAppLocale(...)` **and** equals what the `MaterialApp` `localeListResolutionCallback`
     returns for the same inputs. Echo `storedTag` and the OS list in `reason:`.
  6. Same fuzz loop, second invariant: the result is always a member of `kSupportedLocales` — never
     an unsupported locale, never `null`.
- **Details** — Two providers, both tiny, both load-bearing:
  - `resolvedLocaleProvider` = `Provider<Locale>` returning
    `resolveAppLocale(settings.localeTag, WidgetsBinding.instance.platformDispatcher.locales, kSupportedLocales)`
    — EPIC-03's pure function. It watches `settingsControllerProvider` so a language change in
    Settings re-emits, and it is invalidated by a `WidgetsBindingObserver.didChangeLocales` hook
    mounted in `AppShell` (same place as the `DayTicker`, task 6) so an **OS** locale change re-emits
    too. `MaterialApp`'s `localeListResolutionCallback` must return the same value for the same
    inputs — one function, two call sites.
  - `appLocalizationsProvider` = `Provider<AppLocalizations>` returning
    `lookupAppLocalizations(ref.watch(resolvedLocaleProvider))`. It is keyed on the **resolved**
    locale, not the launch locale; otherwise every string freezes at launch and a locale switch
    silently does nothing until relaunch.
  - Write in the dartdoc that `AppLocalizations.of(context)` stays the rule **inside** widgets, and
    that this provider exists only for notifiers, which sit above the `Localizations` scope. Nobody
    reaches for a global navigator key.
  - **This replaces the `currentLocalizationsProvider` that EPIC-08/09/10 name but nobody builds** —
    those epics import this one.
- **Acceptance** — A test changes `localeTag` from `en` to `de` on a container with a seeded plan and
  asserts every screen notifier's view state re-emits with German strings and German number symbols,
  with no relaunch. A second test changes the platform locale list and asserts the same, with no
  stored `localeTag`.

### 4. Router

- **What** — One app-wide `GoRouter` with five branches and the Welcome gate.
- **Where** — `lib/routing/app_router.dart`, `lib/routing/routes.dart`.
- **Tests first (TDD)** — `test/routing/app_router_test.dart`. Redirects are asserted **headlessly**:
  build the router from a `ProviderContainer`, call `router.go(...)`, and read
  `router.routerDelegate.currentConfiguration.uri.path` — no widget pumped. Cases 6–7 need a real
  tree and use `pumpApp` (task 8).
  Write and watch fail, in this order:
  1. `disclaimerAcceptedAt == null`: a table over all six locations
     (`/today`, `/schedule`, `/progress`, `/plan`, `/settings`, `/settings/disclaimer`) — every one
     lands on `/welcome`.
  2. With `disclaimerAcceptedAt` set, the same six locations each stay where they were sent, and the
     initial location is `/today`.
  3. `/settings/disclaimer` with the disclaimer accepted is **not** redirected, and `router.pop()`
     from it lands on `/settings` — the Settings branch is its parent, so back returns to Settings.
  4. Accepting from `/welcome` leaves the gate exactly once: after `disclaimerAcceptedAt` is written,
     `router.go('/today')` stays at `/today`, and no later navigation re-arms the gate.
  5. No escape from the gate: at `/welcome`, `router.canPop()` is `false` and a system back
     (`tester.binding.handlePopRoute()`) leaves the location unchanged.
  6. Branch state preservation (widget): scroll the Schedule branch's list to offset 1200, switch to
     Today, switch back — the controller's offset is still 1200. `.builder` instead of
     `indexedStack` fails this.
  7. Unknown route `/nope` renders the localized "that page does not exist" copy (found by the ARB
     string, in `de` as well as `en`), `find.byType(ErrorWidget)` is empty, and its button navigates
     to `/today`.
  8. Router identity: `container.read(routerProvider)` is `identical` before and after toggling high
     contrast, and case 6's scroll offset survives the toggle. A `ref.watch` in `routerProvider`
     fails this; `refreshListenable` passes it.
  9. Route literals live in one file: a source test asserting no `'/today'`-shaped string literal
     appears under `lib/` outside `lib/routing/routes.dart` (add it to `tool/check_bans.sh` and let
     the test assert the script is red on a planted violation).
- **Details** —
  ```dart
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => AppShell(shell: shell),
    branches: [ /today, /schedule, /progress, /plan, /settings ],  // each its own navigatorKey
  )
  ```
  `indexedStack` (not `.builder`) so each tab keeps its scroll position and sub-stack across switches —
  a user who scrolled the Schedule back three months and taps Today must not lose that place.
  Route names live in `routes.dart` as a `abstract final class Routes { static const today = '/today'; … }`;
  **no string literal route anywhere else.** Verify the `StatefulShellRoute.indexedStack` builder
  signature and `CustomTransitionPage` arguments against **`go_router` ^17** before writing them —
  three majors of breaking changes separate 17 from the 14.x the skills were written against.

  **Welcome — ownership, settled.** EPIC-06 owns the *route*, the *redirect* and the *gate
  behaviour*; **EPIC-11 owns the screen content** (`DisclaimerContent`, the copy, the scroll-locked
  "I understand" action) and nothing else. EPIC-11 must not declare a second `welcome_route.dart` or
  a second redirect.
  - `/welcome` is a top-level route **outside** the shell, `opaque: true` with its own `c.bg`
    background — **not** `opaque: false`. On first run the redirect fires on cold start with no route
    beneath it, so a translucent page renders a sheet over emptiness. The frame-1 look (a sheet on a
    scrim) is achieved *inside* this opaque route: it paints the Daybreak background and presents
    EPIC-07's `DisclaimerSheet` in gate mode above it. State this in EPIC-11 task 8's parity note.
  - `barrierDismissible: false`, no system-back escape (`PopScope(canPop: false)`); `redirect:` sends
    any location to `/welcome` while `disclaimerAcceptedAt == null` and refuses to leave until it is
    set. `SPEC.md` §4.0 calls it a modal, not a tab.
  - **Re-read is one route, and it is `/settings/disclaimer`** — a child of the Settings branch, so
    back returns to Settings and the Settings tab keeps its stack. `/welcome?readOnly=true` is
    **deleted**: reusing the gate path forces the gate's own redirect to special-case a query
    parameter, which is how a gate develops a hole. `/settings/disclaimer` renders the same
    `DisclaimerContent` in **dismissible** re-read mode and never re-gates. Both route constants live
    in `routes.dart`; EPIC-11 task 9 pushes `Routes.disclaimerReread` and declares no route of its
    own.
  **The router must not be rebuilt on state change**: build it once in a `Provider` and drive
  invalidation with `refreshListenable:` — a small `Listenable` bridged from `settingsControllerProvider`
  via `ref.listen`. `ref.watch` inside `routerProvider` would recreate the `GoRouter` and reset every
  branch's navigation stack. Add `ref.onDispose(router.dispose)`.
  `errorBuilder:` renders a warm, localized "that page does not exist" with a button back to Today —
  never the red Flutter error screen.
- **Acceptance** — With `disclaimerAcceptedAt == null`, deep-linking to `/progress` lands on
  `/welcome`; after accepting, the app resumes at `/today`. Switching tabs and returning preserves each
  branch's scroll offset (asserted via a scroll controller in a test). Pushing
  `/settings/disclaimer` with the disclaimer already accepted shows a dismissible sheet, pops back to
  Settings, and does **not** re-arm the gate.

### 5. The generator bridge

- **What** — The provider graph that turns stored facts into `DayPlan`s. **One derivation, app-wide.**
- **Where** — `lib/app/derived_schedule_provider.dart`.

> **Contract:** `CONTRACTS.md` §4 — the repository returns **facts**; `generateSchedule` runs in the
> **app layer, once**, in `derivedScheduleProvider`. Nothing is "cached in the repository layer" and
> nothing under `lib/data/` builds a `DayPlan`. EPIC-06 defines **no** `todayProvider`,
> `missedDaysProvider` or `currentStepProgressProvider` — those were duplicates of the screen-level
> providers and are deleted from this epic.

- **Tests first (TDD)** — `test/app/derived_schedule_provider_test.dart`, headless
  `ProviderContainer` with `clockProvider.overrideWithValue(Clock.fixed(…))` (the Riverpod seam, not
  ambient `withClock`) and a bare-`implements` `FakeTaperRepository` over a `StreamController`,
  seeded from `test/fixtures/seeded_taper.dart`.
  Write and watch fail, in this order:
  1. **Total coverage (`CONTRACTS.md` §5):** collect the `LocalDate`s of every emitted `DayPlan` into
     a `Set`; assert the set equals an independently-built date range `[planStart,
     lastStepStart + 200 days]` — same length as the list (so no duplicates) and no missing date.
     Building the expected range with a plain day-by-day loop is the independent oracle; do not
     re-use the generator to compute it.
  2. Clock fixed to 2025-04-16 → `todayDateProvider == LocalDate(2025, 4, 16)`, and the lookup for
     that date is the fixture's active-step day 14 at 10mg with `dayInStep: 14` and a non-null
     `blockIndex`.
  3. Advance the clock one day and invalidate `todayDateProvider` → the lookup is 2025-04-17's plan,
     **and the fake repository recorded zero calls** — a clock change must not touch the database.
  4. Steady-state between steps: for the fixture's step 0 (52 days, no holds), day 53 is
     `kind: DayKind.steadyState`, dose 9.5mg (the step's `toDose`), `blockIndex: null`,
     `dayInStep: null`.
  5. After the final step: every date past `lastStepStart + realisedLength` is `steadyState` at the
     target dose (0mg), indefinitely to the end of the range.
  6. A snapshot of `Result.failure(StorageFailure.io)` → `derivedScheduleProvider` is a failure
     carrying that same failure — not an empty list, not a throw.
  7. A plan with **no** steps → a defined result (pin it: success with an empty list) so EPIC-08 has
     a contract for day zero rather than an unhandled shape.
  8. Synchronous derivation: after the stream's first emission, `container.read(derivedScheduleProvider)`
     returns a value in the same microtask, with no `await` and no `AsyncLoading` arm.
  9. Seeded fuzz over 100 generated plans (varied start dates, 1–15 steps, 0–14 holds per step, 0–3
     flares), re-asserting invariant 1 each time with the seed and the plan summary in `reason:`.
- **Details** —
  - `taperSnapshotProvider` = `StreamProvider<Result<TaperSnapshot, StorageFailure>>` from
    `TaperRepository.watchSnapshot()` — the single repository of `CONTRACTS.md` §3.
  - `derivedScheduleProvider` = a `Provider<Result<List<DayPlan>, Failure>>` that takes the snapshot's
    success value and calls `generateSchedule(...)`. **Synchronous** — the generator is pure and fast
    (52–780 days of integer arithmetic); wrapping it in a `compute()` isolate would add a frame of
    latency to the app's most important screen for no measurable gain. If profiling in EPIC-14 says
    otherwise, that is where it changes.
    Per `CONTRACTS.md` §5 the generator emits a `DayPlan` for **every** date in range — step days,
    steady-state days between a step's realised end and the next step's start, and steady-state at
    the target dose after the final step. Consumers may therefore assume a lookup by date always
    hits; an assertion in this provider's test pins that.
  - `todayDateProvider` = `Provider<LocalDate>` reading `ref.watch(clockProvider).now()` as a **local**
    date. It is invalidated by task 6, never by a rebuild. It is a **plain value provider, not a
    stream** — EPIC-08 watches it and owns no timer of its own.
  - **What this epic deliberately does not build.** The three screen view states are projections over
    `derivedScheduleProvider`, owned by their screen epics and living in
    `lib/features/*/application/`: `todayViewProvider` (EPIC-08 — including the trailing run of
    missed days that feeds the backfill banner, and the *"Step 3 of 15 · 10mg → 9mg · day 14 of 52"*
    context line), `scheduleViewProvider(stepIndex)` (EPIC-09), `progressViewProvider` (EPIC-10).
    Building them here and again there is how two `todayProvider`s with different types end up in one
    package. **If you are implementing EPIC-08/09/10: import `derivedScheduleProvider`, do not
    re-derive.**
  Every one of these is derived; **none caches to disk** (`SPEC.md` §6).
- **Acceptance** — With a pinned clock and a seeded plan, `derivedScheduleProvider` contains exactly
  one `DayPlan` for every date from the plan start to `lastStepStart + 200 days`, and looking up
  `todayDateProvider` in it returns the expected plan; overriding `clockProvider` to the next day
  changes which plan that is, with no database write. A grep gate (or a review line) confirms no
  provider named `todayProvider` exists anywhere in the repository.

### 6. Midnight rollover and time-zone change

- **What** — `SPEC.md` §7's two clock edge cases, handled in the shell.
- **Where** — `lib/app/day_ticker.dart`, wired in `AppShell`.

> **Contract:** EPIC-06 owns the `DayTicker` and `todayDateProvider`; **EPIC-08 consumes them and
> builds neither.** `lib/core/time/today_date_provider.dart` (EPIC-08 task 9's file) is not created —
> a second timer means the resume handler fires twice and one of the two rollover suites tests
> nothing. The ticker lives in `lib/app/`, not `lib/core/`, because it invalidates a Riverpod
> provider and `lib/core/**` may not import Riverpod (`CONTRACTS.md` §2).

- **Tests first (TDD)** — `test/app/day_ticker_test.dart`, `fakeAsync` around a `ProviderContainer`
  with `clockProvider.overrideWithValue(…)`. Never sleep, never `pumpAndSettle` — rule 10.
  Write and watch fail, in this order:
  1. Clock at 2025-04-16 23:59:00 local, ticker mounted: `async.elapse(59s)` →
     `todayDateProvider` is still 2025-04-16; `async.elapse(1s)` → 2025-04-17, and a
     `container.listen` counter records exactly **one** invalidation, not two.
  2. Reschedule: elapse a further 7 × 24 h → the date is 2025-04-24 and the counter reads exactly 8.
     A ticker that fires once and stops fails here.
  3. DST: with the clock at 2025-03-30 00:30 in a 23-hour local day, the scheduled interval is
     23 h 30 min, not 24 h 30 min — assert the computed `Duration` equals
     `DateTime(y, m, d + 1).difference(now)` and that the tick lands at local midnight.
     (This case runs in the `TZ=Europe/Berlin` invocation; say so in the file header.)
  4. Resume across midnight: without letting the timer fire, advance the injected clock 8 h past
     midnight and invoke the `AppLifecycleListener`'s `onResume` → `todayDateProvider` is the new
     date. This is the "phone was asleep" and "we flew to Sydney" case.
  5. One lifecycle owner, two hooks, no crosstalk: `didChangeLocales` invalidates
     `resolvedLocaleProvider` and **not** `todayDateProvider`; a midnight tick invalidates
     `todayDateProvider` and **not** `resolvedLocaleProvider`. Assert both counters each way.
  6. Disposal: after `container.dispose()`, `async.pendingTimers` is empty and elapsing another day
     changes nothing. A leaked timer is the "Timer still pending" failure this test prevents.
  7. No side effects on rollover: across the tick the fake repository records zero calls and
     `container.read(routerProvider)` is `identical` before and after.
  8. TZ invariance, asserted by the second CI invocation: a small frozen table of
     `LocalDate → DayPlan` fingerprints from the fixture, asserted byte-identical under both `TZ=UTC`
     and `TZ=Europe/Berlin`. A time-zone change moves *which day is today*, never *which dose belongs
     to a day*.
- **Details** — `DayTicker` schedules a single `Timer` for the interval to the next **local** midnight
  (computed as `DateTime(now.year, now.month, now.day + 1)` minus `now` — using the local constructor
  deliberately, so a DST-shortened day is 23 h and still lands correctly) and, on fire, invalidates
  `todayDateProvider` and reschedules. It also listens via `AppLifecycleListener(onResume:)` and
  recomputes on resume, which covers "the phone was asleep across midnight" and "we flew to Sydney".
  The same host also carries the `didChangeLocales` hook that invalidates `resolvedLocaleProvider`
  (task 3b) — one lifecycle owner in the shell, not two.
  Because dates are stored as dates (EPIC-05), a time-zone change moves *which day is today*, never
  *which dose belongs to a day* — that distinction goes in the class dartdoc.
  Test it with `fakeAsync` plus a controllable `Clock`; do not sleep in a test.
- **Acceptance** — A `fakeAsync` test advancing across midnight sees `todayDateProvider` return the
  next day and the screen notifiers re-project, with no rebuild of the router and no database access.
  The time-zone case is proven by a **second CI invocation**, not by an in-process switch: Dart has
  no API to change the process's local zone (`DateTime`'s local conversions read the platform zone
  fixed at process start), so CI runs `TZ=Europe/Berlin flutter test test/core/time/ test/app/` as a
  separate step and the suite asserts the `DayPlan` for a given date is unchanged. Say so in the test
  file's header comment; EPIC-04's date-sensitive suite rides the same step.

### 7. App shell and placeholders

- **What** — The chrome the five screens live in, plus honest stubs.
- **Where** — `lib/features/shell/presentation/app_shell.dart`,
  `lib/features/{today,schedule,progress,plan,settings}/presentation/*_screen.dart`.
- **Tests first (TDD)** — `test/features/shell/app_shell_test.dart`, `flutter_test` widget via
  `pumpApp`. The behaviour is test-first; the shell golden is written alongside as a gate, not a
  driver.
  Write and watch fail, in this order:
  1. A table over the five destinations: tapping destination *i* changes
     `currentConfiguration.uri.path` to `Routes.today/schedule/progress/plan/settings` respectively,
     each exactly once.
  2. Breakpoint, both sides: at a 599×800 viewport `find.byType(NavigationBar)` is found and
     `NavigationRail` is not; at 600×800 the rail is found and the bar is not.
  3. `labelBehavior == NavigationDestinationLabelBehavior.alwaysShow`, and in `de` at 360dp width all
     five labels are findable as text with `tester.takeException()` null — no overflow, no
     icon-only fallback.
  4. At `TextScaler.linear(2.0)` in `de` the bar's measured height is **greater** than at 1.0,
     `takeException()` is still null, and no label is elided.
  5. Semantics: exactly one destination carries `SemanticsFlag.isSelected` at a time; each carries a
     button role with its localized label; `meetsGuideline(androidTapTargetGuideline)` and
     `meetsGuideline(textContrastGuideline)` pass in `en` and `fa`.
  6. Error region: push a `StorageFailure` into the shell's error state → a banner renders, is
     **still present** after `tester.pump(const Duration(seconds: 30))`, and `find.byType(SnackBar)`
     is empty. Timed `pump`, never `pumpAndSettle`.
  7. Each of the five placeholder screens renders its localized title and one `bodyLarge` line, and
     each is constructed as a `const` in the test — a non-`const` screen fails to compile.
  8. Written alongside, gate not driver: the shell golden in `{light, dark} × {en, fa}` and the
     landscape rail capture, baselined after the widget exists.
- **Details** — `AppShell` is a `Scaffold` with the branch's body and, below 600dp width, a Material 3
  `NavigationBar` with five destinations; at ≥600dp a `NavigationRail` beside the body
  (`adaptive-layout`; `SPEC.md` §5.4 requires landscape to work, people prop tablets on kitchen
  tables). Labels are **always visible** — `NavigationDestinationLabelBehavior.alwaysShow` — never
  icon-only. This bar is explicitly a placeholder: EPIC-07 ships the Daybreak 5-destination tab bar
  with its filled-icon + weight + indicator selection signals, and swaps it in here.
  Each placeholder screen is a `const` widget rendering its localized title and one line of
  `bodyLarge` saying what will live there. They exist so routing, goldens and a11y wiring can be
  tested now, and so each screen epic is a single-file replacement.
  Global error surface: a `ScaffoldMessenger`-free approach per `ui-states-and-feedback` — a persistent
  banner region in the shell for storage failures, because a `SnackBar` times out before this audience
  finishes reading it.
- **Acceptance** — All five destinations navigate; labels are visible in every locale including the
  long German ones; at 200% text scale the bar does not clip (it may grow taller); the rail appears in
  landscape on a 800×600 test viewport.

### 8. Tests

- **What** — The shell's own test suite.
- **Where** — `test/app/`, `test/routing/`, `test/features/shell/`.
- **Tests first (TDD)** — most of this task's suite is **already written**, under tasks 1–7, before
  each implementation. What is genuinely new here is `pumpApp` itself, and a harness that silently
  drops one of its arguments makes every later epic's test vacuous — so it gets its own tests first,
  in `test/support/harness_test.dart` (`flutter_test`).
  Write and watch fail, in this order:
  1. `pumpApp(tester, overrides: [probeProvider.overrideWithValue(42)])` → a widget reading
     `probeProvider` sees `42`. A harness that ignores `overrides` fails here and nowhere else.
  2. `pumpApp(locale: const Locale('de'))` → `Localizations.localeOf(ctx) == Locale('de')` and
     `Directionality.of(ctx) == ltr`; `Locale('fa')` → `rtl`.
  3. `pumpApp(brightness: Brightness.dark)` → `Theme.of(ctx).brightness == Brightness.dark`.
  4. `pumpApp(textScaler: const TextScaler.linear(2.0))` →
     `MediaQuery.textScalerOf(ctx).scale(10) == 20`.
  5. Defaults pinned: `pumpApp(tester)` with no optional arguments gives `en`, `Brightness.light` and
     `scale(10) == 10`, so every later epic's unspecified test is deterministic.
  6. `pumpApp` returns after **one** frame without settling, so a frame-one assertion (task 1) is
     expressible through it — assert a build counter of 1.
  7. a11y smoke across the shell: for each of the five routes, in `en` and `fa`,
     `meetsGuideline(textContrastGuideline)`, `meetsGuideline(androidTapTargetGuideline)` and
     `meetsGuideline(labeledTapTargetGuideline)`.
- **Details** — (a) bootstrap: no-flash test from task 1; (b) corrupt-database bootstrap falls back to
  defaults and surfaces a recoverable error; (c) router: welcome gate, deep link redirect,
  `/settings/disclaimer` re-read, branch state preservation, unknown route → localized error page;
  (d) `fakeAsync` midnight rollover; (e) a `pumpApp` test harness in **`test/support/harness.dart`**
  that every later epic reuses — it takes `overrides`, `locale`, `brightness` and `textScaler` and
  wraps `ProviderScope` + `NearlyStopApp`. The file name is `harness.dart` (matching
  `widget-golden-and-a11y-testing` and EPIC-14's reference), the function is `pumpApp` — there is no
  `test/support/pump_app.dart`; (f) the locale-switch test from task 3b; (g) an a11y smoke pass over
  the shell with `meetsGuideline(textContrastGuideline)` and `androidTapTargetGuideline`.
  Golden files live under `test/golden/` throughout the project — singular, decided here.
- **Acceptance** — `test/support/harness.dart` is used by at least the shell tests and documented in
  its own dartdoc as the shared entry point for EPIC-07 onward.

## Definition of done

- [ ] Every TDD task's tests were written first and observed failing before its implementation
- [ ] Cold start reads settings before the first frame; a test asserts frame one is already in the stored theme
- [ ] Crash sink is local-file-only; no network-capable diagnostics package is in `pubspec.yaml`
- [ ] One `GoRouter`, five `indexedStack` branches with preserved state, Welcome as an opaque non-dismissible gate, re-read at `/settings/disclaimer` only
- [ ] Route strings exist only in `lib/routing/routes.dart`
- [ ] `derivedScheduleProvider` bridges facts → `DayPlan` with no persistence of derived data, and covers every date in range
- [ ] No `todayProvider`, `missedDaysProvider` or `currentStepProgressProvider` exists anywhere — the screen epics own their view providers
- [ ] `resolvedLocaleProvider` and `appLocalizationsProvider` exist in `lib/app/locale_providers.dart`; a locale change re-emits every notifier's view state with no relaunch
- [ ] `LocalDate` and `Milligrams` are the only date and dose types above `lib/core/`; no view model or provider defines its own
- [ ] One `SettingsController` in the app, seeded synchronously from bootstrap; `StreamNotifier` is not used for it
- [ ] `buildDaybreakTheme` is called with all three arguments at every call site
- [ ] Midnight rollover proven by a `fakeAsync` test; the time-zone case proven by the `TZ=Europe/Berlin` CI step
- [ ] Shell adapts to `NavigationRail` in landscape; labels always visible
- [ ] `test/support/harness.dart` exists and is reused
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
