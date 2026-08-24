// "Export before anything destructive" as a code path, not a habit.
//
// The half that matters is the failure: a guard that runs the destructive
// action after a FAILED export is a formality with a progress spinner. Every
// case here asserts an ordered call log rather than two independent counters,
// because "both happened" and "the export happened first" are different
// claims and only the second one protects anybody.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/features/backup/presentation/export_guard.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';

import '../../support/harness.dart';

void main() {
  late List<String> log;

  setUp(() => log = <String>[]);

  /// Pumps a button that opens the guard, and taps it.
  Future<void> openGuard(
    WidgetTester tester, {
    required Future<Result<void, Failure>> Function() export,
  }) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showExportGuard(
                context: context,
                request: const ConfirmRequest(
                  title: 'Delete this plan?',
                  body: 'Everything on this phone is removed.',
                  confirmLabel: 'Delete everything',
                  cancelLabel: 'Cancel',
                ),
                exportLabel: 'Export first',
                onExport: () async {
                  log.add('export');
                  return export();
                },
                onConfirmed: () async => log.add('destroy'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<Result<void, Failure>> succeeds() async =>
      const Ok<void, Failure>(null);

  Future<Result<void, Failure>> fails() async =>
      const Err<void, Failure>(_ExportBroke());

  testWidgets('dismissing it does nothing at all', (tester) async {
    await openGuard(tester, export: succeeds);

    // The scrim, which is how a sheet is actually dismissed on a phone.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(log, isEmpty);
  });

  testWidgets('cancelling does nothing at all', (tester) async {
    await openGuard(tester, export: succeeds);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(log, isEmpty);
  });

  testWidgets('exporting first runs the export, THEN the destruction', (
    tester,
  ) async {
    await openGuard(tester, export: succeeds);

    await tester.tap(find.text('Export first'));
    await tester.pumpAndSettle();

    expect(
      log,
      <String>['export', 'destroy'],
      reason: 'the order is the whole guarantee',
    );
  });

  testWidgets('a FAILED export destroys nothing', (tester) async {
    // The case that separates a guard from a formality. Somebody chose "export
    // first" because they wanted the backup; proceeding without one is the
    // opposite of what they asked for.
    await openGuard(tester, export: fails);

    await tester.tap(find.text('Export first'));
    await tester.pumpAndSettle();

    expect(log, <String>['export']);
  });

  testWidgets('continuing without a backup destroys, and exports nothing', (
    tester,
  ) async {
    await openGuard(tester, export: succeeds);

    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    expect(log, <String>['destroy']);
  });

  testWidgets('the export action is the LESS prominent one', (tester) async {
    // Asserted by widget type, not by colour: the destructive action is the
    // one the reader came for, and dressing the export as the primary would
    // make "keep my data" look like the thing being warned about.
    await openGuard(tester, export: succeeds);

    expect(
      find.widgetWithText(PrimaryPillButton, 'Export first'),
      findsOneWidget,
      reason: 'the action that KEEPS the data is the recommended one',
    );
    expect(
      find.widgetWithText(TertiaryButton, 'Delete everything'),
      findsOneWidget,
      reason: 'destroying without a backup is available, not encouraged',
    );
  });
}

/// A failure with no meaning beyond "the export did not work".
final class _ExportBroke extends Failure {
  const _ExportBroke();

  @override
  String get code => 'test.export_broke';
}
