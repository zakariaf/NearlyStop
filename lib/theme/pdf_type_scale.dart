/// The printed page's own scale.
library;

/// Type sizes and spacing for the doctor's handout, in PostScript points.
///
/// **Under `lib/theme/` like every other design value**, even though the `pdf`
/// package cannot read a `ThemeExtension`: there is no `BuildContext` on a
/// page being written to a file, and a `TextStyle` there is `pw.TextStyle`,
/// not Flutter's. What the rule is actually protecting is that design
/// decisions live in one directory, and this is one.
///
/// **Not `DaybreakTypography`'s scale.** That one is tuned for a phone held at
/// arm's length by somebody in their seventies; this one is A4 at reading
/// distance, in points rather than logical pixels, and has to fit a hundred
/// table rows on as few pages as a rheumatologist will actually read. Reusing
/// the screen scale here produces a nine-page handout.
abstract final class PdfTypeScale {
  /// The document's own title.
  static const double title = 20;

  /// A headline number — the current dose, the cumulative total.
  static const double statValue = 14;

  /// The date range under the title.
  static const double subtitle = 11;

  /// A table cell, and a stat's label.
  static const double body = 9;

  /// The footer, which repeats on every page.
  static const double footnote = 8;

  /// The gap above the footer and below the running header.
  static const double edgeGap = 8;
}
