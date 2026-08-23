// Settings on a tablet: a centred column, not a row stretched to 1200px.
//
// A settings row whose label sits at the far left and whose switch sits at the
// far right of a 1024pt window is unreadable — the eye cannot connect the two
// — and it is the default outcome of a `ListView` on a wide screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/window_size.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/data/storage_failure.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_cards.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: <Override>[
        settingsControllerProvider.overrideWith(_Fixed.new),
      ],
      surfaceSize: size,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('1024x768: the reading column is 640 wide, not 1024', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1024, 768));

    expect(
      tester.getSize(find.byKey(SettingsScreen.contentKey)).width,
      SettingsScreen.maxContentWidth,
    );
    // And the card inside it is narrower still, by the page inset — a row
    // whose control is a hand's width from its label is the thing being
    // prevented, so the CARD is what has to end up readable.
    expect(
      tester.getSize(find.byType(AccessibilityCard)).width,
      lessThan(SettingsScreen.maxContentWidth),
    );
  });

  testWidgets('390x844: the column uses the width it has', (tester) async {
    // The inverted arm. A cap that applies at every width would pass the test
    // above and leave a phone with 640pt of content in a 390pt window.
    await pumpAt(tester, const Size(390, 844));

    expect(tester.getSize(find.byKey(SettingsScreen.contentKey)).width, 390);
  });

  for (final size in <Size>[
    const Size(390, 844),
    Size(WindowSizeClass.medium.minWidth, 900),
    const Size(1024, 768),
  ]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: nothing '
        'scrolls sideways', (tester) async {
      await pumpAt(tester, size);

      final inFields = tester
          .widgetList<Scrollable>(
            find.descendant(
              of: find.byType(EditableText),
              matching: find.byType(Scrollable),
            ),
          )
          .toSet();
      for (final scrollable in tester.widgetList<Scrollable>(
        find.byType(Scrollable),
      )) {
        if (inFields.contains(scrollable)) continue;
        expect(
          scrollable.axisDirection,
          anyOf(AxisDirection.down, AxisDirection.up),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

final class _Fixed extends SettingsController {
  @override
  AppSettings build() => AppSettings.defaults;

  @override
  Future<Result<void, StorageFailure>> setLocaleTag(String? tag) async =>
      const Ok(null);
}
