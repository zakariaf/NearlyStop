@Tags(<String>['golden'])
library;

// Recipe 1's golden sheet — a GATE, not a driver.
//
// The 2.0 captures are the ones that carry weight: the epic's acceptance says
// a 200% golden must show the arc GONE, the layout as a column, and the
// numeral at full size with no overflow. That is a claim about a rendering,
// and this is where it is looked at.
//
// Tagged `golden` and excluded from the default CI lane for the reason EPIC-02
// set out: authored on macOS, and a gate that goes red for the host gets
// switched off.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/today/presentation/widgets/dose_hero_card.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

/// The card's copy per locale, pre-formatted exactly as the notifier hands it
/// over.
DoseHeroCard cardFor(String languageCode, {required bool isTaken}) =>
    languageCode == 'fa'
    ? DoseHeroCard(
        doseText: '۹',
        unitText: 'میلی‌گرم',
        tabletsText: '۱ × ۵ میلی‌گرم · ۴ × ۱ میلی‌گرم',
        dateText: 'پنجشنبه ۲۷ فروردین',
        dayKindLabel: 'روز دوز جدید',
        semanticsLabel: 'امروز، ۹ میلی‌گرم.',
        takenLabel: 'ثبت مصرف امروز',
        isTaken: isTaken,
        onTaken: () {},
      )
    : DoseHeroCard(
        doseText: '9',
        unitText: 'mg',
        tabletsText: '1 × 5mg · 4 × 1mg',
        dateText: 'Thursday 16 April',
        dayKindLabel: 'New dose day',
        semanticsLabel: 'Today, 9 milligrams.',
        takenLabel: 'Mark as taken',
        isTaken: isTaken,
        onTaken: () {},
      );

void main() {
  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'dose_hero_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpApp(
            tester,
            Builder(
              builder: (context) => Align(
                alignment: Alignment.topCenter,
                child: ColoredBox(
                  color: DaybreakColors.of(context).bg,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(16),
                    child: cardFor(languageCode, isTaken: false),
                  ),
                ),
              ),
            ),
            locale: Locale(languageCode),
            brightness: brightness,
            textScaler: TextScaler.linear(scale),
            surfaceSize: Size(390, scale == 1 ? 480 : 900),
          );

          await expectLater(
            find.byType(ColoredBox).first,
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }

  testWidgets('dose_hero_light_en_taken', (tester) async {
    // The other state the reader spends most of the day looking at.
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Align(
          alignment: Alignment.topCenter,
          child: ColoredBox(
            color: DaybreakColors.of(context).bg,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: cardFor('en', isTaken: true),
            ),
          ),
        ),
      ),
      surfaceSize: const Size(390, 480),
    );

    await expectLater(
      find.byType(ColoredBox).first,
      matchesGoldenFile('goldens/dose_hero_light_en_taken.png'),
    );
  });
}
