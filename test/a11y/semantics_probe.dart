/// What counts as a control, for every whole-app semantics sweep.
///
/// **One definition, because the obvious one is wrong.** `DaybreakTappable`
/// wraps `Semantics(button: true, label: …)` around an `ExcludeSemantics` that
/// holds the real `GestureDetector`, so the node a screen reader lands on
/// carries **no tap action at all**. A filter on `SemanticsAction.tap` matches
/// nothing on any screen in this app — which is how the first version of the
/// semantics audit came to report 24 green cells over an empty list.
///
/// Two suites need this rule. Two copies of it is two chances to get it wrong
/// again, and the wrong version is silent.
library;

import 'package:flutter/semantics.dart';

/// Whether a screen reader treats [data] as something to activate.
bool isControl(SemanticsData data) =>
    data.flagsCollection.isButton ||
    data.flagsCollection.isLink ||
    data.flagsCollection.isTextField ||
    data.flagsCollection.isSlider ||
    data.hasAction(SemanticsAction.tap) ||
    data.hasAction(SemanticsAction.longPress);
