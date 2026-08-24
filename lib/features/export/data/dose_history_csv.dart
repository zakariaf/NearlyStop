/// The dose history, as a spreadsheet a doctor can open.
library;

import 'package:meta/meta.dart';

/// The columns, in the order they are written.
///
/// Two kinds in one file, on purpose: `date`, `planned_mg` and `actual_mg` are
/// MACHINE columns a spreadsheet has to parse, so they are ASCII and
/// unlocalized; `weekday` and `note` are HUMAN columns somebody reads, so they
/// are in the reader's own language. Mixing them up either gives a doctor a
/// column of Perso-Arabic numerals their spreadsheet reads as text, or gives a
/// Persian reader an English weekday.
const List<String> kCsvColumns = <String>[
  'date',
  'weekday',
  'step',
  'block',
  'planned_mg',
  'actual_mg',
  'taken',
  'tablets',
  'note',
  'event',
];

/// What a NULL note is written as.
///
/// Distinct from an empty note, which is a different fact: one says "nothing
/// to add", the other says "never asked". Both are blank in a spreadsheet
/// unless one of them says something.
const String kAbsentNote = '—';

/// Where the note sits, for tests that poke at it.
final int kNoteColumnIndex = kCsvColumns.indexOf('note');

/// One row of the doctor's history, already formatted.
///
/// Strings, not domain types: every value here has already been through the
/// locale decision above, and re-deciding it inside the writer is how a
/// machine column ends up localized.
@immutable
class DoseHistoryRow {
  /// Creates a row.
  const DoseHistoryRow({
    required this.date,
    required this.weekday,
    required this.step,
    required this.block,
    required this.plannedMg,
    required this.actualMg,
    required this.taken,
    required this.tablets,
    required this.note,
    required this.event,
  });

  /// `yyyy-MM-dd`, ASCII, unlocalized.
  final String date;

  /// The day's name, in the reader's language.
  final String weekday;

  /// Which step, 1-based.
  final String step;

  /// Which DSNS block, 1-based.
  final String block;

  /// The planned dose, ASCII decimal.
  final String plannedMg;

  /// The dose actually taken, ASCII decimal.
  final String actualMg;

  /// Whether it was ticked.
  final String taken;

  /// The tablet breakdown, in the reader's language.
  final String tablets;

  /// The patient's own words, or null when there are none.
  final String? note;

  /// A flare or a hold that starts on this day.
  final String event;

  /// The cells, in [kCsvColumns] order.
  List<String> get cells => <String>[
    date,
    weekday,
    step,
    block,
    plannedMg,
    actualMg,
    taken,
    tablets,
    note ?? kAbsentNote,
    event,
  ];
}

/// The whole file, as text.
///
/// **UTF-8 with a BOM.** Excel on Windows misreads UTF-8 without one, and a
/// doctor's laptop is Windows — the symptom is a column of mojibake in the
/// only file this feature exists to produce.
String writeDoseHistoryCsv(List<DoseHistoryRow> rows) {
  final buffer = StringBuffer('\u{FEFF}')
    ..write(kCsvColumns.map(_field).join(','))
    ..write('\r\n');
  for (final row in rows) {
    buffer
      ..write(row.cells.map(_field).join(','))
      ..write('\r\n');
  }
  return buffer.toString();
}

/// One field: neutralised, then quoted.
///
/// In that order. Quoting first and then prefixing would put the `'` outside
/// the quotes, where it is a syntax error rather than a defence.
String _field(String value) => _quote(_neutralise(value));

/// Characters that make a spreadsheet treat a cell as a formula.
///
/// `-` is on the list and it is the one that matters: a patient note reading
/// `-2 today` is a real sentence somebody will write and a live formula in
/// Excel. This is not a hypothetical vector.
const String _formulaStarters = '=+-@\t\r';

/// Prefixes a formula-looking field with `'`, and leaves everything else.
String _neutralise(String value) {
  if (value.isEmpty) return value;
  if (!_formulaStarters.contains(value[0])) return value;
  return "'$value";
}

/// RFC 4180: quote when the field contains a delimiter, a quote, CR or LF, and
/// double every embedded quote.
String _quote(String value) {
  final needsQuotes =
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\r') ||
      value.contains('\n');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}
