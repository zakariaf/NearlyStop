@Tags(<String>['golden'])
library;

// Recipe 3's golden sheet — a GATE, not a driver.
//
// Tagged `golden` and excluded from the default CI lane for the reason
// EPIC-02 set out: authored on macOS, text rasterises differently on a Linux
// runner, and a gate that goes red for the host gets switched off. The claims
// CI needs are the measured ones in `block_header_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

/// The three states a block can be in, stacked.
Widget sheet(BuildContext context, String languageCode) {
  final fa = languageCode == 'fa';
  final colors = DaybreakColors.of(context);
  return Align(
    alignment: Alignment.topCenter,
    child: ColoredBox(
      color: colors.bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (title, summary, current, completed)
              in <(String, String, bool, bool)>[
                if (fa) ...<(String, String, bool, bool)>[
                  (
                    'بلوک ۲ از ۱۱',
                    'یک روز ۹ میلی‌گرم، سپس ۵ روز ۱۰ میلی‌گرم',
                    false,
                    true,
                  ),
                  (
                    'بلوک ۳ از ۱۱',
                    'یک روز ۹ میلی‌گرم، سپس ۴ روز ۱۰ میلی‌گرم',
                    true,
                    false,
                  ),
                  (
                    'بلوک ۴ از ۱۱',
                    'دو روز ۹ میلی‌گرم، سپس ۳ روز ۱۰ میلی‌گرم',
                    false,
                    false,
                  ),
                ] else ...<(String, String, bool, bool)>[
                  (
                    'Block 2 of 11',
                    'one day at 9mg, then 5 days at 10mg',
                    false,
                    true,
                  ),
                  (
                    'Block 3 of 11',
                    'one day at 9mg, then 4 days at 10mg',
                    true,
                    false,
                  ),
                  (
                    'Block 4 of 11',
                    'two days at 9mg, then 3 days at 10mg',
                    false,
                    false,
                  ),
                ],
              ])
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
              child: BlockHeader(
                title: title,
                doseSummary: summary,
                semanticsLabel: '$title — $summary',
                isCurrent: current,
                isCompleted: completed,
                completedLabel: fa ? 'تکمیل شد' : 'Completed',
              ),
            ),
        ],
      ),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'block_header_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpApp(
            tester,
            Builder(builder: (context) => sheet(context, languageCode)),
            locale: Locale(languageCode),
            brightness: brightness,
            textScaler: TextScaler.linear(scale),
            surfaceSize: Size(390, scale == 1 ? 500 : 1400),
          );

          await expectLater(
            find.byType(ColoredBox).first,
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
