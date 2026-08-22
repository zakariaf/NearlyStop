/// The sealed failure family the DSNS engine returns.
library;

import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';

/// Why a domain function could not produce an answer.
///
/// Sealed, so every `switch` over it compiles with **no `default:` arm** and a
/// new member breaks the build at every call site rather than falling through
/// at runtime. Every subtype carries the data needed to write a human sentence
/// and **none of them carries a pre-built English string** — localisation is
/// EPIC-03's, and the mapping happens in the presentation layer from
/// [Failure.code].
sealed class DomainFailure extends Failure {
  const DomainFailure();
}

/// The dose cannot be made from the tablet strengths the user holds.
///
/// This is the flag `SPEC.md` §3.3 requires: an unachievable dose is said
/// plainly on the day cell and **never silently rounded**. Carries everything
/// the sentence needs — what was asked for, what is held, and whether splitting
/// was allowed.
final class UnachievableDose extends DomainFailure {
  /// Records that [target] cannot be composed from [strengths].
  const UnachievableDose(
    this.target,
    this.strengths, {
    required this.allowHalves,
  });

  /// The dose that could not be composed.
  final Milligrams target;

  /// The strengths that were available, largest first.
  final List<Milligrams> strengths;

  /// Whether half tablets were permitted when the attempt was made.
  final bool allowHalves;

  @override
  String get code => 'dsns.unachievable_dose';
}

/// The plan holds no tablet strengths, so nothing can be composed at all.
final class NoStrengthsHeld extends DomainFailure {
  /// Records that the strength list was empty.
  const NoStrengthsHeld();

  @override
  String get code => 'dsns.no_strengths_held';
}

/// The target dose is above the starting dose, so this is not a taper.
final class TargetAboveStart extends DomainFailure {
  /// Records that [target] exceeds [start].
  const TargetAboveStart(this.start, this.target);

  /// The dose the plan starts from.
  final Milligrams start;

  /// The dose the plan aims at.
  final Milligrams target;

  @override
  String get code => 'dsns.target_above_start';
}

/// A step size of zero or less was supplied, which would never reach the
/// target.
final class NonPositiveStep extends DomainFailure {
  /// Records the non-positive [step].
  const NonPositiveStep(this.step);

  /// The rejected step size.
  final Milligrams step;

  @override
  String get code => 'dsns.non_positive_step';
}

/// The dose is outside the range the composition solver will search.
///
/// The bound is 100 mg. The highest realistic PMR/GCA starting dose is 60 mg,
/// so this guards the dynamic-programming table rather than a clinical limit.
final class DoseOutOfRange extends DomainFailure {
  /// Records that [dose] is outside the searchable range.
  const DoseOutOfRange(this.dose);

  /// The dose that fell outside the range.
  final Milligrams dose;

  @override
  String get code => 'dsns.dose_out_of_range';
}

/// A step froze a pattern version this build does not know how to render.
///
/// `Step.patternVersion` exists so that if the block table is ever corrected,
/// historical steps still render exactly as the patient lived them.
final class UnknownPatternVersion extends DomainFailure {
  /// Records the unknown [version].
  const UnknownPatternVersion(this.version);

  /// The pattern version that was asked for.
  final int version;

  @override
  String get code => 'dsns.unknown_pattern_version';
}

/// Generation was asked for dates before the plan begins.
final class PlanNotStarted extends DomainFailure {
  /// Records that the plan begins on [startDate].
  const PlanNotStarted(this.startDate);

  /// The first date the plan covers.
  final LocalDate startDate;

  @override
  String get code => 'dsns.plan_not_started';
}

/// The stored method needs a parameter the plan does not carry.
///
/// A `percentage` plan with a null percentage, or a `fixedMg` plan with a null
/// fixed step. A typed value, never a throw, and above all never a silent DSNS
/// schedule the patient did not choose.
final class MissingMethodParameter extends DomainFailure {
  /// Records that [method] is missing its parameter.
  const MissingMethodParameter(this.method);

  /// The method that could not be honoured.
  final TaperMethod method;

  @override
  String get code => 'dsns.missing_method_parameter';
}
