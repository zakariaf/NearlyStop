// Pure `package:test`. The block table is the product; this file is SPEC.md
// §3.1 typed out and diffed row for row against the code.
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/dsns_pattern.dart';
import 'package:nearlystop/core/result.dart';
import 'package:test/test.dart';

/// SPEC.md §3.1, transcribed by hand: (block, new, old, length, cumulative).
const List<(int, int, int, int, int)> specTable = [
  (1, 1, 6, 7, 7),
  (2, 1, 5, 6, 13),
  (3, 1, 4, 5, 18),
  (4, 1, 3, 4, 22),
  (5, 1, 2, 3, 25),
  (6, 1, 1, 2, 27),
  (7, 2, 1, 3, 30),
  (8, 3, 1, 4, 34),
  (9, 4, 1, 5, 39),
  (10, 5, 1, 6, 45),
  (11, 6, 1, 7, 52),
];

void main() {
  const pattern = DsnsPattern.v1();

  test(
    'reproduces SPEC.md §3.1 row for row, including the cumulative column',
    () {
      expect(pattern.blocks, hasLength(specTable.length));
      var cumulative = 0;
      for (final (index, newDays, oldDays, length, expectedCumulative)
          in specTable) {
        final block = pattern.blocks[index - 1];
        cumulative += block.length;
        expect(block.index, index, reason: 'block $index index');
        expect(block.newDays, newDays, reason: 'block $index newDays');
        expect(block.oldDays, oldDays, reason: 'block $index oldDays');
        expect(block.length, length, reason: 'block $index length');
        expect(
          cumulative,
          expectedCumulative,
          reason: 'block $index cumulative',
        );
      }
    },
  );

  test('runs 52 days', () => expect(pattern.totalDays, 52));
  test(
    'spends 26 days on the new dose',
    () => expect(pattern.totalNewDays, 26),
  );
  test(
    'spends 26 days on the old dose',
    () => expect(pattern.totalOldDays, 26),
  );

  test('the single day leads, and it is the new dose only in blocks 1-6', () {
    for (final block in pattern.blocks) {
      expect(
        block.leadsWithNew,
        block.index <= 6,
        reason: 'block ${block.index}',
      );
    }
  });

  test('blocks 7 to 11 all have exactly one old day', () {
    for (final block in pattern.blocks.where((b) => b.index >= 7)) {
      expect(block.oldDays, 1, reason: 'block ${block.index}');
    }
  });

  test(
    'the crossover produces two consecutive old days, and that is correct',
    () {
      // Block 6 is (1 new, 1 old) so it ENDS on an old day; block 7 is
      // (1 old, 2 new) so it OPENS on one. SPEC.md §3.1 accepts this
      // explicitly.
      // Do not "fix" it by reordering.
      final six = pattern.blocks[5];
      final seven = pattern.blocks[6];
      expect((six.newDays, six.oldDays), (1, 1));
      expect((seven.newDays, seven.oldDays), (2, 1));
      expect(six.leadsWithNew, isTrue);
      expect(seven.leadsWithNew, isFalse);
    },
  );

  group('forVersion', () {
    test('knows version 1', () {
      expect(DsnsPattern.forVersion(1), isA<Ok<DsnsPattern, DomainFailure>>());
    });

    test('carries the requested version back on an unknown one', () {
      for (final version in [0, 2]) {
        final result = DsnsPattern.forVersion(version);
        expect(
          result,
          isA<Err<DsnsPattern, DomainFailure>>(),
          reason: 'version $version',
        );
        expect(
          (result as Err<DsnsPattern, DomainFailure>).failure,
          isA<UnknownPatternVersion>().having(
            (f) => f.version,
            'version',
            version,
          ),
          reason: 'version $version',
        );
      }
    });
  });
}
