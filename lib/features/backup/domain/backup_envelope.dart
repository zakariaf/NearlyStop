/// The only file shape restore accepts.
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// This envelope's own shape. Bumps independently of the database schema.
const int kBackupFormatVersion = 1;

/// The tables a backup carries, in DEPENDENCY order.
///
/// Plans first because everything references them, settings last because
/// nothing does. Restore inserts in this order and a foreign key cannot be
/// dangling half way through.
const List<String> kBackupTables = <String>[
  'taper_plans',
  'steps',
  'dose_logs',
  'flare_events',
  'hold_events',
  'settings',
];

/// Why a file is not a backup this app can read.
sealed class EnvelopeFailure extends Failure {
  /// Creates the failure.
  const EnvelopeFailure();
}

/// The bytes are not the shape a backup has.
final class MalformedEnvelope extends EnvelopeFailure {
  /// Creates the failure, naming what was wrong.
  const MalformedEnvelope(this.detail);

  /// What was wrong, for a log and for a localized message key.
  final String detail;

  @override
  String get code => 'backup.malformed';

  @override
  List<Object?> get props => <Object?>[detail];
}

/// A value that is well-formed JSON and not a value this app knows.
final class UnknownCode extends EnvelopeFailure {
  /// Creates the failure with the field and the code that was not recognised.
  const UnknownCode(this.field, this.value);

  /// Which field.
  final String field;

  /// What it said.
  final String value;

  @override
  String get code => 'backup.unknown_code';

  @override
  List<Object?> get props => <Object?>[field, value];
}

/// The first line of every backup.
///
/// **First, and parseable alone.** A truncated download, a CSV somebody
/// renamed, or a file from a different app is refused by line one rather than
/// by an exception a thousand lines in — and the reader gets a sentence about
/// the file instead of a crash.
@immutable
class BackupHeader {
  /// Creates a header.
  const BackupHeader({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAtUtc,
    required this.payloadSha256,
  });

  /// Reads a header from one line, or says why it is not one.
  static Result<BackupHeader, EnvelopeFailure> parse(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException catch (error) {
      return Err(MalformedEnvelope('line 1 is not JSON: ${error.message}'));
    }
    if (decoded is! Map<String, Object?>) {
      return const Err(MalformedEnvelope('line 1 is not a JSON object'));
    }

    final format = decoded['formatVersion'];
    final schema = decoded['schemaVersion'];
    final app = decoded['appVersion'];
    final exported = decoded['exportedAtUtc'];
    final digest = decoded['payloadSha256'];
    if (format is! int ||
        schema is! int ||
        app is! String ||
        exported is! String ||
        digest is! String) {
      return const Err(
        MalformedEnvelope('line 1 is missing a required header field'),
      );
    }
    final instant = DateTime.tryParse(exported);
    if (instant == null || !instant.isUtc) {
      return const Err(
        MalformedEnvelope('exportedAtUtc is not an ISO-8601 UTC instant'),
      );
    }

    return Ok(
      BackupHeader(
        formatVersion: format,
        schemaVersion: schema,
        appVersion: app,
        exportedAtUtc: instant,
        payloadSha256: digest,
      ),
    );
  }

  /// This envelope's shape.
  final int formatVersion;

  /// The `AppDatabase.schemaVersion` the payload was written from.
  final int schemaVersion;

  /// Provenance only. **Never a compatibility check** — the two version
  /// numbers above are what decide whether a file can be read.
  final String appVersion;

  /// When it was written.
  final DateTime exportedAtUtc;

  /// SHA-256 of every payload byte after this line.
  final String payloadSha256;

  /// The header as its one line, with no trailing newline.
  String toJsonLine() => jsonEncode(<String, Object?>{
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'exportedAtUtc': exportedAtUtc.toUtc().toIso8601String(),
    'payloadSha256': payloadSha256,
  });

  @override
  bool operator ==(Object other) =>
      other is BackupHeader &&
      other.formatVersion == formatVersion &&
      other.schemaVersion == schemaVersion &&
      other.appVersion == appVersion &&
      other.exportedAtUtc == exportedAtUtc &&
      other.payloadSha256 == payloadSha256;

  @override
  int get hashCode => Object.hash(
    formatVersion,
    schemaVersion,
    appVersion,
    exportedAtUtc,
    payloadSha256,
  );

  @override
  String toString() =>
      'BackupHeader(format $formatVersion, schema $schemaVersion, '
      '$appVersion, $exportedAtUtc)';
}

/// One row, and the table it belongs to.
@immutable
class PayloadLine {
  /// Creates a payload line.
  const PayloadLine({required this.table, required this.row});

  /// Reads one, or says why it is not one.
  static Result<PayloadLine, EnvelopeFailure> parse(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException catch (error) {
      return Err(
        MalformedEnvelope(
          'a payload line is not JSON: '
          '${error.message}',
        ),
      );
    }
    if (decoded is! Map<String, Object?>) {
      return const Err(MalformedEnvelope('a payload line is not an object'));
    }
    final table = decoded['table'];
    final row = decoded['row'];
    if (table is! String || row is! Map<String, Object?>) {
      return const Err(
        MalformedEnvelope('a payload line needs a table and a row'),
      );
    }
    if (!kBackupTables.contains(table)) {
      return Err(UnknownCode('table', table));
    }
    return Ok(PayloadLine(table: table, row: row));
  }

  /// Which table.
  final String table;

  /// The row's canonical values.
  final Map<String, Object?> row;
}

/// One payload line, as its JSON.
String payloadLine(String table, Map<String, Object?> row) =>
    jsonEncode(<String, Object?>{'table': table, 'row': row});

/// A dose as **integer hundredths of a milligram**. `9.5mg → 950`.
///
/// CONTRACTS §1 and §11. A second canonical integer unit differing by a factor
/// of ten — micrograms — in the one format whose whole job is to round-trip
/// exactly, restores somebody's 9.5mg as 95mg.
int encodeDose(Milligrams dose) => dose.hundredths;

/// The dose [hundredths] names.
Milligrams decodeDose(int hundredths) => Milligrams.fromHundredths(hundredths);

/// A calendar date as `yyyy-MM-dd`.
///
/// A DATE, never an instant: SPEC §7 stores days, so the schedule is invariant
/// under travel. An instant here would shift somebody's whole history by a day
/// when they restore in a different zone.
String encodeDate(LocalDate date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// The date [text] names.
///
/// Delegates to `LocalDate.tryParse`, which is the app's ONE calendar-date
/// parser and already refuses `2026-02-30` — a date `DateTime.utc` would
/// silently normalise into the 2nd of March. A second implementation here
/// re-derived the range checks and missed exactly that case, which is a
/// history restored a day out and no way for anybody to notice.
Result<LocalDate, EnvelopeFailure> decodeDate(String text) {
  final parsed = LocalDate.tryParse(text);
  if (parsed == null) {
    return Err(MalformedEnvelope('"$text" is not a yyyy-MM-dd calendar date'));
  }
  return Ok(parsed);
}

/// The taper method's stable wire code.
///
/// A CODE, not `value.name`. Renaming a Dart identifier must not change what
/// is written into a file somebody already has on their phone.
String encodeTaperMethod(TaperMethod value) => switch (value) {
  TaperMethod.dsns => 'dsns',
  TaperMethod.percentage => 'percentage',
  TaperMethod.fixedMg => 'fixed_mg',
};

/// The method [code] names, or a refusal.
///
/// **Never a default.** A `fixedMg` taper silently restored as `dsns` is a
/// different schedule for the next two years.
Result<TaperMethod, EnvelopeFailure> decodeTaperMethod(String code) =>
    switch (code) {
      'dsns' => const Ok(TaperMethod.dsns),
      'percentage' => const Ok(TaperMethod.percentage),
      'fixed_mg' => const Ok(TaperMethod.fixedMg),
      _ => Err(UnknownCode('method', code)),
    };

/// The step status's stable wire code.
String encodeStepStatus(StepStatus value) => switch (value) {
  StepStatus.pending => 'pending',
  StepStatus.active => 'active',
  StepStatus.completed => 'completed',
  StepStatus.abandoned => 'abandoned',
};

/// The status [code] names, or a refusal.
Result<StepStatus, EnvelopeFailure> decodeStepStatus(String code) =>
    switch (code) {
      'pending' => const Ok(StepStatus.pending),
      'active' => const Ok(StepStatus.active),
      'completed' => const Ok(StepStatus.completed),
      'abandoned' => const Ok(StepStatus.abandoned),
      _ => Err(UnknownCode('status', code)),
    };

/// The day state's stable wire code.
String encodeDayState(DayState value) => switch (value) {
  DayState.taken => 'taken',
  DayState.missed => 'missed',
  DayState.today => 'today',
  DayState.upcoming => 'upcoming',
};

/// The state [code] names, or a refusal.
Result<DayState, EnvelopeFailure> decodeDayState(String code) => switch (code) {
  'taken' => const Ok(DayState.taken),
  'missed' => const Ok(DayState.missed),
  'today' => const Ok(DayState.today),
  'upcoming' => const Ok(DayState.upcoming),
  _ => Err(UnknownCode('day_state', code)),
};

/// The theme mode's stable wire code.
String encodeThemeMode(AppThemeMode value) => switch (value) {
  AppThemeMode.system => 'system',
  AppThemeMode.light => 'light',
  AppThemeMode.dark => 'dark',
};

/// The mode [code] names, or a refusal.
Result<AppThemeMode, EnvelopeFailure> decodeThemeMode(String code) =>
    switch (code) {
      'system' => const Ok(AppThemeMode.system),
      'light' => const Ok(AppThemeMode.light),
      'dark' => const Ok(AppThemeMode.dark),
      _ => Err(UnknownCode('theme_mode', code)),
    };
