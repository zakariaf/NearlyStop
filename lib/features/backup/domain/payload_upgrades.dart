/// Bringing an older payload forward, in memory, before any database sees it.
library;

import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/features/backup/domain/restore_failure.dart';

/// One row from a backup, with the line it came from.
typedef UpgradedRow = ({String table, Map<String, Object?> row, int line});

/// A pure transformer from schema `N` to `N + 1`.
typedef PayloadUpgrader = List<UpgradedRow> Function(List<UpgradedRow> rows);

/// The ladder, keyed by the schema a rung upgrades FROM.
///
/// **In the codec, not in a staging database** (CONTRACTS §11). A fresh drift
/// database opened through `AppDatabase` runs `createAll()` at the CURRENT
/// schema before a single row is inserted, so a staging database is already
/// current: old-shaped rows either fail on a renamed column or drop data
/// silently, and the migration step is a no-op because `user_version` is
/// already right. The one case a ladder exists for — restoring an older backup
/// — is precisely the case that approach cannot do.
///
/// **Every future schema bump adds a rung here and a fixture.** That is a
/// checklist line in EPIC-05's migration ritual, and the empty map below is
/// correct only while the app has ever had one schema version.
const Map<int, PayloadUpgrader> kPayloadUpgraders = <int, PayloadUpgrader>{};

/// Runs [rows] up the ladder from [from] to [to].
///
/// A missing rung is a refusal, never a pass-through: an unmigrated payload
/// inserted into a current-schema database is the silent data loss this whole
/// ladder exists to prevent.
///
/// [ladder] defaults to the shipped one. It is a parameter because at v1 there
/// is no real rung to run, and machinery whose only test is "the empty map
/// does nothing" is machinery nobody has ever seen work.
Result<List<UpgradedRow>, RestoreFailure> upgradePayload({
  required List<UpgradedRow> rows,
  required int from,
  required int to,
  Map<int, PayloadUpgrader> ladder = kPayloadUpgraders,
}) {
  var current = rows;
  for (var version = from; version < to; version++) {
    final upgrader = ladder[version];
    if (upgrader == null) {
      return Err(
        PublishFailed(
          'no payload upgrader from schema $version to ${version + 1}',
        ),
      );
    }
    current = upgrader(current);
  }
  return Ok(current);
}
