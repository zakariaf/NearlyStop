/// The taper-method chooser, which reflows before its labels break.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/core/dsns/facts.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// Chooses between the three taper methods.
///
/// **Above 1.5× text scale it becomes a vertical list.** Three equal-width
/// segments holding "Dead Slow and Nearly Stop", "Prozentual" or
/// "روش کاهش بسیار آهسته" cannot survive a scale this audience routinely uses —
/// each segment becomes a column of stacked letters. The reflow happens before
/// that, not after.
class MethodSegmentedControl extends StatelessWidget {
  /// Creates the chooser.
  const MethodSegmentedControl({
    required this.value,
    required this.labels,
    required this.onChanged,
    super.key,
  });

  /// Above this text scale the segments stack.
  ///
  /// 1.5 is the last scale at which three German method names still fit side
  /// by side on a 390pt screen; measured, not chosen.
  static const double stackAboveTextScale = 1.5;

  /// The chosen method. `TaperMethod.dsns` is the app's default (SPEC.md §4.4).
  final TaperMethod value;

  /// Each method's label, already localized.
  final Map<TaperMethod, String> labels;

  /// Called with the tapped method.
  final void Function(TaperMethod method) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > stackAboveTextScale;

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
        child: stacked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: segments,
              )
            : Row(
                children: <Widget>[
                  // `Expanded`, so the three are equal by construction rather
                  // than by whichever label happens to be longest.
                  for (final segment in segments) Expanded(child: segment),
                ],
              ),
      ),
    );
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

    return Semantics(
      container: true,
      button: true,
      // The group is what makes a screen reader say "1 of 3" rather than
      // reading three unrelated buttons.
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: minHeight),
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: shapes.s3,
              vertical: shapes.s2,
            ),
            decoration: BoxDecoration(
              // Selection is a RAISED TILE plus weight, not a tint: both
              // survive greyscale, and the tile survives it best.
              color: selected ? colors.surface : null,
              borderRadius: BorderRadius.all(Radius.circular(shapes.radiusSm)),
              boxShadow: selected ? elevation.level1 : elevation.level0,
            ),
            child: Center(
              heightFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? colors.ink : colors.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
