// The codegen contract and the ICU shapes.
//
// The WORDING of a translation cannot be wrong in a way `expect` catches — a
// German sentence is a review question. The shapes can: a count spliced into a
// sentence, a plural branch hand-faked into a language that has none, a
// placeholder left behind. Those are what this file pins.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';

import '../support/arb.dart';

void main() {
  test('lookupAppLocalizations works OUTSIDE a Localizations scope', () async {
    // The evidence that `synthetic-package: false` is doing its job. EPIC-06's
    // `appLocalizationsProvider` is built on exactly this call, and a provider
    // body has no BuildContext to hand `AppLocalizations.of`.
    for (final tag in arbLocaleTags) {
      final l10n = lookupAppLocalizations(Locale(tag));

      expect(l10n.localeName, tag, reason: tag);
      expect(l10n.appTitle, isNotEmpty, reason: tag);
    }
  });

  test('the getter is non-null, so a mistyped key cannot compile', () async {
    // No `!` and no `?.` anywhere in this file. It compiles only under
    // `nullable-getter: false`.
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(l10n.actionTaken.length, greaterThan(0));
  });

  test('every count-bearing key is an ICU plural, never a splice', () {
    // A ternary in Dart cannot pass this, and a spliced string looks perfectly
    // fine in English right up until it is translated into a language whose
    // word order differs.
    final template = arbFor(arbTemplateTag);
    final countBearing = template.keys.where(
      (key) =>
          !key.startsWith('@') &&
          (template['@$key'] as Map<String, dynamic>?)?['placeholders'] !=
              null &&
          ((template['@$key']! as Map<String, dynamic>)['placeholders']!
                  as Map<String, dynamic>)
              .containsKey('count'),
    );

    expect(
      countBearing,
      isNotEmpty,
      reason: 'the fixture itself must have some',
    );
    for (final key in countBearing) {
      for (final tag in arbLocaleTags) {
        expect(
          arbFor(tag)[key],
          contains('{count, plural,'),
          reason: '$key in $tag',
        );
      }
    }
  });

  test('plurals select per locale — fa and ckb have no `one` branch', () {
    // Persian and Sorani do not distinguish singular from plural the way
    // English does. A hand-faked `one:` copied into those ARBs fails here.
    expect(
      lookupAppLocalizations(const Locale('en')).takenDays(1),
      contains('day '),
    );
    expect(
      lookupAppLocalizations(const Locale('en')).takenDays(341),
      contains('days'),
    );

    for (final tag in <String>['fa', 'ckb']) {
      final one = lookupAppLocalizations(Locale(tag)).takenDays(1);
      final many = lookupAppLocalizations(Locale(tag)).takenDays(341);

      expect(
        one.replaceAll('1', '#').replaceAll('۱', '#'),
        many.replaceAll('341', '#').replaceAll('۳۴۱', '#'),
        reason: '$tag must use the same branch for 1 and 341',
      );
    }
  });

  test('no placeholder survives unsubstituted, in any locale', () {
    for (final tag in arbLocaleTags) {
      final l10n = lookupAppLocalizations(Locale(tag));
      final rendered = <String>[
        l10n.takenDays(341),
        l10n.stepOfTotal(3, 15),
        l10n.dayOfStep(14, 52),
        l10n.blockOfTotal(3, 11),
        l10n.doseWithUnit('9'),
        l10n.todaySemantics('9', '1 × 5mg, 4 × 1mg'),
      ];

      for (final value in rendered) {
        expect(value, isNot(contains('{')), reason: tag);
        expect(value, isNot(contains('}')), reason: tag);
        expect(value, isNotEmpty, reason: tag);
      }
    }
  });

  test('the SPEC 5.4 semantics sentence is a real ICU message', () {
    // A semantics label is a user-facing string like any other. Building it by
    // concatenation is how VoiceOver ends up reading English word order inside
    // a Persian app.
    expect(
      lookupAppLocalizations(const Locale('en')).todaySemantics(
        '9',
        'one 5 milligram tablet, four 1 milligram tablets',
      ),
      'Today, 9 milligrams: one 5 milligram tablet, four 1 milligram tablets. '
      'Not yet taken.',
    );

    for (final tag in arbLocaleTags) {
      expect(
        arbFor(tag)['todaySemantics'],
        allOf(contains('{dose}'), contains('{breakdown}')),
        reason: tag,
      );
    }
  });

  test('every locale carries exactly the template keys', () {
    // Task 10 makes this a CI gate over the raw files; here it is the reason
    // the tests above can index any locale by key without a null check.
    final template = arbMessageKeys().toSet();

    for (final tag in arbLocaleTags) {
      final keys = arbFor(tag).keys.where((k) => !k.startsWith('@')).toSet();

      expect(keys, template, reason: tag);
    }
  });
}
