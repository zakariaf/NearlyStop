/// The `SPEC.md` §6 data model, as drift tables. **Facts only.**
///
/// There is no `DayPlan` table and no schedule cache. A 780-day schedule is 780
/// rows, so the temptation to store it is real — but then a flare has to
/// rewrite history, an edit has to reconcile, and two-year-old rows become a
/// second source of truth that can disagree with the first. What goes in here
/// is what the patient and the doctor decided, plus what actually happened.
///
/// Every table carries `uid TEXT NOT NULL UNIQUE`, a ULID minted at insert.
/// EPIC-13's backup format is built on stable text ids — re-importing with
/// autoincrement rowids duplicates everything — and retrofitting stable ids
/// onto a database already holding a real user's 400-day taper is exactly the
/// migration this schema exists to avoid (CONTRACTS.md §11).
library;

import 'package:drift/drift.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/data/db/converters.dart';

/// The plan the patient and their doctor agreed.
///
/// **v1 holds at most one plan.** There is no "active" flag and none is needed:
/// the active plan is `ORDER BY createdAt DESC LIMIT 1`, so a fresh install and
/// a post-delete state are both a well-defined `null` rather than a throw.
/// `SPEC.md` §8 cuts multiple concurrent tapers from v1; this is that decision
/// written into the schema instead of left to whichever of
/// `getSingle()`/`getSingleOrNull()` the next implementer reaches for.
@DataClassName('TaperPlanRow')
class TaperPlans extends Table {
  /// Surrogate key. Local only — never exported.
  IntColumn get id => integer().autoIncrement()();

  /// Stable identity across an export/import round trip.
  TextColumn get uid => text().unique()();

  /// Free text, defaulting to Prednisolone. Never looked up in a drug database.
  TextColumn get drugName =>
      text().withDefault(const Constant('Prednisolone'))();

  /// The first day of the plan.
  TextColumn get startDate => text().map(const LocalDateConverter())();

  /// The dose the plan starts from, in hundredths of a milligram.
  IntColumn get startingDose => integer().map(const MilligramsConverter())();

  /// The dose the plan aims at, usually zero.
  IntColumn get targetDose => integer().map(const MilligramsConverter())();

  /// The strengths the patient holds, descending, deduplicated.
  TextColumn get tabletStrengths => text().map(const StrengthListConverter())();

  /// Whether the patient said they can split a tablet.
  BoolColumn get allowHalves => boolean()();

  /// Which arithmetic the plan uses.
  TextColumn get method => text().map(const TaperMethodConverter())();

  /// Percent per step, for [TaperMethod.percentage].
  ///
  /// The one genuine REAL in the schema, and it is not a dose.
  RealColumn get percentage => real().nullable()();

  /// A fixed step size, for [TaperMethod.fixedMg]. A dose, so an INTEGER.
  IntColumn get fixedStep =>
      integer().map(const MilligramsConverter()).nullable()();

  /// When the plan was created, as UTC epoch milliseconds.
  IntColumn get createdAt => integer().map(const UtcInstantConverter())();
}

/// One reduction: from a dose, to a dose, starting on a date.
@DataClassName('StepRow')
class Steps extends Table {
  /// Surrogate key.
  IntColumn get id => integer().autoIncrement()();

  /// Stable identity across an export/import round trip.
  TextColumn get uid => text().unique()();

  /// Owning plan; deleting the plan deletes its steps.
  IntColumn get planId => integer()();

  /// 0-based position in the plan.
  ///
  /// **`stepIndex`, not `index`.** `INDEX` is a reserved SQLite keyword, and
  /// the composite unique below is a hand-written constraint drift passes
  /// through
  /// verbatim — `UNIQUE(plan_id, index)` is a syntax error at table creation.
  IntColumn get stepIndex => integer()();

  /// The dose this step steps down from.
  IntColumn get fromDose => integer().map(const MilligramsConverter())();

  /// The dose this step steps down to.
  IntColumn get toDose => integer().map(const MilligramsConverter())();

  /// The first day of the step.
  TextColumn get startDate => text().map(const LocalDateConverter())();

  /// The stored status. A record of events, never a derived cache.
  TextColumn get status => text().map(const StepStatusConverter())();

  /// The `DsnsPattern` version frozen when this step was created.
  IntColumn get patternVersion => integer()();

  @override
  List<String> get customConstraints => const <String>[
    'UNIQUE(plan_id, step_index)',
    'FOREIGN KEY(plan_id) REFERENCES taper_plans(id) ON DELETE CASCADE',
  ];
}

/// One logged day.
@DataClassName('DoseLogRow')
class DoseLogs extends Table {
  /// Surrogate key.
  IntColumn get id => integer().autoIncrement()();

  /// Stable identity across an export/import round trip.
  TextColumn get uid => text().unique()();

  /// Owning plan; deleting the plan deletes its logs.
  IntColumn get planId => integer()();

  /// The calendar day this log is about.
  TextColumn get date => text().map(const LocalDateConverter())();

  /// What the schedule said, frozen at the moment it was logged.
  IntColumn get plannedMg => integer().map(const MilligramsConverter())();

  /// What the patient actually took, frozen at tick time.
  IntColumn get actualMg => integer().map(const MilligramsConverter())();

  /// Whether the patient ticked the day.
  BoolColumn get taken => boolean()();

  /// When they ticked it, as UTC epoch milliseconds.
  IntColumn get takenAt =>
      integer().nullable().map(const UtcInstantConverter())();

  /// The patient's own words.
  TextColumn get note => text().nullable()();

  @override
  List<String> get customConstraints => const <String>[
    // The idempotency key. Ticking twice and backfilling three days late are
    // both a plain upsert against this, not a read-modify-write race.
    'UNIQUE(plan_id, date)',
    'FOREIGN KEY(plan_id) REFERENCES taper_plans(id) ON DELETE CASCADE',
  ];
}

/// A flare: the patient went back to the last dose that worked.
@DataClassName('FlareEventRow')
class FlareEvents extends Table {
  /// Surrogate key.
  IntColumn get id => integer().autoIncrement()();

  /// Stable identity across an export/import round trip.
  TextColumn get uid => text().unique()();

  /// Owning plan; deleting the plan deletes its flares.
  IntColumn get planId => integer()();

  /// The day the flare was recorded.
  TextColumn get date => text().map(const LocalDateConverter())();

  /// The dose the patient went back to.
  IntColumn get revertToDose => integer().map(const MilligramsConverter())();

  /// The patient's own words.
  TextColumn get note => text().nullable()();

  @override
  List<String> get customConstraints => const <String>[
    'FOREIGN KEY(plan_id) REFERENCES taper_plans(id) ON DELETE CASCADE',
  ];
}

/// A hold: stay at the current block and dose for a few more days.
@DataClassName('HoldEventRow')
class HoldEvents extends Table {
  /// Surrogate key.
  IntColumn get id => integer().autoIncrement()();

  /// Stable identity across an export/import round trip.
  TextColumn get uid => text().unique()();

  /// Owning step; deleting the plan cascades THROUGH Steps to here.
  IntColumn get stepId => integer()();

  /// The last day taken as normal; the extra days follow it.
  TextColumn get fromDate => text().map(const LocalDateConverter())();

  /// How many extra days to insert.
  IntColumn get extraDays => integer()();

  /// The patient's own words.
  TextColumn get note => text().nullable()();

  @override
  List<String> get customConstraints => const <String>[
    // A hold of zero or fewer days is not a hold. The generator ignores one
    // either way; refusing it at the storage layer means the row cannot exist.
    'CHECK(extra_days > 0)',
    'FOREIGN KEY(step_id) REFERENCES steps(id) ON DELETE CASCADE',
  ];
}

/// The single settings row.
///
/// `textScale`, `highContrast`, `themeMode` and `localeTag` live here because
/// they have to be readable **before first paint** (`SPEC.md` §4.5).
@DataClassName('SettingsRow')
class SettingsRows extends Table {
  /// Always 0 — the CHECK below is what stops a second row existing.
  IntColumn get id => integer()();

  /// Stable identity across an export/import round trip.
  TextColumn get uid => text().unique()();

  /// Whether the daily reminder is on.
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Minutes since **local** midnight.
  ///
  /// A reminder is a wall-clock time. Storing it as an instant is the same DST
  /// bug in a different hat.
  IntColumn get reminderMinuteOfDay => integer().nullable()();

  /// The user's text-scale preference, on top of the OS setting.
  RealColumn get textScale => real().withDefault(const Constant(1))();

  /// Whether the high-contrast palette is selected.
  BoolColumn get highContrast => boolean().withDefault(const Constant(false))();

  /// When the disclaimer was accepted, as UTC epoch milliseconds.
  IntColumn get disclaimerAcceptedAt =>
      integer().nullable().map(const UtcInstantConverter())();

  /// The chosen locale, or null to follow the OS.
  TextColumn get localeTag => text().nullable()();

  /// `system`, `light` or `dark`.
  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => const <String>['CHECK(id = 0)'];
}
