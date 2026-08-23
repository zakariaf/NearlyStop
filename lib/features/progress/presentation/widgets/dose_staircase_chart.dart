/// The card that owns the staircase.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/features/progress/presentation/widgets/dose_history_list.dart';
import 'package:nearlystop/features/progress/presentation/widgets/dose_staircase_painter.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// The dose over time, as a chart or — above 1.5× — as a list.
///
/// **No interaction, deliberately.** No tooltip, no crosshair, no pan. A tap
/// target that does nothing is worse than no tap target, and this is a
/// read-only trend line; the hit-testing machinery a chart usually needs is
/// weight this screen does not carry. Stated as a v1 deferral, and pinned by a
/// test so it stays a decision rather than an omission.
class DoseStaircaseChart extends StatelessWidget {
  /// Creates the card.
  const DoseStaircaseChart({
    required this.segments,
    required this.flares,
    required this.holds,
    required this.todayDayIndex,
    required this.todayDose,
    required this.axis,
    required this.summary,
    required this.historyRows,
    required this.eventCountLabel,
    super.key,
  });

  /// The card's plot height at 1.0, from the reference's `viewBox`.
  static const double plotHeight = 176;

  /// The glyph beside the flare-and-hold count.
  static const IconData eventGlyph = Icons.local_fire_department_outlined;

  /// Above this text scale the chart is replaced by [DoseHistoryList].
  ///
  /// **Measured, not chosen.** At 1.5× the axis labels still fit inside the
  /// 176px plot; at 1.6× the date labels collide with the baseline and the
  /// dose labels overlap each other. Shrinking them instead is the defect
  /// `accessibility-as-code` bans outright.
  static const double listAboveTextScale = 1.5;

  /// The treads, in order.
  final List<DoseSegment> segments;

  /// Flares, in date order.
  final List<FlareMark> flares;

  /// Holds, in date order.
  final List<HoldMark> holds;

  /// Where today sits on the x axis.
  final int todayDayIndex;

  /// Today's dose.
  final Milligrams todayDose;

  /// The y axis and the two date labels.
  final ProgressAxis axis;

  /// The chart as one sentence, for a screen reader.
  final String summary;

  /// The same information as rows, in date order.
  final List<String> historyRows;

  /// "2 flares and 1 hold recorded", already localized.
  final String eventCountLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;
    final scale = MediaQuery.textScalerOf(context);
    final perso =
        scriptFor(Localizations.localeOf(context)) == DaybreakScript.perso;
    final asList = scale.scale(1) > listAboveTextScale;

    return Container(
      padding: EdgeInsetsDirectional.all(shapes.s4),
      decoration: BoxDecoration(
        gradient: colors.wash,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
        border: Border.all(color: colors.border, width: shapes.hairlineWidth),
        boxShadow: DaybreakElevation.of(context).level2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            // Cased by the ARB, never by `.toUpperCase()`: Dart's casing is
            // locale-blind and the decision belongs to a translator.
            perso ? l10n.chartOverline : l10n.chartOverlineCaps,
            style: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.inkMuted,
              letterSpacing: perso
                  ? 0
                  : (text.labelSmall?.fontSize ?? 12) * 0.09,
            ),
          ),
          SizedBox(height: shapes.s3),
          if (asList)
            DoseHistoryList(title: l10n.doseHistoryTitle, rows: historyRows)
          else
            Semantics(
              label: summary,
              container: true,
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: SizedBox(
                    height: plotHeight,
                    child: CustomPaint(
                      painter: DoseStaircasePainter(
                        segments: segments,
                        flares: flares,
                        holds: holds,
                        todayDayIndex: todayDayIndex,
                        todayDose: todayDose,
                        minDose: axis.minDose,
                        maxDose: axis.maxDose,
                        gridline: colors.border,
                        lineGradient: colors.chartLine,
                        fillGradient: colors.chartFill,
                        flareRing: colors.danger,
                        flareGlyph: colors.danger,
                        holdBracket: colors.inkMuted,
                        markerFill: colors.surface,
                        todayRing: colors.stateToday,
                        strokeWidth: 3,
                        direction: Directionality.of(context),
                        labels: _labels(context, l10n),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: shapes.s3),
          Row(
            children: <Widget>[
              // The same glyph the chart marks a flare with, so the sentence
              // and the picture name the same thing.
              ExcludeSemantics(
                child: Icon(eventGlyph, size: 16, color: colors.danger),
              ),
              SizedBox(width: shapes.s2),
              Flexible(
                child: Text(
                  eventCountLabel,
                  style: text.bodySmall?.copyWith(color: colors.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The axis text, laid out HERE rather than inside `paint()`.
  ///
  /// This is the one thing a painter genuinely needs the theme for, so it is
  /// done once per build and handed over as metrics — instead of sixty times a
  /// second inside a paint call.
  DoseAxisLabels _labels(BuildContext context, AppLocalizations l10n) {
    final colors = DaybreakColors.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.localeOf(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.inkMuted,
    );

    TextPainter paint(String value) => TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();

    final mid = Milligrams.fromHundredths(
      (axis.minDose.hundredths + axis.maxDose.hundredths) ~/ 2,
    );
    return DoseAxisLabels(
      first: paint(axis.firstLabel),
      last: paint(axis.lastLabel),
      doses: <TextPainter>[
        for (final dose in <Milligrams>[axis.maxDose, mid, axis.minDose])
          paint('${formatDose(dose, locale)}${l10n.milligramUnit}'),
      ],
    );
  }
}
