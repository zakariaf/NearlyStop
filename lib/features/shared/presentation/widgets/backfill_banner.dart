/// The un-ticked-days prompt, which stays until it is answered.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// "You haven't marked the last 3 days." — persistent, and never a `SnackBar`.
///
/// **It has to survive a scroll and a backgrounding.** A `SnackBar` times out;
/// this reader is 78, reads slowly, and the message is about their medication
/// record. It stays until they act on it.
///
/// **The copy is warm, not scolding.** A missed day is not a failure and does
/// not block progress (`SPEC.md` §4.1, §4.3) — which is why the body text is
/// `ink` rather than the warning colour. The semantic amber is for the glyph
/// and the border; a whole paragraph in it reads as a telling-off.
class BackfillBanner extends StatelessWidget {
  /// Creates the banner.
  const BackfillBanner({
    required this.message,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.secondaryActionLabel,
    required this.onSecondaryAction,
    super.key,
  });

  /// Finds the decorated container, for tests that read its tokens.
  static const Key containerKey = Key('backfill-banner-container');

  /// The glyph. A calendar, not an exclamation mark.
  static const IconData glyph = Icons.event_note_outlined;

  /// The message, already localized and already pluralised.
  final String message;

  /// The label on the action that opens the backfill flow.
  final String primaryActionLabel;

  /// Opens the backfill flow.
  final VoidCallback onPrimaryAction;

  /// The label on the dismiss action.
  final String secondaryActionLabel;

  /// Dismisses the banner.
  final VoidCallback onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    // The `Semantics` wrapper covers the PROSE only, and the actions sit
    // outside it. Wrapping the whole banner in `ExcludeSemantics` — to keep it
    // reading as one sentence — also takes its BUTTONS out of the semantics
    // tree, so a screen-reader user hears "you haven't marked the last 3 days"
    // and has no way to act on it.
    return Semantics(
      container: true,
      // Announced when it appears, without stealing focus from whatever the
      // reader was doing.
      liveRegion: true,
      label: message,
      child: Builder(
        builder: (context) => Container(
          key: containerKey,
          padding: EdgeInsetsDirectional.all(shapes.s4),
          decoration: BoxDecoration(
            color: colors.tintWarning,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
            border: Border.all(
              color: colors.warningFill,
              width: shapes.hairlineWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // `ExcludeSemantics` over the PROSE only. Over the whole banner
              // it also removes the two buttons from the semantics tree, and a
              // screen-reader user hears "you haven't marked the last 3 days"
              // with no way to act on it.
              ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(glyph, size: 22, color: colors.warning),
                    SizedBox(width: shapes.s3),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: shapes.s2),
              // A `Wrap`, so two long German action labels stack instead of
              // being squeezed to one word each.
              Wrap(
                spacing: shapes.s2,
                runSpacing: shapes.s1,
                children: <Widget>[
                  TertiaryButton(
                    label: primaryActionLabel,
                    onPressed: onPrimaryAction,
                  ),
                  TertiaryButton(
                    label: secondaryActionLabel,
                    onPressed: onSecondaryAction,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
