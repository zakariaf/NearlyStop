/// One app-wide router: five branches and the disclaimer gate.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/features/plan/presentation/plan_screen.dart';
import 'package:nearlystop/features/progress/presentation/progress_screen.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_screen.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/features/shell/presentation/app_shell.dart';
import 'package:nearlystop/features/today/presentation/today_screen.dart';
import 'package:nearlystop/features/welcome/presentation/widgets/disclaimer_sheet.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/routing/routes.dart';

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
                // `?focus=<iso>` lands the list on one day — what EPIC-08's
                // backfill banner targets when more than one day is
                // outstanding. It reaches the screen UNPARSED, because a deep
                // link is user input and the screen owns the fallback.
                builder: (context, state) =>
                    ScheduleScreen(focus: state.uri.queryParameters['focus']),
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
class _WelcomeGate extends ConsumerWidget {
  const _WelcomeGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      // No system-back escape. `SPEC.md` §4.0 calls this a modal, not a tab.
      canPop: false,
      child: Scaffold(
        // EPIC-07 recipe 10, which is the component built for this screen: it
        // scrolls (at the largest OS text size this column overflowed by 296px
        // on a 390x844 phone), and it keeps the accept action disabled until
        // the reader reaches the end of the text.
        //
        // Before this it rendered the disclaimer and NOTHING ELSE. On a fresh
        // install the app opened on a screen with no action and no way back,
        // and every router test asserted where the redirect lands rather than
        // whether the gate can be left.
        body: SafeArea(
          child: DisclaimerSheet(
            title: l10n.welcomeTitle,
            body: '${l10n.welcomeDisclaimer}\n\n${l10n.welcomeOffline}',
            actionLabel: l10n.welcomeAccept,
            isGate: true,
            onAccept: () async {
              // The redirect is driven by `disclaimerAcceptedAt`, so writing it
              // IS the navigation — `_DisclaimerListenable` refreshes the
              // router and the gate redirects to Today.
              await ref
                  .read(settingsControllerProvider.notifier)
                  .acceptDisclaimer();
            },
            onClose: () {},
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
      // The SAME component as the gate, in its dismissible mode. Two renderings
      // of the disclaimer is two places for it to drift, and the one that
      // drifts is the one nobody opens.
      body: SafeArea(
        top: false,
        child: DisclaimerSheet(
          title: l10n.welcomeTitle,
          body: '${l10n.welcomeDisclaimer}\n\n${l10n.welcomeOffline}',
          actionLabel: l10n.actionClose,
          isGate: false,
          onAccept: () {},
          onClose: () => context.pop(),
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
