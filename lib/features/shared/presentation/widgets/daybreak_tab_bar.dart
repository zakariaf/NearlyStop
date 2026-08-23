/// The five-destination tab bar, and its rail variant.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tappable.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// One destination in the tab bar or the rail.
@immutable
class DaybreakDestination {
  /// Describes one destination.
  const DaybreakDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// The label, already localized. **Always visible** — an unlabelled icon is
  /// a guess, and this reader opens the app half awake.
  final String label;

  /// The outlined glyph, shown when the destination is not current.
  final IconData icon;

  /// The FILLED variant, shown when it is.
  ///
  /// A separate glyph rather than a tint: filled-versus-outlined survives
  /// greyscale and deuteranopia, and a tint does not.
  final IconData selectedIcon;
}

/// The bottom bar: five destinations, three selection signals.
///
/// **No indicator bar.** The reference tints the icon capsule
/// (`.tab[aria-current]`), and a 3px underline was this epic's own invention.
/// The pill IS the indicator.
class DaybreakTabBar extends StatelessWidget {
  /// Creates the bar.
  const DaybreakTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  /// Finds the pill behind the active icon.
  static const Key activePillKey = Key('daybreak-tab-active-pill');

  /// The bar's height at 1.0 text scale, INCLUDING the bottom safe-area inset.
  ///
  /// A **floor**, never a fixed height. Pinned as a fixed 96 the labels are
  /// clipped the moment the reader turns text up, and clipped SILENTLY:
  /// `Flexible` around a `Text` produces no overflow stripe and no exception,
  /// so nothing goes red. Measured at 2.0 in German before this was a
  /// minimum — "Behandlungsplan" wanted 164pt of height inside a bar that
  /// gave it 36. The bar is on every screen, so that is CLAUDE.md rule 4 on
  /// every screen.
  static const double minHeight = 96;

  /// The active pill's size, from `.tab[aria-current]` in the reference.
  static const Size pillSize = Size(52, 30);

  /// The five destinations, in reading order.
  final List<DaybreakDestination> destinations;

  /// Which one is current.
  final int selectedIndex;

  /// Called with the tapped index.
  final void Function(int index) onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final inset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(
          top: BorderSide(color: colors.border, width: shapes.hairlineWidth),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          // The inset is INSIDE the 96, not added to it: a bar that grew by the
          // home indicator's height would be 122 on one phone and 96 on
          // another, and the reference's geometry is the former.
          padding: EdgeInsetsDirectional.only(bottom: inset),
          // `IntrinsicHeight` so `stretch` below means "as tall as the
          // TALLEST destination" rather than "as tall as whatever the parent
          // offers" — under a bottom `Align` that offer is the whole viewport,
          // and the bar became 844pt tall. One extra layout pass over five
          // children is the price of the tap targets being a single band
          // rather than five ragged boxes.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var index = 0; index < destinations.length; index++)
                  Expanded(
                    child: DaybreakTabDestination(
                      destination: destinations[index],
                      selected: index == selectedIndex,
                      onTap: () => onDestinationSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tappable destination, in the bar or the rail.
class DaybreakTabDestination extends StatelessWidget {
  /// Creates one destination.
  const DaybreakTabDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// What it points at.
  final DaybreakDestination destination;

  /// Whether it is current.
  final bool selected;

  /// Called on tap.
  final VoidCallback onTap;

  /// The floor on a destination's height.
  static const double minHeight = 52;

  /// The floor on its width.
  static const double minWidth = 44;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final ink = selected ? colors.primaryDeep : colors.inkMuted;

    return DaybreakTappable(
      semanticsLabel: destination.label,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: minWidth,
          minHeight: minHeight,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TabIconCapsule(
              destination: destination,
              selected: selected,
              ink: ink,
            ),
            SizedBox(height: shapes.s1),
            // NOT `Flexible`: it hands the label whatever height is left and
            // the paragraph clips the rest without a word. The bar grows
            // instead.
            Text(
              destination.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pill behind the icon — the third selection signal, and the only one
/// that is a SHAPE rather than a colour or a weight.
///
/// A CLASS, not a `_buildX()` helper: `widget-composition` bans those. Five of
/// these sit in the bar on every screen, so each getting its own `Element`
/// boundary is worth having.
class _TabIconCapsule extends StatelessWidget {
  const _TabIconCapsule({
    required this.destination,
    required this.selected,
    required this.ink,
  });

  final DaybreakDestination destination;
  final bool selected;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 22,
      color: ink,
    );
    if (!selected) {
      return SizedBox.fromSize(
        size: DaybreakTabBar.pillSize,
        child: Center(child: glyph),
      );
    }
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Container(
      key: DaybreakTabBar.activePillKey,
      width: DaybreakTabBar.pillSize.width,
      height: DaybreakTabBar.pillSize.height,
      decoration: BoxDecoration(
        color: colors.tintPrimary,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusPill)),
      ),
      child: Center(child: glyph),
    );
  }
}

/// The rail variant, for viewports wide enough to give it a column.
///
/// It carries the SAME three signals as the bar. A rail whose selection read
/// differently would make "which screen am I on" a question with two answers
/// depending on how the phone is held.
class DaybreakNavigationRail extends StatelessWidget {
  /// Creates the rail.
  const DaybreakNavigationRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  /// The rail's width.
  static const double width = 88;

  /// The five destinations, in reading order.
  final List<DaybreakDestination> destinations;

  /// Which one is current.
  final int selectedIndex;

  /// Called with the tapped index.
  final void Function(int index) onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(
          end: BorderSide(color: colors.border, width: shapes.hairlineWidth),
        ),
      ),
      child: SizedBox(
        width: width,
        child: SafeArea(
          // Scrollable, because five labelled destinations at the largest text
          // size do not fit a landscape phone's height — and the two that fall
          // off the bottom are Plan and Settings.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: shapes.s4),
                for (var index = 0; index < destinations.length; index++)
                  Padding(
                    padding: EdgeInsetsDirectional.only(bottom: shapes.s3),
                    child: DaybreakTabDestination(
                      destination: destinations[index],
                      selected: index == selectedIndex,
                      onTap: () => onDestinationSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
