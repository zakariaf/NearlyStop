/// The Today screen's reason to exist.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/today/presentation/widgets/new_dose_badge.dart';
import 'package:nearlystop/features/today/presentation/widgets/sunrise_arc_painter.dart';
import 'package:nearlystop/features/today/presentation/widgets/tablet_breakdown_pill.dart';
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
    required this.unachievableMessage,
    required this.dateText,
    required this.dayKindLabel,
    required this.isNewDoseDay,
    required this.semanticsLabel,
    required this.takenLabel,
    required this.isTaken,
    required this.onTaken,
    required this.onUndo,
    super.key,
  });

  /// The dose, already in the locale's digits.
  final String doseText;

  /// The unit beside it, e.g. `mg`.
  final String unitText;

  /// The tablet breakdown, already bidi-isolated.
  final String? tabletsText;

  /// Why the dose cannot be made, when [tabletsText] is null.
  ///
  /// Exactly one of the two is non-null. SPEC.md §3.3 and CLAUDE.md rule 5: an
  /// unachievable dose is FLAGGED, never rounded — and never shown beside a
  /// breakdown that invites the reader to take it anyway.
  final String? unachievableMessage;

  /// Today's date, already formatted for the locale.
  final String dateText;

  /// The day-kind badge's word, e.g. *New dose day*. A **word**, not a colour.
  final String dayKindLabel;

  /// Whether today takes the step's new dose.
  ///
  /// Gates the badge. On an old-dose day the slot is EMPTY rather than a
  /// second badge saying the opposite: a badge that is always there is
  /// furniture, and furniture is not read.
  final bool isNewDoseDay;

  /// The one sentence a screen reader speaks for the whole card.
  final String semanticsLabel;

  /// The action's label.
  final String takenLabel;

  /// Whether the dose is already recorded.
  final bool isTaken;

  /// Records the dose. Never called when [isTaken].
  final VoidCallback onTaken;

  /// Reverses the tick. What the action does once [isTaken].
  final VoidCallback onUndo;

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
                      isNewDoseDay: isNewDoseDay,
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
                    if (tabletsText case final tablets?)
                      TabletBreakdownPill(text: tablets)
                    else
                      _UnachievableStrip(message: unachievableMessage!),
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
                  // Once taken, the action UNDOES. It never becomes dead: a
                  // reader who ticked the wrong day needs a way back, and it
                  // is the same 88pt target their thumb already found.
                  onPressed: isTaken ? onUndo : onTaken,
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
    required this.isNewDoseDay,
    required this.colors,
    required this.shapes,
  });

  final String dateText;
  final String dayKindLabel;

  /// Whether today takes the step's new dose.
  ///
  /// Gates the badge. On an old-dose day the slot is EMPTY rather than a
  /// second badge saying the opposite: a badge that is always there is
  /// furniture, and furniture is not read.
  final bool isNewDoseDay;
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
        // Rendered ONLY on a new-dose day. `NewDoseBadge` is the shared
        // recipe — shape, glyph AND word — and on an old-dose day the slot
        // is empty rather than a second badge saying the opposite.
        if (isNewDoseDay) NewDoseBadge(label: dayKindLabel),
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

/// The strip that REPLACES the tablet pill when the dose cannot be made.
///
/// `SPEC.md` §3.3 and CLAUDE.md rule 5. It carries the exact dose, unrounded,
/// and it appears INSTEAD of a breakdown rather than beside one — a reader who
/// sees both will take the breakdown.
class _UnachievableStrip extends StatelessWidget {
  const _UnachievableStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Container(
      padding: EdgeInsetsDirectional.all(shapes.s3),
      decoration: BoxDecoration(
        color: colors.tintWarning,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
        border: Border.all(
          color: colors.warningFill,
          width: shapes.hairlineWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 20, color: colors.warning),
          SizedBox(width: shapes.s2),
          Expanded(
            child: Text(
              message,
              // Body ink, not the warning colour: the semantic amber is for
              // the glyph and the border. A whole sentence in it is harder to
              // read and reads as a telling-off.
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
