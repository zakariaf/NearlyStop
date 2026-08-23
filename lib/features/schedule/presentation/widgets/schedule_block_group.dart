/// One block as a sliver group, and the reversed history above it.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/features/schedule/presentation/schedule_view_state.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/block_header.dart';
import 'package:nearlystop/features/schedule/presentation/widgets/schedule_day_row.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// One block: a pinned header, then its days.
///
/// **`SliverMainAxisGroup`, not a flat list of slivers.** A plain pinned
/// `SliverPersistentHeader` sticks for the whole scroll view, so block 3's
/// header would sit over block 4's rows and the header would stop being a
/// truthful label. The group scopes the pinning to its own extent.
class ScheduleBlockGroup extends StatelessWidget {
  /// Creates the group for [block].
  const ScheduleBlockGroup({
    required this.block,
    required this.onToggle,
    required this.headerWidth,
    super.key,
  });

  /// The block, already projected.
  final ScheduleBlockVm block;

  /// Forwarded to every row that can be ticked.
  final ValueChanged<ScheduleDayVm>? onToggle;

  /// The width the header is actually laid out at.
  ///
  /// The list is inset, so the delegate cannot read the width off the
  /// viewport: measuring against a wider box wraps the teaching sentence onto
  /// fewer lines than it takes and the pinned header then clips it.
  final double headerWidth;

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: <Widget>[
      SliverPersistentHeader(
        pinned: true,
        delegate: BlockHeaderDelegate(
          header: headerFor(context, block),
          context: context,
          width: headerWidth,
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              ScheduleDayRowTile(day: block.days[index], onToggle: onToggle),
          childCount: block.days.length,
          // 780 rows of history: keeping scrolled-off rows alive is how this
          // screen becomes slow at step 12. Set deliberately, so the default
          // cannot come back by accident.
          addAutomaticKeepAlives: false,
        ),
      ),
    ],
  );

  /// The header widget for [block], shared with the reversed leading region.
  static BlockHeader headerFor(BuildContext context, ScheduleBlockVm block) {
    final l10n = AppLocalizations.of(context);
    final completed = block.status == BlockStatus.completed;
    return BlockHeader(
      title: block.title,
      doseSummary: block.summary,
      semanticsLabel: <String>[
        block.title,
        if (block.summary.isNotEmpty) block.summary,
        if (completed) l10n.blockCompleted,
      ].join('. '),
      isCurrent: block.status == BlockStatus.current,
      isCompleted: completed,
      completedLabel: completed ? l10n.blockCompleted : null,
    );
  }
}

/// One row with the padding the list gives it.
///
/// A named class rather than a closure in the builder: `widget-composition`
/// bans `_buildRow()` helpers, and the `ValueKey(date)` has to live on
/// something the element tree can diff.
class ScheduleDayRowTile extends StatelessWidget {
  /// Creates the padded row for [day].
  ScheduleDayRowTile({required this.day, required this.onToggle})
    : super(key: ValueKey<String>('schedule-day-${day.date.toIso8601()}'));

  /// The row's data.
  final ScheduleDayVm day;

  /// Forwarded to the row when it is tickable.
  final ValueChanged<ScheduleDayVm>? onToggle;

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        shapes.s4,
        shapes.s1,
        shapes.s4,
        shapes.s1,
      ),
      child: ScheduleDayRow(day: day, onToggle: onToggle),
    );
  }
}

/// Everything BEFORE the current block, in the order a reversed sliver wants.
///
/// Slivers placed before `CustomScrollView.center` grow toward the leading
/// edge, and their children are laid out nearest-the-centre first — so the
/// content is flattened and REVERSED, which puts each block's header back
/// above its own rows on screen.
///
/// Its headers do not pin. Pinning inside the reverse-growth region would
/// stick a header to the bottom edge, which is not what a header means; and
/// the reader scrolling back into history is looking for a specific day, not
/// for a label to stay put.
class ScheduleEarlierSliver extends StatelessWidget {
  /// Creates the leading region for [blocks].
  const ScheduleEarlierSliver({
    required this.blocks,
    required this.onToggle,
    super.key,
  });

  /// The blocks before the current one, in forward order.
  final List<ScheduleBlockVm> blocks;

  /// Forwarded to every row that can be ticked.
  final ValueChanged<ScheduleDayVm>? onToggle;

  @override
  Widget build(BuildContext context) {
    final items = <Object>[
      for (final block in blocks) ...<Object>[block, ...block.days],
    ].reversed.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          return switch (item) {
            ScheduleBlockVm() => _EarlierHeader(block: item),
            ScheduleDayVm() => ScheduleDayRowTile(
              day: item,
              onToggle: onToggle,
            ),
            _ => const SizedBox.shrink(),
          };
        },
        childCount: items.length,
        addAutomaticKeepAlives: false,
      ),
    );
  }
}

/// A block header in the scrolled-past region: same widget, no pinning.
class _EarlierHeader extends StatelessWidget {
  const _EarlierHeader({required this.block});

  final ScheduleBlockVm block;

  @override
  Widget build(BuildContext context) {
    final shapes = DaybreakShapes.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        shapes.s4,
        shapes.s3,
        shapes.s4,
        shapes.s2,
      ),
      child: ScheduleBlockGroup.headerFor(context, block),
    );
  }
}
