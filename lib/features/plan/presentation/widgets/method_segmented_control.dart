/// The taper-method chooser, which reflows before its labels break.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tappable.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/type_weight.dart';

/// Chooses between the three taper methods.
///
/// **It stacks when the labels do not fit, measured.** Three equal-width
/// segments holding "Dead Slow and Nearly Stop", "Prozentual" or
/// "روش کاهش بسیار آهسته" cannot survive a text scale this audience routinely
/// uses — each segment becomes a column of stacked letters.
///
/// The trigger is the CONSTRAINTS, not a text-scale number. A threshold picked
/// against German at 1.5 still splits English "Percentage" into "Percentag" and
/// "e" at 1.0 on a 390pt phone, because a third of that row was never wide
/// enough for the word; the reference frame is captured at exactly that size
/// and shows the label whole. Measuring the widest label against the share it
/// would get answers for every locale and every scale at once.
class MethodSegmentedControl extends StatelessWidget {
  /// Creates the chooser.
  const MethodSegmentedControl({
    required this.value,
    required this.labels,
    required this.onChanged,
    super.key,
  });

  /// The most lines the one wrapping label may use.
  ///
  /// Three, because the reference frame shows "Dead Slow and Nearly Stop" on
  /// exactly three lines. A fourth is a column of single words pretending to
  /// be a segment — and a SECOND wrapping label means the row has stopped
  /// working at all, which is what a large text scale does to it.
  static const int maxWrappedLines = 3;

  /// The chosen method. `TaperMethod.dsns` is the app's default (SPEC.md §4.4).
  final TaperMethod value;

  /// Each method's label, already localized.
  final Map<TaperMethod, String> labels;

  /// Called with the tapped method.
  final void Function(TaperMethod method) onChanged;

  @override
  Widget build(BuildContext context) {
    // Checked HERE rather than in the constructor. As a constructor assert it
    // reads `labels.length`, which is not a constant expression — so the
    // widget stops being `const`-constructible and every call site pays for
    // one check. In `build` it still fires on the first frame and still names
    // the widget, which is the whole point: `labels[method]!` on a partial map
    // throws "Null check operator used on a null value" from inside a build,
    // naming neither. A fourth method added in EPIC-11 without a string is
    // exactly how that arrives.
    assert(
      labels.length == TaperMethod.values.length,
      'labels must cover every TaperMethod; got ${labels.keys.toList()}',
    );
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    final segments = <Widget>[
      for (final method in TaperMethod.values)
        MethodSegment(
          method: method,
          label: labels[method]!,
          selected: method == value,
          onTap: () => onChanged(method),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(shapes.s1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final row = _measure(context, constraints.maxWidth);
            if (row == null) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: segments,
              );
            }
            // `IntrinsicHeight`, because `stretch` needs a bounded cross axis
            // and this control is placed inside scroll views that do not give
            // it one. Three children, so the extra measuring pass is cheap.
            return IntrinsicHeight(
              child: Row(
                // STRETCH, so every segment is the height of the tallest. The
                // reference shows three tiles filling the control; centred
                // children leave the short ones floating in a band of ground.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var index = 0; index < segments.length; index++)
                    // Flex by the label's own width, not equal thirds. "Dead
                    // Slow and Nearly Stop" is three times the width of "Fixed
                    // mg"; giving them the same third is what cuts "Percentage"
                    // into "Percentag" and "e" on the reference's own 390pt
                    // phone, and the reference shows all three whole.
                    Expanded(flex: row[index], child: segments[index]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The flex weights for a side-by-side row, or null when it cannot be one.
  ///
  /// Each segment is first given the width of its own longest WORD, so nothing
  /// is ever cut in half; whatever is left over is then shared out in
  /// proportion to how much each label would still like. That is what the
  /// reference frame shows: "Dead Slow and Nearly Stop" wraps onto three lines
  /// while "Percentage" and "Fixed mg" sit whole beside it. Equal thirds
  /// cannot produce that — it starves the short labels to pay for the long one
  /// and then breaks the word it starved.
  ///
  /// Returns null when even the longest words do not fit, or when a label
  /// would need more than [maxWrappedLines]. Measured with the style and the
  /// scaler the segment paints with, so the answer cannot disagree with what
  /// is rendered.
  List<int>? _measure(BuildContext context, double available) {
    if (!available.isFinite || available <= 0) return null;
    final shapes = DaybreakShapes.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    // The SELECTED weight, which is the heavier of the two: a control that
    // fits until you tap the longest segment is a control that reflows under
    // the reader's finger.
    final style = Theme.of(
      context,
    ).textTheme.titleSmall?.atWeight(FontWeight.w800);
    final direction = Directionality.of(context);
    final inset = shapes.s3 * 2;

    TextPainter painterFor(String text, double maxWidth) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);

    double widthOf(String text) {
      final painter = painterFor(text, double.infinity);
      final width = painter.width;
      painter.dispose();
      return width;
    }

    int linesOf(String text, double maxWidth) {
      final painter = painterFor(text, maxWidth);
      final lines = painter.computeLineMetrics().length;
      painter.dispose();
      return lines;
    }

    final texts = <String>[
      for (final method in TaperMethod.values) labels[method]!,
    ];
    final floors = <double>[
      for (final text in texts)
        text
                .split(RegExp(r'\s+'))
                .where((word) => word.isNotEmpty)
                .map(widthOf)
                .fold<double>(0, (a, b) => a > b ? a : b) +
            inset,
    ];
    final wanted = <double>[for (final text in texts) widthOf(text) + inset];

    if (floors.reduce((a, b) => a + b) > available) return null;

    // Max-min fair: nobody gets more than they need, and nobody is squeezed
    // below an equal share while somebody else has surplus. Handing out equal
    // thirds instead starves "Percentage" to pay for a name three times its
    // length, and then breaks the word it starved.
    final shares = List<double>.filled(texts.length, 0);
    final order = List<int>.generate(texts.length, (index) => index)
      ..sort((a, b) => wanted[a].compareTo(wanted[b]));
    var budget = available;
    var left = texts.length;
    for (final index in order) {
      final cap = budget / left;
      shares[index] = wanted[index] < cap ? wanted[index] : cap;
      budget -= shares[index];
      left--;
    }

    // At most ONE label may wrap, and it may use at most [maxWrappedLines].
    // That is the reference's own tolerance: at 1.0 "Dead Slow and Nearly
    // Stop" wraps onto three lines while the other two sit whole beside it.
    // Once a second label has to wrap, nothing on the row is reading as a
    // label any more — which is exactly what a large text scale does to it.
    var wrapped = 0;
    for (var index = 0; index < texts.length; index++) {
      final lines = linesOf(texts[index], shares[index] - inset);
      if (lines > maxWrappedLines) return null;
      if (lines > 1) wrapped++;
    }
    if (wrapped > 1) return null;

    return <int>[
      // Rounded to a whole flex unit at 0.1% resolution: `Expanded` takes an
      // int, and rounding to a percent would visibly mis-split three labels
      // whose widths differ by less than that.
      for (final share in shares) (share / available * 1000).round(),
    ];
  }
}

/// One method in a [MethodSegmentedControl].
///
/// Public so the tests can find a segment by type; a test that reached for an
/// anonymous `Container` would break the moment the padding changed.
class MethodSegment extends StatelessWidget {
  /// Creates one segment.
  const MethodSegment({
    required this.method,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// Which method this segment offers.
  final TaperMethod method;

  /// Its label, already localized.
  final String label;

  /// Whether it is the chosen one.
  final bool selected;

  /// Called on tap.
  final VoidCallback onTap;

  /// The floor on a segment's height.
  static const double minHeight = 48;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final elevation = DaybreakElevation.of(context);

    return DaybreakTappable(
      semanticsLabel: label,
      selected: selected,
      // The group is what makes a screen reader say "1 of 3" rather than
      // reading three unrelated buttons.
      inMutuallyExclusiveGroup: true,
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: minHeight),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: shapes.s3,
          vertical: shapes.s2,
        ),
        decoration: BoxDecoration(
          // Selection is a RAISED TILE plus weight, not a tint: both survive
          // greyscale, and the tile survives it best.
          color: selected ? colors.surface : null,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusSm)),
          boxShadow: selected ? elevation.level1 : elevation.level0,
        ),
        child: Center(
          heightFactor: 1,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall
                ?.atWeight(selected ? FontWeight.w800 : FontWeight.w600)
                .copyWith(color: selected ? colors.ink : colors.inkMuted),
          ),
        ),
      ),
    );
  }
}
