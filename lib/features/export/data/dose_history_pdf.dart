/// The dose history, as something a rheumatologist can read.
library;

import 'package:nearlystop/theme/pdf_type_scale.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The sentence on every page.
///
/// **Every page**, because this document is read out of context: a doctor gets
/// page three photocopied into a file, and a footer that only exists on page
/// one is a page with no disclaimer on it. It is the same sentence the app
/// shows, for the same reason.
const String kPdfDisclaimer =
    "Generated on the patient's device from a plan they entered. "
    'Not medical advice.';

/// The exact line at the bottom of every page.
///
/// A named function so it is assertable: PDF text is encoded per font with a
/// custom CMap, so grepping the saved bytes for a sentence finds nothing even
/// when the sentence is there. What IS checkable is that this returns the
/// disclaimer and that `pw.MultiPage` is given it as its footer builder —
/// which it calls once per page.
String pdfFooter(DoseHistoryPdfCopy copy) =>
    '${copy.footerPrefix} · ${copy.disclaimer}';

/// Everything the document says, already localized.
///
/// Strings, not domain types: the locale decision — which numerals, which
/// date format, which direction — has already been made by the caller, and
/// re-deciding it here is how a Persian handout ends up with English weekdays.
class DoseHistoryPdfCopy {
  /// Creates the copy.
  const DoseHistoryPdfCopy({
    required this.title,
    required this.subtitle,
    required this.currentLabel,
    required this.currentValue,
    required this.targetLabel,
    required this.targetValue,
    required this.statLabels,
    required this.statValues,
    required this.columns,
    required this.disclaimer,
    required this.footerPrefix,
  });

  /// The drug and what this is.
  final String title;

  /// The date range.
  final String subtitle;

  /// "Current dose".
  final String currentLabel;

  /// The dose itself.
  final String currentValue;

  /// "Target".
  final String targetLabel;

  /// The target dose.
  final String targetValue;

  /// The three headline stats' labels.
  final List<String> statLabels;

  /// The three headline stats' values.
  ///
  /// **The same numbers the Progress screen computes** from the same day list.
  /// One source, two renderings: a doctor and a patient comparing notes must
  /// not find two different totals.
  final List<String> statValues;

  /// The day table's header row.
  final List<String> columns;

  /// The sentence on every page.
  final String disclaimer;

  /// The app's name and the export date, before the disclaimer.
  final String footerPrefix;
}

/// The table's rows, header first.
///
/// A named function so the repeating-header claim is assertable: PDF glyphs
/// are font-encoded through a custom CMap, so the words on the page appear
/// nowhere in the saved bytes and a grep over them would pass on an empty
/// document.
List<List<String>> doseHistoryTable({
  required List<String> columns,
  required List<List<String>> rows,
}) => <List<String>>[columns, ...rows];

/// Builds the handout.
///
/// **Both bundled faces are embedded.** `google_fonts` is banned in this app
/// and the `pdf` package's built-in Helvetica has no Perso-Arabic coverage at
/// all — a Persian handout built on it is a page of empty boxes, and nothing
/// in the app would report it.
///
/// **Stated limitation:** `pdf` does bidi reordering and Arabic shaping, but
/// Sorani-specific letterforms (ڕ ڵ ۆ ێ) depend entirely on the embedded
/// font's shaping tables and are not guaranteed to match Flutter's own text
/// engine. That is verified by a human on a device, not here; if `ckb` shapes
/// badly the answer is to offer CSV and say so, never to hand a doctor a
/// broken page.
pw.Document buildDoseHistoryPdf({
  required DoseHistoryPdfCopy copy,
  required List<List<String>> rows,
  required pw.Font latinFont,
  required pw.Font persoFont,
  bool isRightToLeft = false,
}) {
  final theme = pw.ThemeData.withFont(
    base: latinFont,
    bold: latinFont,
    italic: latinFont,
    boldItalic: latinFont,
    // The fallback is what actually draws Perso-Arabic when the base face has
    // no glyph for a codepoint. Without it the runs come out blank.
    fontFallback: <pw.Font>[persoFont, latinFont],
  );

  final document = pw.Document(theme: theme)
    ..addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isRightToLeft
            ? pw.TextDirection.rtl
            : pw.TextDirection.ltr,
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsetsDirectional.only(
                  bottom: PdfTypeScale.edgeGap,
                ),
                child: pw.Text(copy.title),
              ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsetsDirectional.only(
            top: PdfTypeScale.edgeGap,
          ),
          child: pw.Text(
            '${copy.footerPrefix} · ${copy.disclaimer}',
            style: const pw.TextStyle(fontSize: PdfTypeScale.footnote),
          ),
        ),
        build: (context) => <pw.Widget>[
          pw.Text(
            copy.title,
            style: const pw.TextStyle(
              fontSize: PdfTypeScale.title,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            copy.subtitle,
            style: const pw.TextStyle(fontSize: PdfTypeScale.subtitle),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              _pair(copy.currentLabel, copy.currentValue),
              _pair(copy.targetLabel, copy.targetValue),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              for (var index = 0; index < copy.statLabels.length; index++)
                _pair(copy.statLabels[index], copy.statValues[index]),
            ],
          ),
          pw.SizedBox(height: 16),
          // `headerCount: 1`, so pages 2+ each begin with the column names. A
          // table whose header only exists on the first page is a page of
          // unlabelled numbers.
          pw.TableHelper.fromTextArray(
            // Stated even though it is the default. The analyzer calls that
            // redundant; it is not. This one number is the difference between
            // pages 2+ carrying column names and pages 2+ being unlabelled
            // numbers, and a library default is not where that decision
            // should live.
            // ignore: avoid_redundant_argument_values
            headerCount: 1,
            cellStyle: const pw.TextStyle(fontSize: PdfTypeScale.body),
            headerStyle: const pw.TextStyle(
              fontSize: PdfTypeScale.body,
              fontWeight: pw.FontWeight.bold,
            ),
            data: doseHistoryTable(columns: copy.columns, rows: rows),
          ),
        ],
      ),
    );

  return document;
}

/// A label above its value.
pw.Widget _pair(String label, String value) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: <pw.Widget>[
    pw.Text(label, style: const pw.TextStyle(fontSize: PdfTypeScale.body)),
    pw.Text(
      value,
      style: const pw.TextStyle(
        fontSize: PdfTypeScale.statValue,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  ],
);
