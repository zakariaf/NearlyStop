/// The Progress screen: the staircase, three numbers and a sentence.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearlystop/app/window_size.dart';
import 'package:nearlystop/features/progress/application/progress_view_provider.dart';
import 'package:nearlystop/features/progress/presentation/progress_view_state.dart';
import 'package:nearlystop/features/progress/presentation/widgets/dose_staircase_chart.dart';
import 'package:nearlystop/features/progress/presentation/widgets/encouragement_card.dart';
import 'package:nearlystop/features/progress/presentation/widgets/progress_stat_grid.dart';
import 'package:nearlystop/features/progress/presentation/widgets/taper_start_line.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/features/shared/presentation/widgets/error_panel.dart';
import 'package:nearlystop/features/shared/presentation/widgets/taper_empty_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/routing/routes.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// How far somebody has come, and the evidence for it.
///
/// Two years is a long time to take a tablet every morning with nothing to
/// show for it. The staircase is the evidence, and the numbers under it are
/// what a rheumatologist asks for at the six-month appointment.
class ProgressScreen extends ConsumerWidget {
  /// Creates the screen.
  const ProgressScreen({super.key});

  /// Finds the chart's slot, loaded or loading.
  ///
  /// Both states share it, so a test can assert the skeleton reserves the same
  /// height the chart takes — a page that jumps when data lands tells a reader
  /// who is unsure whether they tapped that they did something.
  static const Key chartSlotKey = Key('progress-chart-slot');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(progressViewProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProgress)),
      body: switch (state) {
        AsyncData<ProgressViewState>(value: final ProgressLoaded loaded) =>
          _Loaded(state: loaded),
        AsyncData<ProgressViewState>() => TaperEmptyState(
          heading: l10n.noPlanHeading,
          message: l10n.noPlanBody,
          actionLabel: l10n.noPlanAction,
          onAction: () => context.go(Routes.plan),
        ),
        AsyncError<ProgressViewState>() => ErrorPanel(
          title: l10n.errorTitle,
          retryLabel: l10n.errorRetry,
          onRetry: () => ref.invalidate(progressViewProvider),
        ),
        _ => const ProgressSkeleton(),
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});

  final ProgressLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shapes = DaybreakShapes.of(context);
    final wide = WindowSizeClass.forWidth(
      MediaQuery.sizeOf(context).width,
    ).isAtLeast(WindowSizeClass.expanded);

    final chart = KeyedSubtree(
      key: ProgressScreen.chartSlotKey,
      child: DoseStaircaseChart(
        segments: state.segments,
        flares: state.flares,
        holds: state.holds,
        todayDayIndex: state.todayDayIndex,
        todayDose: state.todayDose,
        axis: state.axis,
        summary: state.chartSummary,
        historyRows: state.historyRows,
        eventCountLabel: state.eventCountLabel,
      ),
    );

    final column = <Widget>[
      TaperStartLine(text: state.startLine),
      SizedBox(height: shapes.s3),
      ProgressStatGrid(stats: state.stats, medicine: l10n.drugPrednisolone),
      SizedBox(height: shapes.s3),
      EncouragementCard(message: state.encouragement),
      SizedBox(height: shapes.s5),
      SecondaryButton(
        label: l10n.settingsExportForDoctor,
        expand: true,
        // Never `onPressed: null`. EPIC-13 has not landed, and the honest
        // answer is a route that says so — not a control that looks broken.
        onPressed: () => context.push(Routes.progressExport),
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(shapes.s5),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // The chart keeps its aspect rather than stretching into a
                // letterbox; the numbers take the rest.
                Expanded(child: chart),
                SizedBox(width: shapes.s5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: column,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[chart, ...column],
            ),
    );
  }
}

/// A chart-shaped placeholder while the first emission lands.
///
/// It reserves the chart card's height exactly, so nothing under it moves when
/// the data arrives. A spinner that becomes a chart shifts the whole page, and
/// a reader who is unsure whether they tapped reads that as their tap having
/// done something.
class ProgressSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const ProgressSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final text = Theme.of(context).textTheme;

    // The card's own STRUCTURE, with grey where the content goes — not a
    // height computed from font metrics. Arithmetic that mirrors a layout
    // drifts from it the first time the layout changes, and this reservation
    // is measured to the pixel by a test precisely because the page must not
    // move when the data lands.
    return ListView(
      padding: EdgeInsetsDirectional.all(shapes.s5),
      children: <Widget>[
        Container(
          key: ProgressScreen.chartSlotKey,
          padding: EdgeInsetsDirectional.all(shapes.s4),
          decoration: BoxDecoration(
            gradient: colors.wash,
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
            border: Border.all(
              color: colors.border,
              width: shapes.hairlineWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(' ', style: text.labelSmall),
              SizedBox(height: shapes.s3),
              SizedBox(
                height: DoseStaircaseChart.plotHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.all(
                      Radius.circular(shapes.radiusMd),
                    ),
                  ),
                ),
              ),
              SizedBox(height: shapes.s3),
              Text(' ', style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
