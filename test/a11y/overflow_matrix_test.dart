// The whole app, at the largest text this audience actually sets.
//
// Every previous epic ran an overflow matrix over its OWN widgets. Nothing had
// been checked across all six surfaces at once, in the combinations no single
// epic owned: largest scale × smallest device × German string length × Sorani
// script × bold. This is that.
//
// **`loadAppFonts` is mandatory.** Under Ahem every glyph is the same box and
// the bold axis is inert, so a matrix without it is a matrix that cannot see
// the failure mode it exists for.
//
// **The loop goes AROUND `testWidgets`, never inside.** Flutter reports an
// overflow once per `RenderObject`; a loop inside one test silently
// under-reports every tuple after the first.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_row.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_hero_card.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/composed_text_scaler.dart';

import '../support/fonts.dart';
import '../support/harness.dart';
import 'app_screens.dart';

/// One surface the app has to survive, named for what it is.
enum Device {
  /// The smallest phone the app supports. Every layout failure appears here
  /// first.
  compact320(Size(320, 640)),

  /// An iPhone SE / small Android.
  small360(Size(360, 740)),

  /// A modern mid-size phone.
  medium412(Size(412, 892));

  const Device(this.size);

  /// The logical surface.
  final Size size;
}

/// The three labels that must land inside the thing that draws them.
///
/// **A clipped `Text` reports no overflow.** `RenderParagraph` paints as much
/// as it can and stops; the exception check above sees nothing. So the three
/// strings this app cannot afford to truncate — the dose numeral, the block
/// name, the day label — are measured against their own container.
void _expectNothingClipped(WidgetTester tester, String label) {
  const pairs = <({Key child, Key parent, String what})>[
    (
      child: DoseHeroCard.numeralKey,
      parent: DoseHeroCard.cardKey,
      what: 'the dose numeral',
    ),
    (
      child: BlockHeader.titleKey,
      parent: BlockHeader.containerKey,
      what: 'the block title',
    ),
    (
      child: DayStateRow.dayLabelKey,
      parent: DayStateRow.containerKey,
      what: 'the day label',
    ),
  ];

  for (final pair in pairs) {
    final child = find.byKey(pair.child);
    final parent = find.byKey(pair.parent);
    // Absent is fine — each pair lives on one screen. Present-but-clipped is
    // not, which is what the rects below say.
    if (child.evaluate().isEmpty || parent.evaluate().isEmpty) continue;

    final inner = tester.getRect(child.first);
    final outer = tester.getRect(parent.first);
    // Half a logical pixel, for the rounding a scaled layout does. Anything
    // larger is a character the reader cannot see.
    const slack = 0.5;
    expect(
      inner.left >= outer.left - slack &&
          inner.right <= outer.right + slack &&
          inner.top >= outer.top - slack &&
          inner.bottom <= outer.bottom + slack,
      isTrue,
      reason: '$label — ${pair.what} $inner is clipped by $outer',
    );
  }
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  /// One cell: pump, then assert nothing overflowed and nothing clipped.
  Future<void> cell(
    WidgetTester tester, {
    required AppScreen screen,
    required Device device,
    required Locale locale,
    required double scale,
    required bool bold,
    required String label,
  }) async {
    final l10n = await AppLocalizations.delegate.load(locale);
    await pumpApp(
      tester,
      screen.build(l10n),
      overrides: screen.overrides(locale),
      locale: locale,
      textScaler: TextScaler.linear(scale),
      boldText: bold,
      surfaceSize: device.size,
    );
    // One pump, not `pumpAndSettle`: several of these screens carry a
    // progress indicator or a stream, and settling one waits forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: label);
    _expectNothingClipped(tester, label);
  }

  group('en — every device, every scale, both weights', () {
    for (final screen in appScreens()) {
      for (final device in Device.values) {
        for (final scale in <double>[1, 1.3, 1.5, 2, 3]) {
          for (final bold in <bool>[false, true]) {
            final label =
                '${screen.name} — ${device.name} en at ${scale}x'
                '${bold ? ' bold' : ''}';
            testWidgets(label, (tester) async {
              await cell(
                tester,
                screen: screen,
                device: device,
                locale: const Locale('en'),
                scale: scale,
                bold: bold,
                label: label,
              );
            });
          }
        }
      }
    }
  });

  group('de — the longest-string locale, where a row breaks first', () {
    for (final screen in appScreens()) {
      for (final scale in <double>[1, 2]) {
        final label = '${screen.name} — compact320 de at ${scale}x bold';
        testWidgets(label, (tester) async {
          await cell(
            tester,
            screen: screen,
            device: Device.compact320,
            locale: const Locale('de'),
            scale: scale,
            bold: true,
            label: label,
          );
        });
      }
    }
  });

  group('fa and ckb — script height and joining, not length', () {
    for (final screen in appScreens()) {
      for (final locale in <Locale>[const Locale('fa'), kurdishSorani]) {
        for (final scale in <double>[1, 2]) {
          final label =
              '${screen.name} — compact320 ${locale.languageCode} at ${scale}x';
          testWidgets(label, (tester) async {
            await cell(
              tester,
              screen: screen,
              device: Device.compact320,
              locale: locale,
              scale: scale,
              bold: false,
              label: label,
            );
          });
        }
      }
    }
  });

  group('the composed ceiling — OS max times the app slider', () {
    // `UserTextScaler` MULTIPLIES the OS scaler, and the audience that maxes
    // the OS setting is exactly the audience that then reaches for the in-app
    // slider. So the field worst case is the product, not the OS value — read
    // from the constant that declares it, never a literal.
    for (final screen in appScreens()) {
      for (final locale in <Locale>[const Locale('en'), const Locale('de')]) {
        final label =
            '${screen.name} — compact320 ${locale.languageCode} at the '
            'composed ceiling bold';
        testWidgets(label, (tester) async {
          await cell(
            tester,
            screen: screen,
            device: Device.compact320,
            locale: locale,
            scale: kMaxComposedTextScale,
            bold: true,
            label: label,
          );
        });
      }
    }
  });

  group('the matrix can fail — proved, not asserted', () {
    // 229 green cells are worth exactly as much as the assertions behind them
    // can fail. Both halves are demonstrated here against a deliberate
    // offender, so the proof stands in the suite rather than in a commit
    // message about a plant somebody once ran.
    testWidgets('a row wider than the device reports an overflow', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Row(children: <Widget>[SizedBox(width: 480, height: 8)]),
        surfaceSize: Device.compact320.size,
      );
      await tester.pump();

      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('a label pushed outside its container reports a clip', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const _ClippedNumeral(),
        surfaceSize: Device.medium412.size,
      );
      await tester.pump();

      expect(
        () => _expectNothingClipped(tester, 'canary'),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  testWidgets('the three fit targets are actually on screen', (tester) async {
    // Without this the fit loop is silently vacuous: a key that matches
    // nothing is skipped, and 229 cells report green about a measurement
    // nobody took.
    for (final name in <String>['Today', 'Schedule']) {
      final screen = appScreens().firstWhere((s) => s.name == name);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpApp(
        tester,
        screen.build(l10n),
        overrides: screen.overrides(const Locale('en')),
        surfaceSize: Device.medium412.size,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      if (name == 'Today') {
        expect(find.byKey(DoseHeroCard.numeralKey), findsOneWidget);
        expect(find.byKey(DoseHeroCard.cardKey), findsOneWidget);
      } else {
        expect(find.byKey(BlockHeader.titleKey), findsWidgets);
        expect(find.byKey(BlockHeader.containerKey), findsWidgets);
        expect(find.byKey(DayStateRow.dayLabelKey), findsWidgets);
        expect(find.byKey(DayStateRow.containerKey), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('every cell reads the shared seeded fixture', () {
    // A matrix shot against a different plan than the parity captures is not
    // comparable to them. Asserted on the source rather than trusted.
    final source = File('test/a11y/app_screens.dart').readAsStringSync();

    expect(source, contains("import '../fixtures/seeded_plan.dart'"));
    expect(
      source,
      isNot(contains('taper_fixture.dart')),
      reason: 'a second fixture reached the whole-app sweep',
    );
  });
}

/// A dose numeral deliberately painted outside its card.
///
/// The offender the clip canary measures. Its geometry is the failure the fit
/// assertion exists for: no overflow is reported, and the reader sees half a
/// number.
class _ClippedNumeral extends StatelessWidget {
  const _ClippedNumeral();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      key: DoseHeroCard.cardKey,
      width: 80,
      height: 40,
      child: OverflowBox(
        maxWidth: 400,
        child: Text('10', key: DoseHeroCard.numeralKey),
      ),
    ),
  );
}
