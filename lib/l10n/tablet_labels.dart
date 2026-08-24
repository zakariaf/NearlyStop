/// A tablet breakdown, as a sentence.
library;

import 'dart:ui';

import 'package:nearlystop/core/dsns/tablet_composer.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/l10n/bidi.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/l10n/number_formats.dart';

/// "1 × 5mg, 1 × 1mg, ½ × 1mg" — what to actually swallow.
///
/// Shared by the Schedule row and the doctor's export. Two copies of this
/// would be two answers to "what does 6.5mg look like", on the two surfaces
/// most likely to be read side by side.
String formatTabletBreakdown(
  TabletComposition composition,
  Locale locale,
  AppLocalizations l10n,
) {
  final parts = <String>[
    for (final count in composition.counts)
      _tabletPart(count.count, count.strength, locale),
    if (composition.half case final half?)
      '½ × ${formatDose(half.strength, locale)}mg',
  ];
  // The separator comes from the ARB: frame 3's `.stab` uses a comma, and
  // in Perso-Arabic that comma is U+060C. Isolated as a unit so the whole
  // breakdown keeps its LTR order inside an RTL sentence.
  return isolateLtr(parts.join(l10n.tabletSeparator));
}

/// "4 × 1mg" — a count, a multiplication sign, a strength.
String _tabletPart(int count, Milligrams strength, Locale locale) {
  final counted = numberFormatFor(locale).format(count);
  return '$counted × ${formatDose(strength, locale)}mg';
}
