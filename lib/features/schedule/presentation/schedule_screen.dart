/// The Schedule screen: blocks, never a calendar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/day_state_row.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_block_group.dart';
import 'package:nearlystop/features/shared/presentation/widgets/error_panel.dart';
import 'package:nearlystop/features/shared/presentation/widgets/taper_empty_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/routing/routes.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// The taper, grouped into blocks and opened on today.
///
/// **Never a seven-column grid** (`SPEC.md` §4.2). A calendar square has no
/// room for a state shape, a localized state word and 200% text; it forces the
/// eye across unrelated days; and it teaches "a taper is a month" when a taper
/// is a sequence of blocks. `no_calendar_grid_test.dart` and a rule in
/// `tool/check_bans.sh` both fail the build if one appears.
class ScheduleScreen extends ConsumerWidget {
  /// Creates the screen.
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stepIndex = ref.watch(currentStepIndexProvider);
    final state = ref.watch(scheduleViewProvider(stepIndex));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSchedule)),
      body: switch (state) {
        AsyncData<ScheduleViewState>(value: final ScheduleLoaded loaded) =>
          ScheduleList(state: loaded, stepIndex: stepIndex),
        AsyncData<ScheduleViewState>() => TaperEmptyState(
          heading: l10n.noPlanHeading,
          message: l10n.noPlanBody,
          actionLabel: l10n.noPlanAction,
          onAction: () => context.go(Routes.plan),
        ),
        AsyncError<ScheduleViewState>() => ErrorPanel(
          title: l10n.errorTitle,
          retryLabel: l10n.errorRetry,
          onRetry: () => ref.invalidate(scheduleViewProvider(stepIndex)),
        ),
        // A skeleton rather than a spinner: a spinner that becomes a list
        // moves everything under it, and this reader is already unsure
        // whether they tapped.
        _ => const ScheduleSkeleton(),
      },
    );
  }
}

/// The scroll view, opened on today.
///
/// **`CustomScrollView(center:)`, not an initial offset.** The centre key goes
/// on the current block, so today's block starts at scroll offset zero and the
/// history above it lives at NEGATIVE offsets. That is what makes "opens in
/// the middle, scrolls both ways" exact rather than arithmetic — and it is
/// what `jump to today` animates back to, with no measurement at all.
class ScheduleList extends ConsumerStatefulWidget {
  /// Creates the list for [state].
  const ScheduleList({required this.state, required this.stepIndex, super.key});

  /// The blocks to render.
  final ScheduleLoaded state;

  /// The step being shown, for the writes.
  final int stepIndex;

  @override
  ConsumerState<ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends ConsumerState<ScheduleList> {
  /// Identifies the sliver that sits at scroll offset zero.
  static final GlobalKey centerKey = GlobalKey(debugLabel: 'schedule-centre');

  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ScheduleRefusal? _refusal;

  /// Ticks or unticks [day], and SAYS SO when the write is refused.
  ///
  /// A tap that does nothing and reports nothing teaches the reader that the
  /// app is broken, which on this screen means they stop trusting the record
  /// of what they swallowed. Non-tickable rows are not tap targets at all, so
  /// a refusal here is a race — and a race still gets a sentence.
  Future<void> _toggle(ScheduleDayVm day) async {
    final notifier = ref.read(scheduleViewProvider(widget.stepIndex).notifier);
    final refusal = day.state == DayState.taken
        ? await notifier.undoTaken(day.date)
        : await notifier.markTaken(day.date, plannedMg: day.plannedMg);
    if (!mounted || refusal == _refusal) return;
    setState(() => _refusal = refusal);
  }

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    final blocks = widget.state.blocks;
    // Today's block anchors the view. Browsing a step today is not in has
    // nothing to centre on, so it opens at the top.
    final centre = widget.state.todayLocator?.$1 ?? 0;
    final inset = shapes.s5;
    final width = MediaQuery.sizeOf(context).width - inset * 2;
    final onToggle = widget.state.steps.isActive ? _toggle : null;

    final list = CustomScrollView(
      controller: _controller,
      center: centerKey,
      slivers: <Widget>[
        // Grows toward the leading edge. One sliver, not one per block: the
        // reverse-growth region lays its children out nearest-the-centre
        // first, so the content is flattened and reversed as a whole.
        SliverPadding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: inset),
          sliver: ScheduleEarlierSliver(
            blocks: blocks.sublist(0, centre),
            onToggle: onToggle,
          ),
        ),
        for (var index = centre; index < blocks.length; index++)
          SliverPadding(
            key: index == centre ? centerKey : null,
            padding: EdgeInsetsDirectional.fromSTEB(
              inset,
              index == centre ? 0 : shapes.s5,
              inset,
              shapes.s3,
            ),
            sliver: ScheduleBlockGroup(
              block: blocks[index],
              onToggle: onToggle,
              headerWidth: width,
            ),
          ),
      ],
    );

    final refusal = _refusal;
    if (refusal == null) return list;
    return Column(
      children: <Widget>[
        RefusalNotice(refusal: refusal),
        Expanded(child: list),
      ],
    );
  }
}

/// Why the last tap was refused, said out loud.
class RefusalNotice extends StatelessWidget {
  /// Creates the notice for [refusal].
  const RefusalNotice({required this.refusal, super.key});

  /// What was refused.
  final ScheduleRefusal refusal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final message = switch (refusal) {
      ScheduleRefusal.readOnly => l10n.pastStepReadOnly,
      ScheduleRefusal.futureDay => l10n.futureDayNotYet,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: EdgeInsetsDirectional.fromSTEB(
          shapes.s5,
          shapes.s2,
          shapes.s5,
          0,
        ),
        padding: EdgeInsetsDirectional.all(shapes.s3),
        decoration: BoxDecoration(
          color: colors.tintWarning,
          borderRadius: BorderRadius.all(Radius.circular(shapes.radiusMd)),
          border: Border.all(
            color: colors.warning,
            width: shapes.hairlineWidth,
          ),
        ),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.ink),
        ),
      ),
    );
  }
}

/// A block-shaped placeholder while the first emission lands.
///
/// A skeleton rather than a spinner: a spinner that becomes a list moves
/// everything under it, and a reader who is unsure whether they tapped
/// reads that movement as their tap having done something.
class ScheduleSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const ScheduleSkeleton({super.key});

  /// One header plus four rows, the shape the first frame settles into.
  static const int rows = 4;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.all(shapes.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 84,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
            ),
          ),
          for (var row = 0; row < rows; row++)
            Padding(
              padding: EdgeInsetsDirectional.only(top: shapes.s2),
              child: Container(
                height: DayStateRow.minHeight,
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.all(
                    Radius.circular(shapes.radiusMd),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
