/// The hero card's decorative sunrise arc.
library;

import 'package:flutter/widgets.dart';

/// Draws the rising arc behind the dose numeral.
///
/// **Decorative only, and deliberately so.** This is the one place the
/// palette's 2.8:1 pair is allowed, because nothing here carries meaning: it
/// never draws text, never draws a meaningful outline, and sits under
/// `ExcludeSemantics`. A reader who cannot see it loses nothing.
///
/// Every token it needs is **snapshotted into a field** at the widget layer.
/// `paint()` takes no `BuildContext` — a painter that reaches for `Theme.of`
/// mid-paint reads whatever the tree happens to hold at that moment, which is
/// how an arc ends up in the light palette on a dark screen for one frame.
class SunriseArcPainter extends CustomPainter {
  /// Creates the painter from already-resolved values.
  const SunriseArcPainter({
    required this.arcColor,
    required this.strokeWidth,
    required this.sweep,
    required this.progress,
  });

  /// The stroke colour, already resolved from the palette.
  final Color arcColor;

  /// How thick the arc is drawn.
  final double strokeWidth;

  /// How far around the circle the arc travels, in radians.
  final double sweep;

  /// How much of [sweep] is filled, from 0 to 1.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = arcColor;
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    // Starts at the horizon on the leading side and rises. The angles are
    // geometry, not design values: they describe the shape, and changing them
    // changes what the arc IS rather than how it is themed.
    canvas.drawArc(rect, _startAngle, sweep * progress, false, paint);
  }

  /// Nine o'clock — the horizon.
  static const double _startAngle = 3.141592653589793;

  @override
  bool shouldRepaint(SunriseArcPainter oldDelegate) =>
      oldDelegate.arcColor != arcColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.sweep != sweep ||
      oldDelegate.progress != progress;
}
