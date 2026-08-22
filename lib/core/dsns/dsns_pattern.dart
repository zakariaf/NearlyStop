/// The eleven-block "Dead Slow and Nearly Stop" pattern, as data.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/result.dart';

/// The number of days one DSNS step runs, before holds.
const int dsnsStepDays = 52;

/// One block of the DSNS calendar.
///
/// A block is a run of days containing exactly one day of the *occasional* dose
/// and some number of the *usual* one. In blocks 1–6 the occasional day is the
/// **new** dose and the gap between those days shrinks (6, 5, 4, 3, 2, 1); at
/// the midpoint the roles invert and blocks 7–11 carry one **old** day against
/// runs of new ones (2, 3, 4, 5, 6).
@immutable
final class DsnsBlock {
  /// Creates block [index] with [newDays] days at the new dose and [oldDays] at
  /// the old one.
  const DsnsBlock({
    required this.index,
    required this.newDays,
    required this.oldDays,
  });

  /// 1-based position in the pattern, 1–11.
  final int index;

  /// Days in this block at the **new** (lower) dose.
  final int newDays;

  /// Days in this block at the **old** (higher) dose.
  final int oldDays;

  /// Total days in this block.
  int get length => newDays + oldDays;

  /// Whether the day that **leads** this block is the new dose.
  ///
  /// The single day always leads its block (`SPEC.md` §3.1, decided for v1). In
  /// blocks 1–6 that leading day is the new dose; from block 7 it is the old
  /// one.
  bool get leadsWithNew => index <= 6;

  @override
  bool operator ==(Object other) =>
      other is DsnsBlock &&
      other.index == index &&
      other.newDays == newDays &&
      other.oldDays == oldDays;

  @override
  int get hashCode => Object.hash(index, newDays, oldDays);

  @override
  String toString() => 'DsnsBlock($index: $newDays new, $oldDays old)';
}

/// A versioned DSNS block table.
///
/// `SPEC.md` §3.1, reproduced here so it is readable at the call site:
///
/// | Block | Pattern | Days | Cumulative |
/// |---|---|---|---|
/// | 1 | 1 day new, 6 days old | 7 | 7 |
/// | 2 | 1 day new, 5 days old | 6 | 13 |
/// | 3 | 1 day new, 4 days old | 5 | 18 |
/// | 4 | 1 day new, 3 days old | 4 | 22 |
/// | 5 | 1 day new, 2 days old | 3 | 25 |
/// | 6 | 1 day new, 1 day old | 2 | 27 |
/// | 7 | 1 day old, 2 days new | 3 | 30 |
/// | 8 | 1 day old, 3 days new | 4 | 34 |
/// | 9 | 1 day old, 4 days new | 5 | 39 |
/// | 10 | 1 day old, 5 days new | 6 | 45 |
/// | 11 | 1 day old, 6 days new | 7 | **52** |
///
/// **52 days per step, 26 at the old dose and 26 at the new.**
///
/// **Block 6 is `1 new, 1 old` and block 7 is `1 old, 2 new`, so the crossover
/// produces two consecutive old-dose days.** That is correct and deliberate —
/// `SPEC.md` §3.1 says so explicitly. Do not "fix" it by reordering.
///
/// [version] is what `Step.patternVersion` freezes, so that if this table is
/// ever corrected, historical steps still render exactly as the patient lived
/// them.
@immutable
final class DsnsPattern {
  /// The v1 table — the only version this build knows.
  ///
  /// [version] and [blocks] are getters rather than fields because a const
  /// class may not initialise a field. When a v2 table exists this becomes a
  /// `sealed` hierarchy with one leaf per version, which is also what makes
  /// `forVersion` exhaustive.
  const DsnsPattern.v1();

  /// The frozen table identifier stored on every step.
  int get version => 1;

  /// The eleven blocks, in order.
  List<DsnsBlock> get blocks => _v1Blocks;

  static const List<DsnsBlock> _v1Blocks = <DsnsBlock>[
    DsnsBlock(index: 1, newDays: 1, oldDays: 6),
    DsnsBlock(index: 2, newDays: 1, oldDays: 5),
    DsnsBlock(index: 3, newDays: 1, oldDays: 4),
    DsnsBlock(index: 4, newDays: 1, oldDays: 3),
    DsnsBlock(index: 5, newDays: 1, oldDays: 2),
    DsnsBlock(index: 6, newDays: 1, oldDays: 1),
    DsnsBlock(index: 7, newDays: 2, oldDays: 1),
    DsnsBlock(index: 8, newDays: 3, oldDays: 1),
    DsnsBlock(index: 9, newDays: 4, oldDays: 1),
    DsnsBlock(index: 10, newDays: 5, oldDays: 1),
    DsnsBlock(index: 11, newDays: 6, oldDays: 1),
  ];

  /// Returns the table for [version], or [UnknownPatternVersion].
  static Result<DsnsPattern, DomainFailure> forVersion(int version) =>
      version == 1
      ? const Ok(DsnsPattern.v1())
      : Err(UnknownPatternVersion(version));

  /// Days in the whole step: 52.
  int get totalDays => blocks.fold(0, (sum, block) => sum + block.length);

  /// Days in the whole step at the new dose: 26.
  int get totalNewDays => blocks.fold(0, (sum, block) => sum + block.newDays);

  /// Days in the whole step at the old dose: 26.
  int get totalOldDays => blocks.fold(0, (sum, block) => sum + block.oldDays);
}
