/// The app's one undo surface.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// An inline row offering to undo the change directly above it.
///
/// **The app's ONLY undo surface**, named here so three epics stop inventing
/// one: EPIC-08's mark-taken undo and EPIC-09's row-tick undo both mount this.
///
/// **Never a `SnackBar`**, for the same reason the backfill banner is not: a
/// `SnackBar` times out before this reader finishes it, and what it is
/// offering to undo is a change to their medication record. It sits in the
/// content flow directly under the thing that changed, and it goes away on an
/// explicit close or when the next mutation replaces it.
class UndoRow extends StatelessWidget {
  /// Creates the row.
  const UndoRow({
    required this.message,
    required this.undoLabel,
    required this.onUndo,
    required this.dismissLabel,
    required this.onDismiss,
    super.key,
  });

  /// The key every mount site should use.
  ///
  /// One shared key means the next mutation REPLACES this row rather than
  /// mounting a second one beside it. Two stacked undo rows offering to undo
  /// different things is not a question a reader can answer by looking.
  static const Key singletonKey = Key('undo-row');

  /// What just happened, already localized.
  final String message;

  /// The undo action's label.
  final String undoLabel;

  /// Reverses the change.
  final VoidCallback onUndo;

  /// The close action's label.
  final String dismissLabel;

  /// Hides the row without undoing anything.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    // The wrapper announces the change; the actions keep their own nodes.
    // `ExcludeSemantics` over the whole row would take "Undo" out of the
    // semantics tree, leaving a screen-reader user told that their medication
    // record changed and unable to reverse it.
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: Builder(
        builder: (context) => Container(
          padding: EdgeInsetsDirectional.all(shapes.s3),
          decoration: BoxDecoration(
            color: colors.tintPrimary,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: shapes.s2,
            runSpacing: shapes.s1,
            children: <Widget>[
              // The PROSE is excluded, not the row: the wrapper already says
              // it, and excluding the whole row would take "Undo" out of the
              // semantics tree — leaving a screen-reader user told their
              // medication record changed and unable to reverse it.
              ExcludeSemantics(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.ink),
                ),
              ),
              TertiaryButton(label: undoLabel, onPressed: onUndo),
              TertiaryButton(label: dismissLabel, onPressed: onDismiss),
            ],
          ),
        ),
      ),
    );
  }
}
