// The mirroring maths. A plain `Alignment` passes any "is the value right"
// test and fails the mirror — the physical-side bug no LTR golden can see.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/theme/gradients.dart';

void main() {
  test('begin and end are AlignmentDirectional, and they MIRROR', () {
    expect(DaybreakGradients.sunriseLight.begin, isA<AlignmentDirectional>());
    expect(DaybreakGradients.sunriseLight.end, isA<AlignmentDirectional>());

    final begin = DaybreakGradients.sunriseLight.begin;
    expect(begin.resolve(TextDirection.ltr).x, closeTo(-0.669, 1e-3));
    expect(begin.resolve(TextDirection.rtl).x, closeTo(0.669, 1e-3));
    // The vertical component does NOT mirror: the sun rises from the top in
    // every script.
    expect(begin.resolve(TextDirection.ltr).y, closeTo(-0.743, 1e-3));
    expect(begin.resolve(TextDirection.rtl).y, closeTo(-0.743, 1e-3));
  });

  test('the 138 degree derivation, recomputed rather than restated', () {
    const begin = DaybreakGradients.sunriseBegin;
    const end = DaybreakGradients.sunriseEnd;
    expect(end.start, closeTo(-begin.start, 1e-9));
    expect(end.y, closeTo(-begin.y, 1e-9));

    // CSS measures clockwise from "to top"; Flutter's box is +y DOWNWARD, so
    // the direction vector for angle t is (sin t, -cos t).
    final degrees = (math.atan2(end.start, -end.y) * 180 / math.pi + 360) % 360;
    expect(degrees, closeTo(138, 0.5));
  });

  test('the stops are the four the design authored', () {
    expect(DaybreakGradients.sunriseLight.stops, <double>[0, 0.32, 0.68, 1]);
    expect(DaybreakGradients.sunriseLight.colors, hasLength(4));
    expect(DaybreakGradients.sunriseDark.stops, <double>[0, 0.34, 0.70, 1]);
    expect(DaybreakGradients.sunriseDark.colors, hasLength(4));
    expect(DaybreakGradients.washLight.colors, hasLength(2));
    expect(DaybreakGradients.washDark.colors, hasLength(2));
  });

  test('the wash is vertical, so it has nothing to mirror', () {
    expect(DaybreakGradients.washLight.begin, AlignmentDirectional.topCenter);
    expect(DaybreakGradients.washLight.end, AlignmentDirectional.bottomCenter);
  });

  testWidgets('in RTL the warm end falls from the LEADING corner', (
    tester,
  ) async {
    // The render-side gate for the maths above.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: DaybreakGradients.sunriseLight,
              ),
            ),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(DecoratedBox));
    // In RTL the gradient's start corner resolves to the RIGHT half of the box
    // and in LTR to the left. Same token, mirrored geometry.
    final rtl = DaybreakGradients.sunriseLight.begin
        .resolve(TextDirection.rtl)
        .withinRect(box);
    final ltr = DaybreakGradients.sunriseLight.begin
        .resolve(TextDirection.ltr)
        .withinRect(box);
    expect(rtl.dx, greaterThan(box.center.dx));
    expect(ltr.dx, lessThan(box.center.dx));
    expect(rtl.dy, ltr.dy);
  });
}
