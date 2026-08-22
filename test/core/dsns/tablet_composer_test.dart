// Pure `package:test`. The composer is f(target, strengths, halves) -> parts,
// and the second-largest thing on the Today screen is read from its output
// every morning for 780 days.
import 'dart:math';

import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:test/test.dart';

import '../../fixtures/taper_fixture.dart';

TabletComposition composed(
  num target,
  List<num> strengths, {
  required bool allowHalves,
}) {
  final result = composeTablets(
    target: mg(target),
    strengths: held(strengths),
    allowHalves: allowHalves,
  );
  expect(
    result,
    isA<Ok<TabletComposition, DomainFailure>>(),
    reason: 'expected $target mg to compose from $strengths',
  );
  return (result as Ok<TabletComposition, DomainFailure>).value;
}

DomainFailure refused(
  num target,
  List<num> strengths, {
  required bool allowHalves,
}) {
  final result = composeTablets(
    target: mg(target),
    strengths: held(strengths),
    allowHalves: allowHalves,
  );
  expect(
    result,
    isA<Err<TabletComposition, DomainFailure>>(),
    reason: 'expected $target mg to be refused',
  );
  return (result as Err<TabletComposition, DomainFailure>).failure;
}

/// An INDEPENDENT oracle: brute-force bounded enumeration, written here and
/// never calling the solver under test. Returns the minimum `(totalTablets,
/// splitCount)` under `(tablets asc, splits asc)`, or null.
(int tablets, int splits)? oracleBest(
  int targetHundredths,
  List<int> strengthHundredths, {
  required bool allowHalves,
}) {
  (int, int)? best;
  void consider(int tablets, int splits) {
    if (best == null ||
        tablets < best!.$1 ||
        (tablets == best!.$1 && splits < best!.$2)) {
      best = (tablets, splits);
    }
  }

  void enumerate(int index, int remaining, int tabletsSoFar, int splits) {
    if (remaining == 0) {
      consider(tabletsSoFar + splits, splits);
      return;
    }
    if (index >= strengthHundredths.length) return;
    final strength = strengthHundredths[index];
    for (var count = 0; count * strength <= remaining; count++) {
      enumerate(
        index + 1,
        remaining - count * strength,
        tabletsSoFar + count,
        splits,
      );
    }
  }

  enumerate(0, targetHundredths, 0, 0);
  if (allowHalves) {
    for (final strength in strengthHundredths) {
      if (!strength.isEven) continue;
      final rest = targetHundredths - strength ~/ 2;
      if (rest < 0) continue;
      enumerate(0, rest, 0, 1);
    }
  }
  return best;
}

void main() {
  group('the SPEC.md §3.3 worked example', () {
    test('6.5mg from [5, 1] with halves is 1x5 + 1x1 + half a 1', () {
      final c = composed(6.5, [5, 1], allowHalves: true);
      expect(c.counts, <TabletCount>[
        TabletCount(mg(5), 1),
        TabletCount(mg(1), 1),
      ]);
      expect(c.half, TabletCount(mg(1), 1));
      expect(c.totalTablets, 3);
      expect(c.splitCount, 1);
    });
  });

  test('minimises TOTAL TABLETS before splits', () {
    // [2.5, 1] with halves at 4mg: 4 x 1mg is reachable with zero splits, but
    // 1 x 2.5 + 1 x 1 + half a 1 is three objects to count out at a kitchen
    // table instead of four. Total tablets is the PRIMARY key.
    final c = composed(4, [2.5, 1], allowHalves: true);
    expect(c.totalTablets, 3);
    expect(c.splitCount, 1);
    expect(c.counts, <TabletCount>[
      TabletCount(mg(2.5), 1),
      TabletCount(mg(1), 1),
    ]);
    expect(c.half, TabletCount(mg(1), 1));
  });

  test('breaks a genuine tie on the largest halved strength', () {
    // [5, 2, 1] with halves at 6.5mg has two candidates at (3 tablets,
    // 1 split): half a 5 + 2 x 2, and 1 x 5 + 1 x 1 + half a 1.
    final c = composed(6.5, [5, 2, 1], allowHalves: true);
    expect(c.totalTablets, 3);
    expect(c.splitCount, 1);
    expect(c.half, TabletCount(mg(5), 1));
    expect(c.counts, <TabletCount>[TabletCount(mg(2), 2)]);
  });

  test(
    'reconstructs deterministically: largest strength wins an equal cost',
    () {
      final c = composed(4, [4, 2, 1], allowHalves: false);
      expect(c.counts, <TabletCount>[TabletCount(mg(4), 1)]);
      expect(c.totalTablets, 1);
    },
  );

  test('refuses rather than rounding when halves are off', () {
    final failure = refused(6.5, [5, 1], allowHalves: false);
    expect(
      failure,
      isA<UnachievableDose>()
          .having((f) => f.target, 'target', mg(6.5))
          .having((f) => f.strengths, 'strengths', <Milligrams>[mg(5), mg(1)])
          .having((f) => f.allowHalves, 'allowHalves', false),
    );
  });

  test('refuses an empty strength list', () {
    expect(
      refused(5, const <num>[], allowHalves: true),
      isA<NoStrengthsHeld>(),
    );
  });

  test('guards the solver range at 100mg, on both sides', () {
    expect(composed(100, [5, 1], allowHalves: false).totalTablets, 20);
    expect(
      refused(100.01, [5, 1], allowHalves: true),
      isA<DoseOutOfRange>().having((f) => f.dose, 'dose', mg(100.01)),
    );
  });

  test('composes zero as no tablets at all', () {
    final c = composed(0, [5, 1], allowHalves: true);
    expect(c.counts, isEmpty);
    expect(c.half, isNull);
    expect(c.totalTablets, 0);
  });

  test('never returns more than one half', () {
    for (var h = 25; h <= 3000; h += 25) {
      final result = composeTablets(
        target: Milligrams.fromHundredths(h),
        strengths: held([5, 1]),
        allowHalves: true,
      );
      if (result case Ok<TabletComposition, DomainFailure>(:final value)) {
        expect(value.splitCount, lessThanOrEqualTo(1), reason: '$h hundredths');
      }
    }
  });

  test('the parts always sum to the target, in hundredths', () {
    for (var h = 25; h <= 3000; h += 25) {
      final result = composeTablets(
        target: Milligrams.fromHundredths(h),
        strengths: held([5, 1]),
        allowHalves: true,
      );
      if (result case Ok<TabletComposition, DomainFailure>(:final value)) {
        expect(value.totalMg.hundredths, h, reason: '$h hundredths');
      }
    }
  });

  test('is deterministic', () {
    for (var h = 25; h <= 3000; h += 25) {
      TabletComposition? once(int hundredths) {
        final result = composeTablets(
          target: Milligrams.fromHundredths(hundredths),
          strengths: held([5, 2.5, 1]),
          allowHalves: true,
        );
        return switch (result) {
          Ok<TabletComposition, DomainFailure>(:final value) => value,
          // A Failure carries no value equality on purpose, so an unreachable
          // dose is compared as "unreachable both times".
          Err<TabletComposition, DomainFailure>() => null,
        };
      }

      expect(once(h), once(h), reason: '$h hundredths');
    }
  });

  group('fuzz against an independent brute-force oracle', () {
    test('matches the oracle on cost, sum and reachability', () {
      final rng = Random(20260421);
      const pool = <num>[0.5, 1, 2, 2.5, 5, 10, 20, 25];
      for (var seed = 0; seed < 1000; seed++) {
        final subset = <num>[
          for (final s in pool)
            if (rng.nextBool()) s,
        ];
        if (subset.isEmpty) subset.add(pool[rng.nextInt(pool.length)]);
        final allowHalves = rng.nextBool();
        final targetHundredths = (rng.nextInt(240) + 1) * 25;
        final reason =
            'seed=$seed strengths=$subset halves=$allowHalves '
            'target=$targetHundredths hundredths';

        final result = composeTablets(
          target: Milligrams.fromHundredths(targetHundredths),
          strengths: held(subset),
          allowHalves: allowHalves,
        );
        final expected = oracleBest(
          targetHundredths,
          <int>[for (final s in subset) (s * 100).round()]
            ..sort((a, b) => b.compareTo(a)),
          allowHalves: allowHalves,
        );

        if (expected == null) {
          expect(
            result,
            isA<Err<TabletComposition, DomainFailure>>(),
            reason: reason,
          );
          expect(
            (result as Err<TabletComposition, DomainFailure>).failure,
            isA<UnachievableDose>(),
            reason: reason,
          );
          continue;
        }

        expect(
          result,
          isA<Ok<TabletComposition, DomainFailure>>(),
          reason: reason,
        );
        final composition =
            (result as Ok<TabletComposition, DomainFailure>).value;
        expect(
          composition.totalMg.hundredths,
          targetHundredths,
          reason: reason,
        );
        expect(
          (composition.totalTablets, composition.splitCount),
          expected,
          reason: reason,
        );
      }
    });
  });

  group('value semantics', () {
    test('a TabletCount equates and hashes on strength and count', () {
      expect(TabletCount(mg(5), 2), TabletCount(mg(5), 2));
      expect(TabletCount(mg(5), 2).hashCode, TabletCount(mg(5), 2).hashCode);
      expect(TabletCount(mg(5), 2) == TabletCount(mg(5), 3), isFalse);
      expect(TabletCount(mg(5), 2) == TabletCount(mg(1), 2), isFalse);
      expect(TabletCount(mg(5), 2).toString(), '2 x 5mg');
    });

    test('a TabletComposition equates on its parts, in order', () {
      final a = composed(6.5, [5, 1], allowHalves: true);
      final b = composed(6.5, [5, 1], allowHalves: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == composed(6, [5, 1], allowHalves: true), isFalse);
      expect(a == composed(10, [5, 1], allowHalves: true), isFalse);
      // A non-composition must never compare equal to one.
      expect(a == Object(), isFalse);
      expect(a.toString(), contains('half'));
      expect(
        composed(10, [5, 1], allowHalves: true).toString(),
        isNot(contains('half')),
      );
    });
  });

  group('isAchievable', () {
    test('agrees with composeTablets on every quarter-mg up to 30mg', () {
      for (var h = 25; h <= 3000; h += 25) {
        final target = Milligrams.fromHundredths(h);
        final byComposition =
            composeTablets(
                  target: target,
                  strengths: held([5, 1]),
                  allowHalves: true,
                )
                is Ok<TabletComposition, DomainFailure>;
        expect(
          isAchievable(target, held([5, 1]), allowHalves: true),
          byComposition,
          reason: '$h hundredths',
        );
      }
    });
  });
}
