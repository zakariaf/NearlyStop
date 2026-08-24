/// Writing a backup, streamed and published atomically.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/db/app_database.dart';
import 'package:nearlystop/features/backup/domain/backup_envelope.dart';

/// Why a backup was not written.
sealed class BackupWriteFailure extends Failure {
  /// Creates the failure.
  const BackupWriteFailure();
}

/// The file could not be written.
final class BackupIoFailed extends BackupWriteFailure {
  /// Creates the failure with what the platform said.
  const BackupIoFailed(this.reason);

  /// For a log — never shown to the reader.
  final String reason;

  @override
  String get code => 'backup.io_failed';

  @override
  List<Object?> get props => <Object?>[reason];
}

/// The name a backup written on [day] carries.
///
/// **`.ndjson`, not a custom extension.** A custom one is unpickable on iOS
/// without a matching `UTExportedTypeDeclarations` UTI, and on Android it
/// resolves to no MIME so the picker greys the file out — import, the half of
/// the feature that matters, would be dead on the platform where somebody most
/// needs it. NDJSON needs no platform declaration anywhere.
String backupFileName(LocalDate day) =>
    'nearlystop-backup-${encodeDate(day)}.ndjson';

/// The MIME type a backup is shared and picked as.
const String kBackupMimeType = 'application/x-ndjson';

/// Writes a backup of [database] into [directory] and returns the file.
///
/// **Streamed, digested and published atomically.** The payload goes to a temp
/// file through an `IOSink` while the same bytes pass through a chunked
/// SHA-256, so a 780-day history never becomes a `String` in memory. Only when
/// the digest is known can the header be written — which is why the header
/// cannot simply be the first thing emitted — so the finished file is assembled
/// in a second temp and published by `rename`. A reader who opens the folder
/// mid-write sees no file at all rather than half of one.
Future<Result<File, BackupWriteFailure>> writeBackup({
  required AppDatabase database,
  required Directory directory,
  required String appVersion,
  required Clock clock,
}) async {
  final now = clock.now().toUtc();
  final payloadTemp = File(
    '${directory.path}${Platform.pathSeparator}.backup-payload.tmp',
  );
  final assembledTemp = File(
    '${directory.path}${Platform.pathSeparator}.backup-file.tmp',
  );

  try {
    final digest = await _writePayload(database, payloadTemp);
    final header = BackupHeader(
      formatVersion: kBackupFormatVersion,
      schemaVersion: database.schemaVersion,
      appVersion: appVersion,
      exportedAtUtc: now,
      payloadSha256: digest,
    );

    final sink = assembledTemp.openWrite()..writeln(header.toJsonLine());
    await sink.addStream(payloadTemp.openRead());
    await sink.flush();
    await sink.close();

    final published = File(
      '${directory.path}${Platform.pathSeparator}'
      '${backupFileName(LocalDate.fromDateTime(now))}',
    );
    await assembledTemp.rename(published.path);
    return Ok(published);
  } on Object catch (error) {
    return Err(BackupIoFailed('$error'));
  } finally {
    // Both temps, on every path. One left behind is a backup-sized file the
    // reader never sees and the OS never reclaims.
    for (final temp in <File>[payloadTemp, assembledTemp]) {
      if (temp.existsSync()) {
        try {
          temp.deleteSync();
        } on Object {
          // Nothing useful to do: the backup either published or failed, and
          // a stuck temp must not turn a successful export into an error.
        }
      }
    }
  }
}

/// Streams every table into [target] and returns the payload's digest.
Future<String> _writePayload(AppDatabase database, File target) async {
  final accumulator = AccumulatorSink<Digest>();
  // `sha256`, the top-level const instance — `Sha256()` has a private
  // constructor. A chunked conversion needs the accumulator to read the digest
  // back out at the end.
  final input = sha256.startChunkedConversion(accumulator);
  final sink = target.openWrite();

  Future<void> emit(String table, Map<String, Object?> row) async {
    final bytes = utf8.encode('${payloadLine(table, row)}\n');
    input.add(bytes);
    sink.add(bytes);
  }

  for (final plan in await _plans(database)) {
    await emit('taper_plans', plan);
  }
  for (final step in await _steps(database)) {
    await emit('steps', step);
  }
  for (final log in await _logs(database)) {
    await emit('dose_logs', log);
  }
  for (final flare in await _flares(database)) {
    await emit('flare_events', flare);
  }
  for (final hold in await _holds(database)) {
    await emit('hold_events', hold);
  }
  for (final settings in await _settings(database)) {
    await emit('settings', settings);
  }

  await sink.flush();
  await sink.close();
  input.close();
  return accumulator.events.single.toString();
}

/// Every plan, `ORDER BY uid`.
///
/// The order is SPECIFIED, not incidental. `select()` without an `orderBy`
/// returns whatever order SQLite chooses, which after a restore is not the
/// source order — so the payload would stop being a deterministic function of
/// the data and the round-trip comparison would fail for a reason that has
/// nothing to do with the data.
Future<List<Map<String, Object?>>> _plans(AppDatabase db) async {
  final rows =
      await (db.select(db.taperPlans)
            ..orderBy(<OrderingTerm Function($TaperPlansTable)>[
              (t) => OrderingTerm(expression: t.uid),
            ]))
          .get();
  return <Map<String, Object?>>[
    for (final row in rows)
      <String, Object?>{
        'uid': row.uid,
        'drug_name': row.drugName,
        'start_date': encodeDate(row.startDate),
        'starting_dose_hundredths_mg': encodeDose(row.startingDose),
        'target_dose_hundredths_mg': encodeDose(row.targetDose),
        'tablet_strengths_hundredths_mg': <int>[
          for (final strength in row.tabletStrengths) encodeDose(strength),
        ],
        'allow_halves': row.allowHalves,
        'method': encodeTaperMethod(row.method),
        'percentage': row.percentage,
        'fixed_step_hundredths_mg': row.fixedStep == null
            ? null
            : encodeDose(row.fixedStep!),
        'hold_period_days': row.holdPeriodDays,
        'created_at': row.createdAt.toUtc().toIso8601String(),
      },
  ];
}

/// Every step, `ORDER BY uid`.
Future<List<Map<String, Object?>>> _steps(AppDatabase db) async {
  final rows =
      await (db.select(db.steps)..orderBy(<OrderingTerm Function($StepsTable)>[
            (t) => OrderingTerm(expression: t.uid),
          ]))
          .get();
  final plans = await _uidByRowId(db);
  return <Map<String, Object?>>[
    for (final row in rows)
      <String, Object?>{
        'uid': row.uid,
        // The plan's UID, never its rowid: re-importing with autoincrement ids
        // would attach every step to whatever plan happened to land on that
        // number.
        'plan_uid': plans[row.planId],
        'step_index': row.stepIndex,
        'from_dose_hundredths_mg': encodeDose(row.fromDose),
        'to_dose_hundredths_mg': encodeDose(row.toDose),
        'start_date': encodeDate(row.startDate),
        'status': encodeStepStatus(row.status),
        'pattern_version': row.patternVersion,
      },
  ];
}

/// Every dose log, `ORDER BY (plan, date), uid`.
Future<List<Map<String, Object?>>> _logs(AppDatabase db) async {
  final rows =
      await (db.select(db.doseLogs)
            ..orderBy(<OrderingTerm Function($DoseLogsTable)>[
              (t) => OrderingTerm(expression: t.planId),
              (t) => OrderingTerm(expression: t.date),
              (t) => OrderingTerm(expression: t.uid),
            ]))
          .get();
  final plans = await _uidByRowId(db);
  return <Map<String, Object?>>[
    for (final row in rows)
      <String, Object?>{
        'uid': row.uid,
        'plan_uid': plans[row.planId],
        'date': encodeDate(row.date),
        'planned_hundredths_mg': encodeDose(row.plannedMg),
        'actual_hundredths_mg': encodeDose(row.actualMg),
        'taken': row.taken,
        'taken_at': row.takenAt?.toUtc().toIso8601String(),
        'note': row.note,
      },
  ];
}

/// Every flare, `ORDER BY uid`.
Future<List<Map<String, Object?>>> _flares(AppDatabase db) async {
  final rows =
      await (db.select(db.flareEvents)
            ..orderBy(<OrderingTerm Function($FlareEventsTable)>[
              (t) => OrderingTerm(expression: t.uid),
            ]))
          .get();
  final plans = await _uidByRowId(db);
  return <Map<String, Object?>>[
    for (final row in rows)
      <String, Object?>{
        'uid': row.uid,
        'plan_uid': plans[row.planId],
        'date': encodeDate(row.date),
        'revert_to_dose_hundredths_mg': encodeDose(row.revertToDose),
        'note': row.note,
      },
  ];
}

/// Every hold, `ORDER BY uid`.
Future<List<Map<String, Object?>>> _holds(AppDatabase db) async {
  final rows =
      await (db.select(db.holdEvents)
            ..orderBy(<OrderingTerm Function($HoldEventsTable)>[
              (t) => OrderingTerm(expression: t.uid),
            ]))
          .get();
  final steps = <int, String>{
    for (final step in await db.select(db.steps).get()) step.id: step.uid,
  };
  return <Map<String, Object?>>[
    for (final row in rows)
      <String, Object?>{
        'uid': row.uid,
        'step_uid': steps[row.stepId],
        'from_date': encodeDate(row.fromDate),
        'extra_days': row.extraDays,
        'note': row.note,
      },
  ];
}

/// The settings row.
///
/// Includes `disclaimer_accepted_at`, so a restored reader who already
/// accepted is not re-gated by the welcome redirect, and `locale_tag`, so they
/// land back in their own language.
Future<List<Map<String, Object?>>> _settings(AppDatabase db) async {
  final rows =
      await (db.select(db.settingsRows)
            ..orderBy(<OrderingTerm Function($SettingsRowsTable)>[
              (t) => OrderingTerm(expression: t.uid),
            ]))
          .get();
  return <Map<String, Object?>>[
    for (final row in rows)
      <String, Object?>{
        'uid': row.uid,
        'reminder_enabled': row.reminderEnabled,
        'reminder_minute_of_day': row.reminderMinuteOfDay,
        'text_scale': row.textScale,
        'high_contrast': row.highContrast,
        'disclaimer_accepted_at': row.disclaimerAcceptedAt
            ?.toUtc()
            .toIso8601String(),
        'locale_tag': row.localeTag,
        'theme_mode': row.themeMode,
      },
  ];
}

/// Plan rowid → uid, so foreign keys are exported as uids.
Future<Map<int, String>> _uidByRowId(AppDatabase db) async => <int, String>{
  for (final plan in await db.select(db.taperPlans).get()) plan.id: plan.uid,
};
