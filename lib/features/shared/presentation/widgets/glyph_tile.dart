/// The rounded tinted square a list row's glyph sits in.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// A 44pt `tintPrimary` square holding one glyph in `primaryDeep`.
///
/// The reference frames put every list glyph in one of these. A bare icon on a
/// white card carries the same information at a third of the size, and this
/// audience finds a small mark beside large text hard to connect to it.
///
/// It **scales with the text**, because a fixed 44pt tile beside doubled type
/// stops reading as a companion to the row and starts reading as a bullet.
class GlyphTile extends StatelessWidget {
  /// Creates the tile.
  const GlyphTile({required this.glyph, super.key});

  /// The tile's side at text scale 1.
  static const double side = 44;

  /// The glyph's size at text scale 1.
  static const double glyphSize = 22;

  /// What to draw inside.
  final IconData glyph;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: scaler.scale(side),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.tintPrimary,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
          ),
          child: Center(
            child: Icon(
              glyph,
              // `primaryDeep`, never `primary`: a glyph that carries meaning
              // is held to 3:1 and #F97350 measures 2.76 on this ground.
              color: colors.primaryDeep,
              size: scaler.scale(glyphSize),
            ),
          ),
        ),
      ),
    );
  }
}
