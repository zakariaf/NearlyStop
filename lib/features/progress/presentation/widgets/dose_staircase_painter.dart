/// The dose staircase, painted from a value snapshot.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';

/// The axis text, laid out BEFORE the painter ever runs.
///
/// Laying text out inside `paint()` is work on every frame, and it is the one
/// thing in a painter that needs a `TextStyle` from the theme — so it is done
/// once, in the widget's `build`, and handed over as pixels-and-metrics.
@immutable
class DoseAxisLabels {
  /// Creates the label set.
  const DoseAxisLabels({
    required this.first,
    required this.last,
    required this.doses,
  });

  /// The earliest date, e.g. "Sep 2024".
  final TextPainter first;

  /// The latest date, e.g. "Apr 2026".
  final TextPainter last;

  /// The y-axis doses, top to bottom.
  final List<TextPainter> doses;

  @override
  bool operator ==(Object other) =>
      other is DoseAxisLabels &&
      _same(other.first, first) &&
      _same(other.last, last) &&
      other.doses.length == doses.length;

  @override
  int get hashCode =>
      Object.hash(first.text, first.size, last.text, last.size, doses.length);

  /// Text AND metrics.
  ///
  /// The words alone are not enough: at 1.0 → 1.3 the labels say the same
  /// thing at a different size, and comparing text answers "nothing changed"
  /// while the chart keeps axis labels laid out for the old scale. Under the
  /// threshold where it would have become a list, which is the range this
  /// audience actually lives in.
  static bool _same(TextPainter a, TextPainter b) =>
      a.text == b.text && a.size == b.size;
}

/// Draws the taper as a staircase, with flare and hold marks.
///
/// **No `BuildContext`.** Every colour, gradient, width and piece of text
/// arrives as a value, which is what makes the geometry testable without
/// pumping a widget — and what stops `paint()` doing theme lookups sixty times
/// a second. A source scan in the suite keeps it that way.
class DoseStaircasePainter extends CustomPainter {
  /// Creates the painter from a snapshot.
  const DoseStaircasePainter({
    required this.segments,
    required this.flares,
    required this.holds,
    required this.todayDayIndex,
    required this.todayDose,
    required this.minDose,
    required this.maxDose,
    required this.gridline,
    required this.lineGradient,
    required this.fillGradient,
    required this.flareRing,
    required this.flareGlyph,
    required this.holdBracket,
    required this.markerFill,
    required this.todayRing,
    required this.strokeWidth,
    required this.direction,
    required this.labels,
  });

  /// Room above the plot for the top dose label.
  static const double plotTop = 14;

  /// Room below the plot for the date labels.
  ///
  /// Deep enough to clear the TODAY MARKER as well as the text: the marker is
  /// a 6px circle centred on the baseline, so a gutter sized for the labels
  /// alone puts half of it through "Apr 2026".
  static const double plotBottom = 32;

  /// How many gridlines the plot is ruled with, matching the reference SVG.
  static const int gridlineCount = 4;

  /// The treads, in order.
  final List<DoseSegment> segments;

  /// Flares, in date order.
  final List<FlareMark> flares;

  /// Holds, in date order.
  final List<HoldMark> holds;

  /// Where today sits on the x axis.
  final int todayDayIndex;

  /// Today's dose, for the marker's y.
  final Milligrams todayDose;

  /// The lowest dose in the series — the baseline.
  final Milligrams minDose;

  /// The highest dose in the series — the top gridline.
  final Milligrams maxDose;

  /// The ruling colour.
  final Color gridline;

  /// The stroke. Must clear 3:1 against the card (WCAG 2.1 SC 1.4.11).
  final Gradient lineGradient;

  /// The area under the stroke. Decorative, so it carries no contrast rule.
  final Gradient fillGradient;

  /// The flare ring.
  final Color flareRing;

  /// The flare glyph inside the ring — the channel that is not colour.
  final Color flareGlyph;

  /// The hold bracket.
  final Color holdBracket;

  /// The fill inside a marker, so it reads against the line behind it.
  final Color markerFill;

  /// Today's ring.
  final Color todayRing;

  /// The stroke width.
  final double strokeWidth;

  /// Which way time runs. The earliest date is at the READING START edge.
  final TextDirection direction;

  /// The axis text, already laid out.
  final DoseAxisLabels labels;

  int get _lastDay => segments.isEmpty ? 0 : segments.last.endDayIndex;

  /// The x a day index maps to, mirrored in RTL.
  ///
  /// Mirrored HERE rather than by transforming the canvas, because the labels
  /// must not be mirrored with it — a reversed "Sep 2024" is not a date. The
  /// earliest date sits at the reading start edge in both directions, which is
  /// a design decision and not an accident of the transform.
  @visibleForTesting
  double xFor(int dayIndex, Size size) {
    if (_lastDay == 0) return direction == TextDirection.ltr ? 0 : size.width;
    final fraction = dayIndex / _lastDay;
    return direction == TextDirection.ltr
        ? fraction * size.width
        : size.width - fraction * size.width;
  }

  /// [xFor], pulled inside the canvas by [radius] so a marker is never
  /// half-clipped by the edge.
  ///
  /// The PATH still spans the full width — the staircase is the data and it
  /// runs edge to edge — but a 9px ring centred on the last day would lose
  /// half of itself, and the today marker is the one mark a reader looks for.
  double markerX(int dayIndex, Size size, double radius) {
    final x = xFor(dayIndex, size);
    return x.clamp(radius, size.width - radius);
  }

  /// The y a dose maps to: the lowest on the baseline, the highest on top.
  @visibleForTesting
  double yFor(Milligrams dose, Size size) {
    final bottom = size.height - plotBottom;
    final span = maxDose.hundredths - minDose.hundredths;
    if (span == 0) return bottom;
    final fraction = (dose.hundredths - minDose.hundredths) / span;
    return bottom - fraction * (bottom - plotTop);
  }

  /// The staircase's corner points, in drawing order.
  ///
  /// The vertices are the source of truth and the path is built FROM them, so
  /// a test can assert the shape without asking `Path` for something it will
  /// not hand back. `computeMetrics` yields one metric for the whole contour —
  /// the two ends and nothing between them — which is exactly the resolution
  /// at which a staircase and a diagonal look identical.
  @visibleForTesting
  List<Offset> staircaseVertices(Size size) {
    final points = <Offset>[];
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final y = yFor(segment.dose, size);
      // A tread runs to where the NEXT one begins, not to its own last day —
      // otherwise the riser between them is a day wide and the staircase is a
      // row of diagonals. The dose was held flat and changed on one morning,
      // and a sloped riser draws a taper nobody experienced.
      final endX = index + 1 < segments.length
          ? xFor(segments[index + 1].startDayIndex, size)
          : xFor(segment.endDayIndex, size);
      points
        ..add(Offset(xFor(segment.startDayIndex, size), y))
        ..add(Offset(endX, y));
    }
    return points;
  }

  /// The staircase as one path of horizontal and vertical moves.
  @visibleForTesting
  Path buildStaircasePath(Size size) {
    final path = Path();
    final points = staircaseVertices(size);
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    // FOUR paints, allocated once and reused. One per segment is thirty-two
    // allocations a frame on a two-year taper.
    final rule = Paint()
      ..color = gridline
      ..strokeWidth = 1;
    final stroke = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;
    final mark = Paint();

    final plot = Rect.fromLTWH(
      0,
      plotTop,
      size.width,
      size.height - plotTop - plotBottom,
    );

    for (var index = 0; index < gridlineCount; index++) {
      final y = plot.top + plot.height * index / (gridlineCount - 1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    final path = buildStaircasePath(size);
    final area = Path.from(path)
      ..lineTo(xFor(_lastDay, size), size.height - plotBottom)
      ..lineTo(xFor(0, size), size.height - plotBottom)
      ..close();
    canvas
      // The direction is PASSED: the token gradients are declared with
      // `AlignmentDirectional`, and resolving one without a text direction
      // throws inside `paint()` — where the painter has no `Directionality`
      // to inherit from, by design.
      ..drawPath(
        area,
        fill
          ..shader = fillGradient.createShader(plot, textDirection: direction),
      )
      ..drawPath(
        path,
        stroke
          ..shader = lineGradient.createShader(plot, textDirection: direction),
      );

    for (final hold in holds) {
      _paintHold(canvas, size, hold, mark);
    }
    for (final flare in flares) {
      _paintFlare(canvas, size, flare, mark);
    }
    _paintToday(canvas, size, mark);
    _paintLabels(canvas, size);
  }

  /// A square bracket over the held days: a span and two ticks.
  ///
  /// A distinct SHAPE, never a second ring in another colour. A reader who
  /// cannot separate the hold's colour from the flare's still sees a bracket
  /// and a circle.
  void _paintHold(Canvas canvas, Size size, HoldMark hold, Paint mark) {
    mark
      ..shader = null
      ..color = holdBracket
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final y = yFor(hold.dose, size) - 10;
    final from = xFor(hold.dayIndex, size);
    final to = xFor(hold.dayIndex + hold.days, size);
    canvas
      ..drawLine(Offset(from, y), Offset(to, y), mark)
      ..drawLine(Offset(from, y), Offset(from, y + 5), mark)
      ..drawLine(Offset(to, y), Offset(to, y + 5), mark);
  }

  /// A ring with the flare glyph inside it — shape AND glyph, never colour.
  void _paintFlare(Canvas canvas, Size size, FlareMark flare, Paint mark) {
    final centre = Offset(
      markerX(flare.dayIndex, size, 9),
      yFor(flare.dose, size),
    );
    canvas
      ..drawCircle(
        centre,
        9,
        mark
          ..shader = null
          ..color = markerFill
          ..style = PaintingStyle.fill,
      )
      ..drawCircle(
        centre,
        9,
        mark
          ..color = flareRing
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      )
      // The glyph: an upward chevron, because a flare is the dose going back
      // up. Two strokes, so it survives greyscale as a shape.
      ..drawPath(
        Path()
          ..moveTo(centre.dx - 3.5, centre.dy + 2)
          ..lineTo(centre.dx, centre.dy - 2.5)
          ..lineTo(centre.dx + 3.5, centre.dy + 2),
        mark
          ..color = flareGlyph
          ..strokeWidth = 1.8,
      );
  }

  void _paintToday(Canvas canvas, Size size, Paint mark) {
    final centre = Offset(
      markerX(todayDayIndex, size, 6),
      yFor(todayDose, size),
    );
    canvas
      ..drawCircle(
        centre,
        6,
        mark
          ..shader = null
          ..color = markerFill
          ..style = PaintingStyle.fill,
      )
      ..drawCircle(
        centre,
        6,
        mark
          ..color = todayRing
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }

  void _paintLabels(Canvas canvas, Size size) {
    final baseline = size.height - plotBottom + 12;
    final startEdge = direction == TextDirection.ltr;
    labels.first.paint(
      canvas,
      Offset(startEdge ? 0 : size.width - labels.first.width, baseline),
    );
    labels.last.paint(
      canvas,
      Offset(startEdge ? size.width - labels.last.width : 0, baseline),
    );

    for (var index = 0; index < labels.doses.length; index++) {
      final painter = labels.doses[index];
      final y =
          plotTop +
          (size.height - plotTop - plotBottom) *
              index /
              (labels.doses.length - 1).clamp(1, 1 << 30);
      painter.paint(
        canvas,
        Offset(startEdge ? 0 : size.width - painter.width, y - painter.height),
      );
    }
  }

  @override
  bool shouldRepaint(DoseStaircasePainter oldDelegate) =>
      oldDelegate.todayDayIndex != todayDayIndex ||
      oldDelegate.todayDose != todayDose ||
      oldDelegate.minDose != minDose ||
      oldDelegate.maxDose != maxDose ||
      oldDelegate.gridline != gridline ||
      oldDelegate.lineGradient != lineGradient ||
      oldDelegate.fillGradient != fillGradient ||
      oldDelegate.flareRing != flareRing ||
      oldDelegate.flareGlyph != flareGlyph ||
      oldDelegate.holdBracket != holdBracket ||
      oldDelegate.markerFill != markerFill ||
      oldDelegate.todayRing != todayRing ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.direction != direction ||
      oldDelegate.labels != labels ||
      // CONTENTS, not just length. Comparing lengths is the shortcut that
      // leaves a changed chart on screen after a flare rewrites the days.
      !listEquals(oldDelegate.segments, segments) ||
      !listEquals(oldDelegate.flares, flares) ||
      !listEquals(oldDelegate.holds, holds);
}
