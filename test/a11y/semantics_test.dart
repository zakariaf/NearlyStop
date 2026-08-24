// The semantic tree, across all six surfaces at once.
//
// Each UI epic asserted its own screen. What no epic could assert is the
// property that only exists across the app: that there is no unlabelled node
// anywhere, in any of the four languages — the failure mode where one screen's
// icon-only control is the one thing a VoiceOver user cannot name.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../support/fonts.dart';
import '../support/harness.dart';
import 'app_screens.dart';
import 'semantics_probe.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  Future<SemanticsHandle> pumpScreen(
    WidgetTester tester,
    AppScreen screen, {
    Locale locale = const Locale('en'),
    double scale = 1,
  }) async {
    final handle = tester.ensureSemantics();
    final l10n = await AppLocalizations.delegate.load(locale);
    await pumpApp(
      tester,
      screen.build(l10n),
      overrides: screen.overrides(locale),
      locale: locale,
      textScaler: TextScaler.linear(scale),
      // Tall enough that a `ListView` BUILDS every row: an off-screen node is
      // a node no assertion is made about, so a phone-height surface would
      // sweep the top third and report green.
      surfaceSize: Size(390, scale == 1 ? 2400 : 4800),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return handle;
  }

  group('nothing interactive is unnamed, in any language', () {
    for (final screen in appScreens()) {
      for (final locale in kSupportedLocales) {
        testWidgets('${screen.name} — ${locale.languageCode}', (tester) async {
          final handle = await pumpScreen(tester, screen, locale: locale);

          // The TRAVERSAL, not the raw tree: it is the ordered list a screen
          // reader actually visits, which is exactly the set that has to be
          // nameable.
          //
          final controls = <SemanticsData>[
            for (final node
                in tester.semantics.simulatedAccessibilityTraversal())
              if (isControl(node.getSemanticsData())) node.getSemanticsData(),
          ];
          final unnamed = <String>[
            for (final data in controls)
              if (data.label.trim().isEmpty && data.value.trim().isEmpty)
                _describe(data),
          ];

          handle.dispose();
          // Never vacuous again: every one of these screens has controls, so
          // an empty set means the FILTER broke, not that the screen is
          // perfect.
          expect(
            controls,
            isNotEmpty,
            reason: '${screen.name} reported no controls at all',
          );
          expect(
            unnamed,
            isEmpty,
            reason:
                '${screen.name} in ${locale.toLanguageTag()} has a control a '
                'screen reader cannot name',
          );
        });
      }
    }
  });

  group('the reader never lands on a node with nothing to say', () {
    // The icon-shaped failure, stated as the property it actually is. A
    // decorative `Icon` inside a labelled parent contributes no node at all
    // and is fine; the bug is a node the traversal STOPS on with no label,
    // no value and no hint — VoiceOver announces a gap where a control is.
    //
    // Asserted over the traversal rather than over `find.byType(Icon)`,
    // because "labelled or wrapped in ExcludeSemantics" is not the rule: a
    // `Semantics` parent that merges its children is the third legal answer
    // and is the one this app uses most.
    for (final screen in appScreens()) {
      testWidgets(screen.name, (tester) async {
        final handle = await pumpScreen(tester, screen);

        final silent = <String>[
          for (final node in tester.semantics.simulatedAccessibilityTraversal())
            if (node.getSemanticsData().label.trim().isEmpty &&
                node.getSemanticsData().value.trim().isEmpty &&
                node.getSemanticsData().hint.trim().isEmpty &&
                !node.getSemanticsData().flagsCollection.scopesRoute)
              'node ${node.id} at ${node.rect}',
        ];

        handle.dispose();
        expect(
          silent,
          isEmpty,
          reason: '${screen.name} has a focusable node with nothing to say',
        );
      });
    }
  });

  testWidgets("Today's hero is ONE node, not four fragments", (tester) async {
    // SPEC §5.4: the screen reads as one natural sentence. Four announcements
    // — "10", "mg", "two 5 milligram tablets", "not yet taken" — is the same
    // information and a different experience.
    final screen = appScreens().firstWhere((s) => s.name == 'Today');
    final handle = await pumpScreen(tester, screen);

    handle.dispose();
    final hero = find.byWidgetPredicate(
      (w) => w is Semantics && (w.properties.label?.contains(':') ?? false),
    );

    expect(hero, findsWidgets);
    // The sentence is composed in the notifier from ARB strings, so this
    // asserts the SHAPE rather than a literal a copy change would break in
    // two places.
    final label = tester
        .widgetList<Semantics>(hero)
        .map((w) => w.properties.label!)
        .firstWhere((l) => l.contains(':'));
    expect(label, contains(':'), reason: 'the dose and its breakdown');
    expect(
      label.split(' ').length,
      greaterThan(5),
      reason: 'a sentence, not a fragment: "$label"',
    );
  });

  testWidgets('a language option names its language, never its tag', (
    tester,
  ) async {
    // `ckb` is not a word. A picker that announces the tag is a picker a
    // Kurdish reader cannot use to find Kurdish.
    final screen = appScreens().firstWhere((s) => s.name == 'Settings');
    final handle = await pumpScreen(tester, screen);

    handle.dispose();
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();

    for (final tag in <String>['ckb', 'fa', 'de']) {
      expect(
        rendered,
        isNot(contains(tag)),
        reason: 'the raw tag "$tag" is on screen',
      );
    }
  });
}

/// What a nameless control is called in a failure message.
String _describe(SemanticsData data) {
  final kind = data.flagsCollection.isButton ? 'button' : 'control';
  return 'a $kind with no name at ${data.rect}';
}
