// The banner that is never a SnackBar.
//
// A `SnackBar` times out. This reader is 78, reads slowly, and the message is
// about their medication record — so it stays until they act on it. The tests
// that matter here are the ones a timing bug would break, and they are written
// with a TIMED `pump`, never `pumpAndSettle` on a surface that never settles.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/backfill_banner.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

void main() {
  const message = "You haven't marked the last 3 days.";

  Future<void> pumpBanner(
    WidgetTester tester, {
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
    TextScaler textScaler = TextScaler.noScaling,
    Locale locale = const Locale('en'),
  }) => pumpApp(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: Material(
        child: BackfillBanner(
          message: message,
          primaryActionLabel: 'Mark them now',
          onPrimaryAction: onPrimary ?? () {},
          secondaryActionLabel: 'Not now',
          onSecondaryAction: onSecondary ?? () {},
        ),
      ),
    ),
    locale: locale,
    textScaler: textScaler,
    surfaceSize: const Size(390, 900),
  );

  testWidgets('it is still there after thirty seconds, and is no SnackBar', (
    tester,
  ) async {
    await pumpBanner(tester);

    // A TIMED pump. `pumpAndSettle` on a surface that never settles either
    // hangs or returns immediately, and neither outcome tests the claim.
    await tester.pump(const Duration(seconds: 30));

    expect(find.byType(BackfillBanner), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a screen reader is told, without being interrupted', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpBanner(tester);

    expect(
      tester.getSemantics(find.byType(BackfillBanner)),
      isSemantics(isLiveRegion: true, label: message),
    );
    handle.dispose();
  });

  testWidgets('each action fires exactly once', (tester) async {
    var primary = 0;
    var secondary = 0;
    await pumpBanner(
      tester,
      onPrimary: () => primary++,
      onSecondary: () => secondary++,
    );

    await tester.tap(find.text('Mark them now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(primary, 1);
    expect(secondary, 1);
  });

  testWidgets('the body is ink, NOT the warning colour', (tester) async {
    // The semantic ink is for the glyph and the border. A whole paragraph in
    // amber is both harder to read and scolding, and a missed day is not a
    // failure (SPEC.md §4.1, §4.3).
    late DaybreakColors colors;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = DaybreakColors.of(context);
          return Align(
            alignment: Alignment.topCenter,
            child: Material(
              child: BackfillBanner(
                message: message,
                primaryActionLabel: 'Mark them now',
                onPrimaryAction: () {},
                secondaryActionLabel: 'Not now',
                onSecondaryAction: () {},
              ),
            ),
          );
        },
      ),
      surfaceSize: const Size(390, 900),
    );

    expect(tester.widget<Text>(find.text(message)).style!.color, colors.ink);
    expect(
      tester.widget<Text>(find.text(message)).style!.color,
      isNot(colors.warning),
    );
    // The glyph and the border ARE the semantic colour.
    expect(
      tester.widget<Icon>(find.byIcon(BackfillBanner.glyph)).color,
      colors.warning,
    );
    final decoration =
        tester
                .widget<Container>(find.byKey(BackfillBanner.containerKey))
                .decoration!
            as BoxDecoration;
    expect(decoration.color, colors.tintWarning);
    expect(decoration.border!.top.color, colors.warningFill);
  });

  testWidgets('at 200% in de it grows and nothing overflows', (tester) async {
    await pumpBanner(
      tester,
      locale: const Locale('de'),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('the actions are reachable by a screen reader', (tester) async {
    // The failure this rules out: wrapping the whole surface in
    // `ExcludeSemantics` to keep it reading as one sentence also removes its
    // BUTTONS from the semantics tree. The reader hears the message and has
    // no way to act on it — and for the undo row, no way to undo a change to
    // their medication record.
    final handle = tester.ensureSemantics();
    await pumpBanner(tester);

    final spoken = <String>[];
    void collect(SemanticsNode node) {
      if (node.label.isNotEmpty) spoken.add(node.label);
      node.visitChildren((child) {
        collect(child);
        return true;
      });
    }

    collect(tester.getSemantics(find.byType(BackfillBanner)));

    for (final action in <String>['Mark them now', 'Not now']) {
      expect(spoken, contains(action), reason: '$action is not announced');
    }
    handle.dispose();
  });
}
