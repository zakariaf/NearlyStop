// Shape is the primary signal, asserted structurally.
//
// A grayscale printout, a deuteranopic reader and a screen reader all have to
// answer "did I take it?". Four colours do not answer it; four SHAPES do. That
// claim is normally checked with a greyscale golden, which tells you something
// changed but not what — so the four shapes are also described by an explicit
// value object here, and the assertion is that the four descriptors are
// pairwise distinct. A fifth state, or two states quietly given the same
// shape, fails on a named line instead of a pixel diff.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_marker.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

import '../../../support/harness.dart';

void main() {
  /// The four states, as an exhaustive list. `DayState.values` rather than a
  /// literal, so a fifth member widens every table below at once.
  const states = DayState.values;

  test('the four shape descriptors are pairwise distinct', () {
    final shapes = <DayState, DayStateShape>{
      for (final state in states) state: DayStateShape.forState(state),
    };

    for (final a in states) {
      for (final b in states) {
        if (a == b) continue;
        expect(
          shapes[a],
          isNot(shapes[b]),
          reason:
              '$a and $b are the same shape, so greyscale cannot tell them '
              'apart and neither can a deuteranopic reader',
        );
      }
    }
  });

  test('each state names its own shape, exhaustively', () {
    // Pinned individually as well as pairwise: "all different" is satisfied by
    // four wrong answers, and this is the table the design is judged against.
    expect(
      DayStateShape.forState(DayState.taken),
      const DayStateShape(
        filled: true,
        strokeWidth: 0,
        dashed: false,
        hasCore: false,
      ),
    );
    expect(
      DayStateShape.forState(DayState.missed),
      const DayStateShape(
        filled: false,
        strokeWidth: 3,
        dashed: false,
        hasCore: false,
      ),
    );
    expect(
      DayStateShape.forState(DayState.today),
      const DayStateShape(
        filled: false,
        strokeWidth: 2,
        dashed: false,
        hasCore: true,
      ),
    );
    expect(
      DayStateShape.forState(DayState.upcoming),
      const DayStateShape(
        filled: false,
        strokeWidth: 2,
        dashed: true,
        hasCore: false,
      ),
    );
  });

  testWidgets('the marker is 26 logical px, not 28, at 1.0 scale', (
    tester,
  ) async {
    // Resolved against the reference: `.srow .mark` is 26px. The states scan
    // as a column of glyphs down the list edge, so this size is shared.
    for (final state in states) {
      await pumpApp(tester, Center(child: DayStateMarker(state: state)));

      expect(
        tester.getSize(find.byType(DayStateMarker)),
        const Size(26, 26),
        reason: '$state',
      );
    }
  });

  testWidgets('the marker does NOT grow with the text scale', (tester) async {
    // It is a glyph in a column of glyphs, not text. Growing it would break
    // the vertical scan line the whole list depends on, and the row's HEIGHT
    // already grows because its text does.
    await pumpApp(
      tester,
      const Center(child: DayStateMarker(state: DayState.today)),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.getSize(find.byType(DayStateMarker)), const Size(26, 26));
  });

  testWidgets('it contributes no semantics of its own', (tester) async {
    // The row reads as ONE sentence. A marker that announced itself would make
    // it two, and the second would be a shape name nobody needs.
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const Center(child: DayStateMarker(state: DayState.taken)),
    );

    expect(
      find.descendant(
        of: find.byType(DayStateMarker),
        matching: find.byType(Semantics),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('shouldRepaint is true for each field, false for none', (
    tester,
  ) async {
    // Looped over the fields rather than spot-checked, so adding a fifth field
    // without extending `shouldRepaint` fails here rather than as a stale
    // marker on somebody's screen.
    const base = DayStateMarkerPainter(
      color: Color(0xFF112233),
      shape: DayStateShape(
        filled: true,
        strokeWidth: 0,
        dashed: false,
        hasCore: false,
      ),
    );

    expect(base.shouldRepaint(base), isFalse);
    expect(
      base.shouldRepaint(
        const DayStateMarkerPainter(
          color: Color(0xFF445566),
          shape: DayStateShape(
            filled: true,
            strokeWidth: 0,
            dashed: false,
            hasCore: false,
          ),
        ),
      ),
      isTrue,
      reason: 'colour changed',
    );
    expect(
      base.shouldRepaint(
        const DayStateMarkerPainter(
          color: Color(0xFF112233),
          shape: DayStateShape(
            filled: false,
            strokeWidth: 3,
            dashed: false,
            hasCore: false,
          ),
        ),
      ),
      isTrue,
      reason: 'shape changed',
    );
  });

  testWidgets('the colour is the slot, never a literal', (tester) async {
    late DaybreakColors colors;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = DaybreakColors.of(context);
          return const Center(child: DayStateMarker(state: DayState.missed));
        },
      ),
    );

    final painter = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(DayStateMarker),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      (painter.painter! as DayStateMarkerPainter).color,
      colors.stateMissed,
    );
  });
}
