// The app's ONE undo surface.
//
// Named once here so three epics stop inventing one, and deliberately not a
// `SnackBar` — for the same reason the backfill banner is not: it times out
// before this reader finishes reading it, and what it is offering to undo is a
// change to their medication record.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/undo_row.dart';

import '../../../support/harness.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    String message = 'Marked Thursday as taken.',
    VoidCallback? onUndo,
    VoidCallback? onDismiss,
  }) => pumpApp(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: Material(
        child: UndoRow(
          message: message,
          undoLabel: 'Undo',
          onUndo: onUndo ?? () {},
          dismissLabel: 'Close',
          onDismiss: onDismiss ?? () {},
        ),
      ),
    ),
    surfaceSize: const Size(390, 900),
  );

  testWidgets('it survives thirty seconds and is no SnackBar', (tester) async {
    await pumpRow(tester);

    await tester.pump(const Duration(seconds: 30));

    expect(find.byType(UndoRow), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a screen reader is told', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRow(tester);

    expect(
      tester.getSemantics(find.byType(UndoRow)),
      isSemantics(isLiveRegion: true, label: 'Marked Thursday as taken.'),
    );
    handle.dispose();
  });

  testWidgets('Undo fires once; the close fires once', (tester) async {
    var undos = 0;
    var dismissals = 0;
    await pumpRow(
      tester,
      onUndo: () => undos++,
      onDismiss: () => dismissals++,
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(undos, 1);
    expect(dismissals, 1);
  });

  testWidgets('two rows sharing the singleton key cannot coexist', (
    tester,
  ) async {
    // The failure mode: mark a day, mark another, and two undo rows are on
    // screen offering to undo different things — which one undoes what is not
    // answerable by looking. Mounting the row under `singletonKey` makes that
    // a BUILD error rather than a UI somebody has to notice, because Flutter
    // refuses duplicate keys among siblings.
    //
    // Asserted by doing it. Changing one row's message and finding one row
    // afterwards would prove nothing: there was only ever one.
    await pumpApp(
      tester,
      const Align(
        alignment: Alignment.topCenter,
        child: Material(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              UndoRow(
                key: UndoRow.singletonKey,
                message: 'Marked Thursday as taken.',
                undoLabel: 'Undo',
                onUndo: _noop,
                dismissLabel: 'Close',
                onDismiss: _noop,
              ),
              UndoRow(
                key: UndoRow.singletonKey,
                message: 'Marked Friday as taken.',
                undoLabel: 'Undo',
                onUndo: _noop,
                dismissLabel: 'Close',
                onDismiss: _noop,
              ),
            ],
          ),
        ),
      ),
      surfaceSize: const Size(390, 900),
    );

    expect(
      tester.takeException(),
      isA<FlutterError>().having(
        (error) => error.message,
        'message',
        contains('Duplicate keys'),
      ),
      reason: 'two undo rows were allowed to stack',
    );
  });

  testWidgets('replacing the row under the same key swaps its message', (
    tester,
  ) async {
    // The other half: the key is stable, so the NEXT mutation reuses the same
    // slot instead of animating in beside the old one.
    var message = 'Marked Thursday as taken.';
    late StateSetter setState;
    await pumpApp(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: Material(
          child: StatefulBuilder(
            builder: (context, setter) {
              setState = setter;
              return UndoRow(
                key: UndoRow.singletonKey,
                message: message,
                undoLabel: 'Undo',
                onUndo: _noop,
                dismissLabel: 'Close',
                onDismiss: _noop,
              );
            },
          ),
        ),
      ),
      surfaceSize: const Size(390, 900),
    );

    setState(() => message = 'Marked Friday as taken.');
    await tester.pumpAndSettle();

    expect(find.byType(UndoRow), findsOneWidget);
    expect(find.text('Marked Friday as taken.'), findsOneWidget);
    expect(find.text('Marked Thursday as taken.'), findsNothing);
  });
}

void _noop() {}
