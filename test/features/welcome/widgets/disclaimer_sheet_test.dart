// The gate, and the same sheet re-read voluntarily.
//
// In gate mode the accept action is disabled until the reader has scrolled to
// the end. That is not a dark pattern in reverse — it is the one screen where
// the app says "this is not medical advice", and a reader who taps past it in
// half a second has not been told.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/disclaimer_sheet.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/sunrise_seal.dart';

import '../../../support/harness.dart';

void main() {
  // Long enough that a 390x500 sheet must scroll to reach the end — which is
  // the whole point of the gate. Repeated rather than written out four times.
  final body =
      'NearlyStop arranges the plan you and your doctor agreed. It does '
          "not give medical advice. Always follow your doctor's instructions. "
          'This app never recommends a dose, never changes one, and never '
          'sends anything anywhere. Everything it knows stays on this phone. '
          'If a dose cannot be made from the tablets you hold, it says so '
          'rather than rounding. Your clinician decides. ' *
      4;

  Future<ScrollController> pumpSheet(
    WidgetTester tester, {
    required bool gate,
    VoidCallback? onAccept,
    VoidCallback? onClose,
    bool accessibleNavigation = false,
    Size surfaceSize = const Size(390, 500),
  }) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(accessibleNavigation: accessibleNavigation),
          child: Material(
            child: DisclaimerSheet(
              title: 'Welcome to NearlyStop',
              body: body,
              actionLabel: gate ? 'I understand' : 'Close',
              isGate: gate,
              controller: controller,
              onAccept: onAccept ?? () {},
              onClose: onClose ?? () {},
            ),
          ),
        ),
      ),
      surfaceSize: surfaceSize,
    );
    await tester.pumpAndSettle();
    return controller;
  }

  /// Whether the accept action can currently be pressed.
  bool acceptEnabled(WidgetTester tester) =>
      tester
          .widget<PrimaryPillButton>(find.byType(PrimaryPillButton))
          .onPressed !=
      null;

  testWidgets('gate: disabled on frame one, and one pixel short of the end', (
    tester,
  ) async {
    // The off-by-one is the case worth pinning: `>= maxScrollExtent` with a
    // fractional extent is the version that enables a pixel early on some
    // screens and never on others.
    var accepted = 0;
    final controller = await pumpSheet(
      tester,
      gate: true,
      onAccept: () => accepted++,
    );

    expect(
      tester
          .widget<PrimaryPillButton>(find.byType(PrimaryPillButton))
          .onPressed,
      isNull,
      reason: 'enabled on frame one',
    );

    controller.jumpTo(controller.position.maxScrollExtent - 1);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PrimaryPillButton>(find.byType(PrimaryPillButton))
          .onPressed,
      isNull,
      reason: 'enabled one pixel short of the end',
    );

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PrimaryPillButton>(find.byType(PrimaryPillButton))
          .onPressed,
      isNotNull,
      reason: 'still disabled at the end',
    );

    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(accepted, 1);
  });

  testWidgets('gate: a body short enough to need no scroll enables at once', (
    tester,
  ) async {
    // Otherwise the gate is unpassable on a tablet, where the whole disclaimer
    // fits — `maxScrollExtent` is zero and "scroll to the end" never happens.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpApp(
      tester,
      Material(
        child: DisclaimerSheet(
          title: 'Welcome',
          body: 'Short.',
          actionLabel: 'I understand',
          isGate: true,
          controller: controller,
          onAccept: () {},
          onClose: () {},
        ),
      ),
      surfaceSize: const Size(390, 844),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<PrimaryPillButton>(find.byType(PrimaryPillButton))
          .onPressed,
      isNotNull,
      reason: 'a disclaimer that fits can never be scrolled to its end',
    );
  });

  testWidgets('gate: a screen reader never emits a scroll, so it is open', (
    tester,
  ) async {
    // Somebody moving through this text by VoiceOver focus produces no scroll
    // notification at all. A gate that waits for one is a first run that
    // cannot be completed — behind a redirect that forces every route here.
    await pumpSheet(tester, gate: true, accessibleNavigation: true);

    expect(acceptEnabled(tester), isTrue);
  });

  testWidgets('gate: a viewport too small to measure does not fail OPEN', (
    tester,
  ) async {
    // The counter-case to the two above. Failing open is right when there is
    // nothing to scroll; it is wrong the moment there is. A guard written as
    // "no dimensions OR nothing scrolled yet → open" reads almost identically
    // and lets somebody past a disclaimer they were never shown.
    await pumpSheet(tester, gate: true, surfaceSize: const Size(390, 40));

    expect(tester.takeException(), isNull);
    expect(acceptEnabled(tester), isFalse);
  });

  testWidgets('gate: the sunrise seal is there, and the re-read has none', (
    tester,
  ) async {
    // The seal is the reference frame's first mark and the app's own promise
    // in one glyph. On the RE-READ it would be ceremony: somebody who opened
    // the disclaimer from Settings is checking a sentence, not being welcomed.
    await pumpSheet(tester, gate: true);
    expect(find.byType(SunriseSeal), findsOneWidget);

    await pumpSheet(tester, gate: false);
    expect(find.byType(SunriseSeal), findsNothing);
  });

  testWidgets('gate: the title and body are centred, the re-read is not', (
    tester,
  ) async {
    await pumpSheet(tester, gate: true);
    expect(
      tester.widget<Text>(find.text('Welcome to NearlyStop')).textAlign,
      TextAlign.center,
    );

    await pumpSheet(tester, gate: false);
    expect(
      tester.widget<Text>(find.text('Welcome to NearlyStop')).textAlign,
      isNot(TextAlign.center),
    );
  });

  testWidgets('gate: it cannot be escaped', (tester) async {
    var accepted = 0;
    var closed = 0;
    await pumpSheet(
      tester,
      gate: true,
      onAccept: () => accepted++,
      onClose: () => closed++,
    );

    // A drag DOWN on the sheet.
    await tester.drag(find.byType(DisclaimerSheet), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(find.byType(DisclaimerSheet), findsOneWidget);
    expect(accepted, 0);
    expect(closed, 0, reason: 'a drag closed the gate');
    expect(
      find.text('Close'),
      findsNothing,
      reason: 'the gate must not offer a way out',
    );
  });

  testWidgets('re-read: the action closes and never accepts', (tester) async {
    var accepted = 0;
    var closed = 0;
    await pumpSheet(
      tester,
      gate: false,
      onAccept: () => accepted++,
      onClose: () => closed++,
    );

    expect(
      tester
          .widget<PrimaryPillButton>(find.byType(PrimaryPillButton))
          .onPressed,
      isNotNull,
      reason: 're-read mode must not gate on scrolling',
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(closed, 1);
    expect(
      accepted,
      0,
      reason: 'reading the disclaimer again re-accepted it',
    );
  });
}
