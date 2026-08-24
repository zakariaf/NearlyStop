// The doctor's CSV, checked against a REAL parser.
//
// Never this file's own reader as the oracle: a writer and a reader that share
// an author agree on the bug as readily as on the rule, and the whole point of
// a CSV is that somebody else's spreadsheet opens it.
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:nearlystop/features/export/data/dose_history_csv.dart';
import 'package:test/test.dart';

void main() {
  /// The rows a real third-party parser reads back out of [text].
  ///
  /// `package:csv`'s own decoder, configured the way a spreadsheet would read
  /// the file — not this feature's writer run backwards.
  List<List<dynamic>> parse(String text) => Csv(autoDetect: false).decode(text);

  group('RFC 4180 quoting', () {
    test('a hostile note survives a round trip exactly', () {
      // A comma, a quote and a newline in one cell. Each of the three is a
      // separate way to lose the rest of the row.
      const note = 'a,b"c\nsecond line';
      final csv = writeDoseHistoryCsv(<DoseHistoryRow>[_row(note: note)]);

      final rows = parse(csv);

      expect(rows, hasLength(2));
      expect(rows[1][kNoteColumnIndex], note);
    });

    test('an embedded quote is doubled, not just wrapped', () {
      // Only a quote, no comma and no newline — so the quoting decision hangs
      // on the quote alone. Wrapping without doubling produces
      // `"he said "fine""`, which a parser reads as something else entirely
      // and which a lenient one silently repairs into a different sentence.
      const note = 'he said "fine"';
      final csv = writeDoseHistoryCsv(<DoseHistoryRow>[_row(note: note)]);

      expect(csv, contains('""fine""'));
      expect(parse(csv)[1][kNoteColumnIndex], note);
    });

    test('an empty note and a missing note stay different', () {
      // Both are blank in a spreadsheet. They are not the same fact: one says
      // "nothing to add", the other says "never asked".
      final csv = writeDoseHistoryCsv(<DoseHistoryRow>[
        _row(note: ''),
        _row(),
      ]);

      final rows = parse(csv);

      expect(rows[1][kNoteColumnIndex], '');
      expect(rows[2][kNoteColumnIndex], kAbsentNote);
      expect(rows[1][kNoteColumnIndex], isNot(rows[2][kNoteColumnIndex]));
    });
  });

  group('formula injection', () {
    // A patient note reading `-2 today` is a real note AND a live formula in
    // Excel. This is not an edge case; it is a sentence somebody will write.
    const hostile = <String>[
      '=cmd()',
      '+1',
      '-2 today',
      '@x',
      '\tleading tab',
      '\rleading cr',
    ];

    for (final note in hostile) {
      test('${jsonEncode(note)} is neutralised, and still readable', () {
        final csv = writeDoseHistoryCsv(<DoseHistoryRow>[_row(note: note)]);

        final cell = parse(csv)[1][kNoteColumnIndex] as String;

        expect(cell, startsWith("'"), reason: 'not neutralised');
        expect(
          cell.substring(1),
          note,
          reason: 'the prefix changed the text as well as disarming it',
        );
      });
    }

    test('an ordinary note is left alone', () {
      // The inverted arm. Prefixing everything would pass every case above and
      // put an apostrophe in front of every note a doctor reads.
      final csv = writeDoseHistoryCsv(<DoseHistoryRow>[
        _row(note: 'felt fine, no aches'),
      ]);

      expect(parse(csv)[1][kNoteColumnIndex], 'felt fine, no aches');
    });
  });

  test('it starts with a UTF-8 BOM and the declared header', () {
    // Excel on Windows misreads UTF-8 without a BOM, and a doctor's laptop is
    // Windows.
    final csv = writeDoseHistoryCsv(<DoseHistoryRow>[_row()]);

    expect(utf8.encode(csv).take(3), <int>[0xEF, 0xBB, 0xBF]);
    final header = parse(csv).first.cast<String>();
    expect(header.first.replaceFirst('﻿', ''), kCsvColumns.first);
    expect(header.skip(1).toList(), kCsvColumns.skip(1).toList());
  });

  test('machine columns are ASCII; the human column is not', () {
    // A machine column and a human column in the same file, behaving
    // differently on purpose: a spreadsheet has to parse the dose, and a
    // person has to read the weekday.
    final csv = writeDoseHistoryCsv(<DoseHistoryRow>[
      _row(weekday: 'چهارشنبه', plannedMg: '9.5', actualMg: '9.5'),
    ]);

    final row = parse(csv)[1].cast<String>();
    expect(row[kCsvColumns.indexOf('planned_mg')], '9.5');
    expect(row[kCsvColumns.indexOf('actual_mg')], '9.5');
    expect(row[kCsvColumns.indexOf('date')], '2026-04-01');
    expect(row[kCsvColumns.indexOf('weekday')], 'چهارشنبه');
  });

  test('every line ends CRLF, as RFC 4180 says', () {
    final csv = writeDoseHistoryCsv(<DoseHistoryRow>[_row(), _row()]);

    expect(csv.split('\r\n'), hasLength(4));
    expect(csv, isNot(contains(RegExp('[^\r]\n'))));
  });
}

/// One row, with everything but the field under test held still.
DoseHistoryRow _row({
  String date = '2026-04-01',
  String weekday = 'Wednesday',
  String plannedMg = '10',
  String actualMg = '10',
  String? note,
}) => DoseHistoryRow(
  date: date,
  weekday: weekday,
  step: '1',
  block: '1',
  plannedMg: plannedMg,
  actualMg: actualMg,
  taken: 'yes',
  tablets: '2 × 5mg',
  note: note,
  event: '',
);
