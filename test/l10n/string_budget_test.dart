// German overflow, caught before there is a screen to overflow.
//
// **A character budget is a PROXY, not a measurement.** It cannot see font
// metrics and it says nothing at 200% text scale. The real check is the golden
// matrix in the UI epics — {en, de, fa, ckb} × {light, dark} × textScale
// {1.0, 1.3, 2.0} — and the layouts that absorb it. This is a cheap early
// tripwire and nothing more.
//
// What it must NOT become: a reason to reach for `FittedBox`,
// `TextOverflow.ellipsis` or `MediaQuery.withClampedTextScaling`. Those turn a
// loud test failure into a truncated instruction on a 78-year-old's phone.
import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:test/test.dart';

/// The template with each placeholder replaced by the example the `@`-metadata
/// declares for it.
///
/// The budget has to measure what RENDERS. `"Step {current} of {total}"` is 25
/// characters as a template and 12 as a rendered string, so budgeting the raw
/// value would either reject a label that fits or force a budget so loose it
/// catches nothing.
String rendered(String value, Map<String, dynamic>? meta) {
  final placeholders =
      meta?['placeholders'] as Map<String, dynamic>? ?? const {};
  var out = value;
  placeholders.forEach((name, spec) {
    final example = (spec as Map<String, dynamic>)['example'] as String?;
    out = out.replaceAll('{$name}', example ?? name);
  });
  return out;
}

const locales = <String>['en', 'de', 'fa', 'ckb'];

Map<String, dynamic> arbFor(String locale) =>
    jsonDecode(File('lib/l10n/arb/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final template = arbFor('en');
  final budgets = <String, int>{
    for (final entry in template.entries)
      if (entry.key.startsWith('@') &&
          entry.value is Map<String, dynamic> &&
          (entry.value as Map<String, dynamic>)['x-maxChars'] != null)
        entry.key.substring(1):
            (entry.value as Map<String, dynamic>)['x-maxChars'] as int,
  };

  test('the fixture itself has budgets, or this file asserts nothing', () {
    expect(budgets, isNotEmpty);
    expect(budgets.length, greaterThan(20));
  });

  for (final locale in locales) {
    final values = arbFor(locale);

    group('$locale fits its budgets', () {
      budgets.forEach((key, budget) {
        test('$key <= $budget', () {
          final value = values[key];

          // A budgeted key MISSING from a locale is the more dangerous of the
          // two failures, because a null read as "fits" is silent.
          expect(
            value,
            isA<String>(),
            reason: '$key is missing from $locale',
          );

          // Grapheme CLUSTERS, not UTF-16 units. A Perso-Arabic string
          // carrying a combining mark overcounts on `String.length` and would
          // fail a budget the layout actually meets.
          final length = rendered(
            value! as String,
            template['@$key'] as Map<String, dynamic>?,
          ).characters.length;
          expect(
            length,
            lessThanOrEqualTo(budget),
            reason:
                'key=$key locale=$locale budget=$budget actual=$length '
                'value="$value"',
          );
        });
      });
    });
  }

  test('length is counted in clusters, not UTF-16 units', () {
    // U+0654 ARABIC HAMZA ABOVE is a combining mark: two UTF-16 units, one
    // cluster. Counting units would fail a budget the rendering meets.
    const combining =
        'ؤ'
        'هٔ';

    expect(combining.length, greaterThan(combining.characters.length));
    expect('هٔ'.characters.length, 1);
  });

  test('a key WITHOUT a budget is skipped, not failed', () {
    // Unconstrained by design. The test must not creep into demanding a budget
    // for every string — a disclaimer paragraph has no width to blow.
    final unbudgeted = template.keys
        .where((k) => !k.startsWith('@') && !budgets.containsKey(k))
        .toList();

    expect(unbudgeted, isNotEmpty);
    expect(unbudgeted, contains('welcomeDisclaimer'));
  });

  test('every budget names the slot it was measured from', () {
    // Traceability. A budget nobody can trace back to a slot is a number
    // somebody will "fix" by raising it.
    for (final key in budgets.keys) {
      final meta = template['@$key'] as Map<String, dynamic>;

      expect(
        meta['description'],
        isA<String>(),
        reason: '$key has a budget but no description to trace it',
      );
    }
  });
}
