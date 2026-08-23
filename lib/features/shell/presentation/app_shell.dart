/// The chrome the five screens live in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final destinations = <({IconData icon, String label})>[
      (icon: Icons.wb_sunny_outlined, label: l10n.tabToday),
      (icon: Icons.view_agenda_outlined, label: l10n.tabSchedule),
      (icon: Icons.trending_down, label: l10n.tabProgress),
      (icon: Icons.medication_outlined, label: l10n.tabPlan),
      (icon: Icons.settings_outlined, label: l10n.tabSettings),
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
            NavigationRail(
              selectedIndex: widget.shell.currentIndex,
              onDestinationSelected: _goBranch,
              // Flutter only wraps the rail's destinations in a scroll view
              // when this is set. Without it, five always-labelled
              // destinations clip 68px in landscape at the largest text size
              // — Plan and Settings become unreachable, with no way to get to
              // them at all.
              scrollable: true,
              // Always visible, never icon-only: an unlabelled icon is a
              // guessing game for the audience this app is for.
              labelType: NavigationRailLabelType.all,
              destinations: <NavigationRailDestination>[
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: _goBranch,
        // `alwaysShow`, and no fixed height anywhere: at 200% text scale the
        // bar is allowed to grow taller rather than clip a label.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: <NavigationDestination>[
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
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
