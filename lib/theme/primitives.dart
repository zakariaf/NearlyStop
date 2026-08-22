/// Tier 1 — the measured primitive pool.
///
/// **This is the only file in the repo allowed a raw `Color(0x…)`.** Every
/// other file, the rest of `lib/theme/` included, composes from [Primitives].
/// `tool/check_raw_values.sh` makes that a build failure rather than a habit.
///
/// Names are `<hueFamily><L*>`: the family is a measured hue/chroma band and
/// the number is CIE L\* rounded, so "are these two far enough apart?" is
/// answerable by reading the names. Never a rank (`brown700`), an appearance
/// (`darkBrown`) or a brand (`brandCoral`) — rank scales have no room to
/// insert, appearance names invert catastrophically in dark, and brand names
/// die with the brand.
///
/// The families:
///
/// | Family | Band |
/// |---|---|
/// | `clay` | warm brown/cream, hue 15–35, chroma > 12 |
/// | `taupe` | the same hue as `clay`, chroma < 12 |
/// | `plum` | dark mauve neutral, hue 300–350 |
/// | `coral` | hue 5–20, high chroma — the brand |
/// | `amber` | hue 25–45 |
/// | `moss` | hue 140–165 |
/// | `rose` | hue 0–8 |
///
/// A colour that appears **only** inside a gradient gets no name here: see
/// `gradients.dart`, where those stops stay inline. A named stop invites a
/// widget to use it as a flat fill, and no row of the contrast budget ever
/// measured it as one.
library;

import 'dart:ui';

/// The measured colour pool. Widgets never read these — they read a
/// `DaybreakColors` slot, because a primitive is a value with no theme.
abstract final class Primitives {
  // --- clay: the warm neutral spine of the light theme -----------------------

  /// surface (light).
  static const Color clay100 = Color(0xFFFFFFFF);

  /// bg (light).
  static const Color clay98 = Color(0xFFFFF9F2);

  /// surfaceRaised (light).
  static const Color clay97 = Color(0xFFFFF4E9);

  /// surfaceSunken (light).
  static const Color clay95 = Color(0xFFFCEFE2);

  /// ink (dark).
  static const Color clay94 = Color(0xFFF9EBE2);

  /// border (light) — the decorative hairline, never a control boundary.
  static const Color clay89 = Color(0xFFF0DDCD);

  /// inkMuted (dark).
  static const Color clay73 = Color(0xFFC9AEA2);

  /// inkFaint (light) — disabled glyphs and placeholders only.
  static const Color clay59 = Color(0xFFA08A80);

  /// borderStrong **and** stateMissed (light).
  ///
  /// The sharing is deliberate: an unticked day carries exactly the weight of a
  /// control boundary — present, legible at 3.65:1, emotionally neutral. A
  /// later "cleanup" that splits them into two primitives is a re-measure, not
  /// a tidy-up, and `test/theme/primitives_test.dart` fails if one lands
  /// quietly.
  static const Color clay56 = Color(0xFFA67D68);

  /// shadow ink (light) — warm brown, never black.
  static const Color clay42 = Color(0xFF8C5438);

  /// inkMuted (light).
  static const Color clay41 = Color(0xFF755B50);

  /// ink (light), and the light overlay ink.
  static const Color clay19 = Color(0xFF3B2A25);

  /// onPrimary (both themes) — the only foreground allowed on the sunrise.
  static const Color clay11 = Color(0xFF2A1A16);

  // --- taupe: the clay hue at markedly lower chroma
  // ---------------------------

  /// inkFaint (dark) — decorative only.
  static const Color taupe56 = Color(0xFF9A8078);

  // --- plum: the dark theme's neutral spine. Warm, never #000
  // -----------------

  /// shadow ink (dark).
  static const Color plum01 = Color(0xFF080406);

  /// overlay ink (dark).
  static const Color plum03 = Color(0xFF10090D);

  /// surfaceSunken (dark).
  static const Color plum08 = Color(0xFF1D1418);

  /// bg (dark) — a warm plum night, never an OLED void.
  static const Color plum11 = Color(0xFF241A20);

  /// surface (dark).
  static const Color plum15 = Color(0xFF2E2229);

  /// surfaceRaised (dark).
  static const Color plum19 = Color(0xFF38292F);

  /// border (dark) — the decorative hairline.
  static const Color plum24 = Color(0xFF45333A);

  /// borderStrong **and** stateMissed (dark) — the dark half of `clay56`'s
  /// deliberate sharing.
  static const Color plum54 = Color(0xFF9A7A82);

  // --- coral: the brand hue
  // ---------------------------------------------------

  /// tintPrimary (light).
  static const Color coral93 = Color(0xFFFFE7DE);

  /// primary, primaryDeep and stateToday (dark) — in dark the fill tone and the
  /// text tone converge at 7.30:1.
  static const Color coral70 = Color(0xFFFF8A66);

  /// glow ink (dark); also a sunrise stop.
  static const Color coral66 = Color(0xFFFF7A52);

  /// primary (light) — **FILL ONLY**, 2.76:1 on surface. Never text, never a
  /// meaningful icon, never a boundary or a focus ring.
  static const Color coral64 = Color(0xFFF97350);

  /// stateToday (light).
  static const Color coral55 = Color(0xFFE2542F);

  /// primaryDeep (light) — the accent **text** tone, 5.56:1.
  static const Color coral43 = Color(0xFFB0402A);

  /// tintPrimary (dark).
  static const Color coral19 = Color(0xFF3E2A26);

  // --- amber
  // ------------------------------------------------------------------

  /// tintWarning (light).
  static const Color amber95 = Color(0xFFFFEFD2);

  /// secondary and stateNewDose (dark).
  static const Color amber83 = Color(0xFFFFC470);

  /// secondary and warningFill (light).
  static const Color amber80 = Color(0xFFFFB84D);

  /// warningFill (dark).
  static const Color amber72 = Color(0xFFE7A54A);

  /// warning and stateNewDose (light).
  static const Color amber42 = Color(0xFF8A5A00);

  /// tintWarning (dark).
  static const Color amber20 = Color(0xFF3A2E1E);

  // --- moss
  // ---------------------------------------------------------------------

  /// tintSuccess (light).
  static const Color moss94 = Color(0xFFDFF3E8);

  /// success (dark).
  static const Color moss78 = Color(0xFF6FD3A4);

  /// successFill and stateTaken (dark).
  static const Color moss70 = Color(0xFF4FBF8B);

  /// successFill and stateTaken (light).
  static const Color moss52 = Color(0xFF2E8B63);

  /// success (light).
  static const Color moss46 = Color(0xFF1F7A55);

  /// tintSuccess (dark).
  static const Color moss22 = Color(0xFF25382F);

  // --- rose
  // ---------------------------------------------------------------------

  /// tintDanger (light).
  static const Color rose92 = Color(0xFFFCE4E1);

  /// danger (dark).
  static const Color rose70 = Color(0xFFFF8A80);

  /// dangerFill (dark).
  static const Color rose58 = Color(0xFFE0655A);

  /// dangerFill (light).
  static const Color rose47 = Color(0xFFC63F32);

  /// danger (light).
  static const Color rose40 = Color(0xFFA8352B);

  /// tintDanger (dark).
  static const Color rose18 = Color(0xFF3E2624);

  // --- high-contrast additions ----------------------------------------------
  // The high-contrast palette holds TEXT rows at 7:1 and boundary/state-mark
  // rows at 4.5:1 — one step above the base palette. A row that cannot reach
  // its floor is a slot that needs a new primitive, not a lowered floor
  // (daybreak-tokens rule 14), so these exist. Each was derived by scaling its
  // base tone in LINEAR sRGB until the floor was met, which moves luminance and
  // leaves hue and chroma where they were: high contrast changes what you can
  // read, never the emotional register.

  /// inkFaint (light, high contrast) — 7.00:1 on `bg`.
  static const Color clay37 = Color(0xFF695147);

  /// borderStrong **and** stateMissed (light, high contrast) — 4.54:1 on
  /// `surface`. Warm taupe darkened, still not `danger`.
  static const Color clay50 = Color(0xFF936E5B);

  /// onPrimary (light, high contrast) — 7.01:1 on the coral fill, which is the
  /// sunrise gradient's worst stop.
  static const Color clay04 = Color(0xFF150B09);

  /// primaryDeep (light, high contrast) — 7.03:1 on `tintPrimary`, its tightest
  /// background.
  static const Color coral33 = Color(0xFF8A301F);

  /// stateToday (light, high contrast) — 4.50:1 on `surface`.
  static const Color coral50 = Color(0xFFCD4C2A);

  /// primaryDeep (dark, high contrast) — 7.03:1 on `tintPrimary`.
  static const Color coral76 = Color(0xFFFFA67C);

  /// success (light, high contrast) — 7.08:1 on `tintSuccess`.
  static const Color moss34 = Color(0xFF145A3D);

  /// stateTaken (light, high contrast) — 4.55:1 on `surface`.
  static const Color moss50 = Color(0xFF2B855E);

  /// success (dark, high contrast) — 7.05:1 on `tintSuccess`.
  static const Color moss79 = Color(0xFF71D6A7);

  /// warning (light, high contrast) — 7.08:1 on `tintWarning`.
  static const Color amber34 = Color(0xFF704800);

  /// danger (light, high contrast) — 7.07:1 on `tintDanger`.
  static const Color rose32 = Color(0xFF8B2A21);

  /// danger (dark, high contrast) — 7.01:1 on `tintDanger` and on `surface`.
  static const Color rose75 = Color(0xFFFF9E93);

  /// borderStrong **and** stateMissed (dark, high contrast) — 4.52:1 on
  /// `surface`. Lightened rather than darkened, because the ground is dark.
  static const Color plum58 = Color(0xFFA5838B);
}
