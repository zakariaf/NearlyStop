// The words a reminder carries, in four locales.
//
// Authoring translations is craft. The medical-safety and privacy constraints
// on them are mechanical, and those are what this file asserts: no dose, no
// drug name, no instruction, and nothing invisible in the middle of the
// Perso-Arabic strings.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

void main() {
  /// Every locale the app ships, loaded the way the app loads them.
  Future<Map<String, AppLocalizations>> loadAll() async =>
      <String, AppLocalizations>{
        for (final locale in kSupportedLocales)
          locale.languageCode: await AppLocalizations.delegate.load(locale),
      };

  test('the body carries no digit, in any script', () async {
    // "No dose in the notification" made checkable. A lock-screen preview
    // reading "9mg" tells anyone holding the phone that its owner has a
    // chronic illness — and the ASCII-only version of this check passes a
    // Persian body that spells the dose in U+06Fx.
    final digits = RegExp('[0-9٠-٩۰-۹]');
    final all = await loadAll();

    all.forEach((tag, l10n) {
      expect(l10n.reminderBody.contains(digits), isFalse, reason: tag);
      expect(l10n.reminderTitle.contains(digits), isFalse, reason: tag);
    });
  });

  test('neither string names the drug', () async {
    final all = await loadAll();

    all.forEach((tag, l10n) {
      for (final name in <String>[
        'Prednisolone',
        'Prednisolon',
        'Prednisone',
      ]) {
        expect(l10n.reminderBody, isNot(contains(name)), reason: tag);
        expect(l10n.reminderTitle, isNot(contains(name)), reason: tag);
      }
    });
  });

  test('English says exactly the sentence SPEC §11.4 settles on', () async {
    final all = await loadAll();

    expect(all['en']!.reminderTitle, 'Your plan for today');
  });

  test('no title is an instruction, in any locale', () async {
    // Authored WITH the translation, not guessed: each entry is the imperative
    // opening this language would actually use. "Take your pills" is the
    // sentence this app cannot ship — it arranges a plan, it does not tell
    // anybody to swallow anything.
    const imperativeOpenings = <String, List<String>>{
      'en': <String>['Take', 'Swallow', 'Remember to', "Don't forget"],
      'de': <String>['Nehmen', 'Nimm', 'Vergessen Sie', 'Denken Sie'],
      'fa': <String>['بخورید', 'مصرف کنید', 'فراموش نکنید'],
      'ckb': <String>['بخۆ', 'بیخۆ', 'لەبیرت نەچێت'],
    };
    final all = await loadAll();

    imperativeOpenings.forEach((tag, openings) {
      for (final opening in openings) {
        expect(
          all[tag]!.reminderTitle,
          isNot(startsWith(opening)),
          reason: '$tag title is an instruction',
        );
      }
    });
  });

  test('no Perso-Arabic string carries a stray bidi mark', () async {
    // U+200E/U+200F are invisible in review and visible in the shade, where
    // they push the whole line the wrong way round.
    final all = await loadAll();

    for (final tag in <String>['fa', 'ckb']) {
      for (final value in <String>[
        all[tag]!.reminderTitle,
        all[tag]!.reminderBody,
        all[tag]!.reminderChannelName,
        all[tag]!.reminderChannelDescription,
      ]) {
        expect(value.contains('‎'), isFalse, reason: '$tag: LRM');
        expect(value.contains('‏'), isFalse, reason: '$tag: RLM');
      }
    }
  });

  test('two locales produce two different (title, body) pairs', () async {
    // What makes the deterministic id change on a language switch — and so
    // what makes the reconcile re-arm a notification that would otherwise stay
    // in a language the reader just told the app they do not use.
    final all = await loadAll();
    final pairs = <(String, String)>{
      for (final l10n in all.values) (l10n.reminderTitle, l10n.reminderBody),
    };

    expect(pairs, hasLength(kSupportedLocales.length));
  });

  test('neither ARB entry takes a placeholder', () async {
    // Structural: a `{dose}` in the body is impossible when the generated
    // getter takes no arguments. Asserted through the generated API rather
    // than by reading the ARB, because the generated API is what a caller
    // could actually reach for.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(l10n.reminderTitle, isA<String>());
    expect(l10n.reminderBody, isA<String>());
  });
}
