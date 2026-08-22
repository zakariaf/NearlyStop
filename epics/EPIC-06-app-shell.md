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
