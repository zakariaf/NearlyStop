// The two renderers, all the way to bytes on disk.
//
// `export_sheet_test.dart` replaces these providers with fakes, which is right
// for a widget test and leaves the actual rendering — the font load, the
// encoder, the write — with nothing over it. This is that.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/data/taper_repository.dart';
import 'package:nearlystop/features/backup/presentation/backup_actions.dart';
import 'package:nearlystop/features/export/application/dose_history_document.dart';
import 'package:nearlystop/features/export/data/dose_history_csv.dart';
import 'package:nearlystop/features/export/domain/export_failure.dart';
import 'package:nearlystop/features/export/presentation/export_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:riverpod/riverpod.dart';

import '../../fixtures/taper_fixture.dart';

void main() {
  // The bundled faces are read through `rootBundle`, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('nearlystop-export');
    addTearDown(() => workspace.delete(recursive: true));
  });

  ProviderContainer containerFor(DoseHistoryDocument? document) {
    final container = ProviderContainer(
      overrides: <Override>[
        workingDirectoryProvider.overrideWithValue(() async => workspace),
        doseHistoryDocumentProvider.overrideWithValue(document),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  DoseHistoryDocument document({Locale locale = const Locale('en')}) =>
      buildDoseHistoryDocument(
        snapshot: TaperSnapshot(
          plan: fixturePlan,
          steps: const <StepFacts>[fixtureStep],
          logs: <DoseLogFacts>[
            DoseLogFacts(
              date: const LocalDate(2026, 4, 1),
              plannedMg: mg(10),
              actualMg: mg(10),
              taken: true,
              note: 'first day',
            ),
          ],
          flares: const <FlareEvent>[],
          holds: const <HoldEvent>[],
          statusByStepId: const <int, StepStatus>{},
        ),
        schedule: generated(
          plan: fixturePlan,
          steps: const <StepFacts>[fixtureStep],
          until: const LocalDate(2026, 4, 10),
        ),
        today: const LocalDate(2026, 4, 5),
        exportedAt: const LocalDate(2026, 4, 5),
        l10n: lookupAppLocalizations(locale),
        locale: locale,
      )!;

  Future<File> unwrap(Future<Result<File, Failure>> pending) async {
    final result = await pending;
    if (result case Err<File, Failure>(:final failure)) {
      fail('export refused: ${failure.code}');
    }
    return (result as Ok<File, Failure>).value;
  }

  test('the PDF embeds the two faces this app bundles', () async {
    // The `pdf` package's built-in Helvetica has no Perso-Arabic coverage at
    // all, so a handout built on it is a page of empty boxes and nothing in
    // the app would report it. A font's PostScript NAME survives as plain
    // ASCII in the font descriptor — unlike the page text, which goes through
    // a per-font CMap and cannot be grepped at all.
    final container = containerFor(document());

    final file = await unwrap(container.read(pdfExportProvider)());

    expect(file.path, endsWith('.pdf'));
    final bytes = await file.readAsBytes();
    final ascii = String.fromCharCodes(bytes);
    expect(ascii, startsWith('%PDF-'));
    expect(ascii, contains('Nunito'), reason: 'the Latin face is missing');
  });

  test('a Persian handout carries the Perso-Arabic face', () async {
    // Same call, the other script. What this catches is a fallback that only
    // exists on the Latin path — the failure mode is a page of empty boxes.
    final container = containerFor(document(locale: const Locale('fa')));

    final file = await unwrap(container.read(pdfExportProvider)());

    final ascii = String.fromCharCodes(await file.readAsBytes());
    expect(ascii, startsWith('%PDF-'));
    expect(ascii, contains('Vazirmatn'));
  });

  test('the CSV keeps its BOM and its header row', () async {
    // Excel on Windows misreads UTF-8 without a BOM, and a doctor's laptop is
    // Windows. The symptom is mojibake in the only file this feature makes.
    final container = containerFor(document());

    final file = await unwrap(container.read(csvExportProvider)());

    expect(file.path, endsWith('.csv'));
    // Asserted in BYTES. Dart's UTF-8 decoder silently drops a leading BOM,
    // so `readAsString` reports success whether the file has one or not.
    expect(
      (await file.readAsBytes()).take(3),
      <int>[0xEF, 0xBB, 0xBF],
      reason: 'Excel on Windows will render this as mojibake',
    );
    expect(
      (await file.readAsString()).split('\r\n').first,
      kCsvColumns.join(','),
    );
  });

  test('exporting twice in one day replaces, never appends', () async {
    // Both writes land on the same name — the file stem carries the date, not
    // a counter. A file with the history in it twice is a doctor reading
    // double the milligrams.
    final container = containerFor(document());

    final first = await unwrap(container.read(csvExportProvider)());
    final firstLines = (await first.readAsString()).split('\r\n').length;
    final second = await unwrap(container.read(csvExportProvider)());

    expect(second.path, first.path);
    expect((await second.readAsString()).split('\r\n').length, firstLines);
  });

  test('nothing to export is its own failure, not a broken write', () async {
    // "Nothing yet" is a sentence somebody can act on. "The file could not be
    // made" for the same state teaches a person on day one that the app is
    // broken.
    final container = containerFor(null);

    expect(
      await container.read(pdfExportProvider)(),
      isA<Err<File, Failure>>(),
    );
    expect(
      (await container.read(csvExportProvider)() as Err<File, Failure>).failure,
      isA<NothingToExport>(),
    );
  });
}
