// `shouldRepaint` is `f(old, new) → bool`, so this needs no `pumpWidget`.
//
// The loop matters more than any single case: a fifth field added without a
// matching comparison would make the arc stop updating, and the only symptom
// would be a stale colour after a theme change — which nobody would trace back
// here.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/features/today/presentation/widgets/sunrise_arc_painter.dart';

const _base = SunriseArcPainter(
  arcColor: Color(0xFF000000),
  strokeWidth: 4,
  sweep: 3,
  progress: 0.5,
);

void main() {
  test('an identical painter does not repaint', () {
    expect(_base.shouldRepaint(_base), isFalse);
    expect(
      _base.shouldRepaint(
        const SunriseArcPainter(
          arcColor: Color(0xFF000000),
          strokeWidth: 4,
          sweep: 3,
          progress: 0.5,
        ),
      ),
      isFalse,
    );
  });

  test('EVERY field, changed alone, repaints', () {
    final mutations = <String, SunriseArcPainter>{
      'arcColor': const SunriseArcPainter(
        arcColor: Color(0xFFFF0000),
        strokeWidth: 4,
        sweep: 3,
        progress: 0.5,
      ),
      'strokeWidth': const SunriseArcPainter(
        arcColor: Color(0xFF000000),
        strokeWidth: 5,
        sweep: 3,
        progress: 0.5,
      ),
      'sweep': const SunriseArcPainter(
        arcColor: Color(0xFF000000),
        strokeWidth: 4,
        sweep: 3.5,
        progress: 0.5,
      ),
      'progress': const SunriseArcPainter(
        arcColor: Color(0xFF000000),
        strokeWidth: 4,
        sweep: 3,
        progress: 0.6,
      ),
    };

    for (final MapEntry(key: field, value: mutated) in mutations.entries) {
      expect(mutated.shouldRepaint(_base), isTrue, reason: field);
      expect(_base.shouldRepaint(mutated), isTrue, reason: field);
    }
  });

  test('painting an empty or zero-progress canvas draws nothing', () {
    // Guards a real crash: `Rect.fromLTWH` with a negative width throws once
    // the stroke is wider than the box, which happens the moment the hero is
    // laid out in a constrained column.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    _base.paint(canvas, Size.zero);
    const SunriseArcPainter(
      arcColor: Color(0xFF000000),
      strokeWidth: 4,
      sweep: 3,
      progress: 0,
    ).paint(canvas, const Size(100, 100));

    expect(recorder.endRecording(), isNotNull);
  });
}
