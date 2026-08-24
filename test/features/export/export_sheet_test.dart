// Progress → Export: the sheet that hands a file to a doctor.
//
// The claims here are about the control, not the file: the format the reader
// picked is the one that renders, the progress lives on the option they tapped
// rather than on a scrim over the app, and a failure says a sentence somebody
// can act on instead of an exception.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/features/backup/presentation/backup_actions.dart';
import 'package:nearlystop/features/export/presentation/export_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/services/files/fake_share_gateway.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  late FakeShareGateway share;
  late List<String> calls;

  setUp(() {
    share = FakeShareGateway();
    calls = <String>[];
  });

  Future<AppLocalizations> pumpSheet(
    WidgetTester tester, {
    Future<Result<File, Failure>> Function()? pdf,
    Future<Result<File, Failure>> Function()? csv,
  }) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    Future<Result<File, Failure>> record(
      String name,
      Future<Result<File, Failure>> Function()? override,
    ) async {
      calls.add(name);
      return await override?.call() ??
          Ok<File, Failure>(File('/tmp/nearlystop-history.$name'));
    }

    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showExportSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: <Override>[
        shareGatewayProvider.overrideWithValue(share),
        pdfExportProvider.overrideWithValue(() => record('pdf', pdf)),
        csvExportProvider.overrideWithValue(() => record('csv', csv)),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return l10n;
  }

  Finder option(String label) => find.widgetWithText(ExportOption, label);

  testWidgets('exactly two options, each carrying its audience line', (
    tester,
  ) async {
    // The two formats differ only by who reads them. An option list that does
    // not say so makes the reader guess, and PDF is the wrong guess for a
    // doctor who wanted the numbers.
    final l10n = await pumpSheet(tester);

    expect(find.byType(ExportOption), findsExactly(2));
    expect(find.text(l10n.exportPdfLabel), findsOneWidget);
    expect(find.text(l10n.exportPdfAudience), findsOneWidget);
    expect(find.text(l10n.exportCsvLabel), findsOneWidget);
    expect(find.text(l10n.exportCsvAudience), findsOneWidget);
  });

  testWidgets('picking PDF renders a PDF and nothing else', (tester) async {
    final l10n = await pumpSheet(tester);

    await tester.tap(option(l10n.exportPdfLabel));
    await tester.pumpAndSettle();

    expect(calls, <String>['pdf']);
    expect(share.calls.single.mimeType, 'application/pdf');
  });

  testWidgets('picking the spreadsheet renders a CSV and nothing else', (
    tester,
  ) async {
    final l10n = await pumpSheet(tester);

    await tester.tap(option(l10n.exportCsvLabel));
    await tester.pumpAndSettle();

    expect(calls, <String>['csv']);
    expect(share.calls.single.mimeType, 'text/csv');
  });

  testWidgets('every share carries an origin rect', (tester) async {
    // A share sheet presented without a source rectangle CRASHES on iPad.
    final l10n = await pumpSheet(tester);

    await tester.tap(option(l10n.exportPdfLabel));
    await tester.pumpAndSettle();

    expect(
      share.calls.single.originRect,
      isNotNull,
      reason: 'this flow will crash on iPad',
    );
  });

  testWidgets('a running export owns its own control, not the whole app', (
    tester,
  ) async {
    final gate = Completer<Result<File, Failure>>();
    final l10n = await pumpSheet(tester, pdf: () => gate.future);
    final barriersBefore = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .length;

    await tester.tap(option(l10n.exportPdfLabel));
    await tester.pump();

    expect(
      tester.widget<ExportOption>(option(l10n.exportPdfLabel)).busy,
      isTrue,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).length,
      barriersBefore,
      reason: 'the export put a second barrier over the app',
    );

    gate.complete(Ok<File, Failure>(File('/tmp/nearlystop-history.pdf')));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed export leaves both options usable, and says why', (
    tester,
  ) async {
    final l10n = await pumpSheet(
      tester,
      pdf: () async => const Err<File, Failure>(_Sentinel()),
    );

    await tester.tap(option(l10n.exportPdfLabel));
    await tester.pumpAndSettle();

    for (final label in <String>[l10n.exportPdfLabel, l10n.exportCsvLabel]) {
      expect(
        tester.widget<ExportOption>(option(label)).onPressed,
        isNotNull,
        reason: '$label is dead after a failure the reader can retry',
      );
    }
    expect(find.text(l10n.exportFailed), findsOneWidget);
    expect(share.calls, isEmpty);
  });

  testWidgets('no exception text ever reaches the screen', (tester) async {
    final l10n = await pumpSheet(
      tester,
      pdf: () async => const Err<File, Failure>(_Sentinel()),
    );

    await tester.tap(option(l10n.exportPdfLabel));
    await tester.pumpAndSettle();

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(rendered, isNot(contains(_Sentinel.sentinel)));
  });

  testWidgets('the sheet says the file is not encrypted', (tester) async {
    // SPEC §5.3's honesty rule on the surface that hands the file to somebody
    // else, and the claim the store privacy copy rests on.
    final l10n = await pumpSheet(tester);

    expect(find.text(l10n.exportNotEncrypted), findsOneWidget);
  });
}

/// A failure whose `toString()` carries a string nothing else would.
final class _Sentinel extends Failure {
  const _Sentinel();

  /// A string no localized message would ever contain.
  static const String sentinel = 'RAW-EXCEPTION-LEAKED-QJ4';

  @override
  String get code => 'test.sentinel';

  @override
  String toString() => sentinel;
}
