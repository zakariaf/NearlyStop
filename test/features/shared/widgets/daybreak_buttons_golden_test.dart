@Tags(<String>['golden'])
library;

// Recipe 4's ladder sheet and recipe 12's confirm sheet — GATES, not drivers.
//
// Tagged `golden` and excluded from the default CI lane for the reason EPIC-02
// set out: authored on macOS, and a gate that goes red for the host is a gate
// somebody switches off. The claims CI needs are the measured ones in the
// sibling suites.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

/// The five variants, enabled and disabled, in one column.
///
/// Both states on one sheet on purpose: "disabled changes the fill, never
/// opacity alone" is a claim about the DIFFERENCE between two renderings, and
/// a sheet showing only one of them cannot show it.
Widget ladderSheet(BuildContext context, String languageCode) {
  final fa = languageCode == 'fa';
  final label = fa ? 'ثبت مصرف امروز' : 'Mark as taken';
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
            for (final enabled in <bool>[true, false]) ...<Widget>[
              PrimaryPillButton(
                label: label,
                expand: true,
                onPressed: enabled ? () {} : null,
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                label: label,
                expand: true,
                onPressed: enabled ? () {} : null,
              ),
              const SizedBox(height: 8),
              TertiaryButton(label: label, onPressed: enabled ? () {} : null),
              const SizedBox(height: 8),
              DestructiveButton(
                label: fa ? 'حذف برنامه' : 'Delete plan',
                expand: true,
                confirm: ConfirmRequest(
                  title: fa ? 'برنامه حذف شود؟' : 'Delete this plan?',
                  body: fa
                      ? 'تاریخچه شما نگه داشته می‌شود.'
                      : 'Your history and your total are kept.',
                  confirmLabel: fa ? 'حذف برنامه' : 'Delete plan',
                  cancelLabel: fa ? 'انصراف' : 'Cancel',
                ),
                onConfirmed: enabled ? () {} : null,
              ),
              const SizedBox(height: 8),
              TakenButton(label: label, onPressed: enabled ? () {} : null),
              const SizedBox(height: 24),
            ],
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
            'buttons_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpApp(
            tester,
            Builder(builder: (context) => ladderSheet(context, languageCode)),
            locale: Locale(languageCode),
            brightness: brightness,
            textScaler: TextScaler.linear(scale),
            surfaceSize: Size(390, scale == 1 ? 820 : 1500),
          );

          await expectLater(
            find.byType(ColoredBox).first,
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }

  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      final name = 'confirm_sheet_${brightness.name}_$languageCode';
      testWidgets(name, (tester) async {
        final fa = languageCode == 'fa';
        await pumpApp(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: ConfirmSheet(
              request: ConfirmRequest(
                title: fa ? 'برنامه حذف شود؟' : 'Delete this plan?',
                body: fa
                    ? 'تاریخچه و مجموع شما نگه داشته می‌شود.'
                    : 'Your history and your total are kept.',
                confirmLabel: fa ? 'حذف برنامه' : 'Delete plan',
                cancelLabel: fa ? 'انصراف' : 'Cancel',
                preActionLabel: fa ? 'ابتدا خروجی بگیرید' : 'Export first',
                onPreAction: () async {},
              ),
            ),
          ),
          locale: Locale(languageCode),
          brightness: brightness,
          surfaceSize: const Size(390, 500),
        );

        await expectLater(
          find.byType(ConfirmSheet),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}
