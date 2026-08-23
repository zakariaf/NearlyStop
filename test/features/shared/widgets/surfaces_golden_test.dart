@Tags(<String>['golden'])
library;

// Recipes 8-11's sheets — GATES, not drivers.
//
// Tagged `golden` and excluded from the default CI lane for the reason EPIC-02
// set out: authored on macOS, and a gate that goes red for the host gets
// switched off. The claims CI needs are the measured ones in the sibling
// suites.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/progress/presentation/widgets/progress_stat_block.dart';
import 'package:nearlystop/features/shared/presentation/widgets/backfill_banner.dart';
import 'package:nearlystop/features/shared/presentation/widgets/taper_empty_state.dart';
import 'package:nearlystop/features/shared/presentation/widgets/undo_row.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/disclaimer_sheet.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

/// Copy per locale, pre-localized as the widgets want it.
({
  String backfill,
  String markNow,
  String notNow,
  String undo,
  String undoLabel,
  String close,
  String unit,
  String heading,
  String emptyBody,
  String setUp,
})
copyFor(String languageCode) => languageCode == 'fa'
    ? (
        backfill: 'سه روز گذشته را ثبت نکرده‌اید.',
        markNow: 'اکنون ثبت کن',
        notNow: 'حالا نه',
        undo: 'پنجشنبه به عنوان مصرف‌شده ثبت شد.',
        undoLabel: 'واگرد',
        close: 'بستن',
        unit: '۳۴۱ روز از ۳۵۰ روز ثبت شد',
        heading: 'برنامه شما از اینجا شروع می‌شود',
        emptyBody: 'برنامه‌ای را که با پزشکتان توافق کرده‌اید اضافه کنید.',
        setUp: 'برنامه‌ام را تنظیم کن',
      )
    : (
        backfill: "You haven't marked the last 3 days.",
        markNow: 'Mark them now',
        notNow: 'Not now',
        undo: 'Marked Thursday as taken.',
        undoLabel: 'Undo',
        close: 'Close',
        unit: 'taken 341 of 350 days',
        heading: 'Your plan starts here',
        emptyBody: 'Add the plan you and your doctor agreed.',
        setUp: 'Set up my plan',
      );

void main() {
  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'surfaces_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          final copy = copyFor(languageCode);
          await pumpApp(
            tester,
            Builder(
              builder: (context) => Align(
                alignment: Alignment.topCenter,
                child: ColoredBox(
                  color: DaybreakColors.of(context).bg,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        BackfillBanner(
                          message: copy.backfill,
                          primaryActionLabel: copy.markNow,
                          onPrimaryAction: () {},
                          secondaryActionLabel: copy.notNow,
                          onSecondaryAction: () {},
                        ),
                        const SizedBox(height: 16),
                        UndoRow(
                          message: copy.undo,
                          undoLabel: copy.undoLabel,
                          onUndo: () {},
                          dismissLabel: copy.close,
                          onDismiss: () {},
                        ),
                        const SizedBox(height: 16),
                        ProgressStatBlock(
                          value: languageCode == 'fa' ? '۳۴۱' : '341',
                          unit: copy.unit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            locale: Locale(languageCode),
            brightness: brightness,
            textScaler: TextScaler.linear(scale),
            surfaceSize: Size(390, scale == 1 ? 620 : 1500),
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
      final name = 'empty_state_${brightness.name}_$languageCode';
      testWidgets(name, (tester) async {
        final copy = copyFor(languageCode);
        await pumpApp(
          tester,
          Material(
            child: TaperEmptyState(
              heading: copy.heading,
              message: copy.emptyBody,
              actionLabel: copy.setUp,
              onAction: () {},
            ),
          ),
          locale: Locale(languageCode),
          brightness: brightness,
          surfaceSize: const Size(390, 620),
        );

        await expectLater(
          find.byType(TaperEmptyState),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }

  for (final brightness in Brightness.values) {
    final name = 'disclaimer_gate_${brightness.name}';
    testWidgets(name, (tester) async {
      await pumpApp(
        tester,
        Material(
          child: DisclaimerSheet(
            title: 'Welcome to NearlyStop',
            body:
                'NearlyStop arranges the plan you and your doctor agreed. It '
                'does not give medical advice. Always follow the instructions '
                'you were given. Everything it knows stays on this phone: no '
                'account, no internet, nothing sent anywhere.',
            actionLabel: 'I understand',
            isGate: true,
            onAccept: () {},
            onClose: () {},
          ),
        ),
        brightness: brightness,
        surfaceSize: const Size(390, 560),
      );

      await expectLater(
        find.byType(DisclaimerSheet),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }
}
