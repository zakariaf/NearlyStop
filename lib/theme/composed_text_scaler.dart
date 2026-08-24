/// The one place `textScaleFactor` may legally be read.
///
/// Its own file, and not because the class is large. `TextScaler` declares
/// `textScaleFactor` as an **abstract deprecated getter**, so any subclass has
/// to implement it — which means `tool/check_bans.sh`'s "never read
/// textScaleFactor" rule needs somewhere to stand down. Scoping that to a file
/// holding one class scopes it to one class; leaving it in the preferences
/// layer would have quietly exempted everything else in that file too.
library;

import 'package:flutter/widgets.dart';

/// The ceiling on the PRODUCT of the two scalers.
///
/// iOS AX5 is about 3.1×, and 3.1 × 2.0 is 6.2× — a size no golden renders and
/// no 320pt device survives. This bounds the product only: with the app slider
/// at 1.0 the layer does not wrap at all, so the OS value passes through
/// untouched at any setting and SPEC §10's "usable at the largest OS text
/// size" is honoured in full. EPIC-14's overflow matrix is built on this
/// number.
const double kMaxComposedTextScale = 4;

/// The OS scaler MULTIPLIED by the app's own factor, product-capped.
///
/// Not `TextScaler.clamp`: clamping to a minimum of 1.5 leaves an OS setting
/// of 2.0 at 2.0, when the user asked for both. Composition means OS 2.0 ×
/// app 1.5 is 3.0.
///
/// The PRODUCT is capped at [kMaxComposedTextScale], and only the product: the
/// layer above does not wrap at all when the factor is 1.0, so the OS value
/// passes through untouched at any setting. This app never shrinks a choice
/// the user made in their phone's own accessibility settings.
@immutable
@visibleForTesting
class ComposedTextScaler extends TextScaler {
  /// Composes [_platform] with [_factor].
  const ComposedTextScaler(this._platform, this._factor);

  final TextScaler _platform;
  final double _factor;

  @override
  double scale(double fontSize) {
    final composed = _platform.scale(fontSize) * _factor;
    final ceiling = fontSize * kMaxComposedTextScale;
    return composed < ceiling ? composed : ceiling;
  }

  @override
  // Deprecated upstream in favour of non-linear scaling, but still abstract on
  // `TextScaler`, so it has to be implemented. Composed the same way as
  // `scale`, so a caller reading either gets a consistent answer.
  // ignore: deprecated_member_use
  double get textScaleFactor => _platform.textScaleFactor * _factor;

  @override
  bool operator ==(Object other) =>
      other is ComposedTextScaler &&
      other._platform == _platform &&
      other._factor == _factor;

  @override
  int get hashCode => Object.hash(_platform, _factor);
}
