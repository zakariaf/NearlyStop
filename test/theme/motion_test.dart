// A user who asked the OS to stop animations asked for STOP — not a shorter
// duration, not a softer curve.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';

void main() {
  Future<List<Duration>> resolveAll(
    WidgetTester tester, {
    required bool disableAnimations,
  }) async {
    late List<Duration> resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(
          builder: (context) {
            resolved = <Duration>[
              resolveMotion(context, daybreakMotion.fast),
              resolveMotion(context, daybreakMotion.base),
              resolveMotion(context, daybreakMotion.slow),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return resolved;
  }

  testWidgets('reduced motion collapses every duration to ZERO', (
    tester,
  ) async {
    expect(
      await resolveAll(tester, disableAnimations: true),
      <Duration>[Duration.zero, Duration.zero, Duration.zero],
    );
  });

  testWidgets('otherwise each duration is its declared value', (tester) async {
    expect(
      await resolveAll(tester, disableAnimations: false),
      <Duration>[
        const Duration(milliseconds: 120),
        const Duration(milliseconds: 220),
        const Duration(milliseconds: 420),
      ],
    );
  });
}
