/// The one bottom-sheet presentation this app uses.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// Presents [builder] as a Daybreak bottom sheet.
///
/// The configuration lives here rather than at each call site because it is
/// four decisions, three of them non-obvious, and the fourth copy is where one
/// of them quietly differs.
Future<T?> showDaybreakSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  // The root navigator, so it reads as a modal route to the accessibility
  // tree rather than as a panel inside the current tab.
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: DaybreakColors.of(context).overlay,
  builder: builder,
);

/// A sheet's surface: the rounded top, the drag handle, the inset.
///
/// Shared so a second sheet cannot round its corners to a different radius
/// than the first one the reader saw.
class DaybreakSheetShell extends StatelessWidget {
  /// Wraps [child] in the sheet surface.
  const DaybreakSheetShell({
    required this.child,
    required this.routeLabel,
    super.key,
  });

  /// The sheet's content.
  final Widget child;

  /// What the sheet is, for the accessibility tree.
  final String routeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: routeLabel,
      explicitChildNodes: true,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadiusDirectional.only(
              topStart: Radius.circular(shapes.radiusXl),
              topEnd: Radius.circular(shapes.radiusXl),
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.all(shapes.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SheetDragHandle(),
                SizedBox(height: shapes.s4),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
