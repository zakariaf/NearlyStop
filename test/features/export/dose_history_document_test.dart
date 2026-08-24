// The doctor's history, assembled from stored facts.
//
// The claim that matters is the last one: the handout's three headline numbers
// are the SAME numbers the Progress screen shows. A doctor and a patient
// comparing notes must not find two different totals.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/dsns/cumulative.dart';
import 'package:nearlystop/core/dsns/day_plan.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/export/application/dose_history_document.dart';
import 'package:nearlystop/features/export/data/dose_history_pdf.dart';
import 'package:nearlystop/l10n/date_formats.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';

import '../../fixtures/taper_fixture.dart';

void main() {
  setUpAll(initializeDateFormatting);

  const en = Locale('en');
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(en);
  });

  group('formatWeekdayName', () {
    test('names the day on its own, with no date in it', () {
      // The CSV carries `date` and `weekday` as two columns. A weekday cell
      // that repeats the date is a wasted column in the only file a doctor
      // opens.
      final label = formatWeekdayName(const LocalDate(2026, 3, 4), en);

      expect(label, 'Wednesday');
      expect(label, isNot(contains('4')));
    });

    test('every locale answers, including the one intl has no symbols for', () {
      // `DateFormat('ckb')` THROWS. A weekday helper that forgets it produces
      // a crash in the one flow whose whole job is to hand a file to a doctor.
      for (final tag in <String>['en', 'de', 'fa', 'ckb']) {
        expect(
          formatWeekdayName(const LocalDate(2026, 3, 4), Locale(tag)),
          isNotEmpty,
          reason: '$tag has no weekday name',
        );
      }
    });
  });

  group('buildDoseHistoryDocument', () {
    test('one row per ELAPSED day, and none for the future', () {
      final document = _build(today: const LocalDate(2026, 4, 3));

      expect(document.rows, hasLength(3));
      expect(document.rows.map((r) => r.date), <String>[
        '2026-04-01',
        '2026-04-02',
        '2026-04-03',
      ]);
    });

    test('the machine columns are ASCII in every locale', () {
      // `date`, `planned_mg` and `actual_mg` are parsed by a spreadsheet. A
      // Persian handout that localizes them gives a doctor a column of
      // Perso-Arabic numerals their software reads as text.
      final document = _build(
        today: const LocalDate(2026, 4, 2),
        locale: const Locale('fa'),
      );

      for (final row in document.rows) {
        expect(row.date, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
        expect(row.plannedMg, matches(RegExp(r'^\d+(\.\d+)?$')));
      }
    });

    test('a day with no log is not reported as taken', () {
      final document = _build(today: const LocalDate(2026, 4, 3));

      expect(document.rows.last.taken, isNot(document.rows.first.taken));
      expect(document.rows.last.actualMg, isEmpty);
    });

    test('the note column tells "nothing to add" apart from "never asked"', () {
      final document = _build(today: const LocalDate(2026, 4, 3));

      expect(document.rows.first.note, 'slept badly');
      expect(document.rows.last.note, isNull);
    });

    test('the handout carries the numbers the Progress screen carries', () {
      // Not "similar numbers" — the SAME pure functions, so the two cannot
      // drift. This is the invariant SPEC §5.2 rests on.
      final snapshot = _snapshot();
      final schedule = _schedule();
      final document = _build(today: const LocalDate(2026, 4, 3));
      final elapsed = <DayPlan>[
        for (final day in schedule)
          if (day.date <= const LocalDate(2026, 4, 3)) day,
      ];

      // Recomputed from the pure primitive, not read back off the same
      // object: this pins the rounding as well as the number.
      final total = cumulativeTakenMg(snapshot.logs);
      expect(
        document.copy.statValues[1],
        contains(numberFormatFor(en).format((total.hundredths / 100).round())),
      );
      expect(
        document.copy.statValues[0],
        numberFormatFor(
          en,
        ).format(
          daysOnSteroids(snapshot.plan!.startDate, const LocalDate(2026, 4, 3)),
        ),
      );
      expect(elapsed, hasLength(3));
    });

    test('no bidi control character reaches the exported file', () {
      // Found on a device. `formatTabletBreakdown` wraps its run in U+2066 /
      // U+2069 so a Perso-Arabic screen does not reorder "1 × 5mg" — correct
      // on screen, and in the handout it is two `.notdef` boxes on EVERY row,
      // because the embedded font has no glyph for a control character and
      // `pdf` draws one rather than skipping it. `bidi.dart` already says
      // where the boundary is: these must never reach an export.
      final document = _build(today: const LocalDate(2026, 4, 3));
      final everything = <String>[
        for (final row in document.rows) ...row.cells,
        for (final row in document.pdfRows) ...row,
        document.copy.title,
        document.copy.subtitle,
        document.copy.currentValue,
        document.copy.targetValue,
        ...document.copy.statValues,
        ...document.copy.columns,
        document.copy.disclaimer,
        document.copy.footerPrefix,
      ];

      for (final cell in everything) {
        expect(
          cell.runes.any(
            (r) =>
                (r >= 0x200E && r <= 0x200F) ||
                (r >= 0x202A && r <= 0x202E) ||
                (r >= 0x2066 && r <= 0x2069),
          ),
          isFalse,
          reason: 'a control character survived into "$cell"',
        );
      }
      // And the fixture reaches the producer: without a tablet breakdown this
      // assertion holds over a document that never had one.
      expect(document.rows.first.tablets, contains('×'));
    });

    test('the footer says the same sentence the code constant does', () {
      // `kPdfDisclaimer` is the English text the PDF layer's own tests pin.
      // Two copies of one sentence is how a handout ends up disclaiming
      // something the app no longer says.
      final document = _build(today: const LocalDate(2026, 4, 2));

      expect(document.copy.disclaimer, l10n.exportDisclaimer);
      expect(l10n.exportDisclaimer, kPdfDisclaimer);
      expect(pdfFooter(document.copy), contains(document.copy.disclaimer));
    });

    test('the pdf table has a header row and one row per day', () {
      final document = _build(today: const LocalDate(2026, 4, 3));
      final table = doseHistoryTable(
        columns: document.copy.columns,
        rows: document.pdfRows,
      );

      expect(table.first, document.copy.columns);
      expect(table, hasLength(document.rows.length + 1));
      for (final row in table) {
        expect(row, hasLength(document.copy.columns.length));
      }
    });

    test('an empty history is empty, not a document with no rows', () {
      // "Nothing to export yet" is a sentence, not a blank PDF with a footer.
      expect(
        buildDoseHistoryDocument(
          snapshot: const TaperSnapshot(
            plan: null,
            steps: <StepFacts>[],
            logs: <DoseLogFacts>[],
            flares: <FlareEvent>[],
            holds: <HoldEvent>[],
            statusByStepId: <int, StepStatus>{},
          ),
          schedule: const <DayPlan>[],
          today: const LocalDate(2026, 4, 3),
          exportedAt: const LocalDate(2026, 4, 3),
          l10n: l10n,
          locale: en,
        ),
        isNull,
      );
    });
  });
}

DoseHistoryDocument _build({
  required LocalDate today,
  Locale locale = const Locale('en'),
}) {
  final built = buildDoseHistoryDocument(
    snapshot: _snapshot(),
    schedule: _schedule(),
    today: today,
    exportedAt: today,
    l10n: lookupAppLocalizations(locale),
    locale: locale,
  );
  return built!;
}

TaperSnapshot _snapshot() => TaperSnapshot(
  plan: fixturePlan,
  steps: const <StepFacts>[fixtureStep],
  logs: <DoseLogFacts>[
    DoseLogFacts(
      date: const LocalDate(2026, 4, 1),
      plannedMg: mg(10),
      actualMg: mg(10),
      taken: true,
      note: 'slept badly',
    ),
    DoseLogFacts(
      date: const LocalDate(2026, 4, 2),
      plannedMg: mg(10),
      actualMg: mg(10),
      taken: true,
    ),
  ],
  flares: const <FlareEvent>[],
  holds: const <HoldEvent>[],
  statusByStepId: const <int, StepStatus>{},
);

List<DayPlan> _schedule() => generated(
  plan: fixturePlan,
  steps: const <StepFacts>[fixtureStep],
  until: const LocalDate(2026, 4, 10),
);
