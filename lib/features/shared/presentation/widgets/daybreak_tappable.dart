/// The one place a Daybreak control becomes tappable.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';

/// Everything a tap target in this app owes its reader.
///
/// **One implementation, not five.** Every tappable surface here — the button
/// ladder, the strength chips, the method segments, the tab destinations —
/// needs the same four things, and each one that hand-rolled them was a chance
/// to get one wrong:
///
/// 1. **An opaque hit test over the whole box.** A control's min-height box is
///    mostly empty space above and below a short label, and that space is the
///    target for someone who cannot aim.
/// 2. **A long press that still counts as a press.** A tremor turns an
///    intended tap into a 600ms hold. What must not exist is a long-press-ONLY
///    path — an action reachable no other way.
/// 3. **A haptic on CONTACT.** `TapGestureRecognizer` defers `onTapDown` until
///    the gesture arena resolves, and these controls also claim long press, so
///    a `GestureDetector`-only implementation makes the confirmation wait to
///    find out whether a slow press was a long press. `Listener` fires on the
///    down event itself. The haptic is never hung off the animation's
///    completion: under reduced motion that duration is zero, and the reader
///    who turned animations off is precisely the one who needs a non-visual
///    confirmation.
/// 4. **One semantics node**, so a screen reader reads the control as one
///    thing rather than as its parts.
class DaybreakTappable extends StatefulWidget {
  /// Wraps [child] in the app's standard tap behaviour.
  const DaybreakTappable({
    required this.semanticsLabel,
    required this.onPressed,
    required this.child,
    this.selected,
    this.inMutuallyExclusiveGroup = false,
    this.pressScale = 0.98,
    super.key,
  });

  /// What a screen reader announces. One label, one node.
  final String semanticsLabel;

  /// Null disables the control: no tap, no press feedback, no haptic.
  final VoidCallback? onPressed;

  /// The subtree, which contributes no semantics of its own.
  final Widget child;

  /// Whether this control is chosen, for controls that have that state.
  ///
  /// Null means "not a selectable control", which is different from "not
  /// selected" and is what a screen reader needs to hear.
  final bool? selected;

  /// Whether this is one of a set where exactly one is chosen.
  final bool inMutuallyExclusiveGroup;

  /// How far the control shrinks under a finger.
  final double pressScale;

  @override
  State<DaybreakTappable> createState() => _DaybreakTappableState();
}

class _DaybreakTappableState extends State<DaybreakTappable> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _press(PointerDownEvent _) {
    if (!_enabled) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _pressed = true);
  }

  void _release([PointerEvent? _]) {
    if (_pressed) setState(() => _pressed = false);
  }

  void _fire() {
    _release();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final motion = DaybreakMotion.of(context);

    return Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      label: widget.semanticsLabel,
      child: ExcludeSemantics(
        child: Listener(
          onPointerDown: _press,
          onPointerUp: _release,
          onPointerCancel: _release,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapCancel: _release,
            onTap: _enabled ? _fire : null,
            onLongPress: _enabled ? _fire : null,
            child: AnimatedScale(
              scale: _pressed ? widget.pressScale : 1,
              duration: resolveMotion(context, motion.fast),
              curve: motion.easeOut,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
