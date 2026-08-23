/// The Schedule screen: blocks, never a calendar.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nearlystop/core/day_state.dart';
import 'package:nearlystop/core/time/local_date.dart';
import 'package:nearlystop/features/schedule/application/schedule_view_provider.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/jump_to_today_button.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_block_group.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_chrome.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/step_switcher_sheet.dart';
import 'package:nearlystop/features/shared/presentation/widgets/error_panel.dart';
import 'package:nearlystop/features/shared/presentation/widgets/taper_empty_state.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/routing/routes.dart';
import 'package:nearlystop/theme/daybreak_motion.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// Above this width the steps get their own pane instead of a sheet.
///
/// `adaptive-layout`'s expanded boundary. Below it the app-bar chevron opens
/// the switcher; above it the pane is permanent and the chevron is GONE — one
/// choice offered in two places is two things to keep in step, and one of them
/// will drift.
const double kScheduleTwoPaneBreakpoint = 840;

/// Below this height the block header drops its teaching sentence.
///
/// A landscape phone. The sentence goes first and the block's identity last,
/// because a header that has stopped saying which block you are in has stopped
/// being a header.
const double kScheduleShortScreenHeight = 500;

/// The taper, grouped into blocks and opened on today.
///
/// **Never a seven-column grid** (`SPEC.md` §4.2). A calendar square has no
/// room for a state shape, a localized state word and 200% text; it forces the
/// eye across unrelated days; and it teaches "a taper is a month" when a taper
/// is a sequence of blocks. `no_calendar_grid_test.dart` and a rule in
/// `tool/check_bans.sh` both fail the build if one appears.
class ScheduleScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  ///
  /// [focus] is the raw `?focus=<iso>` query parameter. It is USER INPUT: a
  /// link can carry anything, so it is parsed defensively and a date the plan
  /// has never heard of falls back to today rather than throwing.
  const ScheduleScreen({this.focus, super.key});

  /// The `?focus=` query parameter, unparsed.
  final String? focus;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  ProviderSubscription<Map<LocalDate, int>>? _pendingFocus;

  @override
  void initState() {
    super.initState();
    // After the first frame: the deep link writes two providers, and writing
    // them during a build is what Riverpod's own assert exists to stop.
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFocus());
    // And AGAIN whenever the derivation changes. On a cold start — a
    // notification tap, a fresh launch — the date → step map is empty until
    // the database read lands, so a link read once on the first frame is a
    // link silently thrown away.
    _pendingFocus = ref.listenManual(
      scheduleFocusDatesProvider,
      (_, _) => _applyFocus(),
    );
  }

  @override
  void didUpdateWidget(ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus) _applyFocus();
  }

  @override
  void dispose() {
    _pendingFocus?.close();
    super.dispose();
  }

  /// Resolves `?focus=` to a step and a day, or leaves the screen on today.
  void _applyFocus() {
    if (!mounted) return;
    // Two ways to miss: an unparseable string, and a perfectly good date the
    // plan has never heard of. Both land on today, because a deep link is the
    // one input this screen does not control. A THIRD way is temporary — the
    // derivation has not arrived yet — which is why this can be called again.
    final date = LocalDate.tryParse(widget.focus ?? '');
    final step = date == null
        ? null
        : ref.read(scheduleFocusDatesProvider)[date];
    if (date == null || step == null) return;
    ref.read(scheduleFocusProvider.notifier).focus(date);
    ref.read(browsedStepProvider.notifier).show(step);
    // Resolved. Later derivations must not drag the reader back to the link
    // they arrived on after they have browsed somewhere else.
    _pendingFocus?.close();
    _pendingFocus = null;
  }

  Future<void> _openSwitcher(
    List<StepOption> options,
    AppLocalizations l10n,
    int current,
  ) async {
    final chosen = await showStepSwitcherSheet(
      context,
      options,
      l10n,
      current: current,
    );
    if (chosen == null || !mounted) return;
    // Browsing is an explicit navigation, so it outranks the deep link that
    // brought the reader here.
    _select(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stepIndex = ref.watch(shownStepIndexProvider);
    final state = ref.watch(scheduleViewProvider(stepIndex));
    final options = ref.watch(scheduleStepOptionsProvider);
    final focus = ref.watch(scheduleFocusProvider);
    final twoPane =
        MediaQuery.sizeOf(context).width > kScheduleTwoPaneBreakpoint &&
        options.length > 1;

    final body = switch (state) {
      AsyncData<ScheduleViewState>(value: final ScheduleLoaded loaded) =>
        ScheduleList(
          // A new centre means a different sliver at offset zero, so the
          // list is REBUILT rather than scrolled: the key gives it a fresh
          // controller sitting at zero, which is exactly the day asked for.
          key: ValueKey<String>('schedule-$stepIndex-$focus'),
          state: loaded,
          stepIndex: stepIndex,
          focus: focus,
        ),
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
      // A skeleton rather than a spinner: a spinner that becomes a list moves
      // everything under it, and this reader is already unsure whether they
      // tapped.
      _ => const ScheduleSkeleton(),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabSchedule),
        actions: <Widget>[
          if (options.length > 1 && !twoPane)
            StepSwitcherButton(
              tooltip: l10n.stepSwitcherTitle,
              onPressed: () => _openSwitcher(options, l10n, stepIndex),
            ),
        ],
      ),
      body: twoPane
          ? Row(
              children: <Widget>[
                // The SAME providers, not a second container: choosing a step
                // on the left is one write, and the right pane is already
                // watching it.
                StepPane(
                  options: options,
                  current: stepIndex,
                  title: l10n.stepSwitcherTitle,
                  completedLabel: l10n.blockCompleted,
                  onSelected: _select,
                ),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }

  /// Browses [index], clearing any deep link that brought the reader here.
  void _select(int index) {
    ref.read(scheduleFocusProvider.notifier).clear();
    ref.read(browsedStepProvider.notifier).show(index);
  }
}

/// The scroll view, opened on today.
///
/// **`CustomScrollView(center:)`, not an initial offset.** The centre key goes
/// on the current block, so today's block starts at scroll offset zero and the
/// history above it lives at NEGATIVE offsets. That is what makes "opens in
/// the middle, scrolls both ways" exact rather than arithmetic — and it is
/// what jump-to-today animates back to, with no measurement at all.
class ScheduleList extends ConsumerStatefulWidget {
  /// Creates the list for [state], centred on [focus] or on today.
  const ScheduleList({
    required this.state,
    required this.stepIndex,
    this.focus,
    super.key,
  });

  /// The blocks to render.
  final ScheduleLoaded state;

  /// The step being shown, for the writes.
  final int stepIndex;

  /// The `?focus=` day, or null to centre on today.
  ///
  /// Today comes from the STATE's own locator, not from the clock: the state
  /// was projected against a date, and asking the clock again is how the list
  /// ends up centred on a day the projection never placed.
  final LocalDate? focus;

  @override
  ConsumerState<ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends ConsumerState<ScheduleList> {
  /// Identifies the sliver that sits at scroll offset zero.
  final GlobalKey _centreKey = GlobalKey(debugLabel: 'schedule-centre');

  /// Finds today's row, so "is today off screen" is measured, not estimated.
  final GlobalKey _todayKey = GlobalKey(debugLabel: 'schedule-today');

  /// Finds the scroll view itself, which is what today has to be inside.
  final GlobalKey _viewportKey = GlobalKey(debugLabel: 'schedule-viewport');

  final ScrollController _controller = ScrollController();

  ScheduleRefusal? _refusal;
  bool _todayOffScreen = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Re-checks AFTER the frame, never during the notification.
  ///
  /// A scroll listener fires before layout, so today's row still reports its
  /// old position. Small scrolls hid that — the next notification corrected it
  /// — but one big fling or jump produces a single notification, and then the
  /// control stayed wrong until the reader happened to scroll again.
  void _onScroll() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final off = !_todayVisible();
      if (off == _todayOffScreen) return;
      setState(() => _todayOffScreen = off);
    });
  }

  /// Whether today's row overlaps the viewport at all.
  ///
  /// Measured off the row itself rather than compared against an estimated
  /// offset: the rows are not a fixed height, and an estimate is wrong at
  /// every text scale but the one it was written at.
  bool _todayVisible() {
    final rowContext = _todayKey.currentContext;
    // The SCROLL VIEW's box, not this widget's. This widget is the Column
    // that also holds the read-only strip and the refusal notice, so a row
    // hidden behind one of those would measure as visible against it.
    final viewportContext = _viewportKey.currentContext;
    final viewport = viewportContext?.findRenderObject();
    if (rowContext == null || viewport is! RenderBox) return false;
    final row = rowContext.findRenderObject();
    if (row is! RenderBox || !row.attached || !viewport.attached) return false;
    final top = row.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return top + row.size.height > 0 && top < viewport.size.height;
  }

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

  /// Returns to today: the active step first, then its centre.
  void _jumpToToday() {
    if (ref.read(shownStepIndexProvider) !=
            ref.read(currentStepIndexProvider) ||
        ref.read(scheduleFocusProvider) != null) {
      // A different step or a different centre rebuilds the list from
      // scratch, which lands at offset zero — today's block — with nothing to
      // animate. There is no arithmetic here and that is the point.
      ref.read(scheduleFocusProvider.notifier).clear();
      ref.read(browsedStepProvider.notifier).followActive();
      return;
    }

    final motion = DaybreakMotion.of(context);
    final duration = resolveMotion(context, motion.base);
    // `resolveMotion` collapses to zero when the OS asks for reduced motion,
    // and `animateTo` ASSERTS on a zero duration — `DrivenScrollActivity`
    // refuses to be driven over no time at all. So the collapse is a real
    // branch, not a zero handed to the same call. The curve comes from the
    // motion slot, never a bare Material easing.
    if (duration == Duration.zero) {
      _controller.jumpTo(0);
      return;
    }
    unawaited(
      _controller.animateTo(0, duration: duration, curve: motion.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shapes = DaybreakShapes.of(context);
    final blocks = widget.state.blocks;
    // The centre anchors the view. A step the centre is not in — a completed
    // step being browsed — opens at the top instead.
    final focused = widget.focus;
    final centreAt = focused == null
        ? widget.state.todayLocator
        : widget.state.locate(focused);
    final centre = centreAt?.$1 ?? 0;
    final todayAt = widget.state.todayLocator;
    // The one row the jump control measures. Null when today is in another
    // step, and then the control simply shows.
    final todayDate = todayAt == null
        ? null
        : blocks[todayAt.$1].days[todayAt.$2].date;
    final inset = shapes.s5;
    final media = MediaQuery.sizeOf(context);
    // The LIST's width, which above the two-pane breakpoint is not the
    // screen's. Measuring the header against the screen wraps the teaching
    // sentence onto fewer lines than it takes and the pinned header clips it.
    final available = media.width > kScheduleTwoPaneBreakpoint
        ? media.width - StepPane.width
        : media.width;
    final width = available - inset * 2;
    final compact = media.height < kScheduleShortScreenHeight;
    final onToggle = widget.state.steps.isActive ? _toggle : null;

    final list = CustomScrollView(
      key: _viewportKey,
      controller: _controller,
      center: _centreKey,
      slivers: <Widget>[
        // Grows toward the leading edge. One sliver, not one per block: the
        // reverse-growth region lays its children out nearest-the-centre
        // first, so the content is flattened and reversed as a whole.
        SliverPadding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: inset),
          sliver: ScheduleEarlierSliver(
            blocks: blocks.sublist(0, centre),
            onToggle: onToggle,
            compactHeaders: compact,
            todayKey: _todayKey,
            todayDate: todayDate,
          ),
        ),
        for (var index = centre; index < blocks.length; index++)
          SliverPadding(
            key: index == centre ? _centreKey : null,
            // Horizontal only. Vertical space between blocks belongs INSIDE
            // the group that owns it, or it becomes a band of scroll during
            // which one block has ended, the next has not begun, and the top
            // of the screen stops saying which block you are in.
            padding: EdgeInsetsDirectional.symmetric(horizontal: inset),
            sliver: ScheduleBlockGroup(
              block: blocks[index],
              onToggle: onToggle,
              headerWidth: width < 0 ? 0 : width,
              compactHeaders: compact,
              todayKey: _todayKey,
              todayDate: todayDate,
            ),
          ),
      ],
    );

    final refusal = _refusal;
    return Column(
      children: <Widget>[
        if (!widget.state.steps.isActive)
          ReadOnlyStrip(message: l10n.pastStepReadOnly),
        if (refusal != null) RefusalNotice(refusal: refusal),
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: list),
              // Absent while today is on screen. BOTH transitions matter: a
              // control that appears once and then stays is one the reader
              // learns to ignore, on a screen they open every morning.
              if (_todayOffScreen || todayAt == null)
                PositionedDirectional(
                  bottom: shapes.s5,
                  start: 0,
                  end: 0,
                  child: Align(
                    child: JumpToTodayButton(
                      label: l10n.jumpToToday,
                      onPressed: _jumpToToday,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
