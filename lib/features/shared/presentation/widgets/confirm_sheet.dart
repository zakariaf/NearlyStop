/// The confirmation sheet, and the result type that is never a bare `bool?`.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// How a [ConfirmSheet] ended.
///
/// **Not `bool?`.** A nullable bool makes "dismissed" and "cancelled" two
/// spellings of the same thing that every call site has to remember to collapse
/// — and the one that forgets treats a scrim tap as a confirmation.
enum ConfirmResult {
  /// The reader pressed the confirm action.
  confirmed,

  /// The reader cancelled, tapped the scrim, or dragged the sheet down.
  cancelled,
}

/// Everything a [ConfirmSheet] says, as pre-localized strings.
@immutable
class ConfirmRequest {
  /// Describes one confirmation.
  const ConfirmRequest({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    this.preActionLabel,
    this.onPreAction,
    this.isDestructive = true,
  }) : assert(
         (preActionLabel == null) == (onPreAction == null),
         'a pre-action needs both a label and a callback',
       );

  /// The question, as a title.
  final String title;

  /// What will happen **and what is kept**.
  ///
  /// "Your history and your total are kept" is not reassurance for its own
  /// sake: this reader has spent two years on a taper and needs to know which
  /// two years are at risk.
  final String body;

  /// The confirm action's label.
  final String confirmLabel;

  /// The cancel action's label.
  final String cancelLabel;

  /// An optional action that runs **without closing the sheet**.
  ///
  /// This is what makes `SPEC.md` §5.3's "export before anything destructive"
  /// implementable: the reader exports, lands back on the sheet, and then
  /// decides.
  final String? preActionLabel;

  /// Runs the pre-action. The sheet stays open.
  final Future<void> Function()? onPreAction;

  /// Whether the confirm action is styled as destructive.
  final bool isDestructive;
}

/// Shows [request] and resolves to how it ended.
///
/// Never resolves to null: every exit — confirm, cancel, scrim, drag — maps to
/// a [ConfirmResult].
Future<ConfirmResult> showConfirmSheet(
  BuildContext context,
  ConfirmRequest request,
) async {
  final result = await showModalBottomSheet<ConfirmResult>(
    context: context,
    // The root navigator, so it reads as a modal route to the accessibility
    // tree rather than as a panel inside the current tab.
    useRootNavigator: true,
    // Unlike the disclaimer gate, both of these stay at their permissive
    // defaults on purpose: cancelling a destructive action must be the EASY
    // path, so the scrim and the drag both work. Stated here rather than
    // passed, because `avoid_redundant_argument_values` bans restating a
    // default and the reason still needs recording.
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: DaybreakColors.of(context).overlay,
    builder: (context) => ConfirmSheet(request: request),
  );
  // A null here is a scrim tap or a drag-down, which is a cancel.
  return result ?? ConfirmResult.cancelled;
}

/// The sheet's body. Shown through [showConfirmSheet].
class ConfirmSheet extends StatefulWidget {
  /// Creates the sheet for [request].
  const ConfirmSheet({required this.request, super.key});

  /// What the sheet says.
  final ConfirmRequest request;

  @override
  State<ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<ConfirmSheet> {
  /// Focus lands here when the sheet opens, so a screen reader starts at the
  /// question rather than at the first button.
  final FocusNode _title = FocusNode(debugLabel: 'confirm-sheet-title');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _title.requestFocus();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;
    final request = widget.request;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: request.title,
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
                Focus(
                  focusNode: _title,
                  child: Text(
                    request.title,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.ink,
                    ),
                  ),
                ),
                SizedBox(height: shapes.s3),
                Text(
                  request.body,
                  style: text.bodyLarge?.copyWith(color: colors.ink),
                ),
                SizedBox(height: shapes.s5),
                if (request.preActionLabel case final label?) ...<Widget>[
                  SecondaryButton(
                    label: label,
                    expand: true,
                    // Runs and RETURNS to the sheet. The reader exports, lands
                    // back here, and then decides.
                    onPressed: () => request.onPreAction!(),
                  ),
                  SizedBox(height: shapes.s3),
                ],
                if (request.isDestructive)
                  DestructiveButton.immediate(
                    label: request.confirmLabel,
                    expand: true,
                    onPressed: () =>
                        Navigator.of(context).pop(ConfirmResult.confirmed),
                  )
                else
                  PrimaryPillButton(
                    label: request.confirmLabel,
                    expand: true,
                    onPressed: () =>
                        Navigator.of(context).pop(ConfirmResult.confirmed),
                  ),
                SizedBox(height: shapes.s2),
                TertiaryButton(
                  label: request.cancelLabel,
                  onPressed: () =>
                      Navigator.of(context).pop(ConfirmResult.cancelled),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The grab bar at the top of a bottom sheet.
///
/// Shared with the disclaimer sheet rather than written twice, and a CLASS
/// rather than a `_buildX()` helper — `widget-composition` bans those.
class SheetDragHandle extends StatelessWidget {
  /// Creates the handle.
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Center(
      child: Container(
        width: shapes.s8,
        height: shapes.s1,
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
        ),
      ),
    );
  }
}
