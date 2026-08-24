// The hero card's decorative rings, against the reference's own numbers.
//
// `design/daybreak-screens.html` draws them as an SVG the card clips:
//
//     <svg class="arc" width="240" height="240" viewBox="0 0 240 240">
//       <g fill="none" stroke="#FFF7EE" stroke-width="2">
//         <circle cx=120 cy=120 r=46  opacity=.85/>
//         <circle cx=120 cy=120 r=70  opacity=.6 />
//         <circle cx=120 cy=120 r=94  opacity=.4 />
//         <circle cx=120 cy=120 r=118 opacity=.25/>
//       </g>
//     </svg>
//     .hero .arc { inset-inline-end: -70px; top: -90px; opacity: .5 }
//
// Four concentric circles, not one arc, and every number above is exact-tier
// under `daybreak-visual-parity` rule 2. So they are asserted, not eyeballed:
// this is the frame's signature move, and a shape that drifts here is the
// first thing a reader sees on the screen they open every morning.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/today/presentation/widgets/sunrise_rings_painter.dart';
import 'package:nearlystop/theme/gradients.dart';

void main() {
  /// Every `drawCircle` the painter issued, in order.
  List<({Offset centre, double radius, Paint paint})> circlesOf(
    SunriseRingsPainter painter,
    Size size,
  ) {
    final canvas = TestRecordingCanvas();
    painter.paint(canvas, size);
    return canvas.invocations
        .where((i) => i.invocation.memberName == #drawCircle)
        .map(
          (i) => (
            centre: i.invocation.positionalArguments[0] as Offset,
            radius: i.invocation.positionalArguments[1] as double,
            paint: i.invocation.positionalArguments[2] as Paint,
          ),
        )
        .toList();
  }

  const size = Size(350, 290);

  test('four concentric circles, at the reference radii', () {
    final circles = circlesOf(
      const SunriseRingsPainter(textDirection: TextDirection.ltr),
      size,
    );

    expect(circles.map((c) => c.radius), <double>[46, 70, 94, 118]);
    // Concentric: one centre, not four.
    expect(circles.map((c) => c.centre).toSet(), hasLength(1));
  });

  test('the centre is where the SVG puts it, clipped by the card', () {
    // The SVG is 240 wide with its right edge 70px past the card's, and its
    // top 90px above it. So the centre lands 50px INSIDE the trailing edge and
    // 30px BELOW the top — three of the four rings are cut off, which is the
    // effect.
    final circles = circlesOf(
      const SunriseRingsPainter(textDirection: TextDirection.ltr),
      size,
    );

    expect(circles.first.centre, const Offset(350 - 50, 30));
  });

  test('it mirrors in RTL', () {
    final circles = circlesOf(
      const SunriseRingsPainter(textDirection: TextDirection.rtl),
      size,
    );

    expect(circles.first.centre, const Offset(50, 30));
  });

  test('the stroke is the wash cream, hairline-thin, fading outward', () {
    final circles = circlesOf(
      const SunriseRingsPainter(textDirection: TextDirection.ltr),
      size,
    );

    for (final circle in circles) {
      expect(circle.paint.style, PaintingStyle.stroke);
      expect(circle.paint.strokeWidth, 2);
      // The group's own opacity:.5 multiplies each circle's.
      expect(
        circle.paint.color.withAlpha(0xFF),
        kWashCream,
        reason: 'the reference strokes #FFF7EE',
      );
    }
    expect(
      circles.map((c) => (c.paint.color.a * 100).round()),
      <int>[43, 30, 20, 13],
      reason: '.85, .6, .4 and .25 through a group at .5',
    );
  });

  test('it draws no arc — the single arc was the defect', () {
    final canvas = TestRecordingCanvas();
    const SunriseRingsPainter(
      textDirection: TextDirection.ltr,
    ).paint(canvas, size);

    expect(
      canvas.invocations.map((i) => i.invocation.memberName),
      isNot(contains(#drawArc)),
    );
  });
}
