/// One app-wide router: five branches and the disclaimer gate.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/features/plan/presentation/plan_screen.dart';
import 'package:nearlystop/features/progress/presentation/progress_screen.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/features/shell/presentation/app_shell.dart';
import 'package:nearlystop/features/today/presentation/today_screen.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/routing/routes.dart';
import 'package:riverpod/riverpod.dart';

/// A `Listenable` that fires when the disclaimer's acceptance changes.
///
/// The router is built **once** and driven by this. A `ref.watch` inside
/// `routerProvider` would rebuild the `GoRouter` on every settings change and
/// reset every branch's navigation stack — a user who scrolled the Schedule
/// back three months would lose that place because they toggled high contrast.
class _DisclaimerListenable extends ChangeNotifier {
  _DisclaimerListenable(this._ref) {
    _accepted = _ref.read(settingsControllerProvider).hasAcceptedDisclaimer;
    _ref.listen<AppSettings>(settingsControllerProvider, (previous, next) {
      if (next.hasAcceptedDisclaimer == _accepted) return;
      _accepted = next.hasAcceptedDisclaimer;
      notifyListeners();
    });
  }

  final Ref _ref;
  late bool _accepted;
}

/// The app's one router.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final refresh = _DisclaimerListenable(ref);
  // Created PER ROUTER, not at module level. A `GlobalKey` is global: two
  // containers sharing one — a second `ProviderContainer`, or a hot restart
  // that outlives the old tree — puts the same key under two widgets, and
  // Flutter refuses to finalize the tree at all.
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final branchKeys = <GlobalKey<NavigatorState>>[
    for (final route in Routes.branches)
      GlobalKey<NavigatorState>(debugLabel: route),
  ];
  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.today,
    refreshListenable: refresh,
    // `redirect` READS the setting rather than watching it: the router must not
    // be rebuilt on state change, and `refreshListenable` is what re-runs this.
    redirect: (context, state) {
      final accepted = ref
          .read(settingsControllerProvider)
          .hasAcceptedDisclaimer;
      if (!accepted) {
        return state.matchedLocation == Routes.welcome ? null : Routes.welcome;
      }
      // Once accepted, the gate is not a place to be. Anyone landing there —
      // a deep link, a restored location — goes home.
      return state.matchedLocation == Routes.welcome ? Routes.today : null;
    },
    errorBuilder: (context, state) => _UnknownRoutePage(uri: state.uri),
    routes: <RouteBase>[
      GoRoute(
        path: Routes.welcome,
        // OPAQUE, not translucent. On first run the redirect fires on cold
        // start with nothing beneath it, so a see-through page would render a
        // sheet over emptiness. The sheet-on-a-scrim look is achieved inside
        // this route, over its own background.
        builder: (context, state) => const _WelcomeGate(),
      ),
      StatefulShellRoute.indexedStack(
        // `indexedStack`, not `.builder`: each tab keeps its scroll position
        // and sub-stack across switches. A user who scrolled the Schedule back
        // three months and taps Today must not lose that place.
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: branchKeys[0],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[1],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.schedule,
                builder: (context, state) => const ScheduleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[2],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.progress,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[3],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.plan,
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[4],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    // A CHILD of Settings, so back returns to Settings with
                    // that tab's stack intact. Re-using the gate's own path
                    // with a query parameter would force its redirect to
                    // special-case one, which is how a gate develops a hole.
                    path: 'disclaimer',
                    builder: (context, state) => const _DisclaimerReread(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref
    ..onDispose(router.dispose)
    ..onDispose(refresh.dispose);
  return router;
});

/// The gate. EPIC-11 fills in the content; EPIC-06 owns that it cannot be left.
class _WelcomeGate extends StatelessWidget {
  const _WelcomeGate();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      // No system-back escape. `SPEC.md` §4.0 calls this a modal, not a tab.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          // SCROLLABLE, and not optional. At the largest OS text size this
          // column overflowed by 296px on a 390x844 phone — clipping the
          // disclaimer the gate exists to make the user read, on the one
          // screen `PopScope(canPop: false)` will not let them leave.
          // CLAUDE.md rule 4: largest OS text size on every screen, without
          // clipping.
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.welcomeTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.welcomeDisclaimer,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.welcomeOffline,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Re-reading the disclaimer, dismissible, from Settings.
class _DisclaimerReread extends StatelessWidget {
  const _DisclaimerReread();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsReadDisclaimer)),
      body: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Text(
          l10n.welcomeDisclaimer,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// A warm, localized "that page does not exist" — never the red error screen.
class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                l10n.unknownRouteTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(Routes.today),
                child: Text(l10n.unknownRouteAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
