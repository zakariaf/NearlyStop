/// The one card surface, and the one way a card is titled.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';
import 'package:nearlystop/theme/daybreak_typography.dart';

/// A Daybreak card: `surface`, `radiusLg`, `level1`, with an optional overline.
///
/// **`surface`, not `surfaceRaised`.** The reference frames put a WHITE card on
/// the cream page: the card lifts off the ground rather than sinking into it,
/// and the warm ground is what the shadow reads against. Two screens were
/// spelling this out separately and one of them had the pair the wrong way
/// round.
class DaybreakCard extends StatelessWidget {
  /// Creates the card.
  const DaybreakCard({
    required this.children,
    this.overline,
    this.overlineCaps,
    this.padding,
    this.gap,
    super.key,
  }) : assert(
         (overline == null) == (overlineCaps == null),
         'an overline needs both casings — the Latin one and the one the '
         'Perso-Arabic locales use unchanged',
       );

  /// The heading in sentence case, already localized.
  ///
  /// Used verbatim in Perso-Arabic, where upper case does not exist.
  final String? overline;

  /// The same heading upper-cased **by the translator**, for Latin scripts.
  ///
  /// Never `.toUpperCase()`: Dart's casing is locale-blind, it no-ops on
  /// Perso-Arabic, and on Latin it produces a word no translator approved.
  final String? overlineCaps;

  /// The card's contents.
  final List<Widget> children;

  /// The inset around [children]. Defaults to `s4`.
  ///
  /// A card of full-bleed rows — Settings — passes `EdgeInsets.zero` and lets
  /// each row own its own inset, so a divider reaches both edges.
  final EdgeInsetsGeometry? padding;

  /// The gap below the card. Defaults to `s4`.
  ///
  /// Owned here rather than by each caller: every card in this app is one item
  /// in a vertical list, and two screens spelling the same gap out separately
  /// is how the two lists end up rhythmically different.
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final perso =
        scriptFor(Localizations.localeOf(context)) == DaybreakScript.perso;

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: gap ?? shapes.s4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
          boxShadow: DaybreakElevation.of(context).level1,
        ),
        child: Padding(
          padding: padding ?? EdgeInsetsDirectional.all(shapes.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (overline case final plain?) ...<Widget>[
                Padding(
                  // The inset a full-bleed card still owes its heading. A
                  // default-padded card has already inset it; one that passed
                  // `EdgeInsets.zero` so its rows reach both edges has not,
                  // and the title has no row to pad it.
                  padding: padding == null
                      ? EdgeInsets.zero
                      : EdgeInsetsDirectional.only(
                          start: shapes.s4,
                          top: shapes.s4,
                        ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      perso ? plain : overlineCaps!,
                      style: DaybreakTypography.of(context).overline,
                    ),
                  ),
                ),
                SizedBox(height: shapes.s3),
              ],
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
