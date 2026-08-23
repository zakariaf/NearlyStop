// Bidi isolation, asserted by code point.
//
// "It wraps in something" is not the test. The app's real mixed-direction
// problem is the tablet breakdown — `1 × 5mg · 2 × 1mg · ½ × 1mg` — a run of
// numbers and a Latin unit inside a Perso-Arabic sentence, which reorders
// wrongly without isolation.
import 'package:nearlystop/l10n/bidi.dart';
import 'package:test/test.dart';

/// The strings this app actually produces at a direction boundary.
const samples = <String>[
  '1 × 5mg · 4 × 1mg',
  '1 × 5mg · 2 × 1mg · ½ × 1mg',
  '10mg → 9mg',
  'Prednisolone',
  '۱ عدد ۵ میلی‌گرمی',
  '',
];

void main() {
  test('isolateLtr wraps in LRI…PDI, by code point', () {
    expect(isolateLtr('1 × 5mg'), '\u20661 × 5mg\u2069');
  });

  test('isolateRtl wraps in RLI…PDI, by code point', () {
    expect(isolateRtl('۹ میلی‌گرم'), '\u2067۹ میلی‌گرم\u2069');
  });

  test('FSI never appears for a value whose direction is known', () {
    // First-strong mis-guesses on a leading `½` or a leading digit — which is
    // exactly the shape of the tablet breakdown.
    for (final sample in samples) {
      expect(isolateLtr(sample), isNot(contains('\u2068')), reason: sample);
      expect(isolateRtl(sample), isNot(contains('\u2068')), reason: sample);
    }
  });

  test('no legacy embedding survives', () {
    // LRE/RLE/PDF/LRO/RLO. They do not nest and they leak past their own end.
    for (final sample in samples) {
      for (final legacy in <String>[
        '\u202A',
        '\u202B',
        '\u202C',
        '\u202D',
        '\u202E',
      ]) {
        expect(isolateLtr(sample), isNot(contains(legacy)), reason: sample);
      }
    }
  });

  test('stripIsolates round-trips every sample', () {
    for (final sample in samples) {
      expect(stripIsolates(isolateLtr(sample)), sample, reason: sample);
      expect(stripIsolates(isolateRtl(sample)), sample, reason: sample);
    }
  });

  test('stripIsolates removes every U+2066–2069, including doubled', () {
    const doubled = '\u2066\u2067x\u2069\u2069';

    expect(stripIsolates(doubled), 'x');
    expect(stripIsolates(isolateLtr(isolateRtl('1 × 5mg'))), '1 × 5mg');
  });

  test('stripIsolates leaves everything else byte-identical', () {
    // Pinned against a string carrying the characters this app really uses.
    const rich = '۱٫۲۵ × ½ → 9mg · تقریباً';

    expect(stripIsolates(rich), rich);
    expect(stripIsolates(''), '');
  });

  test('the export boundary is real', () {
    // EPIC-13 writes CSV. An isolate character in a CSV field, a database write
    // or a search query is invisible in review and corrupts the value.
    for (final sample in samples) {
      final exported = stripIsolates(isolateLtr(sample));

      for (final rune in exported.runes) {
        expect(
          rune,
          isNot(inInclusiveRange(0x2066, 0x2069)),
          reason: 'U+${rune.toRadixString(16)} survived export of "$sample"',
        );
      }
    }
  });

  test('isolating an already-isolated value does not double up', () {
    // The realistic misuse: a caller isolates at the view layer and a helper
    // isolated it already.
    final once = isolateLtr('1 × 5mg');

    expect(isolateLtr(once), once);
  });
}
