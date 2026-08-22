# EPIC-12 — Local notifications

**Branch:** `epic/12-local-notifications`
**Depends on:** EPIC-05 (persistence & repositories), EPIC-06 (app shell & bootstrap), EPIC-11 (the
Settings reminder row that turns this on)

## Where we are now

`AppSettings` already carries `reminderEnabled` (`bool`) and `reminderTime` (minutes since local
midnight, `int?`), written by EPIC-06's one `SettingsController` through `settingsRepository` (CONTRACTS
§3 — there is no `SettingsRepository` class) and surfaced by EPIC-11's Settings reminder row. The Settings
screen has a working toggle and a `showTimePicker`, and both persist — but nothing ever fires. There is
no `flutter_local_notifications` dependency, no `timezone` initialisation, no notification channel, no
`POST_NOTIFICATIONS` permission request, and no receiver in the Android manifest. `bootstrap()` from
EPIC-06 initialises the database, the clock and `ProviderScope`, and is the natural place for `tz.local`.

There is also no service seam for notifications yet: `lib/services/` holds the `Clock` wiring from
`service-boundary-and-native` and nothing this epic can reuse. `lib/core/` holds the pure DSNS engine
from EPIC-04, the `Milligrams`/`LocalDate` value objects and the `Result` type.

> **Contract:** CONTRACTS §2 — `lib/core/**` may not import Flutter, Riverpod, drift or `dart:ui`, with
> **one deliberate exception: `lib/core/notifications/**` may import `package:timezone`**, because a
> scheduling core without `TZDateTime` cannot express "08:00 local on this date". The CI purity gate
> encodes the exception; this epic does not quietly violate the rule.

## Why this epic exists

The whole product is a habit: open the app, look at one number, tap Taken. A taper runs ~780 mornings,
and the failure mode the forum complains about is not a wrong dose — it is forgetting on a day when the
dose *changes*, because DSNS days are not all alike. One local notification at a time the user chose is
the cheapest thing the app can do to protect two years of adherence, and it is the only thing in the app
that has to work while the app is closed.

It also has to work without violating any of the app's promises. No push infrastructure, no server, no
account (SPEC §2), which means the schedule has to be reconstructible from the local database after a
reboot, a Doze window, an OS update, or a restore. And it has to work without becoming medical advice:
SPEC §11.4 settles the copy question — the reminder says *"Your plan for today"*, never *"Take your
pills"*. An app that never recommends a dose cannot ship a push that instructs someone to swallow one.

Finally there is a privacy dimension the design brief implies but does not spell out: a lock-screen
preview reading "Prednisolone 9mg" tells anyone holding the phone that its owner has a chronic illness.
The notification body carries no dose and no drug name, and on Android the notification is `private`
visibility so the lock screen shows the channel, not the content.

## What we will have when it is done

A user turns the reminder on in Settings, picks 8:00, grants the OS permission, and gets one gentle
notification every morning that opens the app on Today. It survives a reboot, a flight across time zones,
a daylight-saving change, and a restore from backup. Turning it off cancels it. Changing the time moves
it. Everything about it is provable off-device in pure Dart tests with a fake gateway and a fixed clock.

## Skills to load

| Skill | What it governs for this epic |
|---|---|
| `local-notifications-scheduler` | The whole architecture: DB-as-truth, one `syncNotifications()` reconcile, the single-file plugin import, pure Clock-injected math, deterministic IDs, `tz.local`, inexact alarms (unconditionally — CONTRACTS §12), the plugin's native boot re-arm. |
| `service-boundary-and-native` | The `NotificationGateway` port as a throws-until-overridden provider, the fake, and the manifest/plist changes kept behind the seam. |
| `app-startup-and-bootstrap` | Where `tz.initializeTimeZones()` / `tz.setLocalLocation()`, channel creation and the first reconcile run, relative to `runApp`. |
| `i18n-rtl-l10n` | Title and body in en/de/fa/ckb, numeral rendering in the time sublabel, and the fact that the fire instant stays Gregorian regardless of display calendar. |
| `async-safety` | Guarded `await`s in the permission flow, subscription disposal on the settings listener, no `BuildContext` across an await in the tap handler. |
| `error-handling-typed-results` | `Result<void, ReminderFailure>` for permission denied / revoked-after-grant / scheduling refused — no throwing at the UI, and no `Unit` type (EPIC-01's convention is `Result<void, F>`). |
| `state-management-riverpod` | The gateway provider, the reconcile provider, and the `ref.listen` on settings that triggers it. |
| `testing-strategy` | Fakes over mocks, the pure-core test matrix, and what genuinely cannot be tested off-device. |

## Tasks

### 1. Dependencies and platform configuration

- **What** — Add the three packages and the platform plumbing they need.
- **Where** — `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`,
  `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`.
- **Tests first** — *Scaffold.* Adding three dependencies, four manifest nodes, a Gradle desugaring flag
  and an `AppDelegate` line has no behaviour a test could catch; a test asserting the plugin exists
  asserts that pub works. Verified by `flutter build apk --debug` and `flutter build ios --no-codesign`
  succeeding, and by `tool/check-manifest-permissions.sh` passing in CI. One thing here **is** worth
  writing first, because it is the gate everything else leans on: give that script a fixture pair
  before wiring it — a merged-manifest fixture containing `SCHEDULE_EXACT_ALARM` that must turn it red,
  and one carrying exactly `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` that must leave it
  green. An unproven gate is not a gate.
- **Details** — `flutter_local_notifications`, `timezone`, `flutter_timezone` — **pin all three in
  `pubspec.yaml` and write the resolved versions into the PR**, because two of this epic's tasks name
  plugin APIs whose shape changed between majors (see tasks 3 and 5). Android manifest gets exactly
  `POST_NOTIFICATIONS` (Android 13+), `RECEIVE_BOOT_COMPLETED` and `VIBRATE`.
  > **Contract:** CONTRACTS §12 — **do not declare `SCHEDULE_EXACT_ALARM`** (and never `USE_EXACT_ALARM`,
  > which Play policy restricts to alarm/timer/calendar apps). A daily "your plan for today" does not
  > need alarm-clock precision, on Android 14+ `SCHEDULE_EXACT_ALARM` is denied by default and this epic
  > refuses to ever prompt for it — so the branch would be dead code that costs a Play policy
  > declaration. EPIC-15 task 5 strips both nodes with `tools:node="remove"`, and its permission
  > expectation is the whole set above; declaring the node here would turn EPIC-15's manifest test red on
  > something this epic added deliberately. Settled: **inexact, unconditionally.**
  Register
  `ScheduledNotificationBootReceiver` for `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED` and
  `QUICKBOOT_POWERON`, plus `ScheduledNotificationReceiver`. Gradle needs
  `compileOptions { isCoreLibraryDesugaringEnabled = true }` and
  `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.x")` — without it the plugin's
  `java.time` usage fails to build on older `minSdk`. iOS: set
  `UNUserNotificationCenter.current().delegate = self` in `AppDelegate` before `GeneratedPluginRegistrant`
  so foreground presentation works, and keep `UIBackgroundModes` **absent** — this app has no background
  fetch and claiming one changes the review story.
- **Acceptance** — `flutter build apk --debug` and `flutter build ios --no-codesign` both succeed;
  `tool/check-manifest-permissions.sh` passes. That script asserts the **whole expected permission set**
  (`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` — and nothing else) against the **merged**
  manifest under `build/app/intermediates/merged_manifests/`, not the source file, because
  `flutter_local_notifications` contributes nodes of its own; a bare "no `USE_EXACT_ALARM`" grep on the
  source would not have caught the conflict this contract settles.

### 2. The pure scheduling core

- **What** — All scheduling maths, with no Flutter, no plugin, no clock of its own.
- **Where** — `lib/core/notifications/scheduled_notification.dart`,
  `lib/core/notifications/recurrence_rule.dart`, `lib/core/notifications/reminder_scheduler.dart`,
  `lib/core/notifications/deterministic_id.dart`.
- **Tests first (TDD)** — `test/core/notifications/reminder_scheduler_test.dart` and
  `test/core/notifications/deterministic_id_test.dart`, pure `package:test` (no `flutter_test`, no
  binding; `setUpAll(tz.initializeTimeZones)` and an explicit `tz.getLocation('Europe/Berlin')` so the
  test never depends on the machine's zone). Time comes from `withClock(Clock.fixed(t), …)` — this
  directory is the purest TDD in the epic. Write and watch fail, in this order:
  1. `nextDailyAt(8, 0)` with the clock at 2025-04-16 07:30 Berlin → `TZDateTime` 2025-04-16 08:00 Berlin
  2. same rule with the clock at 08:30 → rolls to 2025-04-17 08:00
  3. clock at exactly 08:00:00 → **today**, not tomorrow (the boundary, asserted on purpose)
  4. DST spring-forward: Berlin, 2025-03-30, rule 08:00 → local hour 8, UTC offset +02:00. A stored
     instant would fire at 07:00 here, which is the whole reason the rule is wall-clock
  5. DST fall-back: Berlin, 2025-10-26, rule 08:00 → local hour 8, offset +01:00
  6. midnight rule `(0, 0)` with the clock at 23:59 → the next day's 00:00
  7. `compute` returns the empty set when `reminderEnabled == false`; when `taperActive == false`; and
     when current dose equals target. Three separate cases — one emptiness test hides the other two
  8. `compute` with reminder on and taper active → exactly one entry, with
     `matchComponents == DateTimeComponents.time` and
     `androidScheduleMode == AndroidScheduleMode.inexactAllowWhileIdle`. A one-shot passes every other
     test in this list, so this assertion is the one that pins "repeating"
  9. `deterministicId` stability: computed at clock 2025-04-16 07:00 and again at 2025-04-19 09:00 →
     **identical**. Changing the minute changes it; changing the body (a locale switch) changes it;
     changing the title changes it
  10. seeded fuzz, 500 iterations over random `(hour, minute, now)`: `nextDailyAt` is always `>= now`,
      always `< now + 25h`, and its local `(hour, minute)` always equal the rule — the oracle is
      `TZDateTime` component arithmetic written in the test, not the function under test; echo the
      triple in `reason:`
  11. round trip: `DailyReminderRule` → minutes-since-midnight → rule, for all 1440 minutes
- **Details** — `ScheduledNotification` is a value object: `id` (`int`), `fireAt` (`tz.TZDateTime`),
  `title`, `body`, `payload` (a serializable `String`, here `'today'`), `channelId`, `matchComponents`
  (`DateTimeComponents?`). `DailyReminderRule` holds `hourLocal` and `minuteLocal` — **wall clock plus a
  rule, never a UTC instant**, because a stored instant shifts by an hour at every DST boundary.
  `nextDailyAt(hour, minute, {required Clock clock})` resolves it in `tz.local` and rolls forward a day
  if the time has passed. `ReminderScheduler.compute({required AppSettings settings, required bool
  taperActive, required Clock clock, required NotificationCopy copy})` returns the *desired* set — empty
  when the reminder is off, when there is no active plan, or when the taper has reached target;
  otherwise exactly one entry.
  **That entry is a daily-*repeating* schedule, not a one-shot.** State it in the value object and in the
  dartdoc: `matchComponents: DateTimeComponents.time` and
  `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle` (CONTRACTS §12), with `nextDailyAt`
  computing the **first** fire instant only. A one-shot would silently stop after one morning for a user
  who does not reopen the app — exactly the failure this epic exists to prevent, and the epic previously
  left it ambiguous enough that both readings were defensible.
  `deterministicId(...)` folds **rule identity only**: `(ruleId, hourLocal, minuteLocal,
  sha(title + body))`. It must **not** fold the resolved `TZDateTime` — with a repeating schedule the
  resolved instant changes every calendar day, so the id would change every day, every resume after the
  fire time would cancel-and-reschedule a perfectly good alarm, the "zero gateway writes" property below
  would be false from the second morning onward, and the non-atomic cancel/schedule pair leaves a window
  where a process death arms nothing at all. Changing 08:00 → 14:00, or changing locale (which changes
  the body), still changes the id and still forces the reconcile to re-arm — which is the whole point.
  No `DateTime.now()` anywhere in this directory.
- **Acceptance** — `tool/check-scheduler-purity.sh` passes (it allows `package:timezone` under
  `lib/core/notifications/**` per CONTRACTS §2 and bans every other non-core import). Pure Dart tests (no
  `flutter_test` binding needed beyond `tz` init) cover DST spring-forward, DST fall-back, midnight
  boundary, id stability, and — specifically — **advancing the fixed clock past the fire time and
  recomputing yields the same id**.

### 3. The gateway port and its two adapters

- **What** — Isolate the plugin behind five methods.
- **Where** — `lib/services/notifications/notification_gateway.dart`,
  `fln_notification_gateway.dart`, `fake_notification_gateway.dart`.
- **Tests first (TDD)** — `test/services/notifications/fake_notification_gateway_test.dart`, pure
  `package:test`. The fake is the thing every other test in this epic trusts, so its semantics get
  asserted rather than assumed; `FlnNotificationGateway` itself is a thin translation layer with no
  logic and no off-device test (see the honest note below). Write and watch fail, in this order:
  1. `schedule(n)` then `getPending()` → one entry with the same id, `fireAt`, payload and channel
  2. `schedule` with an **existing id replaces** it: pending length stays 1 and `fireAt` is the new one.
     This mirrors the plugin's real semantics and the whole reconcile diff depends on it
  3. `cancel(id)` removes only that id and leaves the others; `cancelAll()` empties the list
  4. `checkPermission()` returns the settable state, including `denied` **after** it returned `granted` —
     a fake that can never fail would make task 6's revoked-after-grant path untestable
  5. every method records its call so a caller can be asserted on counts, and the counters are readable
     and resettable
  6. `class FakeNotificationGateway implements NotificationGateway` with no `noSuchMethod` superclass, so
     adding a sixth port method is a **compile error** rather than a silent pass — assert by writing the
     fake against the port before the port has all five methods
  **Honestly untested here:** the real plugin adapter. Its correctness is the device matrix in task 9's
  deferred list plus `tool/check-single-fln-import.sh`, and the "verify each API against `pubspec.lock`"
  step is a read of the installed source, not a test.
- **Details** — The port is exactly `schedule`, `cancel`, `cancelAll`, `getPending` and
  **`Future<PermissionState> checkPermission()`** — anything more means logic that belongs in
  `ReminderScheduler`. `checkPermission` is a platform *query*, not scheduler logic, which is why it
  belongs on the seam: without it nothing in the app can ever discover that the OS revoked authorization
  (see task 6). `FlnNotificationGateway` is the **only** file in the repository outside
  `lib/core/notifications/` that imports `flutter_local_notifications`, `timezone` or `flutter_timezone`;
  a grep gate enforces it, with the CONTRACTS §2 exception for `package:timezone` inside the pure core.
  It calls `zonedSchedule` with `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`,
  **unconditionally** — inexact is permission-free and still pierces Doze, and per CONTRACTS §12 there is
  no exact-alarm branch and no `canScheduleExact…` call at all. (The method this epic previously named,
  `canScheduleExactAlarms()`, does not exist in the plugin anyway; the branch is gone, not renamed.)
  > **Verify before you write the call.** Every plugin API named in this epic —
  > `zonedSchedule`, `AndroidScheduleMode.inexactAllowWhileIdle`, `AndroidFlutterLocalNotificationsPlugin
  > .requestNotificationsPermission()` / `.areNotificationsEnabled()`,
  > `IOSFlutterLocalNotificationsPlugin.requestPermissions()` / `.checkPermissions()`,
  > `DarwinNotificationDetails` — must be checked against the **version resolved in `pubspec.lock`**
  > before it is written, and the epic amended if a name differs. This epic has already shipped one
  > method name that does not exist; do not trust the prose over the installed source.
  Android details: one channel `daily_reminder`, importance `Importance.defaultImportance` (not `max` —
  this is a gentle nudge, not an alarm), `visibility: NotificationVisibility.private`, no full-screen
  intent, no ongoing flag. iOS: `DarwinNotificationDetails(presentAlert: true, presentSound: true,
  presentBadge: false)` — a badge implies unread items this app does not have.
  `FakeNotificationGateway` is an in-memory `List<ScheduledNotification>` with the same semantics,
  including "schedule with an existing id replaces it", plus a settable `PermissionState` so the
  revoked-after-grant path is testable.
- **Acceptance** — `tool/check-single-fln-import.sh` passes. Every test in the repo runs against the
  fake with no plugin channel mocking.

### 4. The reconcile entrypoint

- **What** — One idempotent function that every scheduling change flows through.
- **Where** — `lib/services/notifications/sync_notifications.dart`,
  `lib/services/notifications/notification_providers.dart`.
- **Tests first (TDD)** — `test/services/notifications/sync_notifications_test.dart`, driven headlessly
  through `ProviderContainer` with `FakeNotificationGateway`, fake repositories and
  `clockProvider.overrideWithValue(Clock.fixed(2025-04-16T07:00))`; container disposed in teardown, no
  widget pumped. Write and watch fail, in this order:
  1. empty gateway, reminder on, taper active → exactly **one** `schedule` call and **zero** `cancel`
     calls; `getPending()` afterwards equals `ReminderScheduler.compute(...)`
  2. run it a second time with nothing changed → **zero** gateway writes. Asserted on the fake's call
     counters, not on the end state, because the end state is identical either way
  3. advance the fixed clock past the fire time and run again → still zero writes. A repeating alarm
     that gets cancelled and re-armed every morning is the bug the id design exists to prevent
  4. edit the time 08:00 → 14:00 and run → exactly one `cancel(oldId)` and one `schedule(newId)`
  5. reminder toggled off with one pending → exactly one cancel, zero schedules, pending empty
  6. taper reaches target → same shape as (5), asserted separately so one condition cannot mask the other
  7. a pending id that appears in no desired set (a foreign id from a restore) → cancelled
  8. the gateway's `schedule` failing → `Err(ReminderFailure.schedulingRefused())`, and the pending set
     is left in a state the next run repairs — run the reconcile again and assert it converges
  9. the conservation invariant, asserted at the end of **every** case above through one shared helper:
     `getPending()` id set == the computed desired id set
- **Details** — `Future<Result<void, ReminderFailure>> syncNotifications(Ref ref)` (`Result<void, F>` is
  the established convention from EPIC-01/EPIC-05; there is no `Unit` type in this codebase) reads
  settings from `settingsRepository` and plan state from `taperRepository.watchSnapshot()`, calls
  `ReminderScheduler.compute`, diffs against
  `gateway.getPending()`, cancels every pending id not in the desired set and schedules every desired id
  not currently pending. It is the **only** caller of `gateway.schedule`/`gateway.cancel` in the app —
  `tool/check-adhoc-schedule-calls.sh` fails the build on any other. It is safe to call repeatedly:
  running it twice with unchanged inputs performs zero gateway writes, which the test asserts by counting
  fake-gateway calls.
- **Acceptance** — Idempotence test green, **including after the fixed clock has advanced past the fire
  time** (the id folds rule identity only, so a repeating alarm is never churned); an id-changing edit
  produces exactly one cancel and one schedule.

### 5. Reconcile triggers

- **What** — Every place that must call the reconcile, and nowhere else.
- **Where** — `lib/bootstrap.dart`, `lib/app_lifecycle_observer.dart` (EPIC-01/06 put `bootstrap.dart`
  and `app.dart` at the root of `lib/`, and `tool/check_structure.sh` flags a `lib/app/` directory —
  this epic previously named one), plus a `ref.listen` in the settings layer.
- **Tests first (TDD)** — `test/services/notifications/reconcile_triggers_test.dart`,
  `ProviderContainer` plus one `flutter_test` case for the lifecycle listener, both against the fake
  gateway with a counting `syncNotifications` wrapper. Write and watch fail, in this order:
  1. changing `reminderTime` fires exactly **one** reconcile; changing `highContrast` fires **zero**.
     The second half is the point — a `ref.listen` without the `select` passes the first and fails this
  2. changing `resolvedLocaleProvider` from `en` to `fa` fires one reconcile and produces a different id
  3. `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed)` fires one reconcile, and
     `checkPermission()` is called **before** the first `getPending()` — assert the recorded call order
  4. two resumes in a row → the second performs zero gateway writes (idempotence at the trigger, not
     only inside the reconcile)
  5. bootstrap ordering: with `FlutterTimezone` faked to return `TimezoneInfo('Asia/Tehran')`,
     `tz.local.name == 'Asia/Tehran'` after `bootstrap()`, and a gateway that **throws if scheduled
     before `tz.setLocalLocation` ran** proves the ordering rather than assuming it
  6. `.identifier` is read, not the object: a fake returning a `TimezoneInfo` whose `toString()` differs
     from its `identifier` still yields the right zone
  7. a structure assertion that no `boot_rearm_android.dart` exists anywhere in `lib/`
  **Honestly untested:** Android boot re-arm, Doze and OEM battery managers. No Dart runs at boot, so
  there is nothing to assert; those live on task 9's deferred list, not in a green test.
- **Details** — Six triggers: (1) **bootstrap**, after `tz.initializeTimeZones()` +
  `tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier))` and after
  the database opens — note the `.identifier`: `flutter_timezone` v5+ returns a `TimezoneInfo`, not a
  `String`, so pin the version in task 1 and match the call to it. The `timezone` package defaults to
  UTC, and skipping this fires every reminder at the wrong hour; (2) **app resume**, via an
  `AppLifecycleListener(onResume: …)`, which is the reliability backbone — with no server there is no
  other way to discover a dropped reminder, and it is also where `gateway.checkPermission()` runs (task
  6); (3) **settings change**, via
  `ref.listen(settingsControllerProvider.select((s) => (s.reminderEnabled, s.reminderTime)), …)`;
  (4) **locale change** (watch `resolvedLocaleProvider`), because the body text is part of the
  deterministic id; (5) **after a restore** — `cancelAll()` then `syncNotifications`, since restored
  pending ids came from another device and mean nothing here; **the call site lives in EPIC-13's restore
  publish step, so EPIC-13 depends on this epic** (its header and the README graph both carry the edge);
  (6) **Android boot** — the plugin's `ScheduledNotificationBootReceiver` (registered in task 1)
  re-registers **its own persisted alarms** after `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED`; no app code
  runs, no Dart isolate starts, and no database is opened. There is therefore **no
  `boot_rearm_android.dart`** — a Dart file cannot participate in boot re-arming, and the earlier plan to
  write one described something the platform does not offer. It also means the plugin's persisted copy is
  the truth until the next launch, so a backup restored or a time changed *before* a reboot is only
  reconciled at the next launch or resume — which is precisely why (1) and (2) are the reliability
  backbone. Everything except (1)–(3) is explicitly best-effort and the epic says so rather than
  pretending OEM battery managers are solved.
- **Acceptance** — Killing and relaunching the app leaves exactly one pending notification, not two.
  Changing the system time zone in the simulator and resuming moves the fire instant to the new local
  08:00.

### 6. Permissions

- **What** — Ask at the right moment, degrade honestly when refused.
- **Where** — `lib/services/notifications/notification_permissions.dart`, and the reminder row from
  EPIC-11.
- **Tests first (TDD)** — `test/services/notifications/notification_permissions_test.dart`
  (`ProviderContainer` + fake gateway + fake `settingsRepository`) and one `flutter_test` case over
  EPIC-11's reminder row. Write and watch fail, in this order:
  1. toggle on with the fake permission `denied` → `Err(ReminderFailure.permissionDenied())`,
     `reminderEnabled` is still `false` in the fake repository, and **zero** `schedule` calls happened
  2. toggle on with `granted` → `reminderEnabled: true` persisted once, exactly one `schedule`
  3. a full `bootstrap()` plus first frame makes **zero** `requestPermission` calls — the "never prompt
     on launch" rule, asserted as a counter rather than remembered
  4. revoked-after-grant: grant → schedule → flip the fake to `denied` → resume. The row reads "Blocked
     in system settings", the stored `reminderEnabled` is **still true**, `getPending()` is untouched,
     and `tester.takeException()` is null
  5. the explanation renders inline inside the reminder card; `find.byType(SnackBar)` finds nothing
  6. an ARB assertion that no string on this path mentions exact alarms in any of the four locales
- **Details** — Never request on first launch — request at the moment the user turns the toggle **on**,
  which is the only point where the request is self-explanatory. Android 13+:
  `AndroidFlutterLocalNotificationsPlugin.requestNotificationsPermission()`. iOS:
  `IOSFlutterLocalNotificationsPlugin.requestPermissions(alert: true, badge: false, sound: true)` — and
  set `requestAlertPermission: false` etc. in `DarwinInitializationSettings` so initialisation does not
  fire the prompt behind the user's back. A refusal returns `Err(ReminderFailure.permissionDenied())`;
  the toggle snaps back off and an inline explanation appears in the card (never a `SnackBar` —
  information the user must act on does not time out). **Honest limitation:** neither
  `flutter_local_notifications` nor the Flutter SDK can open the OS notification settings page, and this
  app is not taking a dependency on `permission_handler`/`app_settings` for one string
  (`dependency-hygiene`); the explanation therefore tells the user where to go in words, per platform.
  Exact alarms are never requested at all and never mentioned in the UI — scheduling is inexact
  unconditionally (CONTRACTS §12), because a ±10 minute morning reminder is fine.
  **Re-check on resume, not only at toggle-on.** A grant is not permanent: on iOS the user can revoke
  authorization in Settings at any time, and on Android 13+ they can revoke `POST_NOTIFICATIONS` or block
  the `daily_reminder` channel on its own. In every one of those cases `zonedSchedule` still succeeds and
  `getPending` still returns the entry, so a reconcile that only diffs pending ids is perfectly happy
  while nothing ever fires — and the Settings row keeps reading "On · 8:00 am" forever. A 78-year-old
  trusts that row and silently loses the daily prompt, which is the exact failure this epic exists to
  prevent, made invisible by the UI. So: the resume reconcile (trigger 2) calls
  `gateway.checkPermission()` first; if `reminderEnabled == true` and the OS says no, **keep the stored
  setting** (the user's intent has not changed) and render the inline explanation above in the reminder
  card with the row marked **"Blocked in system settings"**.
  > **Contract:** CONTRACTS §12 — authorization must be re-checked on resume, and the plugin's real API
  > surface verified against `pubspec.lock` before the call is written.
- **Acceptance** — Toggling on with permission denied leaves `reminderEnabled == false` in the database
  and shows a reason; the app never prompts on launch. A fake-backed test for the **revoked-after-grant**
  path: grant, schedule, flip the fake to denied, resume — the row reads "Blocked in system settings",
  the stored setting is untouched, and no exception reaches the UI.

### 7. Copy, in four locales

- **What** — Notification text that reads as a plan, not an instruction, and carries no medical detail.
- **Where** — `lib/l10n/arb/app_{en,de,fa,ckb}.arb` (the `arb-dir` EPIC-03 set in `l10n.yaml`),
  `lib/services/notifications/notification_copy.dart`.
- **Tests first (TDD)** — `test/services/notifications/notification_copy_test.dart`, over the generated
  `AppLocalizations` loaded per locale with no widget pumped. Authoring the translations is craft; the
  medical-safety and privacy constraints on them are mechanical, and those are the tests. Write and
  watch fail, in this order:
  1. for each of `en`, `de`, `fa`, `ckb`: `reminderBody` contains **no** Unicode decimal digit — not
     ASCII, not U+06Fx, not U+066x. This is the "no dose in the notification" rule made checkable
  2. `reminderTitle` in `en` is exactly `Your plan for today`
  3. neither ARB entry declares a placeholder — a `{dose}` in the body is impossible by construction
  4. neither string contains the drug name from the seeded fixture, in any locale
  5. no locale's title begins with an imperative form, checked against a per-locale prefix list authored
     **with the translator** and committed next to the test — a guess here would be worse than nothing
  6. `fa` and `ckb` values contain no stray U+200E/U+200F — the exact defect the epic names, invisible
     in review and visible in the shade
  7. `NotificationCopy.from(l10n)` for two different locales produces two different `(title, body)`
     pairs, which is what makes task 2's id change on a locale switch
- **Details** — Title `reminderTitle`: **"Your plan for today"** (SPEC §11.4 settles this — *not* "Take
  your pills", *not* "Time for your dose", *not* an imperative in any locale). Body `reminderBody`:
  "Open NearlyStop to see today's dose." — no number, no drug name, no tablet counts. The body must not
  imply the app knows whether the dose was taken. Copy is resolved through a `NotificationCopy` value
  object built from `ref.read(appLocalizationsProvider)` — CONTRACTS §4 makes that the only sanctioned
  way to reach `AppLocalizations` outside a widget, and it already resolves the **current app locale**
  (EPIC-11's Language picker writes `localeTag`, so this is genuinely not always the OS locale) and
  rebuilds on both a settings change and an OS locale change. It is snapshotted at reconcile time and
  passed into the pure scheduler, so
  `ReminderScheduler` stays Flutter-free. German, Persian and Sorani are authored translations, and the
  Persian/Sorani bodies are checked for correct rendering in a real notification shade — RTL text in a
  notification is the platform's job, but a stray LRM in the ARB will show.
- **Acceptance** — Four ARBs carry both keys; no locale's string is an imperative verb form; a test
  asserts the body contains no digits.

### 8. Tap handling

- **What** — Tapping the notification opens Today.
- **Where** — `fln_notification_gateway.dart` (initialisation), `lib/routing/` (the deep link).
- **Tests first (TDD)** — `test/services/notifications/notification_tap_test.dart`, pure
  `package:test` for the mapping; the launch path itself is
  `integration_test/notification_launch_test.dart`, written alongside because it needs a real binding.
  Write and watch fail, in this order:
  1. `payloadToRoute('today')` → `'/today'`
  2. an unknown payload and an empty payload each → `null`, and the caller navigates nowhere
  3. round trip: the payload survives `jsonDecode(jsonEncode(p))` unchanged — proof that nothing
     non-serializable can be put in it
  4. a source assertion that the background handler is a **top-level** function, carries
     `@pragma('vm:entry-point')`, and its file imports no DAO, no `AppDatabase` and no drift symbol.
     Two isolates writing one database is not a bug a runtime test would survive to report
- **Details** — `onDidReceiveNotificationResponse` maps the serializable payload `'today'` to
  `router.go('/today')`. The background handler
  `onDidReceiveBackgroundNotificationResponse` is a **top-level** function annotated
  `@pragma('vm:entry-point')`; it runs in a separate isolate with no access to main-isolate state and
  **must not write to the database** — concurrent access from two isolates risks corruption. It records
  nothing in v1: the tap that matters is the foreground one. Never put a non-serializable object in
  `extra`; reconstruct everything from the DB after the route resolves. Guard `mounted`/`context` after
  every await in the foreground handler.
- **Acceptance** — A launch-from-notification integration test lands on `/today` with the tab bar showing
  Today selected; the background handler is annotated and touches no DAO.

### 9. Tests

- **What** — Prove the engine off-device.
- **Where** — `test/core/notifications/`, `test/services/notifications/`.
- **Tests first (TDD)** — almost everything this task lists was already written first, and watched
  failing, under tasks 2, 4, 5, 6 and 7; this task is where they are collected and where the deferred
  set is written down honestly. One test genuinely belongs here and is written before the wiring it
  covers: `test/features/settings/reminder_toggle_e2e_test.dart`, a `flutter_test` widget test that is
  this epic's single **acceptance gate** —
  1. pump Settings with `FakeNotificationGateway` and the clock pinned; toggle the reminder on; pick
     08:00; then assert `getPending()` holds **exactly one** entry, at local 08:00, with
     `matchComponents == DateTimeComponents.time` and the inexact schedule mode. One realistic scenario,
     asserted to the exact expected value — that the pieces compose is the only thing it proves, and
     nothing else in the epic proves it
  2. toggle it back off in the same test → pending is empty. The round trip, not just the arm
  **Deferred, not faked green:** reboot survival, Doze, OEM battery managers and real notification-shade
  rendering of the `fa`/`ckb` bodies. These go on EPIC-14's manual device matrix and into the PR's
  Deferred section; a green emulator test over any of them would be worse than the admitted gap.
- **Details** — Pure tests with `Clock.fixed` and `tz` initialised from the embedded database:
  DST spring-forward (an 08:00 reminder on the day the clock jumps still fires at local 08:00), DST
  fall-back, reminder off → empty desired set, taper complete → empty desired set, a time edit produces a
  new id, a locale change produces a new id, **the clock advancing past the fire time produces the same
  id and zero gateway writes**, running the reconcile twice writes nothing the second time, the
  revoked-after-grant path from task 6, and a restore path (`cancelAll` then reconcile) ending with the
  desired set exactly. Plus a `FakeNotificationGateway`-backed widget test that toggles the Settings
  switch and asserts exactly one pending, daily-repeating notification at the chosen minute.
  **Stated honestly:** reboot survival, Doze behaviour and OEM battery-manager survival are **not**
  covered by any automated test — an emulator green run proves nothing about a Xiaomi. Those go on the
  EPIC-14 manual device matrix.
- **Acceptance** — All listed tests green; the untestable set is written into the PR's "Deferred"
  section rather than implied to be covered.

## Definition of done

- [ ] Every TDD task's tests were written first and observed failing before its implementation
- [ ] `flutter_local_notifications` imported in exactly one file; the check script passes, with the
      CONTRACTS §2 `package:timezone` exception for `lib/core/notifications/**` encoded in the gate
- [ ] All scheduling maths pure and Clock-injected; the purity check script passes
- [ ] `syncNotifications()` is the only caller of `schedule`/`cancel`; the ad-hoc check script passes
- [ ] `tz.local` set in `bootstrap()` before any `zonedSchedule`, from `TimezoneInfo.identifier`
- [ ] The daily reminder is stored as wall-clock + rule, never a UTC instant, and scheduled as a
      **repeating** entry with `DateTimeComponents.time`
- [ ] `AndroidScheduleMode.inexactAllowWhileIdle` is used unconditionally; **neither
      `SCHEDULE_EXACT_ALARM` nor `USE_EXACT_ALARM` appears in the merged manifest**, and the permission
      script asserts the whole expected set (CONTRACTS §12)
- [ ] Deterministic ids fold rule identity only — never the resolved fire instant; a time or locale
      change reschedules, and a day passing does not
- [ ] Permission requested only on toggle-on; denial returns a typed failure, reverts the toggle, and
      explains in an inline surface
- [ ] Authorization is **re-checked on every resume** via `gateway.checkPermission()`; a revoked grant
      marks the row "Blocked in system settings" without discarding the user's setting
- [ ] Reconcile runs on bootstrap, resume, settings change, locale change and after restore; Android boot
      re-arm is the plugin's own native receiver, and no `boot_rearm_android.dart` exists
- [ ] Copy is "Your plan for today" in all four locales, contains no dose, drug name or imperative, and
      Android visibility is `private`
- [ ] Background tap handler is `@pragma('vm:entry-point')`, writes nothing to the DB, and carries a
      serializable payload
- [ ] The full pure test matrix is green; the untested platform matrix is named explicitly
- [ ] `/simplify` run, every finding fixed
- [ ] `/code-review` run, every finding fixed
- [ ] PR opened with a description covering what/why, tasks closed, tests added, deferrals
- [ ] CI green
- [ ] Merged to `main`
