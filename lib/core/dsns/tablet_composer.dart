/// Turning a dose into the tablets a person counts out at a kitchen table.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';

/// The largest dose the composition solver will search, in hundredths.
///
/// 100 mg. The highest realistic PMR/GCA starting dose is 60 mg, so this bounds
/// the dynamic-programming table rather than expressing a clinical limit.
const int maxComposableHundredths = 10000;

/// A count of one tablet strength.
@immutable
final class TabletCount {
  /// Records [count] tablets of [strength].
  const TabletCount(this.strength, this.count);

  /// The strength of the tablet being counted.
  final Milligrams strength;

  /// How many. Always ≥ 1 in a returned composition; a half is carried
  /// separately on [TabletComposition.half].
  final int count;

  @override
  bool operator ==(Object other) =>
      other is TabletCount &&
      other.strength == strength &&
      other.count == count;

  @override
  int get hashCode => Object.hash(strength, count);

  @override
  String toString() => '$count x $strength';
}

/// How one day's dose is made up.
///
/// Presentation reads [counts] and [half] directly and formats them per
/// `SPEC.md` §4.1 (`1 × 5mg · 4 × 1mg · ½ × 1mg`). The domain never builds that
/// string — the separator, the multiplication sign and the half glyph are all
/// locale decisions.
@immutable
final class TabletComposition {
  /// Creates a composition of whole tablets plus at most one half.
  const TabletComposition({required this.counts, required this.half});

  /// Whole tablets, **largest strength first**.
  final List<TabletCount> counts;

  /// The one optional half tablet, or `null`.
  ///
  /// v1 allows **at most one** half in a composition: that is what `SPEC.md`
  /// §3.3's formula says and what people actually do. A solver that returned "½
  /// × 5mg + ½ × 1mg" would be technically cheaper and practically absurd.
  final TabletCount? half;

  /// Whole tablets plus the half, if there is one — the number of objects the
  /// patient physically picks up.
  int get totalTablets =>
      counts.fold(0, (sum, c) => sum + c.count) + splitCount;

  /// 0 or 1.
  int get splitCount => half == null ? 0 : 1;

  /// The dose these parts add up to. Equal to the requested target by
  /// construction; asserted as a tripwire inside [composeTablets].
  Milligrams get totalMg {
    var hundredths = 0;
    for (final c in counts) {
      hundredths += c.strength.hundredths * c.count;
    }
    final halfPart = half;
    if (halfPart != null) hundredths += halfPart.strength.hundredths ~/ 2;
    return Milligrams.fromHundredths(hundredths);
  }

  @override
  bool operator ==(Object other) {
    if (other is! TabletComposition) return false;
    if (other.half != half) return false;
    if (other.counts.length != counts.length) return false;
    for (var i = 0; i < counts.length; i++) {
      if (other.counts[i] != counts[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(counts), half);

  @override
  String toString() =>
      'TabletComposition($counts${half == null ? '' : ' + half $half'})';
}

/// Composes [target] from [strengths], minimising **total tablets first, then
/// splits**.
///
/// The order is `SPEC.md` §3.3, normatively, and it is not the same as "avoid
/// halves". With UK strengths `[2.5, 1]` and halves allowed, 4 mg is reachable
/// as `4 × 1mg` with no split — but `1 × 2.5 + 1 × 1 + ½ × 1` is three objects
/// instead of four, and the breakdown is read every morning for 780 days. So
/// every candidate is enumerated and then ranked by `(totalTablets asc,
/// splitCount asc, largestHalvedStrength desc)`; the solver never stops at the
/// first reachable one.
///
/// **Never rounds.** An unreachable dose returns [UnachievableDose] carrying
/// the target, the strengths and the halves flag, so the presentation layer can
/// write the sentence. Silent rounding in a dosing app is the one unforgivable
/// bug.
///
/// Total: returns for every input. [NoStrengthsHeld] when [strengths] is empty,
/// [DoseOutOfRange] outside `0 … 100 mg`.
Result<TabletComposition, DomainFailure> composeTablets({
  required Milligrams target,
  required List<TabletStrength> strengths,
  required bool allowHalves,
}) {
  if (strengths.isEmpty) return const Err(NoStrengthsHeld());
  if (target.hundredths < 0 || target.hundredths > maxComposableHundredths) {
    return Err(DoseOutOfRange(target));
  }

  // Deduplicated and descending, so the reconstruction below can prefer the
  // largest strength among equal-cost options just by trying it first.
  final coins = <int>{for (final s in strengths) s.mg.hundredths}.toList()
    ..sort((a, b) => b.compareTo(a));
  final flatStrengths = <Milligrams>[
    for (final c in coins) Milligrams.fromHundredths(c),
  ];

  final table = _MinTabletTable(coins, target.hundredths);

  _Candidate? best;
  void offer(_Candidate? candidate) {
    if (candidate == null) return;
    if (best == null || candidate.beats(best!)) best = candidate;
  }

  offer(_Candidate.zeroHalf(table, target.hundredths, coins));
  if (allowHalves) {
    for (final coin in coins) {
      if (!coin.isEven) continue;
      offer(_Candidate.withHalf(table, target.hundredths, coins, coin));
    }
  }

  final winner = best;
  if (winner == null) {
    return Err(
      UnachievableDose(target, flatStrengths, allowHalves: allowHalves),
    );
  }

  final composition = winner.toComposition();
  // Tripwire: free in release, and it catches a reconstruction bug the moment
  // it happens rather than on someone's kitchen table.
  assert(
    composition.totalMg == target,
    'composition ${composition.totalMg} != target $target',
  );
  return Ok(composition);
}

/// Whether [target] can be made from [strengths] at all.
///
/// The step-size rule needs this for every candidate increment, and asking it
/// through [composeTablets] would reconstruct a composition nobody reads.
bool isAchievable(
  Milligrams target,
  List<TabletStrength> strengths, {
  required bool allowHalves,
}) {
  if (strengths.isEmpty) return false;
  if (target.hundredths < 0 || target.hundredths > maxComposableHundredths) {
    return false;
  }
  if (target.hundredths == 0) return true;

  final coins = <int>{for (final s in strengths) s.mg.hundredths}.toList()
    ..sort((a, b) => b.compareTo(a));
  final table = _MinTabletTable(coins, target.hundredths);
  if (table.isReachable(target.hundredths)) return true;
  if (!allowHalves) return false;
  for (final coin in coins) {
    if (!coin.isEven) continue;
    final rest = target.hundredths - coin ~/ 2;
    if (rest >= 0 && table.isReachable(rest)) return true;
  }
  return false;
}

/// The largest achievable increment at or below [ceilingHundredths], or `null`.
///
/// Lives here, beside the solver, because it is one walk down a single
/// dynamic-programming table. Asking it through [isAchievable] once per
/// candidate value rebuilds that table for every value — quadratic in the
/// ceiling, on the path the step-size rule takes for every dose in the plan.
int? largestAchievableAtMost(
  int ceilingHundredths,
  List<TabletStrength> strengths, {
  required bool allowHalves,
}) {
  if (strengths.isEmpty || ceilingHundredths < 1) return null;
  final capped = ceilingHundredths > maxComposableHundredths
      ? maxComposableHundredths
      : ceilingHundredths;
  final coins = <int>{for (final s in strengths) s.hundredths}.toList()
    ..sort((a, b) => b.compareTo(a));
  final table = _MinTabletTable(coins, capped);

  for (var value = capped; value >= 1; value--) {
    if (table.isReachable(value)) return value;
    if (!allowHalves) continue;
    for (final coin in coins) {
      if (coin.isEven && table.isReachable(value - coin ~/ 2)) return value;
    }
  }
  return null;
}

/// `minTablets[value]` for every value up to the target, computed once.
///
/// One table serves the zero-half candidate and every half candidate, because
/// each of those only needs `minTablets[target - halfOfSomeStrength]`.
final class _MinTabletTable {
  factory _MinTabletTable(List<int> descendingCoins, int upTo) {
    final minTablets = List<int>.filled(upTo + 1, _unreachable);
    final choice = List<int>.filled(upTo + 1, -1);
    minTablets[0] = 0;
    for (var value = 1; value <= upTo; value++) {
      // Coins descend, and a later coin only wins on a STRICTLY lower cost, so
      // the largest strength wins every tie. That is what makes the
      // reconstruction deterministic across runs and platforms.
      for (var index = 0; index < descendingCoins.length; index++) {
        final coin = descendingCoins[index];
        if (coin > value) continue;
        final previous = minTablets[value - coin];
        if (previous == _unreachable) continue;
        if (previous + 1 < minTablets[value]) {
          minTablets[value] = previous + 1;
          choice[value] = index;
        }
      }
    }
    return _MinTabletTable._(minTablets, choice);
  }

  _MinTabletTable._(this._minTablets, this._choice);

  static const int _unreachable = 1 << 30;

  final List<int> _minTablets;
  final List<int> _choice;

  bool isReachable(int value) =>
      value >= 0 &&
      value < _minTablets.length &&
      _minTablets[value] != _unreachable;

  int tabletsFor(int value) => _minTablets[value];

  /// Walks [_choice] back into per-strength counts, largest strength first.
  List<TabletCount> reconstruct(int value, List<int> descendingCoins) {
    final counts = List<int>.filled(descendingCoins.length, 0);
    var remaining = value;
    while (remaining > 0) {
      final index = _choice[remaining];
      counts[index]++;
      remaining -= descendingCoins[index];
    }
    return <TabletCount>[
      for (var i = 0; i < counts.length; i++)
        if (counts[i] > 0)
          TabletCount(Milligrams.fromHundredths(descendingCoins[i]), counts[i]),
    ];
  }
}

/// One reachable way to make the target, with its ranking key.
final class _Candidate {
  _Candidate._({
    required this.wholeValue,
    required this.wholeTablets,
    required this.halfStrength,
    required this.table,
    required this.coins,
  });

  static _Candidate? zeroHalf(
    _MinTabletTable table,
    int target,
    List<int> coins,
  ) {
    if (!table.isReachable(target)) return null;
    return _Candidate._(
      wholeValue: target,
      wholeTablets: table.tabletsFor(target),
      halfStrength: null,
      table: table,
      coins: coins,
    );
  }

  static _Candidate? withHalf(
    _MinTabletTable table,
    int target,
    List<int> coins,
    int halfOf,
  ) {
    final rest = target - halfOf ~/ 2;
    if (rest < 0 || !table.isReachable(rest)) return null;
    return _Candidate._(
      wholeValue: rest,
      wholeTablets: table.tabletsFor(rest),
      halfStrength: halfOf,
      table: table,
      coins: coins,
    );
  }

  final int wholeValue;
  final int wholeTablets;
  final int? halfStrength;
  final _MinTabletTable table;
  final List<int> coins;

  int get splitCount => halfStrength == null ? 0 : 1;

  int get totalTablets => wholeTablets + splitCount;

  /// `(totalTablets asc, splitCount asc, largestHalvedStrength desc)`.
  bool beats(_Candidate other) {
    if (totalTablets != other.totalTablets) {
      return totalTablets < other.totalTablets;
    }
    if (splitCount != other.splitCount) return splitCount < other.splitCount;
    return (halfStrength ?? 0) > (other.halfStrength ?? 0);
  }

  TabletComposition toComposition() => TabletComposition(
    counts: table.reconstruct(wholeValue, coins),
    half: halfStrength == null
        ? null
        : TabletCount(Milligrams.fromHundredths(halfStrength!), 1),
  );
}
