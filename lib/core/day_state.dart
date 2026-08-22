/// The state of one logged day.
library;

/// How a single day's dose stands.
///
/// **Exactly four members** (CONTRACTS.md §1). This is the *row log* state —
/// what the palette colours and what the greyscale golden has to distinguish.
///
/// A dose change is **not** a fifth member. A day is routinely both `today` and
/// a new-dose day, so one enum value could never express a real day; the
/// new-dose signal is a separate `bool isNewDose` on `DayPlan`, rendered with
/// the `stateNewDose` slot. `DoseKind` is the domain-level concept of which
/// dose a day carries, and is a different axis from this one.
enum DayState {
  /// The dose was ticked.
  taken,

  /// The day passed and was never ticked. Rendered in warm taupe, never red.
  missed,

  /// The day the user is looking at now.
  today,

  /// A day that has not happened yet.
  upcoming,
}
