/// One day in the schedule list.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_marker.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// One schedule row: a marker, the day, the dose, and the state as a word.
///
/// **Primitives only.** Every string arrives formatted and localized — the
/// notifier composes, the widget paints. There is no `ref`, no `DateTime` and
/// no drift row in here, which is what lets the whole quartet be golden-tested
/// without a database.
///
/// **Colour is never the only channel.** Each state carries a distinct SHAPE
/// (see [DayStateMarker]), a localized WORD, and a colour, in that order of
/// importance. A greyscale printout and a deuteranopic reader both still get
/// the answer to "did I take it?".
class DayStateRow extends StatelessWidget {
  /// Creates a row for one day.
  const DayStateRow({
    required this.state,
    required this.dayLabel,
    required this.doseText,
    required this.stateLabel,
    required this.semanticsLabel,
    this.tabletsText,
    this.isNewDose = false,
    this.newDoseLabel,
    this.isHoldDay = false,
    this.holdLabel,
    this.unachievableText,
    super.key,
  }) : assert(
         !isHoldDay || holdLabel != null,
         'a hold day is explained by a glyph AND a word; the glyph alone is a '
         'shape nobody has been taught',
       ),
       assert(
         tabletsText != null || unachievableText != null,
         'a row shows a tablet breakdown OR the unachievable flag — never '
         'neither, which would leave the dose unexplained',
       ),
       assert(
         !isNewDose || newDoseLabel != null,
         'the new-dose signal is colour + glyph + WORD; without the word it '
         'is colour alone',
       );

  /// Finds the row's decorated container, for tests that measure it.
  static const Key containerKey = Key('day-state-row-container');

  /// Finds the `CustomPaint` that draws the row's outline.
  static const Key borderKey = Key('day-state-row-border');

  /// The glyph that accompanies the hold word.
  ///
  /// A pause bracket: distinct in SHAPE from all four state markers and from
  /// the new-dose arrow, because a run of five held days is exactly where a
  /// colour-only signal would leave the reader guessing.
  static const IconData holdGlyph = Icons.pause_circle_outline;

  /// The glyph that accompanies the new-dose word.
  ///
  /// A direction glyph, because a dose change is exactly where this population
  /// makes mistakes and "which way" is the thing they need to see.
  static const IconData newDoseGlyph = Icons.south_east;

  /// The row's minimum height, from `.srow` in the reference.
  static const double minHeight = 64;

  /// Above this text scale the row stacks instead of staying side by side.
  ///
  /// **Measured, not chosen.** At 2.0 on a 390pt screen the day block and the
  /// end block each fight for a width the marker and the gaps have already
  /// eaten, and the loser wraps one glyph per line: a single row measured
  /// 826pt tall with "New dose day" running vertically down the screen. 1.6 is
  /// the last scale at which both blocks still have a readable width, and it
  /// is deliberately the same boundary the dose hero card degrades at, so the
  /// two screens change shape together rather than one at a time.
  static const double stackAboveTextScale = 1.6;

  /// Which of the four states this day is in.
  final DayState state;

  /// "Wed 16 Apr" — weekday and date on ONE line, already localized and
  /// already in the active calendar.
  ///
  /// One string, not a weekday and a date: frame 3's `.sday` is a single line,
  /// and the second line of that column belongs to [tabletsText].
  final String dayLabel;

  /// The dose with its unit, already formatted.
  final String doseText;

  /// The state word, already localized. Never omitted: it is the channel that
  /// survives greyscale, colour-blindness and a screen reader.
  final String stateLabel;

  /// The whole row as one sentence, for the semantics tree.
  final String semanticsLabel;

  /// The tablet breakdown, or null when [unachievableText] is supplied.
  final String? tabletsText;

  /// Whether this is the day the new dose is taken.
  ///
  /// A separate channel, never a fifth [DayState] member: a day is routinely
  /// both `today` and a new-dose day (CONTRACTS.md §1).
  final bool isNewDose;

  /// The new-dose word, already localized. Required when [isNewDose].
  final String? newDoseLabel;

  /// Whether this day was inserted by a hold.
  ///
  /// A separate channel, exactly like [isNewDose] and for the same reason. The
  /// alternative — replacing the state marker and the state word with a hold
  /// treatment — takes both the shape channel and the word channel away from
  /// taken/not-taken for up to 28 consecutive days, on rows whose only job is
  /// answering "did I take it?".
  final bool isHoldDay;

  /// "Held at block 3", already localized. Required when [isHoldDay].
  final String? holdLabel;

  /// The flag shown INSTEAD of a tablet breakdown when the dose cannot be made
  /// from the tablets held.
  ///
  /// Never a rounded number (SPEC.md §3.3, CLAUDE.md rule 5). Rounding a
  /// steroid dose silently is the one unforgivable bug in this app.
  final String? unachievableText;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final elevation = DaybreakElevation.of(context);
    final isToday = state == DayState.today;
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > stackAboveTextScale;
    final dayBlock = _DayBlock(
      dayLabel: dayLabel,
      isHoldDay: isHoldDay,
      holdLabel: holdLabel,
      tabletsText: tabletsText,
      unachievableText: unachievableText,
      isToday: isToday,
      isNewDose: isNewDose,
      newDoseLabel: newDoseLabel,
    );

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          key: containerKey,
          constraints: const BoxConstraints(minHeight: minHeight),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: shapes.s4,
            vertical: shapes.s3,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
            // The outline is PAINTED, not a `BorderSide` — see
            // [RowBorderPainter].
            // `level0` is an empty list, so the negative assertion in the test
            // reads as "no shadow" rather than "a shadow of zero blur".
            boxShadow: isToday ? elevation.level2 : elevation.level0,
          ),
          child: CustomPaint(
            key: borderKey,
            foregroundPainter: RowBorderPainter(
              color: _borderColor(colors),
              width: isToday ? 2 : shapes.hairlineWidth,
              radius: shapes.radiusMd,
              dashed: state == DayState.missed,
            ),
            child: stacked
                // The large-text layout: the end block moves UNDER the day
                // block. The marker stays on the day block's line, because it
                // is the thing the eye runs down the list edge looking for —
                // moving it would cost the scan line the whole screen is
                // organised around.
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          DayStateMarker(state: state, isNewDose: isNewDose),
                          SizedBox(width: shapes.s3),
                          Expanded(child: dayBlock),
                        ],
                      ),
                      SizedBox(height: shapes.s2),
                      // Aligned to the START when stacked: a right-aligned
                      // block under a left-aligned one reads as two unrelated
                      // things, and at this size the reader is following one
                      // line down the page.
                      _DayEndBlock(
                        doseText: doseText,
                        unachievableText: unachievableText,
                        stateLabel: stateLabel,
                        stateWordColor: _stateWordColor(colors),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        textAlign: TextAlign.start,
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      DayStateMarker(state: state, isNewDose: isNewDose),
                      SizedBox(width: shapes.s3),
                      Expanded(child: dayBlock),
                      SizedBox(width: shapes.s3),
                      Flexible(
                        child: _DayEndBlock(
                          doseText: doseText,
                          unachievableText: unachievableText,
                          stateLabel: stateLabel,
                          stateWordColor: _stateWordColor(colors),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// The border colour, which is part of the state signal for `missed`.
  ///
  /// `stateMissed` here rather than `borderStrong`: the two resolve to the same
  /// value in both themes today, and asserting a coincidence is not asserting
  /// anything. This names the token the state actually owns.
  Color _borderColor(DaybreakColors colors) => switch (state) {
    DayState.today => colors.stateToday,
    DayState.missed => colors.stateMissed,
    DayState.taken || DayState.upcoming => colors.border,
  };

  /// The state word's colour, at **text** tier.
  ///
  /// The `state*` slots are MARK-tier — EPIC-02's contrast budget pins them at
  /// the 3:1 non-text floor, and `stateMissed` measures 3.65:1 on surface. A
  /// word is text and needs 4.5:1, so the word cannot simply take the state
  /// colour; CLAUDE.md rule 4 outranks EPIC-07 task 4's "all three places".
  ///
  /// For `missed` that means `inkMuted`: the same warm clay family, 2.5 degrees
  /// away in hue from `stateMissed` and 15.5 from `danger`, at 6.23:1. The
  /// ruling that matters — warm taupe, never red — holds; only the tier moves,
  /// which is what the tier is for. `taken` and `today` already have text-tier
  /// semantic colours and use them, exactly as the reference does.
  Color _stateWordColor(DaybreakColors colors) => switch (state) {
    DayState.taken => colors.success,
    DayState.today => colors.primaryDeep,
    DayState.missed || DayState.upcoming => colors.inkMuted,
  };
}

/// The row's outline, drawn rather than declared.
///
/// **Flutter has no dashed `BorderSide`.** `.srow.missed` in the reference is
/// `border-style: dashed`, and that dash is not decoration — it is one more
/// channel that answers "was this taken?" after colour has been taken away by
/// a greyscale printout or a deuteranopic reader. Rendering it solid would
/// leave `missed` distinguished from `upcoming` by a taupe nobody can name.
///
/// Every value is snapshotted at the widget layer; `paint()` takes no
/// `BuildContext`.
@immutable
class RowBorderPainter extends CustomPainter {
  /// Creates the painter from already-resolved values.
  const RowBorderPainter({
    required this.color,
    required this.width,
    required this.radius,
    required this.dashed,
  });

  /// The outline colour, already resolved from the palette.
  final Color color;

  /// The stroke width. `today` is 2; everything else is a hairline.
  final double width;

  /// The corner radius, matching the container's.
  final double radius;

  /// Whether the outline is drawn as dashes.
  final bool dashed;

  /// The dash and gap length, in logical pixels.
  ///
  /// Fixed rather than derived from the perimeter: every row in the list has a
  /// different height once the text scales, and a derived dash would make the
  /// rhythm change from row to row down a 52-day block.
  static const double _dashLength = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || width <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    // Inset by half the stroke so the outline sits inside the row's bounds
    // rather than straddling them — otherwise a 2px `today` border is clipped
    // to 1px by the container.
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        width / 2,
        width / 2,
        size.width - width,
        size.height - width,
      ),
      Radius.circular(radius),
    );

    if (!dashed) {
      canvas.drawRRect(rect, paint);
      return;
    }

    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + _dashLength).clamp(0, metric.length),
          ),
          paint,
        );
        distance += _dashLength * 2;
      }
    }
  }

  @override
  bool shouldRepaint(RowBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.radius != radius ||
      oldDelegate.dashed != dashed;
}

/// The weekday, the date, and the new-dose badge when there is one.
///
/// A CLASS, not a `_buildX()` helper: a helper has no `Element` boundary, so a
/// row that rebuilds for any reason rebuilds this subtree too, and it cannot
/// be `const`. `widget-composition` bans them outright.
class _DayBlock extends StatelessWidget {
  const _DayBlock({
    required this.dayLabel,
    required this.isHoldDay,
    required this.holdLabel,
    required this.tabletsText,
    required this.unachievableText,
    required this.isToday,
    required this.isNewDose,
    required this.newDoseLabel,
  });

  final String dayLabel;
  final bool isHoldDay;
  final String? holdLabel;
  final String? tabletsText;
  final String? unachievableText;
  final bool isToday;
  final bool isNewDose;
  final String? newDoseLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          dayLabel,
          style: text.bodyLarge?.copyWith(
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
            color: colors.ink,
          ),
        ),
        // `.stab`: what you actually swallow that day, directly under the day
        // it belongs to. The trailing column carries the dose and the state,
        // and nothing else.
        if (tabletsText case final tablets?)
          Text(
            tablets,
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.inkMuted,
            ),
          ),
        if (unachievableText case final flag?)
          Text(
            flag,
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.warning,
            ),
          ),
        if (isHoldDay) ...<Widget>[
          SizedBox(height: shapes.s1),
          _DayChannelChip(
            glyph: DayStateRow.holdGlyph,
            label: holdLabel!,
            color: colors.inkMuted,
          ),
        ],
        if (isNewDose) ...<Widget>[
          SizedBox(height: shapes.s1),
          // Colour AND glyph AND word — all three, always.
          _DayChannelChip(
            glyph: DayStateRow.newDoseGlyph,
            label: newDoseLabel!,
            color: colors.stateNewDose,
          ),
        ],
      ],
    );
  }
}

/// The dose, the tablet breakdown or the unachievable flag, and the state word.
class _DayEndBlock extends StatelessWidget {
  const _DayEndBlock({
    required this.doseText,
    required this.unachievableText,
    required this.stateLabel,
    required this.stateWordColor,
    this.crossAxisAlignment = CrossAxisAlignment.end,
    this.textAlign = TextAlign.end,
  });

  final String doseText;
  final String? unachievableText;
  final String stateLabel;
  final Color stateWordColor;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The dose is suppressed entirely when the composition is
        // unachievable: showing "9mg" beside "cannot be made" invites the
        // reader to take 9mg.
        if (unachievableText == null)
          Text(
            doseText,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.ink,
            ),
          ),
        SizedBox(height: shapes.s1),
        Text(
          stateLabel,
          style: text.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: stateWordColor,
          ),
          textAlign: textAlign,
        ),
      ],
    );
  }
}

/// A glyph and a word beside the day, for a channel that is not the state.
///
/// New-dose and held both ride here. Neither is a fifth [DayState] member: a
/// day is routinely both `today` and a new-dose day, and a held day is still
/// either taken or not (CONTRACTS.md §1).
class _DayChannelChip extends StatelessWidget {
  const _DayChannelChip({
    required this.glyph,
    required this.label,
    required this.color,
  });

  final IconData glyph;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(glyph, size: 16, color: color),
        SizedBox(width: shapes.s1),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
