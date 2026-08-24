/// Changing the weight of a style on a variable face.
library;

import 'package:flutter/painting.dart';

/// Weight overrides that actually reach the renderer.
extension DaybreakTextWeight on TextStyle {
  /// This style at [weight].
  ///
  /// **Use this, never `copyWith(fontWeight:)`.** `tool/check_bans.sh` refuses
  /// the latter outside `lib/theme/`, because it is the rare mistake that
  /// looks exactly like the fix:
  ///
  /// Nunito and Vazirmatn are each bundled as ONE variable TTF with a `wght`
  /// axis. `TextStyle.fontWeight` chooses among the *registered assets* for a
  /// family; with a single asset there is nothing to choose, so it selects that
  /// asset at whatever instance the axis is pinned to, and Flutter synthesises
  /// nothing. The axis is moved only by `fontVariations`.
  ///
  /// So `copyWith(fontWeight: FontWeight.w700)` compiles, reads correctly,
  /// survives review, and paints text at exactly the width it had before. It
  /// did, at 57 call sites across every feature, which is why this exists as an
  /// extension with a gate behind it rather than as a convention.
  ///
  /// [weight] is set on both, and any other axis on the style is kept — only
  /// `wght` is replaced, never appended to. Two `wght` entries is neither a
  /// compile error nor a runtime error; the renderer simply picks one.
  TextStyle atWeight(FontWeight weight) => copyWith(
    fontWeight: weight,
    fontVariations: <FontVariation>[
      ...?fontVariations?.where((variation) => variation.axis != 'wght'),
      FontVariation('wght', weight.value.toDouble()),
    ],
  );
}
