/// Restoring a backup: validate, stage, swap.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/features/backup/domain/backup_envelope.dart';
import 'package:nearlystop/features/backup/domain/payload_upgrades.dart';
import 'package:nearlystop/features/backup/domain/restore_failure.dart';

/// Replaces the live database with [file]'s contents, or changes nothing.
///
/// **The live database is never opened for writing until the last moment.**
/// Every refusal below happens before a staging file exists, and the publish
/// itself is a rename with a complete rollback set — so the outcomes are
/// "restored" and "byte-unchanged", with nothing in between.
///
/// The ladder, in order, each rung its own typed failure:
///
/// 1. line 1 is not a header → [NotABackupFile]
/// 2. the envelope's format is newer → [UnsupportedFormat]
/// 3. the payload's schema is newer → [NewerThanApp]. **Refused, never
///    guessed**: this is what stops somebody on an old build from silently
///    mangling data a new one wrote.
/// 4. the digest does not match → [CorruptedBackup], before anything is staged
/// 5. the payload is upgraded IN MEMORY to the current schema
/// 6. it is imported into a fresh staging database, in one transaction
/// 7. the staged file is published WAL-safely, with a rollback set
Future<Result<void, RestoreFailure>> restoreBackup({
  required File file,
  required File liveDatabaseFile,
  required Directory stagingDirectory,
  required int appSchemaVersion,
  Future<void> Function(AppDatabase reopened)? verifyPublished,
  Map<int, PayloadUpgrader> upgraders = kPayloadUpgraders,
}) async {
  final String text;
  try {
    text = await file.readAsString();
  } on Object {
    // Unreadable bytes are not a backup. `PickUnreadable` is the picker's
    // problem; by the time we are here the file was chosen and opened.
    return const Err(NotABackupFile());
  }

  final firstBreak = text.indexOf('\n');
  if (firstBreak <= 0) return const Err(NotABackupFile());
  final headerResult = BackupHeader.parse(text.substring(0, firstBreak));
  if (headerResult is! Ok<BackupHeader, EnvelopeFailure>) {
    return const Err(NotABackupFile());
  }
  final header = headerResult.value;

  if (header.formatVersion > kBackupFormatVersion) {
    return Err(UnsupportedFormat(header.formatVersion));
  }
  if (header.schemaVersion > appSchemaVersion) {
    return Err(
      NewerThanApp(
        fileSchema: header.schemaVersion,
        appSchema: appSchemaVersion,
      ),
    );
  }

  final payload = text.substring(firstBreak + 1);
  if (sha256.convert(utf8.encode(payload)).toString() != header.payloadSha256) {
    return const Err(CorruptedBackup());
  }

  // Parsed and upgraded before any database sees a row. A staging database
  // opened through `AppDatabase` runs `createAll()` at the CURRENT schema
  // before a single insert, so old-shaped rows would either fail on a renamed
  // column or drop data silently — the one case the ladder exists for is the
  // case that approach cannot do (CONTRACTS §11).
  final rows = <({String table, Map<String, Object?> row, int line})>[];
  final payloadLines = const LineSplitter().convert(payload);
  for (var index = 0; index < payloadLines.length; index++) {
    final line = payloadLines[index];
    if (line.trim().isEmpty) continue;
    final parsed = PayloadLine.parse(line);
    if (parsed is! Ok<PayloadLine, EnvelopeFailure>) {
      return Err(
        MalformedPayload(
          table: 'unknown',
          // 1-based, counting the header — the number a person sees when they
          // open the file in a text editor.
          line: index + 2,
          detail: 'the line is not a payload row',
        ),
      );
    }
    rows.add((
      table: parsed.value.table,
      row: parsed.value.row,
      line: index + 2,
    ));
  }

  final upgraded = upgradePayload(
    rows: rows,
    from: header.schemaVersion,
    to: appSchemaVersion,
    ladder: upgraders,
  );
  if (upgraded is Err<List<UpgradedRow>, RestoreFailure>) {
    return Err(upgraded.failure);
  }

  final staged = File('${stagingDirectory.path}/staging_restore.sqlite');
  try {
    final failure = await _stage(
      staged,
      (upgraded as Ok<List<UpgradedRow>, RestoreFailure>).value,
    );
    if (failure != null) {
      await _deleteWithSidecars(staged);
      return Err(failure);
    }
    return await _publish(
      staged: staged,
      live: liveDatabaseFile,
      verify: verifyPublished ?? _defaultVerify,
    );
  } on Object catch (error) {
    await _deleteWithSidecars(staged);
    return Err(PublishFailed('$error'));
  }
}

/// Imports [rows] into a fresh database at [staged], in one transaction.
///
/// Returns the failure, or null. Any row-level problem aborts the WHOLE
/// transaction: a half-imported staging database publishes as a
/// plausible-looking plan with holes in it, which is worse than a refusal
/// because nobody would know to look.
Future<RestoreFailure?> _stage(File staged, List<UpgradedRow> rows) async {
  await _deleteWithSidecars(staged);
  final database = AppDatabase.forTesting(NativeDatabase(staged));
  RestoreFailure? failure;
  try {
    await database.transaction(() async {
      for (final entry in rows) {
        failure = await _insert(database, entry);
        // THROWN, not returned: drift rolls a transaction back on an exception
        // and on nothing else, so a returned failure would leave every row
        // that already landed.
        if (failure != null) throw _AbortRestore();
      }
    });
  } on _AbortRestore {
    // The failure is already recorded; the transaction is rolled back.
  } finally {
    await database.close();
    // The staging engine leaves its own `-wal`/`-shm`. `VACUUM INTO` below is
    // what produces the single clean file the publish renames, so these are
    // never wanted after this point.
    await _deleteSidecarsOf(staged);
  }
  return failure;
}

/// Raised to roll a staging transaction back.
class _AbortRestore implements Exception {}

/// Writes one row, or says why it could not.
///
/// Through the generated companions, not raw SQL: a missing non-null column is
/// then a Dart error naming the field, which is what turns "the backup is
/// malformed" into something a person can act on.
Future<RestoreFailure?> _insert(AppDatabase db, UpgradedRow entry) async {
  try {
    switch (entry.table) {
      case 'taper_plans':
        await db.into(db.taperPlans).insert(_plan(entry.row));
      case 'steps':
        await db.into(db.steps).insert(await _step(db, entry.row));
      case 'dose_logs':
        await db.into(db.doseLogs).insert(await _log(db, entry.row));
      case 'flare_events':
        await db.into(db.flareEvents).insert(await _flare(db, entry.row));
      case 'hold_events':
        await db.into(db.holdEvents).insert(await _hold(db, entry.row));
      case 'settings':
        await db
            .into(db.settingsRows)
            .insertOnConflictUpdate(
              _settings(entry.row),
            );
      default:
        return MalformedPayload(
          table: entry.table,
          line: entry.line,
          detail: 'unknown table',
        );
    }
    return null;
  } on Object catch (error) {
    return MalformedPayload(
      table: entry.table,
      line: entry.line,
      detail: '$error',
    );
  }
}

/// Reads a required field of type [T], or throws with the field's name.
T _need<T>(Map<String, Object?> row, String field) {
  final value = row[field];
  if (value is! T) {
    throw FormatException('"$field" is missing or not a ${T.runtimeType}');
  }
  return value;
}

/// Reads a required date, or throws.
LocalDate _needDate(Map<String, Object?> row, String field) {
  final decoded = decodeDate(_need<String>(row, field));
  if (decoded is Err<LocalDate, EnvelopeFailure>) {
    throw FormatException('"$field" is not a calendar date');
  }
  return (decoded as Ok<LocalDate, EnvelopeFailure>).value;
}

/// Reads a required instant, or throws.
DateTime _needInstant(Map<String, Object?> row, String field) {
  final parsed = DateTime.tryParse(_need<String>(row, field));
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('"$field" is not a UTC instant');
  }
  return parsed;
}

/// Reads an optional instant.
DateTime? _maybeInstant(Map<String, Object?> row, String field) {
  final value = row[field];
  if (value == null) return null;
  if (value is! String) throw FormatException('"$field" is not a string');
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('"$field" is not a UTC instant');
  }
  return parsed;
}

/// Unwraps a decoded enum, or throws with the field's name.
T _needCode<T>(
  Result<T, EnvelopeFailure> decoded,
  String field,
) {
  if (decoded is Err<T, EnvelopeFailure>) {
    throw FormatException('"$field" is not a value this app knows');
  }
  return (decoded as Ok<T, EnvelopeFailure>).value;
}

TaperPlansCompanion _plan(Map<String, Object?> row) =>
    TaperPlansCompanion.insert(
      uid: _need<String>(row, 'uid'),
      drugName: Value<String>(_need<String>(row, 'drug_name')),
      startDate: _needDate(row, 'start_date'),
      startingDose: decodeDose(_need<int>(row, 'starting_dose_hundredths_mg')),
      targetDose: decodeDose(_need<int>(row, 'target_dose_hundredths_mg')),
      tabletStrengths: <Milligrams>[
        for (final each in _need<List<Object?>>(
          row,
          'tablet_strengths_hundredths_mg',
        ))
          decodeDose(each! as int),
      ],
      allowHalves: _need<bool>(row, 'allow_halves'),
      method: _needCode(
        decodeTaperMethod(_need<String>(row, 'method')),
        'method',
      ),
      percentage: Value<double?>(row['percentage'] as double?),
      fixedStep: Value<Milligrams?>(
        row['fixed_step_hundredths_mg'] == null
            ? null
            : decodeDose(row['fixed_step_hundredths_mg']! as int),
      ),
      holdPeriodDays: Value<int>(_need<int>(row, 'hold_period_days')),
      createdAt: _needInstant(row, 'created_at'),
    );

/// The rowid of the plan a row's `plan_uid` names, or throws.
///
/// Resolved by UID because that is what the file carries — a rowid from
/// another phone means nothing here, and using one would attach the row to
/// whatever plan happened to land on that number.
Future<int> _planId(AppDatabase db, Map<String, Object?> row) async {
  final uid = _need<String>(row, 'plan_uid');
  final plan = await (db.select(
    db.taperPlans,
  )..where((t) => t.uid.equals(uid))).getSingleOrNull();
  if (plan == null) throw FormatException('no plan with uid "$uid"');
  return plan.id;
}

Future<StepsCompanion> _step(AppDatabase db, Map<String, Object?> row) async =>
    StepsCompanion.insert(
      uid: _need<String>(row, 'uid'),
      planId: await _planId(db, row),
      stepIndex: _need<int>(row, 'step_index'),
      fromDose: decodeDose(_need<int>(row, 'from_dose_hundredths_mg')),
      toDose: decodeDose(_need<int>(row, 'to_dose_hundredths_mg')),
      startDate: _needDate(row, 'start_date'),
      status: _needCode(
        decodeStepStatus(_need<String>(row, 'status')),
        'status',
      ),
      patternVersion: _need<int>(row, 'pattern_version'),
    );

Future<DoseLogsCompanion> _log(
  AppDatabase db,
  Map<String, Object?> row,
) async => DoseLogsCompanion.insert(
  uid: _need<String>(row, 'uid'),
  planId: await _planId(db, row),
  date: _needDate(row, 'date'),
  plannedMg: decodeDose(_need<int>(row, 'planned_hundredths_mg')),
  actualMg: decodeDose(_need<int>(row, 'actual_hundredths_mg')),
  taken: _need<bool>(row, 'taken'),
  takenAt: Value<DateTime?>(_maybeInstant(row, 'taken_at')),
  note: Value<String?>(row['note'] as String?),
);

Future<FlareEventsCompanion> _flare(
  AppDatabase db,
  Map<String, Object?> row,
) async => FlareEventsCompanion.insert(
  uid: _need<String>(row, 'uid'),
  planId: await _planId(db, row),
  date: _needDate(row, 'date'),
  revertToDose: decodeDose(_need<int>(row, 'revert_to_dose_hundredths_mg')),
  note: Value<String?>(row['note'] as String?),
);

Future<HoldEventsCompanion> _hold(
  AppDatabase db,
  Map<String, Object?> row,
) async {
  final uid = _need<String>(row, 'step_uid');
  final step = await (db.select(
    db.steps,
  )..where((t) => t.uid.equals(uid))).getSingleOrNull();
  if (step == null) throw FormatException('no step with uid "$uid"');
  return HoldEventsCompanion.insert(
    uid: _need<String>(row, 'uid'),
    stepId: step.id,
    fromDate: _needDate(row, 'from_date'),
    extraDays: _need<int>(row, 'extra_days'),
    note: Value<String?>(row['note'] as String?),
  );
}

SettingsRowsCompanion _settings(Map<String, Object?> row) =>
    SettingsRowsCompanion.insert(
      // The single row, always id 0 — the table's own CHECK constraint says so.
      id: const Value<int>(0),
      uid: _need<String>(row, 'uid'),
      reminderEnabled: Value<bool>(_need<bool>(row, 'reminder_enabled')),
      reminderMinuteOfDay: Value<int?>(row['reminder_minute_of_day'] as int?),
      textScale: Value<double>((row['text_scale']! as num).toDouble()),
      highContrast: Value<bool>(_need<bool>(row, 'high_contrast')),
      disclaimerAcceptedAt: Value<DateTime?>(
        _maybeInstant(row, 'disclaimer_accepted_at'),
      ),
      localeTag: Value<String?>(row['locale_tag'] as String?),
      themeMode: Value<String>(_need<String>(row, 'theme_mode')),
    );

/// What a freshly published database has to pass before the rollback set goes.
///
/// Injectable ONLY so the rollback path itself can be tested: the alternative
/// is the one branch in this file whose whole job is "put two years back"
/// having no test at all, which is worse than a seam.
Future<void> _defaultVerify(AppDatabase reopened) async {
  final check = await reopened
      .customSelect('PRAGMA integrity_check;')
      .getSingle();
  if (check.data.values.first != 'ok') {
    throw StateError('integrity_check said ${check.data.values.first}');
  }
  // A read as well: `integrity_check` passes on a structurally sound database
  // that happens to be empty, which is what a truncated rename would leave.
  await reopened.select(reopened.taperPlans).get();
}

/// The two sidecars a WAL-mode SQLite database carries.
///
/// Named once, because every place that forgets one of them is the bug: a
/// `-wal` left beside a freshly published file is either replayed — silently
/// resurrecting pre-restore rows — or refuses to open at all.
const List<String> _sidecarSuffixes = <String>['-wal', '-shm'];

/// Deletes [file] and both its sidecars, ignoring what is not there.
Future<void> _deleteWithSidecars(File file) async {
  for (final path in <String>[
    file.path,
    for (final suffix in _sidecarSuffixes) '${file.path}$suffix',
  ]) {
    final each = File(path);
    if (each.existsSync()) {
      try {
        await each.delete();
      } on Object {
        // Best effort. A stuck temp must not turn a successful restore into a
        // failure, and a stuck one before staging is caught by the open below.
      }
    }
  }
}

/// Deletes only [file]'s sidecars.
Future<void> _deleteSidecarsOf(File file) async {
  for (final suffix in _sidecarSuffixes) {
    final each = File('${file.path}$suffix');
    if (each.existsSync()) {
      try {
        await each.delete();
      } on Object {
        // See above.
      }
    }
  }
}

/// Puts [staged] in place of [live], or leaves [live] byte-unchanged.
///
/// **The live database runs in WAL mode, so it is up to three files.** Renaming
/// only the main one leaves the PREVIOUS database's `-wal` and `-shm` beside
/// the newly published file, and on reopen SQLite either replays those foreign
/// frames — resurrecting pre-restore rows into a plan that no longer has them
/// — or refuses to open. A happy-path test passes either way. A phone killed
/// mid-write does not.
///
/// So, in order: produce a single clean file with `VACUUM INTO` (no sidecars by
/// construction), move the live main file **and both sidecars** into a rollback
/// set, rename the clean file into place, assert no stale sidecar survived,
/// reopen and run `PRAGMA integrity_check`. Any failure puts all three rollback
/// files back and returns [PublishFailed]; the rollback set is deleted only
/// after a clean reopen.
Future<Result<void, RestoreFailure>> _publish({
  required File staged,
  required File live,
  required Future<void> Function(AppDatabase reopened) verify,
}) async {
  final clean = File('${staged.path}.clean');
  await _deleteWithSidecars(clean);

  // `VACUUM INTO` rather than a copy. The staging database is closed and its
  // sidecars are already deleted, so a copy would work today — this is here
  // for the property rather than the current arrangement: it writes ONE
  // consistent, compacted file with no sidecars by construction, which is the
  // only kind of file that is safe to rename over a database.
  final source = AppDatabase.forTesting(NativeDatabase(staged));
  try {
    await source.customStatement("VACUUM INTO '${clean.path}';");
  } on Object catch (error) {
    await source.close();
    return Err(PublishFailed('vacuum: $error'));
  }
  await source.close();
  await _deleteWithSidecars(staged);

  // The rollback set: the main file and BOTH sidecars, so a failed publish can
  // put the database back exactly as it was.
  final rollback = <String, File>{};
  try {
    for (final suffix in <String>['', ..._sidecarSuffixes]) {
      final original = File('${live.path}$suffix');
      if (!original.existsSync()) continue;
      final saved = File('${live.path}$suffix.rollback');
      if (saved.existsSync()) await saved.delete();
      await original.rename(saved.path);
      rollback[suffix] = saved;
    }

    await clean.rename(live.path);

    for (final suffix in _sidecarSuffixes) {
      final stale = File('${live.path}$suffix');
      if (stale.existsSync()) {
        throw StateError('a stale $suffix survived beside the published file');
      }
    }

    final reopened = AppDatabase.forTesting(NativeDatabase(live));
    try {
      await verify(reopened);
    } finally {
      await reopened.close();
      await _deleteSidecarsOf(live);
    }
  } on Object catch (error) {
    // Put everything back, then say so. The live database is what it was.
    if (live.existsSync()) {
      try {
        await live.delete();
      } on Object {
        // If this fails the rename below fails too, and the message says so.
      }
    }
    for (final MapEntry(key: suffix, value: saved) in rollback.entries) {
      try {
        await saved.rename('${live.path}$suffix');
      } on Object {
        // Nothing further to try; the failure below carries the reason.
      }
    }
    await _deleteWithSidecars(clean);
    return Err(PublishFailed('$error'));
  }

  // Only after a clean reopen.
  for (final saved in rollback.values) {
    if (saved.existsSync()) {
      try {
        await saved.delete();
      } on Object {
        // A leftover rollback file costs disk and nothing else.
      }
    }
  }
  return const Ok<void, RestoreFailure>(null);
}
