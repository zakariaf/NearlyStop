/// The tablet-strength chip, and the group that wraps them.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tappable.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// One tablet strength the reader either holds or does not.
///
/// **Selection is three signals, never a tint.** A check glyph, `w800`, and a
/// 2px ring — so it survives a greyscale printout and a deuteranopic reader —
/// plus `Semantics(selected:)` for a screen reader. This is the control that
/// decides which tablets every breakdown in the app is built from; a reader who
/// misreads it gets the wrong count of the wrong strength every morning.
class StrengthChip extends StatelessWidget {
  /// Creates a chip for one strength.
  const StrengthChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Finds the decorated container, for tests that measure the ring.
  static const Key containerKey = Key('strength-chip-container');

  /// The glyph shown when selected.
  static const IconData selectedGlyph = Icons.check;

  /// The floor on both sides.
  static const double minSide = 44;

  /// The strength as the reader reads it, already localized ("5mg", "۵").
  final String label;

  /// The stable identity handed back on tap.
  ///
  /// Not the label: the label is localized, and a handler keyed on it would
  /// work in English and silently fail in Persian.
  final String value;

  /// Whether the reader holds this strength.
  final bool selected;

  /// Called with [value] on tap.
  final void Function(String value) onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return DaybreakTappable(
      semanticsLabel: label,
      selected: selected,
      onPressed: () => onSelected(value),
      child: Container(
        key: containerKey,
        constraints: const BoxConstraints(
          minWidth: minSide,
          minHeight: minSide,
        ),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: shapes.s4,
          vertical: shapes.s2,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.tintPrimary : colors.surfaceRaised,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
          border: Border.all(
            color: selected ? colors.borderStrong : colors.border,
            width: selected ? 2 : shapes.hairlineWidth,
          ),
        ),
        child: Center(
          heightFactor: 1,
          widthFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                Icon(selectedGlyph, size: 18, color: colors.primaryDeep),
                SizedBox(width: shapes.s1),
              ],
              Text(
                label,
                style: text.titleMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chips, laid out so none of them can hide.
///
/// **A `Wrap`, never a horizontal scroller.** At 200% text scale a strip pushes
/// strengths off the edge, and the one it pushes off is a tablet the reader
/// actually holds — which makes every breakdown in the app wrong without ever
/// looking wrong.
class StrengthChipGroup extends StatelessWidget {
  /// Creates a wrapping group.
  const StrengthChipGroup({
    required this.chips,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Every strength on offer, in the order they should read.
  final List<({String label, String value})> chips;

  /// The values the reader holds.
  final Set<String> selected;

  /// Called with a chip's value on tap.
  final void Function(String value) onSelected;

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    return Wrap(
      spacing: shapes.s2,
      runSpacing: shapes.s2,
      children: <Widget>[
        for (final chip in chips)
          StrengthChip(
            label: chip.label,
            value: chip.value,
            selected: selected.contains(chip.value),
            onSelected: onSelected,
          ),
      ],
    );
  }
}
