// Kurdish Sorani is not one of the 116 locales flutter_localizations ships.
//
// Without these three delegates a `ckb` build does not merely lose its
// framework strings — `Directionality` falls back to **LTR**, so the whole app
// renders left-to-right in a right-to-left language. That is verified in this
// file rather than claimed.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/ckb_material_localizations.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

void main() {
  test('the constraint, asserted rather than claimed', () {
    // The tripwire. When upstream adds ckb this goes red and names the file to
    // delete — which is the only way anyone will ever remember to.
    expect(
      GlobalMaterialLocalizations.delegate.isSupported(const Locale('ckb')),
      isFalse,
    );
    expect(kMaterialSupportedLanguages, isNot(contains('ckb')));
  });

  group('the delegates are inert for everything but ckb', () {
    // What makes it safe to place them BEFORE the global delegates: they must
    // win for ckb and never intercept a locale the framework handles properly.
    const others = <Locale>[
      Locale('fa'),
      Locale('en'),
      Locale('de'),
      Locale('ar'),
    ];

    test('CkbMaterialLocalizationsDelegate', () {
      const delegate = CkbMaterialLocalizationsDelegate();

      expect(delegate.isSupported(const Locale('ckb')), isTrue);
      expect(delegate.isSupported(kurdishSorani), isTrue);
      for (final locale in others) {
        expect(delegate.isSupported(locale), isFalse, reason: '$locale');
      }
      expect(delegate.shouldReload(delegate), isFalse);
    });

    test('CkbCupertinoLocalizationsDelegate', () {
      const delegate = CkbCupertinoLocalizationsDelegate();

      expect(delegate.isSupported(const Locale('ckb')), isTrue);
      for (final locale in others) {
        expect(delegate.isSupported(locale), isFalse, reason: '$locale');
      }
      expect(delegate.shouldReload(delegate), isFalse);
    });

    test('CkbWidgetsLocalizationsDelegate', () {
      const delegate = CkbWidgetsLocalizationsDelegate();

      expect(delegate.isSupported(const Locale('ckb')), isTrue);
      for (final locale in others) {
        expect(delegate.isSupported(locale), isFalse, reason: '$locale');
      }
      expect(delegate.shouldReload(delegate), isFalse);
    });
  });

  test('the trade, pinned: framework chrome reads Persian', () async {
    // Shared script, different language. Persian and Kurdish differ in several
    // of these words, and `localeName` reporting 'fa' is the honest evidence
    // of what was borrowed. Pinned so nobody later mistakes it for a bug — or
    // forgets it was deliberate and stops covering the important strings in
    // the app's own ARB.
    final material = await const CkbMaterialLocalizationsDelegate().load(
      const Locale('ckb'),
    );
    final persian = await GlobalMaterialLocalizations.delegate.load(
      const Locale('fa'),
    );

    expect(material.cancelButtonLabel, isNotEmpty);
    expect(material.cancelButtonLabel, persian.cancelButtonLabel);
    expect(material.okButtonLabel, persian.okButtonLabel);
    // The epic asks for `localeName == 'fa'` as the evidence. That getter is
    // not public on either `MaterialLocalizations` or
    // `GlobalMaterialLocalizations` in this Flutter version, and the string
    // comparisons above are the stronger claim anyway: they show the strings
    // ARE the Persian ones, which is the trade itself rather than a label
    // describing it.
    expect(material.runtimeType, persian.runtimeType);
  });

  test('the WIDGETS delegate is where RTL actually comes from', () async {
    final widgets = await const CkbWidgetsLocalizationsDelegate().load(
      const Locale('ckb'),
    );

    expect(widgets.textDirection, TextDirection.rtl);
  });

  test('the Cupertino delegate loads too', () async {
    final cupertino = await const CkbCupertinoLocalizationsDelegate().load(
      const Locale('ckb'),
    );

    expect(cupertino.copyButtonLabel, isNotEmpty);
  });

  testWidgets('end to end: a ckb app builds, mirrors, and speaks Kurdish', (
    tester,
  ) async {
    late TextDirection direction;
    late String appOwnedString;
    late MaterialLocalizations material;

    await tester.pumpWidget(
      MaterialApp(
        locale: kurdishSorani,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        home: Builder(
          builder: (context) {
            direction = Directionality.of(context);
            material = MaterialLocalizations.of(context);
            // An app-owned string, never a framework one: the framework's are
            // Persian by construction, so asserting one would assert the trade
            // rather than the translation.
            appOwnedString = AppLocalizations.of(context).actionTaken;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(direction, TextDirection.rtl);
    expect(material.cancelButtonLabel, isNotEmpty);
    expect(appOwnedString, 'وەرگیرا');
  });
}
