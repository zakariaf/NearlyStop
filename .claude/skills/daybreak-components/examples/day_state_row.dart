// Demonstrates the NearlyStop Schedule day row for all four day states, where SHAPE
// is the primary signal and colour is derived last:
//   taken    = filled disc
//   missed   = hollow ring (stroke only)
//   today    = ring with a filled core (a target)
//   upcoming = faint dashed circle
// Each shape is paired with a glyph AND a localized word, so a grayscale golden, an
// inverted screen, and a screen reader all still answer "did I take it?".
// The marker painter takes a token snapshot and never reads BuildContext in paint().
//
// Lives at: lib/features/schedule/presentation/widgets/day_state_row.dart

import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'package:nearlystop/l10n/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_radii.dart';
import 'package:nearlystop/theme/daybreak_spacing.dart';

/// The canonical value object. Colour is a pure function of THIS — never the reverse.
enum DayState { taken, missed, today, upcoming }

/// Signal 1: shape. Signal 2: glyph. Signal 3: the word. Signal 4 (today only):
/// position, weight and elevation. Colour is last, and it is always a slot read.
extension DayStateView on DayState {
  /// Signal 1 — the marker silhouette, legible with no colour at all.
  MarkerShape get shape => switch (this) {
        DayState.taken => MarkerShape.filledDisc,
        DayState.missed => MarkerShape.hollowRing,
        DayState.today => MarkerShape.ringWithCore,
        DayState.upcoming => MarkerShape.dashedCircle,
      };

  /// Signal 2 — a glyph whose shape differs per state (not one glyph recoloured).
  IconData? get glyph => switch (this) {
        DayState.taken => Icons.check,
        DayState.missed => Icons.remove,
        DayState.today => Icons.today_outlined,
        DayState.upcoming => null, // deliberately bare: nothing has happened yet
      };

  /// Signal 3 — the word, routed through gen-l10n. Never a hardcoded String.
  String label(AppLocalizations l10n) => switch (this) {
        DayState.taken => l10n.dayStateTaken,
        DayState.missed => l10n.dayStateMissed,
        DayState.today => l10n.dayStateToday,
        DayState.upcoming => l10n.dayStateUpcoming,
      };

  /// Signal 4 — today is heavier than every other row on the screen.
  FontWeight get weight =>
      this == DayState.today ? FontWeight.w800 : FontWeight.w600;

  /// Colour is DERIVED LAST, from a semantic slot, never read as the source of state.
  Color color(DaybreakColors c) => switch (this) {
        DayState.taken => c.stateTaken,
        DayState.missed => c.stateMissed,
        DayState.today => c.stateToday,
        DayState.upcoming => c.inkFaint,
      };
}

enum MarkerShape { filledDisc, hollowRing, ringWithCore, dashedCircle }

/// One day in a Schedule block. Takes pre-formatted primitives: the Notifier already
/// resolved the state against `clockProvider` and formatted the dose and date.
class DayStateRow extends StatelessWidget {
  const DayStateRow({
    required this.state,
    required this.dateLabel,
    required this.doseLabel,
    required this.isDoseChange,
    required this.onTap,
    super.key,
  });

  final DayState state;

  /// e.g. "Tue 14 Oct" — formatted by the Notifier via DateFormat.
  final String dateLabel;

  /// e.g. "12.5 mg" — formatted by the Notifier via NumberFormat.
  final String doseLabel;

  /// True on the first day of a new dose level: this population's error moment.
  final bool isDoseChange;

  final VoidCallback onTap;

  static const double _rowMinHeight = 64; // well past the 44px floor

  @override
  Widget build(BuildContext context) {
    final c = DaybreakColors.of(context);
    final e = DaybreakElevation.of(context);
    final sh = DaybreakShapes.of(context);
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    final isToday = state == DayState.today;
    final tint = state.color(c);

    return Semantics(
      button: true,
      container: true,
      label: '$dateLabel, $doseLabel',
      value: state.label(l10n), // the word, never the colour
      hint: isDoseChange ? l10n.dayNewDoseHint : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          margin: EdgeInsetsDirectional.symmetric(vertical: sh.s1),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: sh.s4,
            vertical: sh.s3,
          ),
          decoration: BoxDecoration(
            // Today is raised; every other row is flat. Elevation is signal 4.
            color: isToday ? c.surfaceRaised : c.surface,
            borderRadius: BorderRadius.all(sh.radiusMd),
            boxShadow: isToday ? e.level1 : e.level0,
            border: isToday ? Border.all(color: tint, width: 2) : null,
          ),
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DayStateMarker(state: state, color: tint),
                SizedBox(width: sh.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        doseLabel,
                        style: text.bodyLarge!.copyWith(
                          color: c.ink,
                          fontWeight: state.weight,
                          // Doses align down the column and never jitter on a step.
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        // The state WORD always ships next to the marker — the shape
                        // and the colour are never asked to carry the meaning alone.
                        '$dateLabel · ${state.label(l10n)}',
                        style: text.labelLarge!.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (isDoseChange) NewDoseTag(label: l10n.dayNewDoseTag),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dose change gets its own glyph + word + tint — three channels, because this is
/// where a 74-year-old on day 300 takes yesterday's dose by habit.
class NewDoseTag extends StatelessWidget {
  const NewDoseTag({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = DaybreakColors.of(context);
    final sh = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsetsDirectional.symmetric(horizontal: sh.s3, vertical: sh.s1),
      decoration: BoxDecoration(
        color: c.warningTint,
        borderRadius: BorderRadius.all(sh.radiusPill),
        border: Border.all(color: c.warningFill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_down, size: 16, color: c.stateNewDose),
          SizedBox(width: sh.s1),
          // Ink stays c.ink, not c.warning: the semantic colour is for the glyph and
          // the border; the text keeps its high-contrast pair.
          Text(
            label,
            style: text.labelLarge!.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the state's silhouette. Its size is fixed so the markers scan as a clean
/// column down the list edge; it carries a glyph on top for a second channel.
class DayStateMarker extends StatelessWidget {
  const DayStateMarker({required this.state, required this.color, super.key});

  final DayState state;
  final Color color;

  static const double size = 28;

  @override
  Widget build(BuildContext context) {
    final c = DaybreakColors.of(context);

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        // Token snapshot happens here, at the widget layer.
        painter: DayStateMarkerPainter(
          shape: state.shape,
          color: color,
          surface: c.surface,
          strokeWidth: 2.5,
        ),
        child: Center(
          child: state.glyph == null
              ? const SizedBox.shrink()
              : Icon(
                  state.glyph,
                  size: 16,
                  // On a filled disc the glyph sits on the fill; elsewhere on surface.
                  color: state.shape == MarkerShape.filledDisc ? c.surface : color,
                ),
        ),
      ),
    );
  }
}

/// Draws the four silhouettes. Pure fields in, pixels out — no BuildContext, so this
/// is unit-testable without a MaterialApp (see custom-canvas-and-gestures).
class DayStateMarkerPainter extends CustomPainter {
  const DayStateMarkerPainter({
    required this.shape,
    required this.color,
    required this.surface,
    required this.strokeWidth,
  });

  final MarkerShape shape;
  final Color color;
  final Color surface;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    switch (shape) {
      case MarkerShape.filledDisc:
        canvas.drawCircle(center, radius, Paint()..color = color);

      case MarkerShape.hollowRing:
        canvas.drawCircle(center, radius, _stroke());

      case MarkerShape.ringWithCore:
        canvas.drawCircle(center, radius, _stroke());
        canvas.drawCircle(center, radius * 0.42, Paint()..color = color);

      case MarkerShape.dashedCircle:
        _drawDashedCircle(canvas, center, radius);
    }
  }

  Paint _stroke() => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..color = color;

  void _drawDashedCircle(Canvas canvas, Offset center, double radius) {
    const dashes = 10;
    const gapRatio = 0.45;
    final arc = (2 * math.pi) / dashes;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = _stroke();

    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, arc * i, arc * (1 - gapRatio), false, paint);
    }
  }

  @override
  bool shouldRepaint(DayStateMarkerPainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.surface != surface ||
      old.strokeWidth != strokeWidth;
}
