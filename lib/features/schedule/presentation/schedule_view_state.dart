/// The Schedule screen as blocks, not days.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// Where a block sits relative to the reader.
enum BlockStatus {
  /// Its days are behind them.
  completed,

  /// Today is inside it.
  current,

  /// It has not started.
  upcoming,
}

/// One day, ready to render.
///
/// Every string is pre-formatted and pre-localized. Which SOURCE each one came
/// from is a correctness rule, not a detail — see [recordedSource].
@immutable
final class ScheduleDayVm {
  /// Creates one row.
  const ScheduleDayVm({
    required this.date,
    required this.dayLabel,
    required this.doseLabel,
    required this.tabletsLabel,
    required this.unachievable,
    required this.state,
    required this.isNewDose,
    required this.isHoldDay,
    required this.holdLabel,
    required this.tickable,
    required this.plannedMg,
    required this.recordedSource,
  }) : assert(
         isHoldDay == (holdLabel != null),
         'a hold day is explained by a WORD, never by a glyph alone — and a '
         'day that is not held has nothing to explain',
       ),
       assert(
         state != DayState.taken || recordedSource,
         'a TAKEN row must be labelled from what was RECORDED, not from the '
         'derived plan. SPEC.md 5.2: the generator recomposes every day from '
         'the plan CURRENT strengths, so a past row rendered from it silently '
         'rewrites itself to a breakdown the person never took.',
       );

  /// The calendar day. The only value a callback needs.
  final LocalDate date;

  /// "Wed 16 Apr", locale-formatted.
  final String dayLabel;

  /// "9mg".
  final String doseLabel;

  /// "1 × 5mg · 4 × 1mg", or the unachievable message.
  final String tabletsLabel;

  /// Whether [tabletsLabel] is a warning rather than a breakdown.
  final bool unachievable;

  /// One of exactly four (CONTRACTS.md §1).
  final DayState state;

  /// A separate channel, never a fifth [DayState] member.
  final bool isNewDose;

  /// Inserted by a `HoldEvent`.
  ///
  /// A hold day repeats its host's `dayInStep`, so without a marker the list
  /// grows five identical rows all reading "day 14 of 52" — which looks like a
  /// bug on the one screen whose job is making the structure legible.
  final bool isHoldDay;

  /// "Held at block 3", or just "Held" on a day that belongs to no block.
  ///
  /// Pre-localized like every other string here. A hold on a steady-state day
  /// has no block number, and inventing one would be a lie on the screen whose
  /// job is making the structure legible.
  final String? holdLabel;

  /// Whether this row can be ticked: the active step, and not in the future.
  final bool tickable;

  /// Passed to `markTaken`. `DoseLogs.plannedMg` is non-null (CONTRACTS.md §3).
  final Milligrams plannedMg;

  /// Whether [doseLabel] and [tabletsLabel] came from a `DoseLog`.
  ///
  /// **The SPEC.md §5.2 join.** For a taken row the labels are what was
  /// RECORDED; for every other row they are the derived plan. Presentation
  /// joins, it does not overwrite — otherwise changing the prescription from
  /// 5mg+1mg to 2.5mg+1mg rewrites every day the person already swallowed.
  final bool recordedSource;

  List<Object?> get _props => <Object?>[
    date,
    dayLabel,
    doseLabel,
    tabletsLabel,
    unachievable,
    state,
    isNewDose,
    isHoldDay,
    holdLabel,
    tickable,
    plannedMg,
    recordedSource,
  ];

  @override
  bool operator ==(Object other) =>
      other is ScheduleDayVm && _listEquals(other._props, _props);

  @override
  int get hashCode => Object.hashAll(_props);
}

/// One block, with the header that teaches what it is.
@immutable
final class ScheduleBlockVm {
  /// Creates one block group.
  const ScheduleBlockVm({
    required this.blockNumber,
    required this.title,
    required this.summary,
    required this.status,
    required this.days,
  });

  /// 1–11, or null for the trailing steady-state group.
  final int? blockNumber;

  /// "Block 3 of 11", already localized.
  final String title;

  /// "one day at 9mg, then 4 days at 10mg" — generated from the block table.
  final String summary;

  /// Where it sits relative to today.
  final BlockStatus status;

  /// Its days, in order.
  final List<ScheduleDayVm> days;

  @override
  bool operator ==(Object other) =>
      other is ScheduleBlockVm &&
      other.blockNumber == blockNumber &&
      other.title == title &&
      other.summary == summary &&
      other.status == status &&
      _listEquals(other.days, days);

  @override
  int get hashCode =>
      Object.hash(blockNumber, title, summary, status, Object.hashAll(days));
}

/// Which step is on screen, and what else there is.
@immutable
final class StepNav {
  /// Describes the step switcher's state.
  const StepNav({
    required this.index,
    required this.total,
    required this.hasPrevious,
    required this.hasNext,
    required this.isActive,
  });

  /// 0-based.
  final int index;

  /// How many steps the plan has.
  final int total;

  /// Whether a completed step precedes this one.
  final bool hasPrevious;

  /// Whether a later step exists.
  final bool hasNext;

  /// Whether this is the step the reader is currently in.
  ///
  /// Only the active step's rows are tickable; everything else is history and
  /// history is read-only.
  final bool isActive;

  @override
  bool operator ==(Object other) =>
      other is StepNav &&
      other.index == index &&
      other.total == total &&
      other.hasPrevious == hasPrevious &&
      other.hasNext == hasNext &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(index, total, hasPrevious, hasNext, isActive);
}

/// What the Schedule screen is showing.
@immutable
sealed class ScheduleViewState {
  const ScheduleViewState();
}

/// No plan yet.
final class ScheduleNoPlan extends ScheduleViewState {
  /// Creates the empty state.
  const ScheduleNoPlan();

  @override
  bool operator ==(Object other) => other is ScheduleNoPlan;

  @override
  int get hashCode => (ScheduleNoPlan).hashCode;
}

/// One step's blocks.
final class ScheduleLoaded extends ScheduleViewState {
  /// Creates the loaded state.
  const ScheduleLoaded({
    required this.steps,
    required this.blocks,
    required this.todayLocator,
  });

  /// Which step, and what else there is.
  final StepNav steps;

  /// The blocks, in order, with a trailing steady-state group when needed.
  final List<ScheduleBlockVm> blocks;

  /// Where today is, or null when today is not in this step.
  ///
  /// The list opens centred here. A browsed completed step has no today in it,
  /// and then there is nothing to centre on.
  final (int block, int day)? todayLocator;

  @override
  bool operator ==(Object other) =>
      other is ScheduleLoaded &&
      other.steps == steps &&
      other.todayLocator == todayLocator &&
      _listEquals(other.blocks, blocks);

  @override
  int get hashCode => Object.hash(steps, todayLocator, Object.hashAll(blocks));
}

/// Element-wise list equality, so this file needs no dependency to be tested.
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
