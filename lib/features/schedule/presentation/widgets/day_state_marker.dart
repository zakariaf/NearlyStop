/// The 26px glyph that carries a day's state by SHAPE.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/theme/day_state_colors.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

/// What a marker looks like, independent of colour.
///
/// Extracted as a value object rather than left implicit in `paint()` so the
/// "shape is the primary signal" claim can be asserted structurally. A
/// greyscale golden tells you the four states still differ; it does not tell
/// you WHICH pair collapsed when they stop differing, and it cannot fail until
/// somebody looks at it. Four descriptors that must be pairwise distinct can.
@immutable
class DayStateShape {
  /// Describes one marker.
  const DayStateShape({
    required this.filled,
    required this.strokeWidth,
    required this.dashed,
    required this.hasCore,
  });

  /// The shape for [state].
  ///
  /// An exhaustive switch with no `default:` — a fifth `DayState` member is a
  /// compile error here, which is the point (CONTRACTS.md §1).
  factory DayStateShape.forState(DayState state) => switch (state) {
    DayState.taken => const DayStateShape(
      filled: true,
      strokeWidth: 0,
      dashed: false,
      hasCore: false,
    ),
    DayState.missed => const DayStateShape(
      filled: false,
      strokeWidth: 3,
      dashed: false,
      hasCore: false,
    ),
    DayState.today => const DayStateShape(
      filled: false,
      strokeWidth: 2,
      dashed: false,
      hasCore: true,
    ),
    DayState.upcoming => const DayStateShape(
      filled: false,
      strokeWidth: 2,
      dashed: true,
      hasCore: false,
    ),
  };

  /// A solid disc rather than a ring.
  final bool filled;

  /// The ring's stroke width. Zero when [filled].
  final double strokeWidth;

  /// The ring is drawn as dashes rather than a continuous stroke.
  final bool dashed;

  /// A filled dot sits inside the ring.
  final bool hasCore;

  @override
  bool operator ==(Object other) =>
      other is DayStateShape &&
      other.filled == filled &&
      other.strokeWidth == strokeWidth &&
      other.dashed == dashed &&
      other.hasCore == hasCore;

  @override
  int get hashCode => Object.hash(filled, strokeWidth, dashed, hasCore);

  @override
  String toString() =>
      'DayStateShape(filled: $filled, strokeWidth: $strokeWidth, '
      'dashed: $dashed, hasCore: $hasCore)';
}

/// The day-state glyph: one fixed-size mark, no text, no semantics.
///
/// **Fixed at 26 logical px and deliberately not scaled by the text scaler.**
/// The markers form a vertical scan line down the edge of the schedule list —
/// that is how a reader finds their place in a 52-day block — and a column of
/// glyphs that each grew by a different amount would not be a line. The row's
/// height still grows, because the row's TEXT grows.
class DayStateMarker extends StatelessWidget {
  /// Creates the marker for [state].
  const DayStateMarker({
    required this.state,
    this.isNewDose = false,
    super.key,
  });

  /// Which of the four states this day is in.
  final DayState state;

  /// The separate new-dose channel, which takes the colour when set.
  ///
  /// Never a fifth [DayState] member: a day is routinely both `today` and a
  /// new-dose day (CONTRACTS.md §1).
  final bool isNewDose;

  /// The marker's diameter. Resolved against `.srow .mark` in the reference.
  static const double diameter = 26;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: diameter,
    child: CustomPaint(
      painter: DayStateMarkerPainter(
        color: dayStateColor(
          state,
          DaybreakColors.of(context),
          isNewDose: isNewDose,
        ),
        shape: DayStateShape.forState(state),
      ),
    ),
  );
}

/// Paints one [DayStateShape] in one colour.
///
/// Both values are **snapshotted at the widget layer**: `paint()` takes no
/// `BuildContext`, because a painter that reaches for `Theme.of` mid-paint
/// reads whatever the tree happens to hold at that moment.
@immutable
class DayStateMarkerPainter extends CustomPainter {
  /// Creates the painter from already-resolved values.
  const DayStateMarkerPainter({required this.color, required this.shape});

  /// The mark's colour, already resolved from the palette.
  final Color color;

  /// What to draw.
  final DayStateShape shape;

  /// How long each dash and each gap is, for the `upcoming` ring.
  static const double _dashLength = 3.2;

  /// The core dot's diameter as a fraction of the marker's.
  static const double _coreFraction = 0.38;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centre = size.center(Offset.zero);
    final paint = Paint()..color = color;

    if (shape.filled) {
      canvas.drawCircle(centre, size.shortestSide / 2, paint);
      return;
    }

    final radius = (size.shortestSide - shape.strokeWidth) / 2;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = shape.strokeWidth;

    if (shape.dashed) {
      _drawDashedCircle(canvas, centre, radius, paint);
    } else {
      canvas.drawCircle(centre, radius, paint);
    }

    if (shape.hasCore) {
      canvas.drawCircle(
        centre,
        size.shortestSide * _coreFraction / 2,
        Paint()..color = color,
      );
    }
  }

  /// A ring of evenly spaced dashes.
  ///
  /// Drawn arc by arc rather than with a dash `PathEffect`, which Flutter's
  /// canvas does not have. The dash count is derived from the circumference so
  /// the gaps stay even at any radius rather than bunching at one size.
  void _drawDashedCircle(
    Canvas canvas,
    Offset centre,
    double radius,
    Paint paint,
  ) {
    final circumference = 2 * 3.141592653589793 * radius;
    // Even count, so dashes and gaps alternate all the way round without a
    // double gap where the ring closes.
    final segments = ((circumference / (_dashLength * 2)).round() * 2).clamp(
      4,
      64,
    );
    final step = 2 * 3.141592653589793 / segments;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    for (var i = 0; i < segments; i += 2) {
      canvas.drawArc(rect, i * step, step, false, paint);
    }
  }

  @override
  bool shouldRepaint(DayStateMarkerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shape != shape;
}
