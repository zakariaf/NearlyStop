# Crash policy — how a crash becomes readable with no SDK

## The decision

**No crash SDK. No Sentry, no Crashlytics, no telemetry core.** Not a
preference — all three are data collection under both stores' rules, all three
would change the privacy declaration from "collects nothing" to something that
needs a form filling in, and all three contradict SPEC §5.3 and rule 1 of this
project.

What replaces them is a file the user can open and read themselves.

## The mechanism

Two handlers, installed as the **first statements** of `bootstrap()`, before
anything that can throw and in particular before the database is opened — a
corrupt database is exactly the crash worth having a record of:

- `FlutterError.onError`
- `PlatformDispatcher.instance.onError`

**No `runZonedGuarded`.** It would catch the same errors a third time and add
a zone the whole app then runs inside, for no reportable gain.

Both feed `CrashSink` (`lib/core/diagnostics/crash_sink.dart`), which appends
one JSON line per crash to `diagnostics.log` in the app's support directory.

### What a record contains

| Field | Why |
|---|---|
| `version` | `1.0.0+1`. A release build is obfuscated, so the trace only decodes against the symbol archive for **that exact version**. A stack with no version on it is a stack nobody can read. |
| `platform` | `ios 18.0`, `android 14`. Enough to tell two reports apart. |
| `context` | Where it happened, e.g. `building TodayScreen`. |
| `error` | The exception's own `toString()`. |
| `stack` | Escaped onto one line, so counting records never means parsing them. |

### What a record must never contain

No drug name, no dose, no note, no date from the taper, and no device
identifier. `test/core/diagnostics/crash_log_test.dart` seeds the exact values
a real plan carries, forces an error, and searches the log for each of them —
plus a shape check for anything matching `\d+(\.\d+)? ?mg`, because a dose is a
dose whatever the number is.

The failure this guards against is concrete: somebody mails a diagnostic report
to a stranger and it carries their medication, their dose and what they wrote
about how the week went.

## The cap

Two caps, both enforced, because either alone has a hole:

- **50 records** — a flood of tiny entries would otherwise push out the one
  that mattered.
- **64 KB** — one 2 MB stack trace would otherwise fill the disk of a phone
  that is already misbehaving.

`FlutterError.onError` can fire **once per frame** — a throwing `build` method
does exactly that — so the steady-state write is an append and the file is only
rewritten on the frames where rotation actually drops something. A seeded fuzz
of 500 entries at random sizes asserts the ceiling holds every time, not on
average.

Truncation cuts on a **character boundary**. Slicing UTF-8 bytes mid-character
leaves a partial sequence that decodes to U+FFFD, which is itself three bytes —
so the slice can re-encode *longer* than the cap. Two of this app's four
locales are Perso-Arabic, where every character is two bytes, so that is the
ordinary case rather than an exotic one.

## Getting it off the phone

`CrashSink.diagnosticReport()` returns the file, or **null when nothing has
crashed** — and it does not create an empty file to say so, because an empty
report mailed to somebody is worse than no report: it makes them wait for an
answer to it.

It returns a path and nothing else. It opens no share sheet, touches no gateway
and sends nothing. The share happens **only** from the reader's own tap. That
separation is asserted by grepping the source, because it is a claim about what
the code does *not* do.

> ### ⚠️ Defect against EPIC-11 — the row does not exist
>
> Per CONTRACTS §13 the **"Send diagnostic report"** row belongs in EPIC-11's
> Settings → About card, with its ARB keys in all four locales, its semantics
> label, its golden and its frame-6 parity cell. **It was never built.**
>
> EPIC-15 deliberately does not add it. A control added now would ship
> unlocalized, unlabelled for VoiceOver and unmeasured, on the
> accessibility-critical screen for the accessibility-critical audience, after
> EPIC-14 signed off that screen's parity, semantics, tap targets and 200%
> reflow. That is exactly the sequence the contract exists to prevent.
>
> **Filed as a defect against EPIC-11.** Until it is built, the log exists and
> is written but there is no in-app way to hand it over; a support request has
> to ask for the file by path. The plumbing behind the row — the handlers, the
> file, the cap, `diagnosticReport()` and the symbolication below — is done and
> tested, so building the row is a UI task with a golden and a parity cell, not
> a feature.

## Symbolication

Release builds are obfuscated, so a user-mailed trace is meaningless until it
is decoded — locally, on the machine that has the symbols:

```bash
flutter symbolize \
  -i crash.txt \
  -d build/symbols/1.0.0+1/app.android-arm64.symbols
```

**It only works against that exact build.** A rebuild of the same commit
produces different symbols and decodes nothing.

### Retention

Keep `build/symbols/<version>/` for **as long as that version is installable**
— which on both stores means until every user has been forced past it, not
until the next release ships. Practically: keep every version's archive for two
years, matching the longest taper this app is designed for, because a user on
version 1.0.0 four hundred days into their plan is exactly the person whose
crash report matters most.

Archive it **off this machine, before anything is uploaded**
(`docs/release/RELEASING.md` step 4).
