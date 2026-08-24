// Zero network calls, proved at RUNTIME rather than only by grep.
//
// Three layers hold this claim up, and all three are required:
//
//   1. **Static** — `tool/check_bans.sh` rejects `package:http`, `dio`,
//      `google_fonts`, `HttpClient`, `WebSocket` and `Socket` anywhere in
//      `lib/`, each with a must-fail fixture in `check_bans_test.dart`.
//   2. **Dependency** — `tool/audit_deps.py` walks the resolved tree, not the
//      pubspec, with a self-test that plants a banned package three hops down.
//   3. **Runtime** — this file. Every socket the process can open is made to
//      THROW, then the whole app is driven. A grep proves nothing calls a
//      socket by a name we thought of; this proves nothing calls one at all.
//
// The fourth layer is the release manifest's absent `INTERNET`
// (`permissions_test.dart`) — which on Android makes a network call
// impossible rather than merely absent. iOS has no equivalent, so there the
// proof is layers 1–3 plus the airplane-mode run recorded in the gate file.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../a11y/app_screens.dart';
import '../support/fonts.dart';
import '../support/harness.dart';

/// Every HTTP client this process could create, replaced by one that throws.
///
/// `HttpOverrides` is the only interception point that covers `dart:io`'s
/// client wholesale — including a call from inside a dependency, which is
/// exactly the call a source grep cannot see.
class _RefuseEverything extends HttpOverrides {
  /// Every attempt, with the stack that made it.
  static final List<StackTrace> attempts = <StackTrace>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts.add(StackTrace.current);
    throw StateError(
      'a network call was attempted. This app has no network path — see '
      'docs/release/privacy-declarations.md.',
    );
  }
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  setUp(_RefuseEverything.attempts.clear);

  testWidgets('no screen reaches a socket, in any language', (tester) async {
    // Every surface, every locale. A network call from a dependency's lazy
    // initialiser would fire on the screen that first touches it, so sweeping
    // all six is the point rather than sampling one.
    await HttpOverrides.runWithHttpOverrides(() async {
      for (final screen in appScreens()) {
        for (final locale in <Locale>[const Locale('en'), const Locale('fa')]) {
          final l10n = await AppLocalizations.delegate.load(locale);
          await pumpApp(
            tester,
            screen.build(l10n),
            overrides: screen.overrides(locale),
            locale: locale,
            surfaceSize: const Size(390, 2400),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.name} in ${locale.languageCode} threw',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }, _RefuseEverything());

    expect(
      _RefuseEverything.attempts,
      isEmpty,
      reason:
          '${_RefuseEverything.attempts.length} network attempt(s):\n'
          '${_RefuseEverything.attempts.join('\n\n')}',
    );
  });

  testWidgets('the interceptor can actually fail', (tester) async {
    // A refusal that never refuses anything is a refusal nobody has tested.
    // This is the same override, given something to catch.
    await HttpOverrides.runWithHttpOverrides(() async {
      expect(HttpClient.new, throwsStateError);
    }, _RefuseEverything());

    expect(_RefuseEverything.attempts, hasLength(1));
  });
}
