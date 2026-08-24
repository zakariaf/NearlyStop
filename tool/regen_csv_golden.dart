/// Rewrites the committed CSV golden vector.
///
/// Run deliberately — `dart run tool/regen_csv_golden.dart` — and READ the
/// diff. This file is what a rheumatologist opens.
library;

import 'dart:convert';
import 'dart:io';

import 'package:nearlystop/features/export/data/dose_history_csv.dart';

import '../test/features/export/csv_golden_fixture.dart';

void main() {
  const path = 'test/features/export/golden/dose_history.csv';
  File(path).writeAsBytesSync(utf8.encode(writeDoseHistoryCsv(csvGoldenRows)));
  stdout.writeln('wrote $path');
}
