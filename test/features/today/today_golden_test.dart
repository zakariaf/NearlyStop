@Tags(<String>['golden'])
library;

// Frame 2 — the Today screen — as a GATE, not a driver.
//
// Eight captures: {light, dark} × {en, fa} × {1.0, 2.0}. The 2.0 pair is where
// the declared degradation order is looked at: the arc gone, the amount and
// unit stacked, the numeral untouched.
//
// Tagged `golden` and excluded from the default CI lane for the reason EPIC-02
// set out: authored on macOS, and a gate that goes red for the host is a gate
// somebody switches off.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/today/application/today_view_provider.dart';
import 'package:nearlystop/features/today/presentation/today_screen.dart';
import 'package:nearlystop/features/today/presentation/today_view_state.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';

/// Emits one fixed state, so a golden captures a rendering and not a race.
class _FixedNotifier extends StreamNotifier<TodayViewState>
    implements TodayNotifier {
  _FixedNotifier(this._state);

  final TodayViewState _state;

  @override
  Stream<TodayViewState> build() => Stream<TodayViewState>.value(_state);

  @override
  dynamic noSuchMethod(Invocation invocation) async {}
}

TodayDose doseFor(String languageCode) {
  final fa = languageCode == 'fa';
  return TodayDose(
    dateLine: fa ? 'پنجشنبه ۲۷ فروردین' : 'Thursday 16 April',
    doseAmount: fa ? '۹' : '9',
    doseUnit: fa ? 'میلی‌گرم' : 'mg',
    tablets: fa ? '۱ × ۵ · ۴ × ۱' : '1 × 5mg · 4 × 1mg',
    unachievableMessage: null,
    isNewDoseDay: true,
    taken: false,
    stepIndex: fa ? '۳' : '3',
    stepCount: fa ? '۱۵' : '15',
    fromDose: fa ? '۱۰ میلی‌گرم' : '10mg',
    toDose: fa ? '۹ میلی‌گرم' : '9mg',
    dayInStep: fa ? '۱۴' : '14',
    stepLength: fa ? '۵۲' : '52',
    isSteadyState: false,
    holdingLabel: null,
    backfill: BackfillPrompt(
      oldest: const LocalDate(2026, 4, 12),
      count: 4,
      label: fa
          ? '۴ روز گذشته ثبت نشده است'
          : 'You haven’t marked the last 4 days',
    ),
    noteText: null,
    flare: const FlarePrompt(
      candidates: <FlareCandidate>[],
      defaultRevertTo: Milligrams.fromHundredths(1000),
      suggestedStep: Milligrams.fromHundredths(50),
      stepDiffersFromCommunity: false,
    ),
    hold: const HoldPrompt(
      stepId: 7,
      blockLabel: 'Block 3 of 11',
      defaultExtraDays: 7,
      minExtraDays: 1,
      maxExtraDays: 28,
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'today_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpApp(
            tester,
            const TodayScreen(),
            overrides: <Override>[
              todayViewProvider.overrideWith(
                () => _FixedNotifier(doseFor(languageCode)),
              ),
            ],
            locale: Locale(languageCode),
            brightness: brightness,
            textScaler: TextScaler.linear(scale),
            // The shell's real height, not the device's: this screen never
            // gets 844 with a 96pt tab bar under it.
            surfaceSize: Size(390, scale == 1 ? 720 : 1500),
          );
          await tester.pump();

          await expectLater(
            find.byType(TodayScreen),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
