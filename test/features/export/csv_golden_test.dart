// The doctor's spreadsheet, pinned byte for byte.
//
// A golden vector rather than a set of assertions about escaping, because the
// thing that matters is the WHOLE file: the BOM, the CRLF line endings, the
// header row, the formula neutralisation, the quoting, and the order they
// happen in. An assertion per rule passes while the rules are applied in the
// wrong order — quoting before neutralising puts the guard outside the quotes,
// where it is a syntax error rather than a defence.
//
// Regenerate deliberately, never reflexively: `dart run
// tool/regen_csv_golden.dart`, then READ the diff. A change here is a change
// to a file somebody's rheumatologist opens.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/export/data/dose_history_csv.dart';

import 'csv_golden_fixture.dart';

/// Where the pinned bytes live.
const String kCsvGoldenPath = 'test/features/export/golden/dose_history.csv';

void main() {
  test('the written CSV is byte-identical to the committed vector', () {
    final produced = utf8.encode(writeDoseHistoryCsv(csvGoldenRows));

    expect(
      produced,
      File(kCsvGoldenPath).readAsBytesSync(),
      reason:
          'the doctor-facing CSV changed. Read the diff, then regenerate with '
          '`dart run tool/regen_csv_golden.dart` if the change is intended.',
    );
  });

  test('the vector actually exercises every escaping rule', () {
    // A golden over tidy data is a golden that passes forever and guards
    // nothing. These are the four things the writer has to do.
    // The BOM is asserted in BYTES: Dart's UTF-8 decoder silently drops a
    // leading one, so `readAsString` reports success either way.
    expect(
      File(kCsvGoldenPath).readAsBytesSync().take(3),
      <int>[0xEF, 0xBB, 0xBF],
      reason: 'no BOM — Excel on Windows will render this as mojibake',
    );
    final text = File(kCsvGoldenPath).readAsStringSync();

    expect(text, contains('\r\n'), reason: 'no CRLF');
    expect(text, contains('""'), reason: 'no escaped double quote');
    expect(
      text,
      contains("'="),
      reason: 'a formula cell is not neutralised inside its quotes',
    );
  });
}
