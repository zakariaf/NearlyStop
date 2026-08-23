/// The sunrise mark that opens the app.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';

/// A filled sunrise circle: the app's one ceremonial mark.
///
/// **The gradient's only appearance outside a primary action.** It is the
/// first thing anybody sees, on the one screen they cannot leave, and the
/// product's whole idea in one glyph — every dose is a step toward the morning
/// you are heading for.
///
/// Purely decorative, and excluded from semantics: the heading beside it says
/// what this screen is, and a screen reader announcing "sunrise image" before
/// it would put a picture ahead of the words.
class SunriseSeal extends StatelessWidget {
  /// Creates the seal.
  const SunriseSeal({super.key});

  /// The seal's diameter at text scale 1.
  static const double diameter = 96;

  /// The glyph's size at text scale 1.
  static const double glyphSize = 48;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: scaler.scale(diameter),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: colors.sunrise,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.wb_twilight,
              // The ONE foreground allowed on the sunrise gradient.
              color: colors.onPrimary,
              size: scaler.scale(glyphSize),
            ),
          ),
        ),
      ),
    );
  }
}
