// Day zero, which has to have a defined shape.
//
// Copy is warm — "Your plan starts here", never "No data" — because the person
// reading it has just been told they will be on steroids for two years, and
// the first thing the app says to them should not be an error message.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/taper_empty_state.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

void main() {
  const message =
      'Add the plan you and your doctor agreed, and this screen '
      'will show what to take each morning.';

  Future<void> pumpState(
    WidgetTester tester, {
    VoidCallback? onAction,
    TextScaler textScaler = TextScaler.noScaling,
  }) => pumpApp(
    tester,
    Material(
      child: TaperEmptyState(
        heading: 'Your plan starts here',
        message: message,
        actionLabel: 'Set up my plan',
        onAction: onAction ?? () {},
      ),
    ),
    textScaler: textScaler,
    surfaceSize: const Size(390, 844),
  );

  testWidgets('exactly ONE primary action', (tester) async {
    // Two primary actions on an empty screen is two decisions asked of someone
    // who has not made the first one yet.
    await pumpState(tester);

    expect(find.byType(PrimaryPillButton), findsOneWidget);
    expect(find.text('Set up my plan'), findsOneWidget);
  });

  testWidgets('the action fires once', (tester) async {
    var taps = 0;
    await pumpState(tester, onAction: () => taps++);

    await tester.tap(find.text('Set up my plan'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('the illustration is SILENT to a screen reader', (tester) async {
    // Asserted on the SEMANTICS tree, not the widget tree: `Icon` builds a
    // `Semantics` widget of its own, so a descendant search for one finds it
    // even under `ExcludeSemantics` — which excludes it from what is
    // ANNOUNCED, not from what is built. The claim is about what a reader
    // hears, so the oracle is every label in the subtree.
    final handle = tester.ensureSemantics();
    await pumpState(tester);

    final spoken = <String>[];
    void collect(SemanticsNode node) {
      if (node.label.isNotEmpty) spoken.add(node.label);
      node.visitChildren((child) {
        collect(child);
        return true;
      });
    }

    collect(tester.getSemantics(find.byType(TaperEmptyState)));

    expect(
      spoken,
      unorderedEquals(<String>[
        'Your plan starts here',
        message,
        'Set up my plan',
      ]),
      reason: 'the decorative illustration announced itself',
    );
    handle.dispose();
  });

  testWidgets('heading and sentence are exactly the strings passed in', (
    tester,
  ) async {
    late DaybreakColors colors;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = DaybreakColors.of(context);
          return const Material(
            child: TaperEmptyState(
              heading: 'Your plan starts here',
              message: 'Add the plan you and your doctor agreed.',
              actionLabel: 'Set up my plan',
              onAction: _noop,
            ),
          );
        },
      ),
      surfaceSize: const Size(390, 844),
    );

    expect(find.text('Your plan starts here'), findsOneWidget);
    expect(
      find.text('Add the plan you and your doctor agreed.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.text('Add the plan you and your doctor agreed.'))
          .style!
          .color,
      colors.inkMuted,
    );
  });

  testWidgets('at 200% it scrolls rather than clipping', (tester) async {
    // The one screen a reader cannot navigate away from to see the rest of the
    // message — there is nothing else on it.
    await pumpState(tester, textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}

void _noop() {}
