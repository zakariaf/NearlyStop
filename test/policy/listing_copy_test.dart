// The one line the store listing must never cross.
//
// Apple's Guideline 1.4.1: an app that **calculates medication dosages** must
// come from a drug manufacturer, hospital, university, health insurer or an
// equivalent approved entity. NearlyStop is not one, and it is not a dosage
// calculator — SPEC §2 makes "never recommends a dose" non-negotiable. But a
// listing sentence that says "works out your taper for you" recasts it as one
// and earns a rejection no code change fixes.
//
// **A grep cannot judge framing.** It catches the sentences somebody already
// knows are wrong. Reading the whole listing against 1.4.1 is a human pass and
// stays the task's acceptance. This is the half a machine can hold.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// The five files every listing locale must have.
const List<String> kRequiredFiles = <String>[
  'title.txt',
  'subtitle.txt',
  'short-description.txt',
  'full-description.txt',
  'keywords.txt',
];

/// The locales the app itself speaks. Store-locale support is a separate and
/// smaller question — see `store/README.md`.
const List<String> kListingLocales = <String>['en', 'de', 'fa', 'ckb'];

/// Phrases that recast the app as a dosage calculator.
///
/// The German, Persian and Sorani entries are **the same claim in each
/// language**, not a machine translation of the English list: what matters is
/// the sentence a reviewer in that market would read as "the app decides the
/// dose".
const Map<String, List<String>> kBannedPhrases = <String, List<String>>{
  'en': <String>[
    'calculate',
    'calculates',
    'calculating',
    'recommends',
    'recommend the dose',
    'optimises the dose',
    'optimizes the dose',
    'works out your taper',
    'tells you what to take',
    'decides your dose',
    'adjusts your dose',
  ],
  'de': <String>[
    'berechnet',
    'berechnen',
    'empfiehlt die dosis',
    'optimiert die dosis',
    'passt ihre dosis an',
    'sagt ihnen, was sie einnehmen',
  ],
  'fa': <String>[
    'دوز را محاسبه',
    'محاسبه دوز',
    'دوز را توصیه',
    'دوز شما را تنظیم',
  ],
  'ckb': <String>[
    'دۆز دەژمێرێت',
    'ژماردنی دۆز',
    'دۆز پێشنیار دەکات',
  ],
};

void main() {
  String read(String locale, String file) =>
      File('store/listing/$locale/$file').readAsStringSync();

  test('the banned list is not empty, in any locale', () {
    // A phrase list that has never matched anything is indistinguishable from
    // a broken one. This is the guard that keeps the loop below meaningful.
    for (final locale in kListingLocales) {
      expect(
        kBannedPhrases[locale],
        isNotNull,
        reason: '$locale has no banned-phrase list at all',
      );
      expect(kBannedPhrases[locale], isNotEmpty, reason: locale);
    }
  });

  test('the check can fail — proved against a deliberate violation', () {
    // Seeded rather than trusted: the matcher below is case-insensitive and
    // works on a normalised string, and both of those are easy to get wrong
    // in a way that matches nothing.
    const violation = 'NearlyStop CALCULATES your dose for you.';

    expect(
      _hits(violation, kBannedPhrases['en']!),
      contains('calculates'),
      reason: 'the matcher cannot see an obvious violation',
    );
  });

  group('every listing locale', () {
    for (final locale in kListingLocales) {
      test('$locale has all five files, non-empty', () {
        for (final name in kRequiredFiles) {
          final file = File('store/listing/$locale/$name');
          expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
          expect(
            file.readAsStringSync().trim(),
            isNotEmpty,
            reason: '${file.path} is empty',
          );
        }
      });

      test('$locale claims nothing about deciding a dose', () {
        final banned = kBannedPhrases[locale]!;
        for (final name in kRequiredFiles) {
          final hits = _hits(read(locale, name), banned);
          expect(
            hits,
            isEmpty,
            reason:
                'store/listing/$locale/$name says $hits — Guideline 1.4.1 '
                'reads that as a dosage calculator',
          );
        }
      });
    }
  });

  test('the app own strings hold the same line', () {
    // The listing and the app must agree. A listing that is careful while the
    // in-app copy says "we work out your taper" is a listing that describes a
    // different app from the one under review.
    for (final locale in kListingLocales) {
      final arb =
          json.decode(File('lib/l10n/arb/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      final banned = kBannedPhrases[locale]!;

      for (final entry in arb.entries) {
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        final hits = _hits(entry.value as String, banned);
        expect(
          hits,
          isEmpty,
          reason: 'app_$locale.arb: ${entry.key} says $hits',
        );
      }
    }
  });

  test('the reviewer note quotes the app disclaimer exactly', () {
    // Byte-identical, so the two cannot drift. A reviewer who reads one
    // sentence in the note and a different one on screen has found an
    // inconsistency in a medical app, which is the worst place to have one.
    final arb =
        json.decode(File('lib/l10n/arb/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final disclaimer = arb['welcomeDisclaimer'] as String;

    expect(
      File('store/review-notes.md').readAsStringSync(),
      contains(disclaimer),
      reason: 'the reviewer note does not quote the disclaimer verbatim',
    );
  });
}

/// Every banned phrase present in [text], case-insensitively.
List<String> _hits(String text, List<String> banned) {
  final haystack = text.toLowerCase();
  return <String>[
    for (final phrase in banned)
      if (haystack.contains(phrase.toLowerCase())) phrase,
  ];
}
