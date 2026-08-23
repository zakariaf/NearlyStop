/// The date line, the title, and the note button.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// "Wednesday 16 April" above "Today", with the note button trailing.
///
/// **`Row` with `spaceBetween`, never `Positioned(left:)`.** The button belongs
/// on the trailing edge, which in Persian and Kurdish is the LEFT one — and a
/// hand-rolled inset gets that right in one direction and silently wrong in
/// the other.
class TodayDateHeader extends StatelessWidget {
  /// Creates the header.
  const TodayDateHeader({
    required this.dateLine,
    required this.title,
    required this.noteHint,
    required this.onOpenNote,
    super.key,
  });

  /// Finds the note button.
  static const Key noteButtonKey = Key('today-note-button');

  /// The note button's side. The platform floor, and this one is small.
  static const double buttonSide = 44;

  /// "Wednesday 16 April", already localized.
  final String dateLine;

  /// "Today", already localized.
  final String title;

  /// What the note button announces.
  final String noteHint;

  /// Opens the note sheet. The header opens nothing itself.
  final VoidCallback onOpenNote;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                dateLine,
                style: text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.inkMuted,
                ),
              ),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: shapes.s3),
        Semantics(
          button: true,
          label: noteHint,
          child: ExcludeSemantics(
            child: GestureDetector(
              key: noteButtonKey,
              behavior: HitTestBehavior.opaque,
              onTap: onOpenNote,
              child: Container(
                width: buttonSide,
                height: buttonSide,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.all(
                    Radius.circular(shapes.radiusPill),
                  ),
                  border: Border.all(
                    color: colors.border,
                    width: shapes.hairlineWidth,
                  ),
                  boxShadow: DaybreakElevation.of(context).level1,
                ),
                child: Icon(
                  Icons.edit_note_outlined,
                  size: 22,
                  color: colors.primaryDeep,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
