// The sheet that stands between a reader and something they cannot undo.
//
// Its result type is an enum rather than `bool?` for a reason this file makes
// concrete: there are FOUR ways out and three of them are a cancel. A nullable
// bool makes "dismissed" and "cancelled" two spellings of the same thing that
// every call site has to remember to collapse — and the one that forgets
// treats a scrim tap as a confirmation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';

import '../../../support/harness.dart';

void main() {
  const request = ConfirmRequest(
    title: 'Delete this plan?',
    body: 'Your history and your total are kept.',
    confirmLabel: 'Delete plan',
    cancelLabel: 'Cancel',
  );

  Future<ConfirmResult?> openAndAnswer(
    WidgetTester tester,
    Future<void> Function(WidgetTester tester) answer, {
    ConfirmRequest requested = request,
  }) async {
    ConfirmResult? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async =>
                result = await showConfirmSheet(context, requested),
            child: const Text('open'),
          ),
        ),
      ),
      surfaceSize: const Size(390, 844),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmSheet), findsOneWidget);

    await answer(tester);
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('all four exits, and NONE of them is null', (tester) async {
    // A table over every way out. `null` is not in the enum, so a call site
    // cannot forget to handle "dismissed".
    final exits = <String, Future<void> Function(WidgetTester)>{
      'confirm': (t) async => t.tap(find.text('Delete plan')),
      'cancel': (t) async => t.tap(find.text('Cancel')),
      // Above the sheet: the modal barrier.
      'scrim': (t) async => t.tapAt(const Offset(195, 40)),
      'drag down': (t) async {
        await t.drag(find.byType(ConfirmSheet), const Offset(0, 600));
        await t.pumpAndSettle();
      },
    };

    for (final MapEntry(key: name, value: answer) in exits.entries) {
      final result = await openAndAnswer(tester, answer);

      expect(result, isNotNull, reason: '$name resolved to null');
      expect(
        result,
        name == 'confirm' ? ConfirmResult.confirmed : ConfirmResult.cancelled,
        reason: name,
      );
    }
  });

  testWidgets('the pre-action runs and the sheet STAYS OPEN', (tester) async {
    // This is what makes `SPEC.md` §5.3's "export before anything destructive"
    // implementable: the reader exports, lands back on the sheet, and only
    // then decides. A pre-action that dismissed the sheet would make "export
    // first" mean "export, then find the delete button again".
    var exports = 0;
    final result = await openAndAnswer(
      tester,
      (t) async {
        await t.tap(find.text('Export first'));
        await t.pumpAndSettle();
        expect(exports, 1);
        expect(
          find.byType(ConfirmSheet),
          findsOneWidget,
          reason: 'the pre-action closed the sheet',
        );
        await t.tap(find.text('Delete plan'));
      },
      requested: ConfirmRequest(
        title: request.title,
        body: request.body,
        confirmLabel: request.confirmLabel,
        cancelLabel: request.cancelLabel,
        preActionLabel: 'Export first',
        onPreAction: () async => exports++,
      ),
    );

    expect(exports, 1);
    expect(result, ConfirmResult.confirmed);
  });

  testWidgets('it reads as a named modal route, focused on the question', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    ConfirmResult? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async =>
                result = await showConfirmSheet(context, request),
            child: const Text('open'),
          ),
        ),
      ),
      surfaceSize: const Size(390, 844),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byType(ConfirmSheet));
    expect(node.flagsCollection.scopesRoute, isTrue);
    expect(node.flagsCollection.namesRoute, isTrue);
    expect(node.label, contains(request.title));
    // Focus on the QUESTION, not on the first button: a reader who lands on
    // "Delete plan" has been handed the answer before the question.
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'confirm-sheet-title',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, ConfirmResult.cancelled);
    handle.dispose();
  });

  testWidgets('the body names what is KEPT, not only what is lost', (
    tester,
  ) async {
    // Copy, asserted as structure: this reader has spent two years on a taper
    // and the question they are actually asking is "what happens to my two
    // years". A sheet that only says what is destroyed does not answer it.
    await openAndAnswer(tester, (t) async {
      expect(find.text(request.body), findsOneWidget);
      await t.tap(find.text('Cancel'));
    });
  });

  testWidgets('the confirm styling follows isDestructive', (tester) async {
    // Structural, not a colour read: which CLASS the sheet builds is what
    // decides whether the confirm looks like a warning, and it is the thing a
    // future edit would get wrong.
    await openAndAnswer(tester, (t) async {
      expect(
        find.widgetWithText(DestructiveButton, 'Delete plan'),
        findsOneWidget,
      );
      expect(find.byType(PrimaryPillButton), findsNothing);
      await t.tap(find.text('Cancel'));
    });

    await openAndAnswer(
      tester,
      (t) async {
        expect(
          find.widgetWithText(PrimaryPillButton, 'Go ahead'),
          findsOneWidget,
        );
        expect(find.byType(DestructiveButton), findsNothing);
        await t.tap(find.text('Go ahead'));
      },
      requested: const ConfirmRequest(
        title: 'Import this file?',
        body: 'Nothing is replaced until you confirm.',
        confirmLabel: 'Go ahead',
        cancelLabel: 'Cancel',
        isDestructive: false,
      ),
    );
  });
}
