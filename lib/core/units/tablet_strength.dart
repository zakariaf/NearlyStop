/// A tablet the patient actually holds.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// A tablet strength: an amount, strictly greater than zero, that one whole
/// tablet delivers.
///
/// Deliberately a `final class` and **not** an `extension type`. An extension
/// type is an explicitly unsafe abstraction — the representation stays
/// reachable, so it cannot enforce the `> 0` invariant it would exist for, and
/// a zero-strength tablet makes the composition solver loop forever
/// (`dart3-idioms-and-coding-standards` rule 2).
///
/// The stored field is [hundredths] rather than a [Milligrams], because a const
/// assert cannot read a field of another const object — and this type has to be
/// const-constructible so fixtures and the golden-vector tool can declare a
/// strength list without a runtime step. [mg] projects it back.
///
/// Splittability is **not** here: it is a plan-level flag (`allowHalves`), per
/// `SPEC.md` §4.4, because the patient either has a pill cutter or does not.
@immutable
final class TabletStrength implements Comparable<TabletStrength> {
  /// Creates a strength from [mg].
  TabletStrength(Milligrams mg) : this.fromHundredths(mg.hundredths);

  /// Creates a strength from an exact count of hundredths of a milligram.
  const TabletStrength.fromHundredths(this.hundredths)
    : assert(hundredths > 0, 'a tablet strength must be greater than zero');

  /// Hundredths of a milligram, matching [Milligrams.hundredths].
  final int hundredths;

  /// The amount one whole tablet delivers.
  Milligrams get mg => Milligrams.fromHundredths(hundredths);

  @override
  int compareTo(TabletStrength other) => hundredths.compareTo(other.hundredths);

  @override
  bool operator ==(Object other) =>
      other is TabletStrength && other.hundredths == hundredths;

  @override
  int get hashCode => hundredths.hashCode;

  @override
  String toString() => mg.toString();
}
