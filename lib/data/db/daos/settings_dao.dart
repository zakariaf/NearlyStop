/// Queries over the single settings row.
library;

import 'package:drift/drift.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/data/db/tables.dart';

part 'settings_dao.g.dart';

/// The only door to SQL for [SettingsRows].
@DriftAccessor(tables: <Type>[SettingsRows])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  /// Creates the DAO over [db].
  SettingsDao(super.attachedDatabase);

  /// The row id. `CHECK(id = 0)` is what stops a second row existing.
  static const int rowId = 0;

  /// Writes the defaults row if it is not there. Idempotent.
  Future<void> ensureRowExists(String uid) async {
    await into(settingsRows).insert(
      SettingsRowsCompanion.insert(id: const Value<int>(rowId), uid: uid),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// The settings row, re-emitting on every write.
  Stream<SettingsRow?> watchSettings() => (select(
    settingsRows,
  )..where((t) => t.id.equals(rowId))).watchSingleOrNull();

  /// The settings row, read once — the pre-first-paint path.
  Future<SettingsRow?> readSettingsOnce() => (select(
    settingsRows,
  )..where((t) => t.id.equals(rowId))).getSingleOrNull();

  /// Writes the given fields, leaving every other one untouched.
  Future<void> updateSettings(SettingsRowsCompanion patch) async {
    await (update(
      settingsRows,
    )..where((t) => t.id.equals(rowId))).write(patch);
  }
}
