/// The one breakpoint vocabulary, shared by every adaptive decision.
library;

/// The Material 3 window size classes, by logical width.
///
/// **One enum, not a constant per screen.** Before this the shell switched to
/// a rail at 600 and the Plan screen went two-up at 840, each with its own
/// literal; the two are the same vocabulary and drift the first time one is
/// tuned. Declared widest-last so [isAtLeast] compares in the direction it
/// reads.
enum WindowSizeClass {
  /// Phones in portrait. Below 600.
  compact(0),

  /// Large phones in landscape, small tablets. 600 to 839.
  medium(600),

  /// Tablets. 840 to 1199.
  expanded(840),

  /// Desktop windows. 1200 to 1599.
  large(1200),

  /// 1600 and up.
  extraLarge(1600);

  const WindowSizeClass(this.minWidth);

  /// The narrowest width in this class.
  final double minWidth;

  /// The class [width] falls in.
  ///
  /// A width below zero — some embedders report a zero or unset size on the
  /// first frame — is [compact]: the narrowest layout is the one that fits
  /// everywhere, so guessing small fails safe.
  static WindowSizeClass forWidth(double width) {
    var result = WindowSizeClass.compact;
    for (final candidate in WindowSizeClass.values) {
      if (width >= candidate.minWidth) result = candidate;
    }
    return result;
  }

  /// Whether this class is [other] or wider.
  bool isAtLeast(WindowSizeClass other) => index >= other.index;
}
