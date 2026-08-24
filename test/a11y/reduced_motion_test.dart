// Reduced motion, across the whole app rather than one duration helper.
//
// `test/theme/motion_test.dart` proves `resolveMotion` returns zero. What it
// cannot prove is the property the setting actually promises: that with
// animations off, the app comes to REST — no scheduled frame, no pending
// timer, nothing moving in the corner of the eye of somebody who turned the
// setting on because movement makes them ill.
//
// **Never `pumpAndSettle` here.** It hangs on an indefinite indicator, and
// hanging is a worse answer than failing.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';

import '../support/fonts.dart';
import '../support/harness.dart';
import 'app_screens.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  group('with animations off, every screen comes to REST', () {
    for (final screen in appScreens()) {
      testWidgets(screen.name, (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await pumpApp(
          tester,
          screen.build(l10n),
          overrides: screen.overrides(const Locale('en')),
          disableAnimations: true,
          surfaceSize: const Size(390, 2400),
        );
        // Two pumps and one long one: the first builds, the second delivers
        // the stream's value, the third would run any animation that survived
        // the collapse.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(seconds: 2));

        expect(
          SchedulerBinding.instance.hasScheduledFrame,
          isFalse,
          reason: '${screen.name} is still animating with motion disabled',
        );
      });
    }
  });

  testWidgets('every declared duration collapses, and only when asked', (
    tester,
  ) async {
    // Both directions in one test on purpose: a reduced-motion assertion that
    // never checks the enabled path passes trivially on a feature nobody
    // built.
    late DaybreakMotion motion;
    late Duration collapsed;
    late Duration full;

    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          motion = DaybreakMotion.of(context);
          collapsed = resolveMotion(context, motion.base);
          return const SizedBox.shrink();
        },
      ),
      disableAnimations: true,
    );
    await tester.pump();

    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          full = resolveMotion(context, DaybreakMotion.of(context).base);
          return const SizedBox.shrink();
        },
      ),
    );
    await tester.pump();

    expect(collapsed, Duration.zero);
    expect(full, motion.base);
    expect(
      full,
      greaterThan(Duration.zero),
      reason: 'the declared duration is itself zero, so nothing was proved',
    );
  });

  test('nothing in lib/ animates forever', () {
    // `motion-and-haptics` rule 11. An ambient animation with no stop
    // condition keeps the raster thread awake for as long as the screen is
    // up, and it is the one kind of motion a reduced-motion setting cannot
    // help with because nothing asked for it.
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'\.repeat\(').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
