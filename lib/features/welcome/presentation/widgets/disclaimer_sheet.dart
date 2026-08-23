/// The disclaimer, as a gate and as something to re-read.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// "This is not medical advice", in two modes.
///
/// **Gate mode** (`SPEC.md` §4.0) is the first thing the app ever shows. The
/// accept action stays disabled until the reader reaches the end of the text —
/// not to be obstructive, but because this is the one screen where the app
/// says it does not give medical advice, and a reader who taps past it in half
/// a second has not been told. It cannot be dragged away or dismissed.
///
/// **Re-read mode**, opened from Settings, is dismissible and its action says
/// "Close". It never re-accepts: acceptance already happened, and re-stamping
/// it would silently move the date on a record the reader might one day need.
class DisclaimerSheet extends StatefulWidget {
  /// Creates the sheet.
  const DisclaimerSheet({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.isGate,
    required this.onAccept,
    required this.onClose,
    this.controller,
    super.key,
  });

  /// The heading, already localized.
  final String title;

  /// The disclaimer text, already localized.
  final String body;

  /// The single action's label, already localized.
  final String actionLabel;

  /// Whether this is the first-run gate.
  final bool isGate;

  /// Called when the gate is accepted. Never called in re-read mode.
  final VoidCallback onAccept;

  /// Called when a re-read is closed. Never called in gate mode.
  final VoidCallback onClose;

  /// Injected so a test can drive the scroll position directly.
  final ScrollController? controller;

  @override
  State<DisclaimerSheet> createState() => _DisclaimerSheetState();
}

class _DisclaimerSheetState extends State<DisclaimerSheet> {
  late final ScrollController _controller =
      widget.controller ?? ScrollController();
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    // Evaluated once after layout as well as on scroll: a disclaimer that FITS
    // has a `maxScrollExtent` of zero and can never be scrolled to its end, so
    // a gate that only listened to scrolls would be unpassable on a tablet.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || _reachedEnd || !_controller.hasClients) return;
    final position = _controller.position;
    // `>=`, not `==`: a fractional extent means an exact comparison never
    // fires on some screens.
    //
    // This one comparison also covers the disclaimer that FITS — on a tablet
    // `maxScrollExtent` is 0 and `pixels` is 0, so `0 >= 0` enables the gate
    // immediately, which is what has to happen or the gate is unpassable
    // there. An explicit `maxScrollExtent <= 0` branch was here and was dead;
    // deleting it and re-running the tablet test is what proved it.
    if (position.pixels >= position.maxScrollExtent) {
      setState(() => _reachedEnd = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;
    final enabled = !widget.isGate || _reachedEnd;

    return PopScope(
      // The gate is the one surface in this app the system back button may not
      // leave. Everything else is freely dismissible.
      canPop: !widget.isGate,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(shapes.radiusXl),
            topEnd: Radius.circular(shapes.radiusXl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsetsDirectional.all(shapes.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SheetDragHandle(),
                SizedBox(height: shapes.s4),
                Text(
                  widget.title,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.ink,
                  ),
                ),
                SizedBox(height: shapes.s3),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _controller,
                    child: Text(
                      widget.body,
                      style: text.bodyLarge?.copyWith(color: colors.ink),
                    ),
                  ),
                ),
                SizedBox(height: shapes.s4),
                PrimaryPillButton(
                  label: widget.actionLabel,
                  expand: true,
                  onPressed: enabled
                      ? (widget.isGate ? widget.onAccept : widget.onClose)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
