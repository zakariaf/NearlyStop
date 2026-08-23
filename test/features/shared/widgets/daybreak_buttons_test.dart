// The five buttons, and the rule that a destructive one cannot act alone.
//
// The Taken button is pressed one-handed by a 74-year-old with a tremor, half
// awake, 780 times. That is why it is 88 tall, why a long press must still
// count as a press, and why the press confirmation is a haptic AND a scale
// rather than either alone.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';

import '../../../support/harness.dart';

void main() {
  const confirmRequest = ConfirmRequest(
    title: 'Delete this plan?',
    body: 'Your history and your total are kept.',
    confirmLabel: 'Delete plan',
    cancelLabel: 'Cancel',
  );

  /// Every variant, built with the same label and callback.
  ///
  /// A table rather than eight separate tests: a variant added without being
  /// added here is a variant with no min-height, no tap-target and no
  /// no-uppercase assertion, which is exactly how one ships 40pt tall.
  List<(String, Widget Function(VoidCallback?))> ladder(
    String label,
  ) => <(String, Widget Function(VoidCallback?))>[
    (
      'primary',
      (onPressed) => PrimaryPillButton(label: label, onPressed: onPressed),
    ),
    (
      'secondary',
      (onPressed) => SecondaryButton(label: label, onPressed: onPressed),
    ),
    (
      'tertiary',
      (onPressed) => TertiaryButton(label: label, onPressed: onPressed),
    ),
    (
      'destructive',
      (onPressed) => DestructiveButton(
        label: label,
        confirm: confirmRequest,
        onConfirmed: onPressed,
      ),
    ),
    ('taken', (onPressed) => TakenButton(label: label, onPressed: onPressed)),
  ];

  Future<void> pumpButton(
    WidgetTester tester,
    Widget button, {
    TextScaler textScaler = TextScaler.noScaling,
    bool disableAnimations = false,
  }) => pumpApp(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: Center(child: Material(child: button)),
      ),
    ),
    textScaler: textScaler,
    surfaceSize: const Size(390, 844),
  );

  testWidgets('one tap fires once; a LONG press still fires once', (
    tester,
  ) async {
    // Not "a long press fires zero times". A tremor turns an intended tap into
    // a 600ms press, and a button that ignored it would drop the one
    // interaction this app has. What must not exist is a long-press-ONLY path
    // — an action reachable no other way — and the tap case above is what
    // proves it is reachable normally.
    for (final (name, build) in ladder('Mark as taken')) {
      var taps = 0;
      await pumpButton(tester, build(() => taps++));
      await tester.tap(find.text('Mark as taken'));
      await tester.pumpAndSettle();
      if (name == 'destructive') {
        await tester.tap(find.text('Delete plan'));
        await tester.pumpAndSettle();
      }
      expect(taps, 1, reason: '$name: one tap');

      await tester.longPress(find.text('Mark as taken'));
      await tester.pumpAndSettle();
      if (name == 'destructive') {
        await tester.tap(find.text('Delete plan'));
        await tester.pumpAndSettle();
      }
      expect(taps, 2, reason: '$name: a slow press is still a press');
    }
  });

  testWidgets('disabled: nothing fires, the FILL changes, and it SAYS so', (
    tester,
  ) async {
    // Opacity alone fails this, which is the point: a dimmed button is
    // invisible to a screen reader and ambiguous to anyone with low contrast
    // vision.
    final handle = tester.ensureSemantics();
    for (final (name, build) in ladder('Do the thing')) {
      var taps = 0;
      await pumpButton(tester, build(() => taps++));
      final enabledLabel = tester
          .getSemantics(find.byType(DaybreakButtonSkin))
          .label;
      final enabledFill = fillOf(tester);

      await pumpButton(tester, build(null));
      await tester.tap(find.text('Do the thing'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(taps, 0, reason: name);
      expect(fillOf(tester), isNot(enabledFill), reason: '$name: fill');
      final disabledLabel = tester
          .getSemantics(find.byType(DaybreakButtonSkin))
          .label;
      expect(disabledLabel, isNot(enabledLabel), reason: '$name: label');
      expect(
        disabledLabel,
        contains('Unavailable'),
        reason: '$name: the state has to be said in words',
      );
    }
    handle.dispose();
  });

  testWidgets('min heights at 1.0, and every one GROWS at 2.0', (tester) async {
    const floors = <String, double>{
      'primary': 56,
      'secondary': 56,
      'tertiary': 48,
      'destructive': 56,
      'taken': 88,
    };
    for (final (name, build) in ladder('Taken')) {
      await pumpButton(tester, build(() {}));
      final small = tester.getSize(find.byType(DaybreakButtonSkin)).height;
      expect(small, greaterThanOrEqualTo(floors[name]!), reason: name);
      expect(
        small,
        greaterThanOrEqualTo(tester.getSize(find.text('Taken')).height),
        reason: '$name clipped its own label at 1.0',
      );

      await pumpButton(
        tester,
        build(() {}),
        textScaler: const TextScaler.linear(2),
      );
      final large = tester.getSize(find.byType(DaybreakButtonSkin)).height;

      expect(
        large,
        greaterThanOrEqualTo(small),
        reason: '$name SHRANK when the reader asked for larger text',
      );
      expect(
        large,
        greaterThanOrEqualTo(tester.getSize(find.text('Taken')).height),
        reason: '$name clipped its own label at 2.0',
      );
      if (name == 'taken') {
        // The one that does not have to grow. 88 is a MOTOR floor — a tremor
        // needs a large target whatever size the text is — and doubled
        // `titleLarge` plus its padding still fits inside it. Not shrinking
        // and not clipping are asserted above; demanding that it also grow
        // would be demanding that the floor be too low.
        continue;
      }
      expect(
        large,
        greaterThan(small),
        reason: '$name did not grow with its text',
      );
    }
  });

  testWidgets('every variant reads its tokens from the resolved slots', (
    tester,
  ) async {
    late DaybreakColors colors;
    late DaybreakElevation elevation;
    Future<DaybreakButtonSkin> skinOf(
      Widget Function(VoidCallback?) build,
    ) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            colors = DaybreakColors.of(context);
            elevation = DaybreakElevation.of(context);
            return Center(child: Material(child: build(() {})));
          },
        ),
        surfaceSize: const Size(390, 844),
      );
      return tester.widget<DaybreakButtonSkin>(find.byType(DaybreakButtonSkin));
    }

    final builders = <String, Widget Function(VoidCallback?)>{
      for (final (name, build) in ladder('x')) name: build,
    };

    final taken = await skinOf(builders['taken']!);
    expect(taken.fill, colors.surface);
    expect(taken.ink, colors.ink);
    expect(taken.shadow, elevation.level2);
    // `glow` stays reserved for the hero card BENEATH this button; two glowing
    // surfaces stacked is the one place the gradient stops reading as light.
    expect(taken.shadow, isNot(elevation.glow));

    final secondary = await skinOf(builders['secondary']!);
    expect(secondary.fill, colors.surface);
    expect(secondary.ink, colors.ink);
    expect(secondary.borderColor, colors.borderStrong);
    expect(secondary.borderWidth, 2);

    final destructive = await skinOf(builders['destructive']!);
    expect(destructive.fill, colors.tintDanger);
    expect(destructive.ink, colors.danger);
    expect(destructive.borderColor, colors.dangerFill);

    final primary = await skinOf(builders['primary']!);
    expect(primary.gradient, colors.sunrise);
    expect(primary.ink, colors.onPrimary);

    final tertiary = await skinOf(builders['tertiary']!);
    expect(tertiary.fill, isNull);
    expect(tertiary.ink, colors.primaryDeep);
  });

  testWidgets('press = scale AND haptic, and the haptic survives no-motion', (
    tester,
  ) async {
    // Both halves, separately. A haptic wired to the animation's completion
    // never fires when the duration is zero — which is precisely the user who
    // most needs a non-visual confirmation.
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String? ?? 'unknown');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    // Measured on the CONTAINER, which is inside the `Transform`. The skin's
    // own box wraps the `Semantics` node, which sits OUTSIDE it, so a rect read
    // there is identical pressed or not — and `Transform.scale` builds its
    // matrix in the render object, so reading `Transform.transform` off the
    // widget returns the identity and would pass with no scaling at all.
    final body = find.descendant(
      of: find.byType(DaybreakButtonSkin),
      matching: find.byType(Container),
    );
    await pumpButton(tester, PrimaryPillButton(label: 'Go', onPressed: () {}));
    final resting = tester.getRect(body);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Go')),
    );
    // TWO pumps. The first applies the `setState` from the pointer-down and
    // STARTS the implicit animation; a single `pump(fast)` would advance the
    // clock and then start the controller, leaving it at zero elapsed and the
    // scale at 1.0 — a green test that proves the press does nothing.
    await tester.pump();
    await tester.pump(daybreakMotion.fast);

    expect(
      tester.getRect(body).width / resting.width,
      closeTo(0.98, 0.005),
      reason: 'the button did not shrink under the finger',
    );
    expect(haptics, isNotEmpty, reason: 'no haptic on press');
    await gesture.up();
    await tester.pumpAndSettle();

    haptics.clear();
    await pumpButton(
      tester,
      PrimaryPillButton(label: 'Go', onPressed: () {}),
      disableAnimations: true,
    );
    final second = await tester.startGesture(
      tester.getCenter(find.text('Go')),
    );
    await tester.pump();

    expect(
      haptics,
      isNotEmpty,
      reason:
          'reduced motion collapsed the scale AND lost the haptic — the '
          'reader who turned animations off now has no confirmation at all',
    );
    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a tap on the padding inside the box counts', (tester) async {
    // `HitTestBehavior.opaque`: the min-height box is mostly empty space above
    // and below a short label, and that space is the target for someone who
    // cannot aim.
    for (final (name, build) in ladder('Hit me')) {
      var taps = 0;
      await pumpButton(tester, build(() => taps++));
      final box = tester.getRect(find.byType(DaybreakButtonSkin));

      await tester.tapAt(Offset(box.center.dx, box.top + 4));
      await tester.pumpAndSettle();
      if (name == 'destructive') {
        await tester.tap(find.text('Delete plan'));
        await tester.pumpAndSettle();
      }

      expect(taps, 1, reason: '$name: the top edge of the box is the button');
    }
  });

  testWidgets('labels are never uppercased, in either script', (tester) async {
    for (final label in <String>['Mark as taken', 'ثبت مصرف امروز']) {
      for (final (name, build) in ladder(label)) {
        await pumpButton(tester, build(() {}));

        expect(find.text(label), findsOneWidget, reason: '$name: $label');
      }
    }
  });

  testWidgets('destructive NEVER acts directly', (tester) async {
    // The rule made structural: `DestructiveButton` cannot be constructed
    // without a `ConfirmRequest`, and the callback is behind the sheet.
    var deleted = 0;
    await pumpButton(
      tester,
      DestructiveButton(
        label: 'Delete plan',
        confirm: confirmRequest,
        onConfirmed: () => deleted++,
      ),
    );

    await tester.tap(find.text('Delete plan').first);
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmSheet), findsOneWidget);
    expect(deleted, 0, reason: 'it acted before the sheet was answered');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, 0, reason: 'cancel deleted the plan');

    await tester.tap(find.text('Delete plan').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DestructiveButton, 'Delete plan').last,
    );
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets(
    'every variant meets both tap-target guidelines, at both scales',
    (
      tester,
    ) async {
      for (final scale in <double>[1, 2]) {
        for (final (name, build) in ladder('Tap')) {
          final handle = tester.ensureSemantics();
          await pumpButton(
            tester,
            build(() {}),
            textScaler: TextScaler.linear(scale),
          );

          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
            reason: '$name at $scale',
          );
          await expectLater(
            tester,
            meetsGuideline(iOSTapTargetGuideline),
            reason: '$name at $scale',
          );
          handle.dispose();
        }
      }
    },
  );
}

/// The fill actually PAINTED by the single button in the tree.
///
/// Off the decoration, not off `DaybreakButtonSkin.fill`: that field is the
/// constructor argument, so a skin that ignored it entirely would satisfy a
/// test that read it back.
Color? fillOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(DaybreakButtonSkin),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration! as BoxDecoration).color;
}
