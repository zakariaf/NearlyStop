/// The Today screen's reason to exist.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/today/presentation/widgets/sunrise_arc_painter.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

/// One gradient card, one number, one action.
///
/// **Primitives only.** Every string arrives already formatted and already
/// localized — the notifier formats, the widget paints. No `ref`, no drift row,
/// no `DateTime`, no `Milligrams`: a widget that formats a dose is a widget
/// that has to know about locales, and then the same rounding lives in two
/// places.
///
/// **The numeral never shrinks.** No `FittedBox`, no computed `fontSize`, no
/// `ellipsis`. Shrinking the one number the patient reads every morning turns a
/// loud layout failure into a quietly wrong dose on a phone, and this audience
/// will not notice the difference. If it does not fit, the layout degrades
/// around it — see [_arcVisibleBelow].
class DoseHeroCard extends StatelessWidget {
  /// Creates the card from pre-formatted text.
  const DoseHeroCard({
    required this.doseText,
    required this.unitText,
    required this.tabletsText,
    required this.dateText,
    required this.dayKindLabel,
    required this.semanticsLabel,
    required this.takenLabel,
    required this.isTaken,
    required this.onTaken,
    super.key,
  });

  /// The dose, already in the locale's digits.
  final String doseText;

  /// The unit beside it, e.g. `mg`.
  final String unitText;

  /// The tablet breakdown, already bidi-isolated.
  final String tabletsText;

  /// Today's date, already formatted for the locale.
  final String dateText;

  /// The day-kind badge's word, e.g. *New dose day*. A **word**, not a colour.
  final String dayKindLabel;

  /// The one sentence a screen reader speaks for the whole card.
  final String semanticsLabel;

  /// The action's label.
  final String takenLabel;

  /// Whether the dose is already recorded.
  final bool isTaken;

  /// Records the dose. Never called when [isTaken].
  final VoidCallback onTaken;

  /// Above this text scale the decorative arc is dropped.
  ///
  /// First step of the degradation order: arc → row becomes column → the
  /// caption's second line. Decoration goes before content, always.
  static const double _arcVisibleBelow = 1.6;

  /// Above this, the horizontal layout becomes vertical.
  static const double _columnAbove = 1.6;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final elevation = DaybreakElevation.of(context);
    final type = DaybreakTypography.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: colors.sunrise,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
          // `glow` is reserved for this card. One sunrise per screen.
          boxShadow: elevation.glow,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(shapes.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Only the VISUAL content is excluded. The action stays outside
              // the exclusion and keeps its own node: swallowing it too would
              // leave a screen-reader user with a card they can hear and no
              // way to record the dose — the one thing the screen is for.
              ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _Header(
                      dateText: dateText,
                      dayKindLabel: dayKindLabel,
                      colors: colors,
                      shapes: shapes,
                    ),
                    SizedBox(height: shapes.s4),
                    if (scale > _columnAbove)
                      _Numerals(
                        doseText: doseText,
                        unitText: unitText,
                        colors: colors,
                        type: type,
                      )
                    else
                      Row(
                        children: <Widget>[
                          _Numerals(
                            doseText: doseText,
                            unitText: unitText,
                            colors: colors,
                            type: type,
                          ),
                          if (scale < _arcVisibleBelow) ...<Widget>[
                            SizedBox(width: shapes.s4),
                            Expanded(
                              child: _Arc(colors: colors, shapes: shapes),
                            ),
                          ],
                        ],
                      ),
                    SizedBox(height: shapes.s3),
                    Text(
                      tabletsText,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: colors.onPrimary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: shapes.s4),
              // `liveRegion` on the wrapper only: the confirmation is spoken
              // when the state flips, while the button keeps its own node so a
              // screen reader still has something named to activate.
              Semantics(
                liveRegion: isTaken,
                child: TakenButton(
                  label: takenLabel,
                  onPressed: isTaken ? null : onTaken,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dateText,
    required this.dayKindLabel,
    required this.colors,
    required this.shapes,
  });

  final String dateText;
  final String dayKindLabel;
  final DaybreakColors colors;
  final DaybreakShapes shapes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: shapes.s3,
      runSpacing: shapes.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          dateText,
          style: text.labelLarge?.copyWith(color: colors.onPrimary),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: shapes.s3,
              vertical: shapes.s1,
            ),
            // A GLYPH and a WORD. Never colour alone: a deuteranopic reader
            // and a grayscale printout both have to answer "is this a new
            // dose day".
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.brightness_low,
                  size: shapes.s4,
                  color: colors.stateNewDose,
                ),
                SizedBox(width: shapes.s1),
                Text(
                  dayKindLabel,
                  style: text.labelMedium?.copyWith(color: colors.ink),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Numerals extends StatelessWidget {
  const _Numerals({
    required this.doseText,
    required this.unitText,
    required this.colors,
    required this.type,
  });

  final String doseText;
  final String unitText;
  final DaybreakColors colors;
  final DaybreakTypography type;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    textBaseline: TextBaseline.alphabetic,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    children: <Widget>[
      Text(
        doseText,
        // `doseNumeral` carries the tabular figures that stop 9 → 10 shifting
        // the numeral's start edge. No override of its size here, ever.
        style: type.doseNumeral.copyWith(color: colors.onPrimary),
      ),
      Text(
        unitText,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: colors.onPrimary),
      ),
    ],
  );
}

class _Arc extends StatelessWidget {
  const _Arc({required this.colors, required this.shapes});

  final DaybreakColors colors;
  final DaybreakShapes shapes;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: shapes.s9,
      child: CustomPaint(
        painter: SunriseArcPainter(
          arcColor: colors.onPrimary,
          strokeWidth: shapes.hairlineWidth * 3,
          sweep: math.pi,
          progress: 1,
        ),
      ),
    ),
  );
}
