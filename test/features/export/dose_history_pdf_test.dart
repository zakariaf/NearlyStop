// The doctor's handout, checked over the built document rather than pixels.
//
// Two claims here cannot be checked by looking at one page: that the
// disclaimer is on EVERY page, and that no built-in Helvetica is referenced.
// The second is what catches a Persian page rendering as empty boxes before a
// human ever opens the file — the `pdf` package's built-in faces have no
// Perso-Arabic coverage at all.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nearlystop/features/export/data/dose_history_pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  late pw.Font latin;
  late pw.Font perso;

  setUpAll(() {
    // The BUNDLED faces, read off disk the way the app bundles them —
    // `google_fonts` is banned and the built-ins cannot draw Persian.
    latin = pw.Font.ttf(
      File(
        'assets/fonts/Nunito-VariableFont_wght.ttf',
      ).readAsBytesSync().buffer.asByteData(),
    );
    perso = pw.Font.ttf(
      File(
        'assets/fonts/Vazirmatn-VariableFont_wght.ttf',
      ).readAsBytesSync().buffer.asByteData(),
    );
  });

  /// A document over [days] rows of history.
  Future<List<int>> build({
    int days = 300,
    bool rtl = false,
    String disclaimer = kPdfDisclaimer,
  }) async {
    final document = buildDoseHistoryPdf(
      copy: DoseHistoryPdfCopy(
        title: 'Prednisolone taper',
        subtitle: '1 April 2026 – 16 April 2025',
        currentLabel: 'Current dose',
        currentValue: '9mg',
        targetLabel: 'Target',
        targetValue: '0mg',
        statLabels: <String>['Total taken', 'Days so far', 'Ticked'],
        statValues: <String>['6,842mg', '581', '574 of 581'],
        columns: <String>['Date', 'Dose', 'Taken', 'Note'],
        disclaimer: disclaimer,
        footerPrefix: 'NearlyStop · exported 16 April 2025',
      ),
      rows: <List<String>>[
        for (var index = 0; index < days; index++)
          <String>['2026-04-${index % 28 + 1}', '9mg', 'yes', ''],
      ],
      latinFont: latin,
      persoFont: perso,
      isRightToLeft: rtl,
    );
    return document.save();
  }

  test('a 300-day history is more than one page', () async {
    final bytes = await build();

    expect(_pageCount(bytes), greaterThan(1));
  });

  test('the footer line carries the disclaimer', () async {
    // Asserted on the FUNCTION, not by grepping the file: PDF text is encoded
    // per font through a custom CMap, so a sentence that is plainly on the
    // page appears nowhere in the bytes. What this pins is that the line
    // `pw.MultiPage` renders once per page is the disclaimer — the per-page
    // part is `MultiPage`'s documented job, and the multi-page assertion above
    // is what makes it more than one page in the first place.
    const copy = DoseHistoryPdfCopy(
      title: 't',
      subtitle: 's',
      currentLabel: 'c',
      currentValue: '9mg',
      targetLabel: 'x',
      targetValue: '0mg',
      statLabels: <String>['a', 'b', 'c'],
      statValues: <String>['1', '2', '3'],
      columns: <String>['d'],
      disclaimer: kPdfDisclaimer,
      footerPrefix: 'NearlyStop · exported 16 April 2025',
    );

    expect(pdfFooter(copy), contains(kPdfDisclaimer));
    expect(pdfFooter(copy), contains('NearlyStop'));
  });

  test(
    'the footer is actually RENDERED, on a document with many pages',
    () async {
      // The text itself cannot be grepped — PDF glyphs go through a per-font
      // CMap — but its PRESENCE can: the same document with a one-character
      // disclaimer is measurably smaller, and the gap grows with the page count
      // because `pw.MultiPage` draws the footer once per page. A document that
      // rendered no footer at all would be the same size either way.
      final long = await build();
      final short = await build(disclaimer: 'x');

      expect(_pageCount(long), greaterThan(1));
      expect(
        long.length,
        greaterThan(short.length),
        reason: 'the disclaimer text reaches no page',
      );
    },
  );

  test('the disclaimer says it is not medical advice', () {
    // The whole reason it is on the page. This document is read out of
    // context, by somebody who did not watch it being made.
    expect(kPdfDisclaimer, contains('Not medical advice'));
    expect(kPdfDisclaimer, contains("patient's device"));
  });

  test('the table has a repeating header row', () {
    // `headerCount: 1`, so pages 2+ each begin with the column names. A table
    // whose header only exists on page one is a page of unlabelled numbers —
    // and page one is the page that does not get photocopied.
    //
    // Asserted on the row data rather than on rendered text: PDF glyphs are
    // font-encoded through a custom CMap, so the words on the page appear
    // nowhere in the saved bytes and a grep over them would pass on an empty
    // document just as happily.
    const columns = <String>['Date', 'Dose', 'Taken', 'Note'];
    final table = doseHistoryTable(
      columns: columns,
      rows: <List<String>>[
        <String>['2026-04-01', '9mg', 'yes', ''],
      ],
    );

    expect(table.first, columns);
    expect(table, hasLength(2));
  });

  test('a Latin document embeds Nunito and no built-in face', () async {
    final text = _rawStrings(await build());

    expect(text, contains('Nunito'));
    expect(
      text,
      isNot(contains('Helvetica')),
      reason: 'a built-in face is referenced, and it has no Persian at all',
    );
  });

  test('a Persian document embeds Vazirmatn', () async {
    // The check that catches a page of empty boxes before a human opens the
    // file. `pdf`'s built-in faces have no Perso-Arabic coverage, and a
    // document that silently fell back to one of them passes every structural
    // assertion in this file.
    final document = buildDoseHistoryPdf(
      copy: const DoseHistoryPdfCopy(
        title: 'کاهش پردنیزولون',
        subtitle: 'فروردین',
        currentLabel: 'دوز کنونی',
        currentValue: '۹',
        targetLabel: 'هدف',
        targetValue: '۰',
        statLabels: <String>['مجموع', 'روزها', 'ثبت‌شده'],
        statValues: <String>['۶۸۴۲', '۵۸۱', '۵۷۴'],
        columns: <String>['تاریخ', 'دوز'],
        disclaimer: kPdfDisclaimer,
        footerPrefix: 'نیرلی‌استاپ',
      ),
      rows: <List<String>>[
        for (var index = 0; index < 40; index++) <String>['فروردین', '۹'],
      ],
      latinFont: latin,
      persoFont: perso,
      isRightToLeft: true,
    );

    final text = _rawStrings(await document.save());

    expect(text, contains('Vazirmatn'));
    expect(text, isNot(contains('Helvetica')));
  });

  test('an RTL document is still more than one page', () async {
    expect(_pageCount(await build(rtl: true)), greaterThan(1));
  });
}

/// The document's bytes with every FlateDecode stream inflated.
///
/// A PDF 1.5 document keeps its page tree, its font dictionaries and its
/// content streams inside compressed object streams, so a grep over the raw
/// bytes finds nothing at all — which is a test that passes on an empty
/// document. Inflating first is what makes these assertions mean anything.
String _inflated(List<int> bytes) {
  final buffer = StringBuffer(latin1.decode(bytes, allowInvalid: true));
  final raw = Uint8List.fromList(bytes);
  final marker = latin1.encode('stream');
  for (var index = 0; index + marker.length < raw.length; index++) {
    if (!_matchesAt(raw, index, marker)) continue;
    var start = index + marker.length;
    if (start < raw.length && raw[start] == 0x0D) start++;
    if (start < raw.length && raw[start] == 0x0A) start++;
    final end = _indexOf(raw, latin1.encode('endstream'), start);
    if (end < 0) continue;
    try {
      buffer.write(
        latin1.decode(
          ZLibCodec().decode(raw.sublist(start, end)),
          allowInvalid: true,
        ),
      );
    } on Object {
      // Not a deflate stream — an embedded font file, an image. Its raw bytes
      // are already in the buffer above.
    }
  }
  return buffer.toString();
}

bool _matchesAt(Uint8List haystack, int at, List<int> needle) {
  for (var index = 0; index < needle.length; index++) {
    if (haystack[at + index] != needle[index]) return false;
  }
  return true;
}

int _indexOf(Uint8List haystack, List<int> needle, int from) {
  for (var index = from; index + needle.length <= haystack.length; index++) {
    if (_matchesAt(haystack, index, needle)) return index;
  }
  return -1;
}

/// How many pages the document has, read out of its own page tree.
/// How many pages the document has, read out of its own page tree.
int _pageCount(List<int> bytes) {
  final raw = _inflated(bytes);
  final match = RegExp(r'/Type\s*/Pages[^>]*?/Count\s+(\d+)').firstMatch(raw);
  if (match != null) return int.parse(match.group(1)!);
  return RegExp(r'/Type\s*/Page[^s]').allMatches(raw).length;
}

/// The document's bytes as searchable text, streams inflated.
String _rawStrings(List<int> bytes) => _inflated(bytes);
