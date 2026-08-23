/// The block header — the teaching device that replaces the month grid.
library;

import 'package:flutter/material.dart';
import 'package:nearlystop/theme/daybreak_colors.dart';
import 'package:nearlystop/theme/daybreak_elevation.dart';
import 'package:nearlystop/theme/daybreak_shapes.dart';

/// One block's identity and pattern, as a sentence.
///
/// **This is the product, not chrome.** `SPEC.md` §4.2: the schedule is never a
/// seven-column grid, because a grid re-creates exactly the confusion the app
/// exists to remove. Block grouping is the teaching device, and this header is
/// what does the teaching — "Block 3 of 11 — one day at 9mg, then 4 days at
/// 10mg" is the answer to the forum's most-asked question.
///
/// Every string arrives pre-localized. The widget paints.
class BlockHeader extends StatelessWidget {
  /// Creates a header for one block.
  const BlockHeader({
    required this.title,
    required this.doseSummary,
    required this.semanticsLabel,
    required this.isCurrent,
    required this.isCompleted,
    this.completedLabel,
    super.key,
  }) : assert(
         !isCompleted || completedLabel != null,
         'a completed block is signalled by tint AND glyph AND word; without '
         'the word the tint is colour alone',
       );

  /// Finds the decorated container, for tests that measure it.
  static const Key containerKey = Key('block-header-container');

  /// Finds the leading glyph tile.
  static const Key glyphTileKey = Key('block-header-glyph');

  /// The glyph on a finished block.
  static const IconData completedGlyph = Icons.check_circle;

  /// The glyph on the leading tile.
  static const IconData leadingGlyph = Icons.view_agenda_outlined;

  /// The leading tile's side, from `.bh-ico` in the reference.
  ///
  /// Fixed, and deliberately not scaled by the text scaler: it is a marker in
  /// the margin, and the sentence beside it is what has to grow.
  static const double tileSide = 36;

  /// "Block 3 of 11", already localized.
  final String title;

  /// "one day at 9mg, then 4 days at 10mg", already localized.
  final String doseSummary;

  /// Both lines as one sentence, for the semantics tree.
  final String semanticsLabel;

  /// Whether this is the block the user is in today.
  final bool isCurrent;

  /// Whether this block is behind them.
  final bool isCompleted;

  /// The completed word, already localized. Required when [isCompleted].
  final String? completedLabel;

  /// The title's style, shared with the delegate's measurement.
  static TextStyle titleStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
        fontWeight: FontWeight.w800,
        color: DaybreakColors.of(context).ink,
      );

  /// The summary's style, shared with the delegate's measurement.
  ///
  /// `ink`, not `inkMuted`: the reference sets `.bh-txt` to full `ink`, and
  /// this is the teaching sentence rather than a caption.
  static TextStyle summaryStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.w700,
        color: DaybreakColors.of(context).ink,
      );

  /// The completed word's style.
  static TextStyle completedStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!.copyWith(
        fontWeight: FontWeight.w800,
        color: DaybreakColors.of(context).success,
      );

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    final elevation = DaybreakElevation.of(context);

    return Semantics(
      container: true,
      header: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          key: containerKey,
          padding: EdgeInsetsDirectional.all(shapes.s4),
          decoration: BoxDecoration(
            color: switch ((isCompleted, isCurrent)) {
              (true, _) => colors.tintSuccess,
              (false, true) => colors.tintPrimary,
              (false, false) => colors.surfaceRaised,
            },
            borderRadius: BorderRadius.all(Radius.circular(shapes.radiusLg)),
            border: Border.all(
              // The SLOT, never a `Color.lerp` here: a computed colour outside
              // `lib/theme/` is what `tool/check_raw_values.sh` exists to catch,
              // and no parity test could compare it to the design source.
              color: isCurrent ? colors.borderCurrentBlock : colors.border,
              width: shapes.hairlineWidth,
            ),
            boxShadow: elevation.level1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _BlockGlyphTile(),
              SizedBox(width: shapes.s3),
              Expanded(
                child: _BlockSentence(
                  title: title,
                  doseSummary: doseSummary,
                  isCompleted: isCompleted,
                  completedLabel: completedLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 36x36 tile that leads the header.
///
/// A CLASS, not a `_buildX()` helper: `widget-composition` bans those outright
/// — no `Element` boundary, no `const`, no key. This one is fully `const`, so
/// it is built once for every header in a 52-day list.
class _BlockGlyphTile extends StatelessWidget {
  const _BlockGlyphTile();

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Container(
      key: BlockHeader.glyphTileKey,
      width: BlockHeader.tileSide,
      height: BlockHeader.tileSide,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.all(Radius.circular(shapes.radiusSm)),
        border: Border.all(color: colors.border, width: shapes.hairlineWidth),
      ),
      child: Icon(
        BlockHeader.leadingGlyph,
        size: 20,
        color: colors.primaryDeep,
      ),
    );
  }
}

/// The title, the pattern, and the completed word when there is one.
class _BlockSentence extends StatelessWidget {
  const _BlockSentence({
    required this.title,
    required this.doseSummary,
    required this.isCompleted,
    required this.completedLabel,
  });

  final String title;
  final String doseSummary;
  final bool isCompleted;
  final String? completedLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DaybreakColors.of(context);
    final shapes = DaybreakShapes.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: BlockHeader.titleStyle(context)),
        Text(doseSummary, style: BlockHeader.summaryStyle(context)),
        if (isCompleted) ...<Widget>[
          SizedBox(height: shapes.s1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(BlockHeader.completedGlyph, size: 18, color: colors.success),
              SizedBox(width: shapes.s1),
              Flexible(
                child: Text(
                  completedLabel!,
                  style: BlockHeader.completedStyle(context),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Pins a [BlockHeader] to the top of the block the user is scrolling through.
///
/// **`maxExtent` is measured, never a constant.** A fixed extent looks right at
/// 1.0 and clips the teaching sentence at 2.0 — which is the scale this
/// audience actually uses, so the constant version ships a header that says
/// "Block 3 of 11 — one day at 9mg, then 4 day…". The extent is laid out with
/// the same styles the widget renders, at the same width.
class BlockHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// Creates a delegate that measures [header] against [context].
  ///
  /// [width] is the width the header will actually be laid out at. It defaults
  /// to the whole viewport, which is right only when the list is not inset —
  /// and the Schedule list IS inset, so it passes its own.
  BlockHeaderDelegate({
    required this.header,
    required BuildContext context,
    double? width,
  }) : _extent = _measure(header, context, width);

  /// The header this delegate pins.
  final BlockHeader header;

  final double _extent;

  /// The laid-out height of [header] at the current width and text scale.
  ///
  /// Width defaults to the whole viewport. A caller that lays the header out
  /// NARROWER than that — an inset list, a tablet with a rail — must pass its
  /// own, because measuring against a wider box wraps the sentence onto fewer
  /// lines than it really takes and the pinned header then CLIPS it. That
  /// direction is the dangerous one, and the audience runs at 200%.
  static double _measure(
    BlockHeader header,
    BuildContext context, [
    double? width,
  ]) {
    final shapes = DaybreakShapes.of(context);
    final media = MediaQuery.of(context);
    final contentWidth =
        (width ?? media.size.width) -
        shapes.s4 * 2 -
        BlockHeader.tileSide -
        shapes.s3 -
        // The container's own hairline, both sides.
        shapes.hairlineWidth * 2;

    double heightOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: media.textScaler,
      )..layout(maxWidth: contentWidth);
      return painter.height;
    }

    var sentence =
        heightOf(header.title, BlockHeader.titleStyle(context)) +
        heightOf(header.doseSummary, BlockHeader.summaryStyle(context));
    if (header.isCompleted) {
      sentence +=
          shapes.s1 +
          heightOf(header.completedLabel!, BlockHeader.completedStyle(context));
    }

    // The tile is a floor, not an addend: it sits BESIDE the sentence.
    return shapes.s4 * 2 +
        shapes.hairlineWidth * 2 +
        (sentence < BlockHeader.tileSide ? BlockHeader.tileSide : sentence);
  }

  @override
  double get maxExtent => _extent;

  @override
  double get minExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(height: _extent, child: header);

  @override
  bool shouldRebuild(BlockHeaderDelegate oldDelegate) =>
      oldDelegate.header.title != header.title ||
      oldDelegate.header.doseSummary != header.doseSummary ||
      oldDelegate.header.isCurrent != header.isCurrent ||
      oldDelegate.header.isCompleted != header.isCompleted ||
      oldDelegate.header.completedLabel != header.completedLabel ||
      // The text scale is not a field on the header, so it reaches this
      // comparison through the extent it produced.
      oldDelegate._extent != _extent;
}
