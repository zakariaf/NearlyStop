/// The one database.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
// The generated part file below names these types; a part does not inherit
// tables.dart's imports, so they have to be visible from this library.
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/converters.dart';
import 'package:nearlystop/data/db/daos/log_dao.dart';
import 'package:nearlystop/data/db/daos/plan_dao.dart';
import 'package:nearlystop/data/db/daos/settings_dao.dart';
import 'package:nearlystop/data/db/daos/step_dao.dart';
import 'package:nearlystop/data/db/database_location.dart';
import 'package:nearlystop/data/db/schema_versions.dart';
import 'package:nearlystop/data/db/tables.dart';

part 'app_database.g.dart';

/// The app's SQLite database.
///
/// Ships at **schema version 1**. The database on the patient's phone is the
/// only copy of a 780-day plan that exists until EPIC-13 gives them an export,
/// which is why the migration ceremony in `test/data/migration_test.dart` is
/// exercised against a fixture before it is ever needed for real.
@DriftDatabase(
  tables: <Type>[
    TaperPlans,
    Steps,
    DoseLogs,
    FlareEvents,
    HoldEvents,
    SettingsRows,
  ],
  daos: <Type>[PlanDao, StepDao, LogDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the shipping database at [location], on a background isolate.
  AppDatabase(DatabaseLocation location)
    : super(
        LazyDatabase(
          () async => NativeDatabase.createInBackground(await location()),
        ),
      );

  /// Opens a database over [e] — an in-memory or temp-file engine.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Generated from the dumped schemas in `drift_schemas/`, one step per
    // version. At v1 there are no steps to take and this helper is a no-op —
    // it is wired now so that adding v2 is a dump and a regenerate rather than
    // hand-writing a migration against a database holding 780 days of history.
    onUpgrade: stepByStep(),
    beforeOpen: (details) async {
      // PER-CONNECTION and not persisted in the file, so it has to be
      // re-asserted on every open. SQLite defaults it OFF and silently no-ops
      // every cascade below, which makes deleting a plan leave orphaned logs.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
