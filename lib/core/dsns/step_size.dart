/// How big the next step should be, and where the honest sentence comes from.
library;

import 'package:meta/meta.dart';
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/core/units/tablet_strength.dart';

/// What the Plan screen shows for the next step.
///
/// Three fields, no more (CONTRACTS.md §6): the number to use, the strict 10%
/// value so the UI can show the honest sentence, and whether the two diverge.
@immutable
final class StepSuggestion {
  /// Creates a suggestion.
  const StepSuggestion({
    required this.suggested,
    required this.tenPercent,
    required this.communityPracticeDiffers,
  });

  /// The step to offer. Never exceeds `currentDose - targetDose`, never exceeds
  /// the current dose, and is zero exactly when the taper is complete.
  final Milligrams suggested;

  /// The strict 10%-of-current value, reported whether or not it was usable, so
  /// the Plan screen can say *"10% of 9mg is 0.9mg — your doctor's instruction
  /// wins"* rather than substituting silently.
  final Milligrams tenPercent;

  /// Whether [suggested] differs from [tenPercent], and the banner is shown.
  ///
  /// Two regimes, both honest:
  ///
  /// * **10 mg – 5 mg** — 10% permits a *smaller* step than community practice
  ///   actually uses. At 9 mg, 10% is 0.9 mg, so the rule returns 0.5 mg while
  ///   the community steps 1 mg.
  /// * **below 5 mg** — 10% permits *no achievable step at all*, and the
  ///   smallest-achievable fallback is what makes a suggestion exist. `SPEC.md`
  ///   §3.4 puts ten of the fifteen steps — 520 of the 780 days — in that
  /// range.
  ///
  /// Judged on the **unclamped** value: clamping to the remaining gap is a
  /// separate concern and must not light the banner.
  final bool communityPracticeDiffers;
}

/// Suggests the next step size, with the honest 10% figure beside it.
///
/// `SPEC.md` §3.2: the largest achievable increment ≤ 10% of [currentDose],
/// where achievable means composable from the held strengths. The 10% ceiling
/// is the integer **floor** of a tenth, so the suggestion never exceeds 10%.
///
/// **When no achievable increment ≤ 10% exists, returns the *smallest*
/// achievable increment and sets [StepSuggestion.communityPracticeDiffers]**
/// (CONTRACTS.md §6). Without that fallback the rule is undefined for 520 of
/// the 780 days: with `[5, 1]` + halves the smallest achievable increment is
/// 0.5 mg, while 10% of 4 mg is 0.40 mg and 10% of 1 mg is 0.10 mg.
///
/// The result is a **default the user can override** — `SPEC.md` §3.2 — because
/// their rheumatologist may have said something different, and that instruction
/// wins.
///
/// Total: returns for every input. [NoStrengthsHeld] when nothing is held,
/// [TargetAboveStart] when the target is above the current dose, and
/// `Ok(suggested: zero)` when the taper is already complete.
Result<StepSuggestion, DomainFailure> suggestStep({
  required Milligrams currentDose,
  required Milligrams targetDose,
  required List<TabletStrength> strengths,
  required bool allowHalves,
}) {
  if (strengths.isEmpty) return const Err(NoStrengthsHeld());
  if (targetDose > currentDose) {
    return Err(TargetAboveStart(currentDose, targetDose));
  }

  final tenPercent = Milligrams.fromHundredths(currentDose.hundredths ~/ 10);
  if (currentDose == targetDose) {
    return Ok(
      StepSuggestion(
        suggested: Milligrams.zero,
        tenPercent: tenPercent,
        communityPracticeDiffers: false,
      ),
    );
  }

  final unclamped =
      largestAchievableAtMost(
        tenPercent.hundredths,
        strengths,
        allowHalves: allowHalves,
      ) ??
      _smallestAchievable(strengths, allowHalves: allowHalves);

  final gap = currentDose.hundredths - targetDose.hundredths;
  final clamped = unclamped < gap ? unclamped : gap;
  return Ok(
    StepSuggestion(
      suggested: Milligrams.fromHundredths(clamped),
      tenPercent: tenPercent,
      // Judged before the clamp: the 10% rule either WAS satisfiable exactly or
      // it was not, and running out of gap is a different sentence.
      communityPracticeDiffers: unclamped != tenPercent.hundredths,
    ),
  );
}

/// The dose after taking [step] off [from], clamped at [target].
///
/// `SPEC.md` §7 — a step larger than the remaining gap clamps to the target,
/// and a step is never generated to a negative dose.
Milligrams nextDose(Milligrams from, Milligrams step, Milligrams target) {
  final reduced = from - step;
  return reduced < target ? target : reduced;
}

/// The step size a `percentage` plan uses: [percent]% of [fromDose], rounded
/// **down** to the largest achievable increment.
///
/// Falls back to the smallest achievable increment when nothing fits, for the
/// same reason [suggestStep] does. Returns zero only when nothing at all is
/// composable, which the caller has already ruled out by holding a strength
/// below the dose.
Milligrams percentageStepSize(
  Milligrams fromDose,
  int percent,
  List<TabletStrength> strengths, {
  required bool allowHalves,
}) {
  final ceiling = fromDose.hundredths * percent ~/ 100;
  final value =
      largestAchievableAtMost(ceiling, strengths, allowHalves: allowHalves) ??
      _smallestAchievable(strengths, allowHalves: allowHalves);
  return Milligrams.fromHundredths(value);
}

/// The smallest increment the held strengths can make: the smallest tablet, or
/// half of the smallest even one.
///
/// Total on a non-empty [strengths]: every [TabletStrength] is greater than
/// zero by construction, so at least one candidate always exists. The caller
/// has already returned [NoStrengthsHeld] for the empty case.
int _smallestAchievable(
  List<TabletStrength> strengths, {
  required bool allowHalves,
}) {
  assert(strengths.isNotEmpty, 'guarded by the NoStrengthsHeld check');
  var smallest = strengths.first.hundredths;
  void consider(int candidate) {
    if (candidate >= 1 && candidate < smallest) smallest = candidate;
  }

  for (final strength in strengths) {
    consider(strength.hundredths);
    if (allowHalves && strength.hundredths.isEven) {
      consider(strength.hundredths ~/ 2);
    }
  }
  return smallest;
}
