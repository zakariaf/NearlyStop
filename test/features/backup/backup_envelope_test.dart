// The envelope: the only file shape restore accepts.
//
// The bugs in this file are silent data loss. A dose that encodes as 9500
// instead of 950 restores as 95mg; an enum written as a label instead of a
// code stops decoding the day somebody renames the label; a header that only
// parses when the whole file is present turns a truncated download into a
// mid-parse exception instead of a refusal.
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/backup/domain/backup_envelope.dart';
import 'package:test/test.dart';

void main() {
  final header = BackupHeader(
    formatVersion: kBackupFormatVersion,
    schemaVersion: 1,
    appVersion: '1.0.0+1',
    exportedAtUtc: DateTime.utc(2025, 4, 16, 8, 30),
    payloadSha256: 'a' * 64,
  );

  group('the header', () {
    test('it round trips', () {
      final parsed = BackupHeader.parse(header.toJsonLine());

      expect(parsed, isA<Ok<BackupHeader, EnvelopeFailure>>());
      expect((parsed as Ok<BackupHeader, EnvelopeFailure>).value, header);
    });

    test('it parses from line ONE alone, with no payload at all', () {
      // The entire reason the header goes first. A truncated download, or a
      // file that is not a backup, is refused by its first line rather than by
      // an exception a thousand lines in.
      final line = header.toJsonLine();

      expect(line.contains('\n'), isFalse);
      expect(
        BackupHeader.parse(line),
        isA<Ok<BackupHeader, EnvelopeFailure>>(),
      );
    });

    test('a line that is not JSON is a refusal, not a throw', () {
      for (final line in <String>[
        '',
        'not json',
        '[]',
        '{"formatVersion": 1}',
        _headerLine('"one"', '"2025-04-16T08:30:00.000Z"'),
        // A FLOATING local time, with no zone at all. It parses, and it means
        // a different moment on every phone that reads it — so "which backup
        // is newer" silently depends on where each file was written. An
        // explicit `+02:00` is fine and is not listed here: it names one
        // instant, which is the whole requirement.
        _headerLine('1', '"2025-04-16T08:30:00.000"'),
      ]) {
        expect(
          BackupHeader.parse(line),
          isA<Err<BackupHeader, EnvelopeFailure>>(),
          reason: 'accepted: $line',
        );
      }
    });

    test('the instant is UTC, with its Z, and comes back identical', () {
      final line = header.toJsonLine();
      expect(line, contains('2025-04-16T08:30:00.000Z'));

      final parsed =
          (BackupHeader.parse(line) as Ok<BackupHeader, EnvelopeFailure>).value;
      expect(parsed.exportedAtUtc.isUtc, isTrue);
      expect(parsed.exportedAtUtc, header.exportedAtUtc);
    });
  });

  group('doses are HUNDREDTHS, not micrograms', () {
    test('9.5mg is 950', () {
      // CONTRACTS §1 and §11. A second canonical integer unit differing by a
      // factor of ten, in the one format whose whole job is to round-trip
      // exactly, restores somebody's 9.5mg as 95mg.
      expect(encodeDose(const Milligrams.fromHundredths(950)), 950);
      expect(decodeDose(950), const Milligrams.fromHundredths(950));
    });

    test('a quarter milligram and zero survive', () {
      for (final dose in <Milligrams>[
        const Milligrams.fromHundredths(25),
        Milligrams.zero,
        const Milligrams.fromHundredths(1),
        const Milligrams.fromHundredths(12000),
      ]) {
        expect(decodeDose(encodeDose(dose)), dose, reason: '$dose');
      }
    });
  });

  group('dates are calendar dates', () {
    test('a date round trips as yyyy-MM-dd', () {
      expect(encodeDate(const LocalDate(2025, 4, 16)), '2025-04-16');
      expect(
        decodeDate('2025-04-16'),
        const Ok<LocalDate, EnvelopeFailure>(
          LocalDate(2025, 4, 16),
        ),
      );
    });

    test('a leap day survives', () {
      expect(encodeDate(const LocalDate(2024, 2, 29)), '2024-02-29');
      expect(
        decodeDate('2024-02-29'),
        const Ok<LocalDate, EnvelopeFailure>(LocalDate(2024, 2, 29)),
      );
    });

    test('a malformed date is a refusal', () {
      // `2025-02-30` is the one that needs the round-trip guard: it passes
      // every range check and `DateTime` happily turns it into the 2nd of
      // March. A history restored a day out is a history nobody can reconcile
      // with their own diary.
      for (final text in <String>[
        '',
        '2025-4-16',
        '16/04/2025',
        '2025-13-01',
        '2025-02-30',
        '2025-04-31',
        '2023-02-29',
      ]) {
        expect(
          decodeDate(text),
          isA<Err<LocalDate, EnvelopeFailure>>(),
          reason: 'accepted: $text',
        );
      }
    });
  });

  group('enums are CODES, not labels', () {
    // A renamed label must not change the wire format. Every value of every
    // exported enum, so a value added without a code is a red test rather than
    // a file that stops decoding on somebody's phone.
    test('every TaperMethod round trips', () {
      for (final value in TaperMethod.values) {
        expect(
          decodeTaperMethod(encodeTaperMethod(value)),
          Ok<TaperMethod, EnvelopeFailure>(value),
        );
      }
    });

    test('every StepStatus round trips', () {
      for (final value in StepStatus.values) {
        expect(
          decodeStepStatus(encodeStepStatus(value)),
          Ok<StepStatus, EnvelopeFailure>(value),
        );
      }
    });

    test('every DayState round trips', () {
      for (final value in DayState.values) {
        expect(
          decodeDayState(encodeDayState(value)),
          Ok<DayState, EnvelopeFailure>(value),
        );
      }
    });

    test('every AppThemeMode round trips', () {
      for (final value in AppThemeMode.values) {
        expect(
          decodeThemeMode(encodeThemeMode(value)),
          Ok<AppThemeMode, EnvelopeFailure>(value),
        );
      }
    });

    test('an unknown code is a refusal, never a default', () {
      // Defaulting here silently rewrites somebody's plan: a `fixedMg` taper
      // restored as `dsns` is a different schedule for the next two years.
      expect(
        decodeTaperMethod('nonsense'),
        isA<Err<TaperMethod, EnvelopeFailure>>(),
      );
      expect(
        decodeStepStatus('nonsense'),
        isA<Err<StepStatus, EnvelopeFailure>>(),
      );
      expect(decodeDayState('nonsense'), isA<Err<DayState, EnvelopeFailure>>());
      expect(
        decodeThemeMode('nonsense'),
        isA<Err<AppThemeMode, EnvelopeFailure>>(),
      );
    });

    test('the codes are stable strings, pinned here', () {
      // Pinned, so renaming a Dart identifier cannot change what is written to
      // a file somebody already has on their phone.
      expect(encodeTaperMethod(TaperMethod.dsns), 'dsns');
      expect(encodeTaperMethod(TaperMethod.percentage), 'percentage');
      expect(encodeTaperMethod(TaperMethod.fixedMg), 'fixed_mg');
    });
  });

  group('the table order is specified, not incidental', () {
    test('it is dependency order, plans first and settings last', () {
      expect(kBackupTables, <String>[
        'taper_plans',
        'steps',
        'dose_logs',
        'flare_events',
        'hold_events',
        'settings',
      ]);
    });
  });

  test('a payload line names its table and carries a row', () {
    final line = payloadLine('dose_logs', <String, Object?>{
      'uid': 'log-1',
      'dose_hundredths_mg': 950,
    });

    expect(line.contains('\n'), isFalse);
    final parsed = PayloadLine.parse(line);
    expect(parsed, isA<Ok<PayloadLine, EnvelopeFailure>>());
    final row = (parsed as Ok<PayloadLine, EnvelopeFailure>).value;
    expect(row.table, 'dose_logs');
    expect(row.row['dose_hundredths_mg'], 950);
  });
}

/// A header line with [format] and [exported] substituted in.
///
/// A helper rather than two adjacent string literals in the list: the analyzer
/// flags those because a missing comma between them is invisible, and in a
/// list of malformed inputs a silently concatenated pair is a case that
/// stopped being tested.
String _headerLine(String format, String exported) =>
    '{"formatVersion": $format, "schemaVersion": 1, "appVersion": "1", '
    '"exportedAtUtc": $exported, "payloadSha256": "x"}';
