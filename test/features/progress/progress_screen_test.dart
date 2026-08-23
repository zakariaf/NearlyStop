// The screen, its non-happy states, and the export door.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nearlystop/core/units/milligrams.dart';
import 'package:nearlystop/features/progress/application/progress_view_provider.dart';
import 'package:nearlystop/features/progress/presentation/export_placeholder_screen.dart';
import 'package:nearlystop/features/progress/presentation/progress_screen.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/features/progress/presentation/widgets/dose_staircase_chart.dart';
import 'package:nearlystop/features/progress/presentation/widgets/encouragement_card.dart';
import 'package:nearlystop/features/progress/presentation/widgets/progress_stat_grid.dart';
import 'package:nearlystop/features/progress/presentation/widgets/taper_start_line.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/error_panel.dart';
import 'package:nearlystop/features/shared/presentation/widgets/taper_empty_state.dart';
import 'package:nearlystop/l10n/app_locales.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/routing/routes.dart';
import 'package:nearlystop/theme/daybreak_script.dart';
import 'package:nearlystop/theme/daybreak_theme.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';
import 'support/progress_fixture.dart';

void main() {
  const loaded = ProgressLoaded(
    segments: <DoseSegment>[
      DoseSegment(
        startDayIndex: 0,
        endDayIndex: 51,
        dose: Milligrams.fromHundredths(1500),
      ),
      DoseSegment(
        startDayIndex: 52,
        endDayIndex: 103,
        dose: Milligrams.fromHundredths(900),
      ),
    ],
    flares: <FlareMark>[],
    holds: <HoldMark>[],
    todayDayIndex: 103,
    todayDose: Milligrams.fromHundredths(900),
    axis: ProgressAxis(
      minDose: Milligrams.fromHundredths(900),
      maxDose: Milligrams.fromHundredths(1500),
      firstLabel: 'Sep 2024',
      lastLabel: 'Apr 2026',
    ),
    stats: ProgressStats(
      daysOnDrug: '581',
      cumulativeMg: '6,842',
      adherence: '574 of 581',
      adherenceCaption: 'days ticked so far — a few gaps change nothing',
    ),
    startLine: 'Started 12 September 2024 at 15mg',
    encouragement: 'You are 6mg lower than when you started.',
    eventCountLabel: 'No flares or holds recorded',
    chartSummary: 'Chart: your dose fell from 15mg to 9mg.',
    historyRows: <String>['15 milligrams from 12 September 2024 for 52 days'],
  );

  Future<AppLocalizations> pumpScreen(
    WidgetTester tester,
    AsyncValue<ProgressViewState> state, {
    Size size = const Size(390, 844),
  }) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      const ProgressScreen(),
      overrides: <Override>[
        progressViewProvider.overrideWith(() => FixedProgress(state)),
      ],
      surfaceSize: size,
    );
    // Settled, not pumped. The fixture emits through a stream, so a frame
    // after `pumpWidget` the provider is still loading — and a test that
    // measured the loaded state one pump too early would be comparing the
    // skeleton with itself, which is exactly what the first version did.
    // `testing-strategy` rule 10 bans a settle where an animation never ends;
    // this screen's skeleton is static, so there is nothing to hang on.
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('loading reserves the chart card’s height, and never spins', (
    tester,
  ) async {
    // A spinner that becomes a chart moves everything under it. This reader is
    // already unsure whether they tapped.
    await pumpScreen(tester, const AsyncValue<ProgressViewState>.loading());

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final skeleton = tester
        .getSize(find.byKey(ProgressScreen.chartSlotKey))
        .height;

    // Tear the scope down between the two states. `pumpWidget` REUSES a
    // `ProviderScope` of the same type, so a second pump with a different
    // override keeps the existing notifier — and the "loaded" measurement was
    // silently the skeleton again, comparing it with itself.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpScreen(tester, const AsyncValue<ProgressViewState>.data(loaded));
    expect(
      find.byType(DoseStaircaseChart),
      findsOneWidget,
      reason: 'still loading — the comparison below would be self-referential',
    );
    final real = tester.getSize(find.byKey(ProgressScreen.chartSlotKey)).height;

    expect(
      (skeleton - real).abs(),
      lessThanOrEqualTo(1),
      reason: 'the page jumps by ${(skeleton - real).abs()} when data lands',
    );
  });

  testWidgets('an error offers the one action that can help', (tester) async {
    final l10n = await pumpScreen(
      tester,
      AsyncValue<ProgressViewState>.error(StateError('x'), StackTrace.empty),
    );

    expect(find.byType(ErrorPanel), findsOneWidget);
    expect(find.text(l10n.errorRetry), findsOneWidget);
  });

  testWidgets('no plan sends them to the plan screen', (tester) async {
    final l10n = await pumpScreen(
      tester,
      const AsyncValue<ProgressViewState>.data(ProgressNoPlan()),
    );

    expect(find.byType(TaperEmptyState), findsOneWidget);
    expect(find.text(l10n.noPlanAction), findsOneWidget);
  });

  testWidgets(
    'the loaded order is chart, start, stats, encouragement, export',
    (tester) async {
      // Read off the tree as a list, so a reordering is a failure rather than a
      // surprise on somebody's phone.
      await pumpScreen(
        tester,
        const AsyncValue<ProgressViewState>.data(loaded),
      );

      final order = <Type>[
        DoseStaircaseChart,
        TaperStartLine,
        ProgressStatGrid,
        EncouragementCard,
        SecondaryButton,
      ];
      final tops = <double>[
        for (final type in order) tester.getTopLeft(find.byType(type).first).dy,
      ];
      expect(
        tops,
        orderedEquals(<double>[...tops]..sort()),
        reason: 'the blocks are out of order: $tops',
      );
    },
  );

  testWidgets('the body scrolls — unlike Today, this screen expects to', (
    tester,
  ) async {
    await pumpScreen(tester, const AsyncValue<ProgressViewState>.data(loaded));

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('two panes at 841, stacked at 839', (tester) async {
    await pumpScreen(
      tester,
      const AsyncValue<ProgressViewState>.data(loaded),
      size: const Size(839, 1000),
    );
    final narrow = tester.getTopLeft(find.byType(ProgressStatGrid)).dy;
    expect(
      narrow,
      greaterThan(tester.getTopLeft(find.byType(DoseStaircaseChart)).dy),
      reason: 'at 839 the stats sit under the chart',
    );

    await pumpScreen(
      tester,
      const AsyncValue<ProgressViewState>.data(loaded),
      size: const Size(841, 1000),
    );
    expect(
      tester.getTopLeft(find.byType(ProgressStatGrid)).dx,
      greaterThan(tester.getTopLeft(find.byType(DoseStaircaseChart)).dx),
      reason: 'at 841 they should be side by side',
    );
  });

  testWidgets('the export button is enabled, tall enough, and labelled', (
    tester,
  ) async {
    // A disabled button is the failure mode this task names: EPIC-13 is not
    // here yet, and the honest answer is a route that says so — not a control
    // that looks broken.
    final handle = tester.ensureSemantics();
    for (final scale in <double>[1, 2]) {
      await pumpApp(
        tester,
        const ProgressScreen(),
        overrides: <Override>[
          progressViewProvider.overrideWith(
            () =>
                FixedProgress(const AsyncValue<ProgressViewState>.data(loaded)),
          ),
        ],
        textScaler: TextScaler.linear(scale),
        surfaceSize: const Size(390, 2000),
      );
      await tester.pump();

      final button = find.byType(SecondaryButton);
      expect(tester.widget<SecondaryButton>(button).onPressed, isNotNull);
      expect(
        tester.getSize(button).height,
        greaterThanOrEqualTo(44),
        reason: '${scale}x',
      );
    }
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsExportForDoctor), findsOneWidget);
    handle.dispose();
  });

  test('EPIC-13’s dependencies have not arrived early', () {
    // `dependency-hygiene`: an unused package in `pubspec.yaml` is a package
    // nobody audits, and this app's premise is that it opens no sockets.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final package in <String>['pdf:', 'csv:', 'share_plus:']) {
      expect(
        pubspec,
        isNot(contains(package)),
        reason: '$package is EPIC-13’s, and this epic builds only the door',
      );
    }
  });

  testWidgets('tapping export navigates to a REAL route', (tester) async {
    // The difference between a live route and a dead tap. A local router with
    // the same two paths, rather than the whole app: what is under test is the
    // push, not the shell's redirects, which `app_router_test` owns.
    final router = GoRouter(
      initialLocation: Routes.progress,
      routes: <RouteBase>[
        GoRoute(
          path: Routes.progress,
          builder: (context, state) => const ProgressScreen(),
          routes: <RouteBase>[
            GoRoute(
              path: 'export',
              builder: (context, state) => const ExportPlaceholderScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          progressViewProvider.overrideWith(
            () =>
                FixedProgress(const AsyncValue<ProgressViewState>.data(loaded)),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kAppLocalizationsDelegates,
          theme: buildDaybreakTheme(Brightness.light, DaybreakScript.latin),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(SecondaryButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SecondaryButton));
    await tester.pumpAndSettle();

    expect(find.byType(ExportPlaceholderScreen), findsOneWidget);
    expect(
      find.byType(BackButton),
      findsOneWidget,
      reason: 'a screen you cannot leave is worse than one you cannot reach',
    );
  });
}
