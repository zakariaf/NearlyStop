/// Add note · Hold · Flare — subordinate, and equal.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tappable.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// The three actions that are not Taken.
///
/// **They must not compete with Taken.** No gradient, no glow, no primary ink:
/// there is one thing to do on this screen every morning, and two of these
/// three are used a handful of times in two years.
///
/// **Equal widths**, so none of them reads as the recommended one.
class QuietActionRow extends StatelessWidget {
  /// Creates the row.
  const QuietActionRow({
    required this.noteLabel,
    required this.holdLabel,
    required this.flareLabel,
    required this.holdDisabledReason,
    required this.onAddNote,
    required this.onHold,
    required this.onFlare,
    super.key,
  });

  /// Above this text scale the row becomes a column of full-width tiles.
  static const double stackAboveTextScale = 1.5;

  /// "Add note", already localized.
  final String noteLabel;

  /// "Hold", already localized.
  final String holdLabel;

  /// "Flare", already localized.
  final String flareLabel;

  /// Why Hold is unavailable, or null when it is available.
  ///
  /// **Disabled with a reason, never hidden.** A control that vanishes teaches
  /// nothing and leaves the reader wondering where it went.
  final String? holdDisabledReason;

  /// Opens the note sheet.
  final VoidCallback onAddNote;

  /// Opens the hold sheet.
  final VoidCallback onHold;

  /// Opens the flare sheet.
  final VoidCallback onFlare;

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > stackAboveTextScale;

    final tiles = <Widget>[
      QuietActionTile(
        label: noteLabel,
        glyph: Icons.edit_note_outlined,
        onTap: onAddNote,
      ),
      QuietActionTile(
        label: holdLabel,
        glyph: Icons.pause_circle_outline,
        onTap: onHold,
        disabledReason: holdDisabledReason,
      ),
      QuietActionTile(
        label: flareLabel,
        glyph: Icons.local_fire_department_outlined,
        onTap: onFlare,
      ),
    ];

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final tile in tiles) ...<Widget>[
            tile,
            SizedBox(height: shapes.s2),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < tiles.length; index++) ...<Widget>[
          // `Expanded`, so the three are equal by construction rather than by
          // whichever label happens to be longest.
          Expanded(child: tiles[index]),
          if (index < tiles.length - 1) SizedBox(width: shapes.s2),
        ],
      ],
    );
  }
}

/// One subordinate action.
class QuietActionTile extends StatelessWidget {
  /// Creates a tile.
  const QuietActionTile({
    required this.label,
    required this.glyph,
    required this.onTap,
    this.disabledReason,
    super.key,
  });

  /// The floor on a tile's height. Above the 44 platform minimum, because
  /// three of these sit side by side on a 390pt phone.
  static const double minHeight = 52;

  /// The caption, already localized.
  final String label;

  /// The glyph above it.
  final IconData glyph;

  /// Called on tap, unless [disabledReason] is set.
  final VoidCallback onTap;

  /// Why this tile is unavailable, or null.
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final enabled = disabledReason == null;

    return DaybreakTappable(
      // The reason is part of the LABEL, not a tooltip: a screen reader
      // announcing "Hold, dimmed" has said nothing the reader can act on.
      semanticsLabel: enabled ? label : '$label, $disabledReason',
      onPressed: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: minHeight),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: shapes.s2,
          vertical: shapes.s2,
        ),
        decoration: BoxDecoration(
          color: enabled ? colors.surface : colors.surfaceSunken,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
          border: Border.all(
            color: colors.border,
            width: shapes.hairlineWidth,
          ),
          boxShadow: enabled
              ? DaybreakElevation.of(context).level1
              : DaybreakElevation.of(context).level0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              glyph,
              size: 20,
              color: enabled ? colors.inkFaint : colors.border,
            ),
            SizedBox(height: shapes.s1),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: enabled ? colors.inkMuted : colors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
