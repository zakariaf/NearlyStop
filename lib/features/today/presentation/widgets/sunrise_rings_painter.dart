/// The hero card's decorative sunrise rings.
library;

import 'package:flutter/widgets.dart';
import 'package:nearlystop/theme/gradients.dart';

/// Draws the four concentric rings the hero card clips at its trailing corner.
///
/// **Decorative only, and deliberately so.** Nothing here carries meaning: it
/// never draws text, never draws a meaningful outline, and sits under
/// `ExcludeSemantics`. A reader who cannot see it loses nothing, which is the
/// one condition under which the palette's low-contrast cream is allowed.
///
/// **Every number is the reference's**, from `design/daybreak-screens.html`:
///
/// ```html
/// <svg class="arc" width="240" height="240" viewBox="0 0 240 240">
///   <g fill="none" stroke="#FFF7EE" stroke-width="2">
///     <circle cx="120" cy="120" r="46"  opacity=".85"/>
///     <circle cx="120" cy="120" r="70"  opacity=".6" />
///     <circle cx="120" cy="120" r="94"  opacity=".4" />
///     <circle cx="120" cy="120" r="118" opacity=".25"/>
///   </g>
/// </svg>
/// .hero .arc { inset-inline-end: -70px; top: -90px; opacity: .5 }
/// ```
///
/// The card clips it, so most of the outer two rings never appear — the visible
/// result is a corner of ripples rather than a target, and it only reads that
/// way because the circles are drawn full-size and cut off.
///
/// It takes a [textDirection] rather than a `BuildContext`: a painter that
/// reaches for `Directionality.of` mid-paint reads whatever the tree happens to
/// hold at that moment, which is how a decoration ends up mirrored for one
/// frame.
class SunriseRingsPainter extends CustomPainter {
  /// Creates the painter.
  const SunriseRingsPainter({required this.textDirection});

  /// Which corner the rings sit in. `inset-inline-end`, so it mirrors.
  final TextDirection textDirection;

  /// The radii, from the reference SVG.
  static const List<double> radii = <double>[46, 70, 94, 118];

  /// Each ring's own opacity, before the group's.
  static const List<double> opacities = <double>[0.85, 0.6, 0.4, 0.25];

  /// The opacity on the `<g>`, which multiplies every ring's.
  static const double groupOpacity = 0.5;

  /// The stroke width, from the reference SVG.
  static const double strokeWidth = 2;

  /// How far the centre sits inside the trailing edge: 120 − 70.
  static const double _inset = 50;

  /// How far the centre sits below the top edge: 120 − 90.
  static const double _below = 30;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centre = Offset(
      textDirection == TextDirection.rtl ? _inset : size.width - _inset,
      _below,
    );

    for (var i = 0; i < radii.length; i++) {
      canvas.drawCircle(
        centre,
        radii[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = kWashCream.withValues(
            alpha: opacities[i] * groupOpacity,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(SunriseRingsPainter oldDelegate) =>
      oldDelegate.textDirection != textDirection;
}
