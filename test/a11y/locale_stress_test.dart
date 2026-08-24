// The two locales the mockup never showed, checked against rules.
//
// German is the longest-string locale and is where a row breaks; Sorani shares
// its script with Persian and still needs its own pass, because joining and
// letterforms are the font's job and the font is a different one.
//
// The overflow matrix (task 2) renders both locales on every screen with the
// FIXTURE's strings. This file renders the longest string the ARB actually
// contains — derived from the file, never typed out, because a hardcoded
// "longest string" rots the first time a translator changes copy.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';

import '../support/fonts.dart';
import '../support/harness.dart';

/// How many of the longest strings to render. Enough to cover the tail.
const int _longest = 12;

/// The narrowest supported surface, where German breaks first.
const Size _compact = Size(320, 640);

/// Every translatable value in an ARB, longest first.
List<(String, String)> _byLength(String tag) {
  final raw =
      json.decode(File('lib/l10n/arb/app_$tag.arb').readAsStringSync())
          as Map<String, dynamic>;
  final entries = <(String, String)>[
    for (final MapEntry<String, dynamic> entry in raw.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        // Skip the ICU messages: their braces are a plural selector, not
        // text, and rendering the raw source measures the wrong string.
        if (!(entry.value as String).contains('{'))
          (entry.key, entry.value as String),
  ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  return entries;
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting();
  });

  group('de — the longest string the ARB actually contains', () {
    final longest = _byLength('de').take(_longest).toList();

    test('the corpus is real, and German really is the longest', () {
      // A stress test over an empty list is a stress test that passes.
      expect(longest, hasLength(_longest));
      expect(longest.first.$2.length, greaterThan(40));
      expect(
        longest.first.$2.length,
        greaterThanOrEqualTo(_byLength('en').first.$2.length),
        reason: 'English is longer than German, so this axis is the wrong one',
      );
    });

    for (var i = 0; i < _longest; i++) {
      testWidgets('#$i does not overflow or truncate at 320 × 2.0 bold', (
        tester,
      ) async {
        final (key, value) = longest[i];
        await pumpApp(
          tester,
          Scaffold(
            body: Center(
              // A card's inner width on the narrowest phone: the padding a
              // real screen puts around body copy, so the measurement is the
              // one that ships.
              child: SizedBox(
                width: _compact.width - 32,
                child: Text(value),
              ),
            ),
          ),
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(2),
          boldText: true,
          surfaceSize: _compact,
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: '$key overflowed');

        // Rendered in FULL. An ellipsis or a shrink would satisfy the
        // exception check above while leaving the reader a sentence they
        // cannot finish.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(Text).first,
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: key);
        expect(paragraph.text.toPlainText(), value, reason: key);
      });
    }
  });

  group('ckb — script, not length', () {
    testWidgets('Sorani text resolves to the Perso-Arabic face', (
      tester,
    ) async {
      // Nunito has no Perso-Arabic coverage at all. Falling back to it is a
      // page of `.notdef` boxes, and every geometry assertion in the suite
      // would still pass over them.
      final theme = buildDaybreakTheme(
        Brightness.light,
        scriptFor(kurdishSorani),
      );

      expect(theme.textTheme.bodyLarge?.fontFamily, 'Vazirmatn');
      expect(scriptFor(kurdishSorani), DaybreakScript.perso);
    });

    testWidgets('joining happens — a joined word is narrower than its parts', (
      tester,
    ) async {
      // The machine-checkable proxy for shaping. Perso-Arabic letters join,
      // so a shaped word is strictly narrower than the same letters laid out
      // in isolation. A font that failed to shape would measure the same.
      const word = 'کوردی';
      final style = buildDaybreakTheme(
        Brightness.light,
        DaybreakScript.perso,
      ).textTheme.bodyLarge;

      double widthOf(String text) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.rtl,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      final joined = widthOf(word);
      final isolated = word.characters.fold<double>(
        0,
        (sum, ch) => sum + widthOf(ch),
      );

      // A MARGIN, not just "less than". Any font is a little narrower as one
      // run than as five, from kerning alone, so "narrower" on its own would
      // pass over a face that never joined a letter. Vazirmatn measures 46.7
      // against 56.9 — an 18% saving; kerning is a couple of percent. 10% is
      // the line between them.
      expect(
        joined,
        lessThan(isolated * 0.9),
        reason: 'joined $joined vs isolated $isolated — nothing shaped',
      );
    });

    test('numerals RENDER in the locale block and STORE as ASCII', () {
      // Both halves. Either alone is satisfiable by the wrong implementation:
      // a formatter that localizes on the way in corrupts the database, and
      // one that never localizes puts Latin digits in a Kurdish sentence.
      final rendered = numberFormatFor(kurdishSorani).format(52);

      expect(rendered, isNot('52'));
      expect(
        rendered.runes.every((r) => r >= 0x06F0 && r <= 0x06F9),
        isTrue,
        reason: 'rendered "$rendered" is not extended Arabic-Indic',
      );
      // The stored side, through the same normalizer the fields use.
      expect(normalizeToAscii(rendered), '52');
    });

    testWidgets('a framework string comes from the ckb delegate', (
      tester,
    ) async {
      // EPIC-03 borrows Persian for the framework strings, deliberately and
      // with a stated cost. What must never happen is falling back to
      // ENGLISH — which is what a missing delegate does, silently, along with
      // laying the whole app out left to right.
      late MaterialLocalizations material;
      late TextDirection direction;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            material = MaterialLocalizations.of(context);
            direction = Directionality.of(context);
            return const SizedBox.shrink();
          },
        ),
        locale: kurdishSorani,
      );
      await tester.pump();

      expect(direction, TextDirection.rtl, reason: 'ckb rendered LTR');
      expect(
        material.cancelButtonLabel,
        isNot('Cancel'),
        reason: 'the framework fell back to English',
      );
    });

    testWidgets('the app own strings are Kurdish, not the borrowed Persian', (
      tester,
    ) async {
      // The other half of the same decision: framework strings are borrowed,
      // app strings never are.
      final ckb = await AppLocalizations.delegate.load(kurdishSorani);
      final fa = await AppLocalizations.delegate.load(const Locale('fa'));

      expect(ckb.tabToday, isNot(fa.tabToday));
      expect(ckb.welcomeAccept, isNot(fa.welcomeAccept));
    });
  });
}
