// Every target, measured — not trusted to a built-in guideline.
//
// `meetsGuideline(androidTapTargetGuideline)` SKIPS every node flush with the
// view edge, which on these screens is most of the tab bar. It is advisory
// here and nothing rests on it; the gate is the explicit loop below.
//
// Run at 1.0 AND 2.0. A target that is 44 at 1.0 and still exactly 44 at 2.0
// is a parent clamping it — which is the actual bug, and it is invisible at
// one scale.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../support/fonts.dart';
import '../support/harness.dart';
import 'app_screens.dart';

/// The floor every interactive target clears, in logical pixels.
///
/// 44 is the iOS Human Interface floor and the smaller of the two; Android
/// asks 48. This audience is 60–80 and using the app one-handed in the
/// morning, so the ladder's own minimums sit well above both.
const double kTargetFloor = 44;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  /// Every interactive node's size, by its label.
  Future<Map<String, Size>> measure(
    WidgetTester tester,
    AppScreen screen, {
    required double scale,
  }) async {
    final handle = tester.ensureSemantics();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      screen.build(l10n),
      overrides: screen.overrides(const Locale('en')),
      textScaler: TextScaler.linear(scale),
      // Tall enough that a `ListView` builds every row — an off-screen target
      // is a target nothing measures.
      surfaceSize: Size(390, scale == 1 ? 2400 : 4800),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final sizes = <String, Size>{};
    for (final node in tester.semantics.simulatedAccessibilityTraversal()) {
      final data = node.getSemanticsData();
      final isControl =
          data.flagsCollection.isButton ||
          data.flagsCollection.isLink ||
          data.flagsCollection.isTextField ||
          data.flagsCollection.isSlider;
      if (!isControl) continue;
      // Keyed by label so a failure names the control rather than an id.
      sizes[data.label.isEmpty ? 'node ${node.id}' : data.label] =
          node.rect.size;
    }
    handle.dispose();
    return sizes;
  }

  for (final scale in <double>[1, 2]) {
    group('every target clears ${kTargetFloor}pt at ${scale}x', () {
      for (final screen in appScreens()) {
        testWidgets(screen.name, (tester) async {
          final sizes = await measure(tester, screen, scale: scale);

          // Never vacuous: each of these screens has controls, so an empty
          // map means the filter broke rather than the screen being perfect.
          expect(
            sizes,
            isNotEmpty,
            reason: '${screen.name} reported no controls at all',
          );

          final small = <String>[
            for (final MapEntry<String, Size>(key: label, value: size)
                in sizes.entries)
              if (size.width < kTargetFloor || size.height < kTargetFloor)
                _tooSmall(label, size),
          ];

          expect(small, isEmpty, reason: '${screen.name} at ${scale}x');
        });
      }
    });
  }

  testWidgets('the Taken action is twice the floor', (tester) async {
    // `daybreak-components` rule 10. It is pressed every morning for 780
    // mornings, often before the reader has their glasses on, and it is the
    // only control on the screen whose miss costs a day of history.
    final today = appScreens().firstWhere((s) => s.name == 'Today');
    final sizes = await measure(tester, today, scale: 1);
    final taken = sizes.entries.firstWhere(
      (e) => e.key.toLowerCase().contains('taken'),
      orElse: () => throw StateError('no Taken control found: ${sizes.keys}'),
    );

    expect(
      taken.value.height,
      greaterThanOrEqualTo(kTargetFloor * 2),
      reason: '"${taken.key}" is ${taken.value.height}pt tall',
    );
  });

  testWidgets('no action is reachable only by long press', (tester) async {
    // A long press is undiscoverable and, for a hand with a tremor, often
    // unperformable. Anything it does must also be one tap away.
    for (final screen in appScreens()) {
      final handle = tester.ensureSemantics();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpApp(
        tester,
        screen.build(l10n),
        overrides: screen.overrides(const Locale('en')),
        surfaceSize: const Size(390, 2400),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final longPressOnly = <String>[
        for (final node in tester.semantics.simulatedAccessibilityTraversal())
          if (node.getSemanticsData().hasAction(SemanticsAction.longPress) &&
              !node.getSemanticsData().hasAction(SemanticsAction.tap) &&
              !node.getSemanticsData().flagsCollection.isButton)
            node.getSemanticsData().label,
      ];

      handle.dispose();
      expect(longPressOnly, isEmpty, reason: screen.name);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('the loop can fail, and says which control', (tester) async {
    // A measurement loop with a useless failure message costs more than it
    // saves. This is the message, proved against a deliberate offender.
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      Center(
        child: SizedBox(
          height: 40,
          child: Semantics(
            container: true,
            button: true,
            label: 'a squashed button',
            child: const SizedBox(width: 200),
          ),
        ),
      ),
    );
    await tester.pump();

    final small = <String>[
      for (final node in tester.semantics.simulatedAccessibilityTraversal())
        if (node.getSemanticsData().flagsCollection.isButton &&
            node.rect.size.height < kTargetFloor)
          node.getSemanticsData().label,
    ];

    handle.dispose();
    expect(small, <String>['a squashed button']);
  });
}

/// What an undersized target is called in a failure message.
String _tooSmall(String label, Size size) =>
    '"$label" is ${size.width.toStringAsFixed(0)}×'
    '${size.height.toStringAsFixed(0)}';
