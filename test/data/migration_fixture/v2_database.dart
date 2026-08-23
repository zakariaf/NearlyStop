/// A **synthetic** schema v2, living only in `test/`.
///
/// The upgrade ceremony has to be exercised before an upgrade is needed, and
/// the alternative — shipping a dead column in v1 so there is something to
/// migrate — puts a lie in the schema every future migration then carries.
/// This fixture is v1 plus one additive nullable column. `drift_schemas/`
/// holds v1 alone, so the app ships nothing extra.
library;

import 'package:drift/drift.dart';
// The generated part below names these; a part does not inherit tables.dart's
// imports.
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/converters.dart';
import 'package:nearlystop/data/db/tables.dart';

part 'v2_database.g.dart';

/// `DoseLogs` at v2: the v1 columns plus `recordedSource`.
///
/// `tableName` is overridden because the migration must land on the **same**
/// SQL table the v1 rows are in; without it drift would derive
/// `dose_logs_v2` and the test would happily migrate an empty table.
@DataClassName('DoseLogV2Row')
class DoseLogsV2 extends DoseLogs {
  /// The additive column under test. Nullable, so the migration is a plain
  /// `ALTER TABLE ... ADD COLUMN` with no backfill.
  TextColumn get recordedSource => text().nullable()();

  @override
  String get tableName => 'dose_logs';
}

/// The database at the synthetic v2.
@DriftDatabase(
  tables: <Type>[
    TaperPlans,
    Steps,
    DoseLogsV2,
    FlareEvents,
    HoldEvents,
    SettingsRows,
  ],
)
class AppDatabaseV2 extends _$AppDatabaseV2 {
  /// Opens the v2 database over [e].
  AppDatabaseV2(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(doseLogsV2, doseLogsV2.recordedSource);
      }
    },
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
