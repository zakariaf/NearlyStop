// The witness for a compile-time guarantee, not a runtime one.
//
// What matters about DomainFailure is that every `switch` over it compiles with
// NO `default:` arm. That is held by the compiler and by
// `flutter analyze --fatal-infos`, not by an `expect` — so this file's job is
// to
// stop compiling the moment a member is added and left unhandled.
//
// The PAYLOADS are asserted where they are produced: UnachievableDose in
// tablet_composer_test, TargetAboveStart / NoStrengthsHeld in step_size_test,
// MissingMethodParameter / PlanNotStarted in schedule_generator_test.
import 'package:nearlystop/core/dsns/dsns_failure.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:test/test.dart';

String tag(DomainFailure failure) => switch (failure) {
  UnachievableDose() => 'unachievable_dose',
  NoStrengthsHeld() => 'no_strengths_held',
  TargetAboveStart() => 'target_above_start',
  NonPositiveStep() => 'non_positive_step',
  DoseOutOfRange() => 'dose_out_of_range',
  UnknownPatternVersion() => 'unknown_pattern_version',
  PlanNotStarted() => 'plan_not_started',
  MissingMethodParameter() => 'missing_method_parameter',
};

void main() {
  test('every member is reachable and carries a distinct stable code', () {
    const oneMg = Milligrams.fromHundredths(100);
    final all = <DomainFailure>[
      const UnachievableDose(oneMg, <Milligrams>[oneMg], allowHalves: false),
      const NoStrengthsHeld(),
      const TargetAboveStart(oneMg, oneMg),
      const NonPositiveStep(Milligrams.zero),
      const DoseOutOfRange(oneMg),
      const UnknownPatternVersion(2),
      const PlanNotStarted(LocalDate(2026, 4, 1)),
      const MissingMethodParameter(TaperMethod.percentage),
    ];

    expect(all.map(tag).toSet(), hasLength(all.length));
    expect(all.map((f) => f.code).toSet(), hasLength(all.length));
    for (final failure in all) {
      expect(
        failure.code,
        startsWith('dsns.'),
        reason: '${failure.runtimeType}',
      );
    }
  });
}
