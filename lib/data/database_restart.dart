/// Replacing the database file under a running app.
library;

import 'package:riverpod/riverpod.dart';

/// How many times the database file has been replaced since launch.
///
/// A restore does not write rows — it renames a whole new file over the live
/// one (`restore_service.dart`). Every handle the app is holding then points
/// at the **old inode**: on POSIX the rename succeeds and the old connection
/// carries on reading a file nothing will ever look at again. The symptom is
/// the worst one this app has: a restore that reports success and shows the
/// pre-restore plan until the next launch.
///
/// Bumping this rebuilds `databaseProvider`, which closes the stale connection
/// and opens one on the file that is actually there — and, because every
/// repository watches it, rebuilds every screen with it.
final NotifierProvider<DatabaseGeneration, int> databaseGenerationProvider =
    NotifierProvider<DatabaseGeneration, int>(DatabaseGeneration.new);

/// Counts database-file replacements.
class DatabaseGeneration extends Notifier<int> {
  @override
  int build() => 0;

  /// Says the file underneath has been replaced.
  ///
  /// Called by the restore, **after** the publish and whether it succeeded or
  /// not: the connection was closed before the rename either way, so the app
  /// needs a fresh one in both outcomes.
  void replaced() => state = state + 1;
}
