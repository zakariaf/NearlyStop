/// The chrome the five screens live in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_tab_bar.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/providers.dart';

/// The width at which a bottom bar becomes a side rail.
///
/// `SPEC.md` §5.4 requires landscape to work: people prop tablets on kitchen
/// tables, and a bottom bar there wastes the short dimension.
const double kRailBreakpoint = 600;

/// The tab bar and the branch's body.
///
/// It does **not** own the lifecycle hooks. The epic puts them here, but the
/// disclaimer gate is a top-level route OUTSIDE the shell — so on first run,
/// and for as long as the gate is up, this widget does not exist and neither
/// would the observer. They live in `NearlyStopApp`, which is the one widget
/// that is always mounted. Still one owner, just not this one.
class AppShell extends ConsumerStatefulWidget {
  /// Creates the shell around [shell].
  const AppShell({required this.shell, super.key});

  /// The branch navigator go_router is driving.
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Outlined AND filled for every destination: which tab is current is
    // signalled by the glyph's fill as well as by the pill and the weight, so
    // it survives greyscale and deuteranopia (EPIC-07 recipe 7).
    final destinations = <DaybreakDestination>[
      DaybreakDestination(
        label: l10n.tabToday,
        icon: Icons.wb_sunny_outlined,
        selectedIcon: Icons.wb_sunny,
      ),
      DaybreakDestination(
        label: l10n.tabSchedule,
        icon: Icons.view_agenda_outlined,
        selectedIcon: Icons.view_agenda,
      ),
      DaybreakDestination(
        label: l10n.tabProgress,
        icon: Icons.trending_down_outlined,
        selectedIcon: Icons.trending_down,
      ),
      DaybreakDestination(
        label: l10n.tabPlan,
        icon: Icons.medication_outlined,
        selectedIcon: Icons.medication,
      ),
      DaybreakDestination(
        label: l10n.tabSettings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];
    final isWide = MediaQuery.sizeOf(context).width >= kRailBreakpoint;
    final failure = ref.watch(bootstrapErrorProvider);

    final body = Column(
      children: <Widget>[
        if (failure != null)
          // `SafeArea` on the banner alone, with `bottom: false`: `Scaffold`
          // does not inset its `body`, so an unpadded banner paints under the
          // status bar and notch. Insetting the whole column instead would
          // make the screen's own Scaffold reserve the top inset a second
          // time, leaving a blank strip inside its app bar.
          SafeArea(
            bottom: false,
            child: _ErrorBanner(message: l10n.shellStorageError),
          ),
        Expanded(child: widget.shell),
      ],
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            // Scrolls internally, for the reason EPIC-06 found the hard way:
            // five always-labelled destinations clip 68px in landscape at the
            // largest text size, and the two that fall off are Plan and
            // Settings.
            DaybreakNavigationRail(
              destinations: destinations,
              selectedIndex: widget.shell.currentIndex,
              onDestinationSelected: _goBranch,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: DaybreakTabBar(
        destinations: destinations,
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: _goBranch,
      ),
    );
  }

  void _goBranch(int index) => widget.shell.goBranch(
    index,
    // Tapping the tab you are already on returns to that branch's root, which
    // is what every platform's tab bar does.
    initialLocation: index == widget.shell.currentIndex,
  );
}

/// A persistent banner, never a `SnackBar`.
///
/// A `SnackBar` times out. This audience does not finish reading a message that
/// removes itself, and the message is about their data.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
