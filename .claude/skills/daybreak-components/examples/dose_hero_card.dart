// Demonstrates the NearlyStop Daybreak dose hero card: the sunrise-gradient card
// that carries today's dose. Shows (a) every visual value read from a Daybreak token
// slot, (b) a CustomPainter that snapshots those tokens at the widget layer and never
// touches BuildContext in paint(), (c) tabular display numerals that never shrink, and
// (d) an explicit degradation ladder at large text scale: the decorative arc goes first,
// then the Row becomes a Column — the number itself never gives way.
//
// Lives at: lib/features/today/presentation/widgets/dose_hero_card.dart

import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nearlystop/l10n/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';
import 'package:nearlystop/theme/daybreak_radii.dart';
import 'package:nearlystop/theme/daybreak_spacing.dart';

/// The Today screen's hero. Takes pre-formatted, pre-localized primitives only —
/// the Notifier resolved the dose, the day index, and the high/low wording.
class DoseHeroCard extends StatelessWidget {
  const DoseHeroCard({
    required this.doseAmount,
    required this.doseUnit,
    required this.dayCaption,
    required this.isTaken,
    required this.onTaken,
    super.key,
  });

  /// Already formatted by the Notifier via NumberFormat, e.g. "12.5".
  final String doseAmount;

  /// Localized unit word, e.g. "mg" / "میلی‌گرم".
  final String doseUnit;

  /// e.g. "Day 43 · high day" — wraps, never truncates.
  final String dayCaption;

  final bool isTaken;
  final VoidCallback onTaken;

  /// Above this scale the decorative arc is dropped: it would either collide with
  /// the numeral or force the card taller than a 6am one-handed reach.
  static const double _arcDropScale = 1.6;

  /// Above this scale the amount/unit Row becomes a Column.
  static const double _stackScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final c = DaybreakColors.of(context);
    final e = DaybreakElevation.of(context);
    final r = DaybreakRadii.of(context);
    final s = DaybreakSpacing.of(context);
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    // textScaler is READ to choose a layout, never clamped and never applied to a
    // fontSize by hand. accessibility-as-code owns that distinction.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final showArc = scale <= _arcDropScale;
    final stacked = scale > _stackScale;

    final amountStyle = text.displayLarge!.copyWith(
      color: c.onPrimary,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final unitStyle = text.titleLarge!.copyWith(
      color: c.onPrimary,
      fontWeight: FontWeight.w600,
    );

    final amount = Text(doseAmount, style: amountStyle); // never FittedBox'd
    final unit = Text(doseUnit, style: unitStyle);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: c.sunrise, // slot — the ONLY component allowed this gradient
        borderRadius: BorderRadius.all(r.xl),
        boxShadow: e.shadowGlow, // warm-tinted; never a black shadow
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(s.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The whole dose face is ONE semantic node: a screen-reader user hears
            // "Today, 12.5 milligrams, day 43, high day" once — not four fragments.
            // The button is deliberately OUTSIDE this node so it stays focusable.
            Semantics(
              container: true,
              label: l10n.todayDoseSemanticLabel(doseAmount, doseUnit, dayCaption),
              value: isTaken ? l10n.dayStateTaken : l10n.dayStateUpcoming,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The arc paints BEHIND the numeral; decorative, dropped first.
                    Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [
                        if (showArc)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SunriseArcPainter(
                                // Tokens snapshotted HERE, at the widget layer.
                                stroke: c.onPrimaryDecorative, // the 2.8:1 pair
                                strokeWidth: 3,
                                sweep: isTaken ? 1 : 0.62,
                              ),
                            ),
                          ),
                        if (stacked)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [amount, unit],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            mainAxisSize: MainAxisSize.min,
                            children: [amount, SizedBox(width: s.s2), unit],
                          ),
                      ],
                    ),
                    SizedBox(height: s.s3),
                    Text(
                      dayCaption,
                      style: text.bodyLarge!.copyWith(color: c.onPrimary),
                      // No maxLines, no ellipsis: it wraps as far as it needs to.
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: s.s6),
            TakenButton(isTaken: isTaken, onPressed: onTaken),
          ],
        ),
      ),
    );
  }
}

/// The app's one important control: 88 tall, full width, single tap, haptic.
/// Deliberately far above the 44x44 floor — it is pressed half-awake, one-handed.
class TakenButton extends StatelessWidget {
  const TakenButton({required this.isTaken, required this.onPressed, super.key});

  final bool isTaken;
  final VoidCallback onPressed;

  static const double minHeight = 88;

  @override
  Widget build(BuildContext context) {
    final c = DaybreakColors.of(context);
    final r = DaybreakRadii.of(context);
    final motion = DaybreakMotion.of(context);
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    // Reduced motion collapses the press animation to zero (design-system-structure).
    final duration = resolveMotion(context, motion.fast);

    return Semantics(
      button: true,
      enabled: !isTaken,
      label: isTaken ? l10n.doseTakenButtonDone : l10n.doseTakenButton,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isTaken
            ? null
            : () {
                HapticFeedback.selectionClick(); // survives reduced motion
                onPressed();
              },
        child: AnimatedContainer(
          duration: duration,
          curve: motion.easeOut,
          constraints: const BoxConstraints(minHeight: minHeight),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isTaken ? c.successTint : c.surface,
            borderRadius: BorderRadius.all(r.pill),
            border: Border.all(color: isTaken ? c.successFill : c.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                // Shape differs per state — not a recolour of one glyph.
                isTaken ? Icons.check_circle : Icons.circle_outlined,
                color: isTaken ? c.success : c.primaryDeep,
                semanticLabel: null, // announced by the Semantics node above
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  isTaken ? l10n.doseTakenButtonDone : l10n.doseTakenButton,
                  style: text.titleLarge!.copyWith(
                    color: isTaken ? c.success : c.primaryDeep,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decorative sunrise arc. Receives a TOKEN SNAPSHOT — it never reads BuildContext,
/// so it allocates nothing per frame and can be unit-tested without a MaterialApp.
class SunriseArcPainter extends CustomPainter {
  const SunriseArcPainter({
    required this.stroke,
    required this.strokeWidth,
    required this.sweep,
  });

  /// The 2.8:1 decorative-only pair. Must never be used for text or a state ring.
  final Color stroke;
  final double strokeWidth;

  /// 0..1 — how much of the arc is drawn.
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) * 0.9;
    final center = Offset(size.width * 0.82, size.height * 1.05);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi, // start at due west
      math.pi * sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(SunriseArcPainter old) =>
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth ||
      old.sweep != sweep;
}

/// Provided by design-system-structure; repeated here so the example compiles alone.
Duration resolveMotion(BuildContext context, Duration full) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : full;
