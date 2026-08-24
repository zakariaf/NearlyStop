/// Handing a file to the OS share sheet.
library;

import 'dart:ui';

import 'package:nearlystop/core/result.dart';

/// Why a share did not happen.
sealed class ShareFailure extends Failure {
  /// Creates the failure.
  const ShareFailure();
}

/// The reader dismissed the sheet. Not an error, and not worth a message.
final class ShareCancelled extends ShareFailure {
  /// Creates the failure.
  const ShareCancelled();

  @override
  String get code => 'share.cancelled';
}

/// The platform refused.
final class ShareRefused extends ShareFailure {
  /// Creates the failure with what the platform said.
  const ShareRefused(this.reason);

  /// For a log — never shown to the reader.
  final String reason;

  @override
  String get code => 'share.refused';

  @override
  List<Object?> get props => <Object?>[reason];
}

/// The OS share sheet, behind one method.
// A one-method interface on purpose: it is a SEAM, not a helper. A top-level
// function cannot be swapped for a fake, and swapping it for a fake is the
// entire reason this file exists.
// ignore: one_member_abstracts
abstract interface class ShareGateway {
  /// Offers the file at [path] to the share sheet.
  ///
  /// **[originRect] is not optional on iPad.** UIKit anchors a popover to a
  /// source rectangle, and a share sheet presented without one crashes the
  /// app. Every call site in this app passes one; a test walks the recorded
  /// calls and asserts it, because that is the only way to check it off a
  /// device.
  Future<Result<void, ShareFailure>> shareFile({
    required String path,
    required String mimeType,
    required String subject,
    Rect? originRect,
  });
}
