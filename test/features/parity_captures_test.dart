@Tags(<String>['golden'])
library;

// The no-reference parity passes: `de` and `ckb`.
//
// The reference sheets exist in `en` and `fa` only, so these two get no paired
// comparison — they are captured and READ, against the two things a missing
// reference cannot excuse: German is the longest-string locale and is where a
// row overflows, and Kurdish Sorani shares Perso-Arabic with Persian but needs
// its own script pass because its letterforms and its Material strings differ.
//
// Written straight into `parity/`, not into a `goldens/` folder: these are
// evidence attached to a pull request, not a regression gate. Regenerate with
// `--update-goldens` when the screens change.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/features/plan/presentation/plan_screen.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/disclaimer_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:riverpod/misc.dart' show Override;

import '../fixtures/seeded_plan.dart';
import '../support/harness.dart';

const String _out = '../../parity/11-plan-settings-welcome';

void main() {
  setUpAll(initializeDateFormatting);

  for (final tag in <String>['de', 'ckb']) {
    widgetTestWithDatabase('plan_$tag', (tester) async {
      await pumpApp(
        tester,
        const PlanScreen(),
        overrides: seededPlanOverrides(locale: Locale(tag)),
        locale: Locale(tag),
        surfaceSize: const Size(390, 1500),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(PlanScreen),
        matchesGoldenFile('$_out/app--05-plan--light-$tag.png'),
      );
    });

    testWidgets('settings_$tag', (tester) async {
      await pumpApp(
        tester,
        const SettingsScreen(),
        overrides: <Override>[
          settingsControllerProvider.overrideWith(
            FixedSettingsController.seeded,
          ),
        ],
        locale: Locale(tag),
        surfaceSize: const Size(390, 1200),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('$_out/app--06-settings--light-$tag.png'),
      );
    });

    testWidgets('welcome_$tag', (tester) async {
      final l10n = await AppLocalizations.delegate.load(Locale(tag));
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
        locale: Locale(tag),
        surfaceSize: const Size(390, 844),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DisclaimerSheet),
        matchesGoldenFile('$_out/app--01-welcome--light-$tag.png'),
      );
    });
  }
}
