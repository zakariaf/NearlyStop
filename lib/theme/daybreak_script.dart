/// Which script the app is currently rendering.
///
/// Owned by `daybreak-bilingual-type` (CONTRACTS.md §9). It is a *script*, not
/// a locale: `en` and `de` both render Latin, `fa` and `ckb` both render
/// Perso-Arabic, and the typography differences follow the script rather than
/// the language. EPIC-03 supplies the locale → script mapping; this epic ships
/// the enum and the transform it selects.
library;

/// The two scripts NearlyStop ships.
enum DaybreakScript {
  /// Nunito. English and German.
  latin,

  /// Vazirmatn. Persian and Kurdish Sorani.
  perso,
}
