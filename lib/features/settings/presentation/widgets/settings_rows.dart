/// The row and card recipes the Settings screen is built from.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_card.dart';
import 'package:nearlystop/features/shared/presentation/widgets/glyph_tile.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// A card of settings rows, with a heading.
///
/// A thin naming layer over [DaybreakCard]: the surface, the radius, the
/// shadow and the overline treatment are shared with the Plan screen, because
/// the reference frames show the same card on both.
class SettingsCard extends StatelessWidget {
  /// Creates the card.
  const SettingsCard({
    required this.children,
    this.heading,
    this.headingCaps,
    super.key,
  });

  /// The card's heading in sentence case, already localized.
  final String? heading;

  /// The same heading upper-cased by the translator, for Latin scripts.
  final String? headingCaps;

  /// The rows.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(
      bottom: DaybreakShapes.of(context).s4,
    ),
    child: DaybreakCard(
      overline: heading,
      overlineCaps: headingCaps,
      // Zero, so a divider reaches both edges: each row owns its own inset,
      // and a card-level pad would leave a hairline floating in white.
      padding: EdgeInsets.zero,
      children: children,
    ),
  );
}

/// One settings row: a glyph, a title, a sublabel and a trailing control.
///
/// **Never a `ListTile`.** Material's own padding and minimum heights are not
/// the reference's, and a ±2px parity measurement against them is a
/// measurement against Material rather than against Daybreak.
class SettingsRow extends StatelessWidget {
  /// Creates the row.
  const SettingsRow({
    required this.glyph,
    required this.title,
    this.sublabel,
    this.trailing,
    this.onTap,
    this.semanticsLabel,
    super.key,
  });

  /// The row's minimum height. 44 is the floor; 56 is the reference.
  static const double minHeight = 56;

  /// The leading glyph.
  final IconData glyph;

  /// The row's name, already localized.
  final String title;

  /// The current value, in words, already localized.
  final String? sublabel;

  /// A switch, a chevron, a slider.
  final Widget? trailing;

  /// What tapping the row does, or null when only the control is interactive.
  final VoidCallback? onTap;

  /// The whole row as one sentence, when the parts do not read as one.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    final content = Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: shapes.s4,
        vertical: shapes.s3,
      ),
      child: Row(
        children: <Widget>[
          GlyphTile(glyph: glyph),
          SizedBox(width: shapes.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                if (sublabel case final value?)
                  Text(
                    value,
                    style: text.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
              ],
            ),
          ),
          if (trailing case final control?) ...<Widget>[
            SizedBox(width: shapes.s3),
            control,
          ],
        ],
      ),
    );

    final sized = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: content,
    );

    if (onTap == null) {
      return semanticsLabel == null
          ? sized
          : Semantics(
              container: true,
              label: semanticsLabel,
              child: ExcludeSemantics(child: sized),
            );
    }
    return Semantics(
      container: true,
      button: true,
      label: semanticsLabel ?? '$title${sublabel == null ? '' : ', $sublabel'}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
            child: sized,
          ),
        ),
      ),
    );
  }
}

/// The hairline between two rows in a card.
class SettingsDivider extends StatelessWidget {
  /// Creates the divider.
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: shapes.s7),
      child: Divider(
        height: shapes.hairlineWidth,
        thickness: shapes.hairlineWidth,
        color: DaybreakColors.of(context).border,
      ),
    );
  }
}
