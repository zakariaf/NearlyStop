// `flutter_test` rather than `package:test` because the subject is a `Color`,
// which comes from `dart:ui`. No `pumpWidget`: this is a value test.
//
// THE NAME IS THE CLAIM. `clay19` promises a measured CIE L* of 19, so the test
// is an independent oracle — it linearises the channels and computes L* from
// first principles — rather than a restatement of the same hex.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/primitives.dart';

import '../support/contrast.dart';

/// Every constant in `lib/theme/primitives.dart`, by name.
///
/// Hand-maintained, and asserted **complete** below against the file itself, so
/// a primitive added without a row here fails rather than escaping the L*
/// check.
const Map<String, Color> pool = <String, Color>{
  'clay100': Primitives.clay100,
  'clay98': Primitives.clay98,
  'clay97': Primitives.clay97,
  'clay95': Primitives.clay95,
  'clay94': Primitives.clay94,
  'clay89': Primitives.clay89,
  'clay73': Primitives.clay73,
  'clay59': Primitives.clay59,
  'clay56': Primitives.clay56,
  'clay50': Primitives.clay50,
  'clay42': Primitives.clay42,
  'clay41': Primitives.clay41,
  'clay37': Primitives.clay37,
  'clay19': Primitives.clay19,
  'clay11': Primitives.clay11,
  'clay04': Primitives.clay04,
  'taupe56': Primitives.taupe56,
  'plum01': Primitives.plum01,
  'plum03': Primitives.plum03,
  'plum08': Primitives.plum08,
  'plum11': Primitives.plum11,
  'plum15': Primitives.plum15,
  'plum19': Primitives.plum19,
  'plum24': Primitives.plum24,
  'plum54': Primitives.plum54,
  'plum58': Primitives.plum58,
  'coral93': Primitives.coral93,
  'coral76': Primitives.coral76,
  'coral70': Primitives.coral70,
  'coral66': Primitives.coral66,
  'coral64': Primitives.coral64,
  'coral55': Primitives.coral55,
  'coral50': Primitives.coral50,
  'coral43': Primitives.coral43,
  'coral33': Primitives.coral33,
  'coral19': Primitives.coral19,
  'amber95': Primitives.amber95,
  'amber83': Primitives.amber83,
  'amber80': Primitives.amber80,
  'amber72': Primitives.amber72,
  'amber42': Primitives.amber42,
  'amber34': Primitives.amber34,
  'amber20': Primitives.amber20,
  'moss94': Primitives.moss94,
  'moss79': Primitives.moss79,
  'moss78': Primitives.moss78,
  'moss70': Primitives.moss70,
  'moss52': Primitives.moss52,
  'moss50': Primitives.moss50,
  'moss46': Primitives.moss46,
  'moss34': Primitives.moss34,
  'moss22': Primitives.moss22,
  'rose92': Primitives.rose92,
  'rose75': Primitives.rose75,
  'rose70': Primitives.rose70,
  'rose58': Primitives.rose58,
  'rose47': Primitives.rose47,
  'rose40': Primitives.rose40,
  'rose32': Primitives.rose32,
  'rose18': Primitives.rose18,
};

void main() {
  group('the L* oracle itself', () {
    // Pin the oracle before trusting it with sixty constants: a linearisation
    // bug would make every row below agree with the same wrong maths.
    test('white is 100 and black is 0', () {
      expect(lStar(const Color(0xFFFFFFFF)), closeTo(100, 1e-9));
      expect(lStar(const Color(0xFF000000)), closeTo(0, 1e-9));
    });

    test('mid grey #777777 is about 50', () {
      expect(lStar(const Color(0xFF777777)), closeTo(50.0, 0.6));
    });
  });

  test('every primitive measures the L* its name claims', () {
    for (final MapEntry(key: name, value: color) in pool.entries) {
      final claimed = int.parse(RegExp(r'(\d+)$').firstMatch(name)!.group(1)!);
      final measured = lStar(color);
      expect(
        measured.round(),
        closeTo(claimed, 1),
        reason: '$name measured L*=${measured.toStringAsFixed(2)}',
      );
    }
  });

  test('no two primitives share a value under different names', () {
    final byValue = <int, List<String>>{};
    for (final MapEntry(key: name, value: color) in pool.entries) {
      byValue.putIfAbsent(color.toARGB32(), () => <String>[]).add(name);
    }
    final duplicates = byValue.values.where((names) => names.length > 1);
    expect(
      duplicates,
      isEmpty,
      reason: 'a duplicated primitive is a slot that will drift: $duplicates',
    );
  });

  test('no two primitives in one hue family share an L*', () {
    // Compare the MEASURED lightness, not the names — names are Map keys and
    // unique by construction, so comparing them asserts nothing at all.
    final byFamily = <String, Map<int, String>>{};
    for (final MapEntry(key: name, value: color) in pool.entries) {
      final family = RegExp('^([a-z]+)').firstMatch(name)!.group(1)!;
      final measured = lStar(color).round();
      final seen = byFamily.putIfAbsent(family, () => <int, String>{});
      expect(
        seen[measured],
        isNull,
        reason:
            '$name and ${seen[measured]} both measure L*=$measured — '
            'two tones a reader cannot tell apart from their names',
      );
      seen[measured] = name;
    }
    expect(byFamily.keys, isNotEmpty);
  });

  test('clay56 feeds BOTH borderStrong and stateMissed, deliberately', () {
    // An unticked day carries exactly the weight of a control boundary:
    // present, legible at 3.65:1, emotionally neutral. A later "cleanup" that
    // splits them into two primitives is a re-measure, not a tidy-up.
    final source = File('lib/theme/primitives.dart').readAsStringSync();
    final clay56Doc = source.substring(
      source.indexOf('/// borderStrong'),
      source.indexOf('static const Color clay56'),
    );
    expect(clay56Doc, contains('stateMissed'));
    expect(clay56Doc.toLowerCase(), contains('deliberate'));
  });

  group('the primitives file itself', () {
    // ONE file read, asserting two properties of THAT file. Not a policy gate:
    // tool/check_bans.sh is the repo's only grep entry point, and this is not a
    // rule about the tree, it is the completeness proof for the table above.
    final source = File('lib/theme/primitives.dart').readAsStringSync();
    final declared = RegExp(
      r'static const Color ([a-z]+\d+) =',
    ).allMatches(source).map((m) => m.group(1)!).toSet();

    test('the table above lists every declared primitive', () {
      expect(
        declared.difference(pool.keys.toSet()),
        isEmpty,
        reason: 'primitives declared but never measured by this test',
      );
      expect(
        pool.keys.toSet().difference(declared),
        isEmpty,
        reason: 'this test names primitives the file does not declare',
      );
    });

    test('the gradient-only stops get no primitive name', () {
      // A named stop invites a widget to use it as a flat fill, and no row of
      // the contrast budget ever measured one as a background.
      for (final stop in const <String>[
        '0xFFF9633F',
        '0xFFFF9A4D',
        '0xFFFFC46A',
        '0xFFFFF7EE',
      ]) {
        expect(source, isNot(contains(stop)), reason: stop);
      }
    });
  });
}
