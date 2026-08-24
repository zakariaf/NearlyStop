/// The doctor's handout, assembled from stored facts.
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/export/data/dose_history_csv.dart';
import 'package:nearlystop/features/export/data/dose_history_pdf.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/bidi.dart';
import 'package:nearlystop/l10n/date_formats.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:nearlystop/l10n/tablet_labels.dart';
import 'package:nearlystop/theme/daybreak_script.dart';

/// Everything both renderings need, localized once.
///
/// One object for two files: the CSV and the PDF must not disagree about what
/// happened on a day, and the way they come to disagree is by each assembling
/// its own rows from the same facts a fortnight apart.
@immutable
class DoseHistoryDocument {
  /// Creates the document.
  const DoseHistoryDocument({
    required this.rows,
    required this.pdfRows,
    required this.copy,
    required this.isRightToLeft,
    required this.fileStem,
  });

  /// Every elapsed day, oldest first, as spreadsheet rows.
  final List<DoseHistoryRow> rows;

  /// The same days, narrowed to the columns an A4 page can hold.
  final List<List<String>> pdfRows;

  /// The handout's own words.
  final DoseHistoryPdfCopy copy;

  /// Whether the page is laid out right to left.
  final bool isRightToLeft;

  /// The file name, without an extension.
  final String fileStem;
}

/// The columns the A4 handout carries, in order.
///
/// Narrower than [kCsvColumns] on purpose. Ten columns on A4 is a page nobody
/// reads; a doctor at an appointment wants the dose, whether it was taken and
/// what the patient wrote.
List<String> pdfColumnsFor(AppLocalizations l10n) => <String>[
  l10n.exportColumnDate,
  l10n.exportColumnPlanned,
  l10n.exportColumnActual,
  l10n.exportColumnTablets,
  l10n.exportColumnNote,
];

/// Builds the handout, or `null` when there is nothing to hand over.
///
/// **Null rather than an empty document.** "Nothing to export yet" is a
/// sentence the reader can act on; a blank PDF with a footer is a file they
/// send to a doctor by mistake.
DoseHistoryDocument? buildDoseHistoryDocument({
  required TaperSnapshot snapshot,
  required List<DayPlan> schedule,
  required LocalDate today,
  required LocalDate exportedAt,
  required AppLocalizations l10n,
  required Locale locale,
}) {
  final plan = snapshot.plan;
  if (plan == null) return null;

  final elapsed = <DayPlan>[
    for (final day in schedule)
      if (day.date <= today) day,
  ];
  if (elapsed.isEmpty) return null;

  final numbers = numberFormatFor(locale);
  final logs = <LocalDate, DoseLogFacts>{
    for (final log in snapshot.logs) log.date: log,
  };
  final events = _eventsByDate(snapshot, l10n);

  final rows = <DoseHistoryRow>[
    for (final day in elapsed)
      _row(
        day: day,
        log: logs[day.date],
        event: events[day.date] ?? '',
        l10n: l10n,
        locale: locale,
        numbers: numbers,
      ),
  ];

  // The SAME primitives the Progress screen goes through, not a second
  // arithmetic. A patient and a rheumatologist comparing notes must not find
  // two different totals.
  final stats = ProgressStats.from(
    plan: plan,
    logs: snapshot.logs,
    days: elapsed,
    today: today,
    l10n: l10n,
    numbers: numbers,
  );

  return DoseHistoryDocument(
    rows: rows,
    pdfRows: <List<String>>[
      for (var index = 0; index < rows.length; index++)
        <String>[
          // The HUMAN date here, unlike the CSV's ISO one: this page is read,
          // not parsed.
          formatFullDayLabel(elapsed[index].date, locale),
          rows[index].plannedMg,
          rows[index].actualMg,
          rows[index].tablets,
          rows[index].note ?? '',
        ],
    ],
    copy: DoseHistoryPdfCopy(
      title: l10n.exportHandoutTitle(plan.drugName),
      subtitle: l10n.exportDateRange(
        formatFullDayLabel(elapsed.first.date, locale),
        formatFullDayLabel(elapsed.last.date, locale),
      ),
      currentLabel: l10n.planCurrentDose,
      currentValue: l10n.doseWithUnit(formatDose(elapsed.last.dose, locale)),
      targetLabel: l10n.planTarget,
      targetValue: l10n.doseWithUnit(formatDose(plan.targetDose, locale)),
      statLabels: <String>[
        l10n.daysOnDrugLabel(plan.drugName),
        l10n.totalTaken,
        stats.adherenceCaption,
      ],
      statValues: <String>[
        stats.daysOnDrug,
        l10n.doseWithUnit(stats.cumulativeMg),
        stats.adherence,
      ],
      columns: pdfColumnsFor(l10n),
      disclaimer: l10n.exportDisclaimer,
      footerPrefix: l10n.exportFooterPrefix(
        l10n.appTitle,
        formatFullDayLabel(exportedAt, locale),
      ),
    ),
    isRightToLeft: scriptFor(locale) == DaybreakScript.perso,
    fileStem: 'nearlystop-dose-history-${exportedAt.toIso8601()}',
  );
}

DoseHistoryRow _row({
  required DayPlan day,
  required DoseLogFacts? log,
  required String event,
  required AppLocalizations l10n,
  required Locale locale,
  required NumberFormat numbers,
}) => DoseHistoryRow(
  date: day.date.toIso8601(),
  weekday: _exported(formatWeekdayName(day.date, locale)),
  step: numbers.format(day.stepIndex + 1),
  block: day.blockIndex == null ? '' : numbers.format(day.blockIndex),
  plannedMg: asciiDose(day.dose),
  // EMPTY, not zero. A day with no log is a day nobody answered for, and a
  // `0` in that cell is a doctor reading "they took nothing".
  actualMg: log == null ? '' : asciiDose(log.actualMg),
  taken: log != null && log.taken ? l10n.stateTaken : '',
  tablets: _exported(switch (day.composition) {
    Ok<TabletComposition, DomainFailure>(:final value) => formatTabletBreakdown(
      value,
      locale,
      l10n,
    ),
    // Never silently rounded, and never blank: CLAUDE.md rule 5 reaches the
    // exported file too, because this is the copy a clinician reads.
    Err<TabletComposition, DomainFailure>() => l10n.doseNotAchievable(
      formatDose(day.dose, locale),
    ),
  }),
  note: log?.note == null ? null : _exported(log!.note!),
  event: event,
);

/// A string on its way OUT of the app.
///
/// `bidi.dart` names this boundary: an isolate is a rendering instruction for
/// Flutter's text engine, and it must never reach the database, a search or an
/// export. Found on a device — the tablet breakdown carries `U+2066`/`U+2069`
/// so a Perso-Arabic screen does not reorder "1 × 5mg", and the embedded font
/// has no glyph for a control character, so the handout drew two `.notdef`
/// boxes on every single row.
///
/// The patient's own note goes through it too. A control character is
/// formatting, not a word: stripping it changes how the sentence renders and
/// not what it says, and a tofu box in the middle of a doctor's copy is worse
/// than a run that reorders. The BACKUP is untouched — that is the path where
/// fidelity is the point.
String _exported(String value) => stripIsolates(value);

/// A dose as a spreadsheet parses it: ASCII digits, a full stop, no grouping.
///
/// **Never [formatDose].** That is the reader's locale, and a Persian export
/// would put U+06Fx digits in a column a doctor's software reads as text.
String asciiDose(Milligrams dose) {
  final whole = dose.hundredths ~/ 100;
  final fraction = dose.hundredths % 100;
  if (fraction == 0) return '$whole';
  if (fraction % 10 == 0) return '$whole.${fraction ~/ 10}';
  return '$whole.${fraction.toString().padLeft(2, '0')}';
}

/// One word per day that has an event on it.
Map<LocalDate, String> _eventsByDate(
  TaperSnapshot snapshot,
  AppLocalizations l10n,
) => <LocalDate, String>{
  for (final hold in snapshot.holds) hold.fromDate: l10n.exportEventHold,
  // Flares LAST, so a day carrying both names the bigger one: a flare rewrites
  // the schedule, while a hold adds a day to it.
  for (final flare in snapshot.flares) flare.date: l10n.exportEventFlare,
};
