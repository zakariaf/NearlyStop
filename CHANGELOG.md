# Changelog

All notable changes to NearlyStop. The format is [Keep a Changelog][kac] and
the versions are [semantic][semver]; the build number after the `+` is Play's
`versionCode` and Apple's `CFBundleVersion`, and it only ever goes up.

[kac]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html

## [Unreleased]

Nothing yet.

## [1.0.0+1] — unreleased

The first version. An offline, account-free companion for a *Dead Slow and
Nearly Stop* prednisolone taper.

### Added

- **Today.** The one number the morning is about, the tablets it is made from,
  and one 88pt action to tick it. A backfill prompt when yesterday was missed,
  and quiet paths to a note, a hold or a flare.
- **Schedule.** The 52-day step, grouped by its eleven DSNS blocks, with the
  teaching sentence for each. Never a seven-column month grid — the calendar is
  the confusion this app exists to remove.
- **Progress.** The staircase, days on the drug, cumulative milligrams and a
  taken-day count that is never a percentage and never a streak.
- **Plan.** Drug, start date, current and target dose, the tablet strengths you
  actually hold, and three taper methods. The suggested step is an editable
  default; the app never decides a dose.
- **Settings.** A daily reminder, an in-app text-size control on top of the OS
  one, high contrast, and a language picker for all four languages.
- **Open source, and linked from inside the app.** Settings names the public
  repository and opens it in the system browser. It is the app's only outbound
  link, and it exists because "nothing leaves your phone" is a claim the app
  cannot demonstrate about itself — the code can be read instead of trusted.
- **Backup and restore.** One NDJSON file with a SHA-256 header. Restore is
  replace-all, behind a guard that offers a backup first, and either restores
  or leaves the database byte-unchanged.
- **Doctor export.** A one-page PDF handout and a spreadsheet, both from the
  same numbers the Progress screen shows.
- **Four languages** — English, German, Persian and Kurdish Sorani — with full
  right-to-left support and each locale's own numerals.
- **Accessibility as correctness.** Every screen survives the largest OS text
  size multiplied by the in-app one, on a 320pt phone, in every language. WCAG
  AA measured in all four palettes and published in
  `docs/a11y/contrast-budget.md`. No state signalled by colour alone.

### Privacy

- No account, no server, no analytics, no crash SDK. The Android release build
  carries no `INTERNET` permission at all. Exports leave the app only when you
  choose to share them.
