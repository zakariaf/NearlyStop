@Tags(<String>['golden'])
library;

// Recipes 5, 6 and 7's sheets — GATES, not drivers.
//
// Two of these earn their place beyond the usual matrix: a GREYSCALE sheet, on
// which "which one is selected" has to still be answerable, and the 1.6x
// German reflow, which is the capture the segmented control's whole
// degradation rule exists for.
//
// Tagged `golden` and excluded from the default CI lane for the reason EPIC-02
// set out: authored on macOS, and a gate that goes red for the host gets
// switched off.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/features/plan/presentation/widgets/method_segmented_control.dart';
import 'package:nearlystop/features/plan/presentation/widgets/strength_chip.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tab_bar.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

/// Saturation zero — the same matrix EPIC-02's greyscale gate uses.
const ColorFilter greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// The five destinations, in a given locale.
List<DaybreakDestination> destinationsFor(String languageCode) {
  const labels = <String, List<String>>{
    'en': <String>['Today', 'Schedule', 'Progress', 'Plan', 'Settings'],
    'de': <String>[
      'Heute',
      'Zeitplan',
      'Fortschritt',
      'Behandlungsplan',
      'Einstellungen',
    ],
    'fa': <String>[
      'امروز',
      'برنامه زمانی',
      'پیشرفت',
      'برنامه درمان',
      'تنظیمات',
    ],
  };
  const outlined = <IconData>[
    Icons.wb_sunny_outlined,
    Icons.view_agenda_outlined,
    Icons.trending_down_outlined,
    Icons.medication_outlined,
    Icons.settings_outlined,
  ];
  const filled = <IconData>[
    Icons.wb_sunny,
    Icons.view_agenda,
    Icons.trending_down,
    Icons.medication,
    Icons.settings,
  ];
  final words = labels[languageCode] ?? labels['en']!;
  return <DaybreakDestination>[
    for (var i = 0; i < words.length; i++)
      DaybreakDestination(
        label: words[i],
        icon: outlined[i],
        selectedIcon: filled[i],
      ),
  ];
}

/// Method labels per locale, pre-localized as the widget wants them.
Map<TaperMethod, String> methodLabels(String languageCode) =>
    switch (languageCode) {
      'de' => const <TaperMethod, String>{
        TaperMethod.dsns: 'Dead Slow and Nearly Stop',
        TaperMethod.percentage: 'Prozentual',
        TaperMethod.fixedMg: 'Feste mg',
      },
      'fa' => const <TaperMethod, String>{
        TaperMethod.dsns: 'بسیار آهسته و تقریباً توقف',
        TaperMethod.percentage: 'درصدی',
        TaperMethod.fixedMg: 'میلی‌گرم ثابت',
      },
      _ => const <TaperMethod, String>{
        TaperMethod.dsns: 'Dead Slow and Nearly Stop',
        TaperMethod.percentage: 'Percentage',
        TaperMethod.fixedMg: 'Fixed mg',
      },
    };

/// All three selection components on one sheet.
Widget sheet(BuildContext context, String languageCode) {
  final fa = languageCode == 'fa';
  final colors = DaybreakColors.of(context);
  return Align(
    alignment: Alignment.topCenter,
    child: ColoredBox(
      color: colors.bg,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StrengthChipGroup(
              chips: <({String label, String value})>[
                for (final mg in <String>['0.5', '1', '2.5', '5', '10', '20'])
                  (label: fa ? '$mg میلی‌گرم' : '${mg}mg', value: mg),
              ],
              selected: const <String>{'1', '5'},
              onSelected: (_) {},
            ),
            const SizedBox(height: 20),
            MethodSegmentedControl(
              value: TaperMethod.dsns,
              labels: methodLabels(languageCode),
              onChanged: (_) {},
            ),
            const SizedBox(height: 20),
            DaybreakTabBar(
              destinations: destinationsFor(languageCode),
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'selection_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpApp(
            tester,
            Builder(builder: (context) => sheet(context, languageCode)),
            locale: Locale(languageCode),
            brightness: brightness,
            textScaler: TextScaler.linear(scale),
            surfaceSize: Size(390, scale == 1 ? 600 : 1500),
          );

          await expectLater(
            find.byType(ColoredBox).first,
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }

  testWidgets('selection_greyscale', (tester) async {
    // The sheet the "which one is selected" claim is judged against. Colour
    // removed, the check glyph, the ring, the raised tile, the filled icon and
    // the weight are all that is left — which is the design.
    await pumpApp(
      tester,
      ColorFiltered(
        colorFilter: greyscale,
        child: Builder(builder: (context) => sheet(context, 'en')),
      ),
      surfaceSize: const Size(390, 600),
    );

    await expectLater(
      find.byType(ColorFiltered),
      matchesGoldenFile('goldens/selection_greyscale.png'),
    );
  });

  testWidgets('method_reflow_de_1.6x', (tester) async {
    // The capture the segmented control's degradation rule exists for: three
    // German method names at 1.6x, stacked rather than squeezed into equal
    // columns of one letter each.
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Align(
          alignment: Alignment.topCenter,
          child: ColoredBox(
            color: DaybreakColors.of(context).bg,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: MethodSegmentedControl(
                value: TaperMethod.percentage,
                labels: methodLabels('de'),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
      locale: const Locale('de'),
      textScaler: const TextScaler.linear(1.6),
      surfaceSize: const Size(390, 700),
    );

    await expectLater(
      find.byType(ColoredBox).first,
      matchesGoldenFile('goldens/method_reflow_de_1.6x.png'),
    );
  });
}
