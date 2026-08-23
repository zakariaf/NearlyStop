@Tags(<String>['golden'])
library;

// Frame 1 — the disclaimer gate — as a GATE, not a driver.
//
// Eight captures: {light, dark} × {en, fa} × {1.0, 2.0}. This is the first
// screen anybody ever sees and the only one they cannot leave, so it is also
// the screen where a clipped paragraph is unrecoverable rather than annoying.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/disclaimer_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../../support/harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Future<void> pumpFrame(
    WidgetTester tester, {
    required String languageCode,
    required Brightness brightness,
    required double scale,
  }) async {
    final l10n = await AppLocalizations.delegate.load(Locale(languageCode));
    await pumpApp(
      tester,
      Scaffold(
        body: SafeArea(
          child: DisclaimerSheet(
            title: l10n.welcomeTitle,
            body: '${l10n.welcomeDisclaimer}\n\n${l10n.welcomeOffline}',
            actionLabel: l10n.welcomeAccept,
            isGate: true,
            onAccept: () {},
            onClose: () {},
          ),
        ),
      ),
      locale: Locale(languageCode),
      brightness: brightness,
      textScaler: TextScaler.linear(scale),
      surfaceSize: const Size(390, 844),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final languageCode in <String>['en', 'fa']) {
      for (final scale in <double>[1, 2]) {
        final name =
            'welcome_${brightness.name}_${languageCode}_'
            '${scale.toStringAsFixed(0)}x';
        testWidgets(name, (tester) async {
          await pumpFrame(
            tester,
            languageCode: languageCode,
            brightness: brightness,
            scale: scale,
          );

          await expectLater(
            find.byType(DisclaimerSheet),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}
