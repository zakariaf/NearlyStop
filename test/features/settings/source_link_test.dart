// The one row in this app that leaves it.
//
// It is also the row that PROVES the rest. "No account, no server, no
// telemetry" is a claim the app makes about itself; a public repository is how
// somebody who does not take the claim on trust can go and check. So the
// destination, the way it is opened, and what happens on a phone with no
// browser are all pinned here rather than left to the widget.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/app/app_links.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/features/settings/presentation/widgets/settings_rows.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/services/links/link_opener.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  /// Every URL handed to the opener, in order, and what it answered.
  late List<Uri> opened;
  late bool opens;

  /// Every string put on the clipboard by the screen.
  late List<String> copied;

  setUp(() {
    opened = <Uri>[];
    opens = true;
    copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add(
              ((call.arguments as Map<Object?, Object?>)['text'] as String?) ??
                  '',
            );
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  });

  Future<AppLocalizations> pumpSettings(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    final l10n = await AppLocalizations.delegate.load(locale);
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: <Override>[
        settingsControllerProvider.overrideWith(FixedSettingsController.new),
        linkOpenerProvider.overrideWithValue((url) async {
          opened.add(url);
          return opens;
        }),
      ],
      locale: locale,
      surfaceSize: const Size(390, 1400),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  Finder sourceRow(AppLocalizations l10n) => find.ancestor(
    of: find.text(l10n.settingsSourceCode),
    matching: find.byType(SettingsRow),
  );

  // The two constants are read by different things — one is rendered, one is
  // opened — so nothing in the widget tests can tell them apart if they drift.
  // A row that SHOWS one repository and OPENS another is the failure that
  // matters here: it is indistinguishable from a link that has been tampered
  // with, in the one place the app asks to be trusted.
  test('the address shown is the address opened', () {
    expect(
      '${kSourceRepositoryUrl.host}${kSourceRepositoryUrl.path}',
      kSourceRepositoryLabel,
    );
    expect(kSourceRepositoryUrl.scheme, 'https');
  });

  testWidgets('the About card says the code is public and names where', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester);
    await tester.scrollUntilVisible(sourceRow(l10n), 200);

    expect(sourceRow(l10n), findsOneWidget);
    // The repository, spelled where the reader can see it — not hidden behind
    // a word that only becomes a URL after they have already tapped it.
    expect(find.text(kSourceRepositoryLabel), findsOneWidget);
    expect(find.text(l10n.settingsSourceCodeNote), findsOneWidget);
  });

  testWidgets('tapping it hands the repository URL to the system browser', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester);
    await tester.scrollUntilVisible(sourceRow(l10n), 200);
    await tester.tap(sourceRow(l10n));
    await tester.pumpAndSettle();

    expect(opened, <Uri>[kSourceRepositoryUrl]);
    expect(kSourceRepositoryUrl.scheme, 'https');
    // Nothing is copied when the browser took it: a clipboard the reader did
    // not ask for silently destroys whatever they had in it.
    expect(copied, isEmpty);
  });

  testWidgets('when no browser takes it, the URL goes to the clipboard', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester);
    opens = false;
    await tester.scrollUntilVisible(sourceRow(l10n), 200);
    await tester.tap(sourceRow(l10n));
    await tester.pumpAndSettle();

    expect(opened, <Uri>[kSourceRepositoryUrl]);
    expect(copied, <String>[kSourceRepositoryUrl.toString()]);
    expect(find.text(l10n.settingsSourceCodeCopied), findsOneWidget);
  });

  testWidgets('the row reads as one sentence naming where it goes', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester);
    await tester.scrollUntilVisible(sourceRow(l10n), 200);

    final semantics = tester.getSemantics(sourceRow(l10n));
    expect(semantics.label, contains(l10n.settingsSourceCode));
    expect(
      semantics.label,
      contains(kSourceRepositoryLabel),
      reason: 'a screen reader must hear the destination before the tap',
    );
  });
}
