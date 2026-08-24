/// The shipping share sheet.
library;

import 'dart:ui';

import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/services/files/share_gateway.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a file to the OS share sheet through `share_plus`.
///
/// Not covered by a widget test — it is the platform channel itself, and a
/// test over it would assert that a mock answers. What IS covered is every
/// call site, against `FakeShareGateway`, which is why this class does as
/// little as possible: translate, call, translate back.
class SharePlusGateway implements ShareGateway {
  /// Creates the gateway.
  const SharePlusGateway();

  @override
  Future<Result<void, ShareFailure>> shareFile({
    required String path,
    required String mimeType,
    required String subject,
    Rect? originRect,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path, mimeType: mimeType)],
          subject: subject,
          // The iPad popover anchor. `share_plus` centres the sheet rather
          // than throwing when it is missing, but a popover in the middle of
          // the screen with no arrow is a dialog nobody can trace back to the
          // button they pressed.
          sharePositionOrigin: originRect,
          // OFF. The web fallback downloads the file through a browser API
          // this app never runs in, and the mail fallback opens a `mailto:`
          // — an app whose whole premise is that nothing leaves the phone
          // unless the reader sends it must not have a hidden second path
          // that sends it.
          downloadFallbackEnabled: false,
          mailToFallbackEnabled: false,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success ||
        // "The platform shared it but cannot say what the user chose." Not a
        // failure: the file left, and telling somebody it did not is worse
        // than saying nothing.
        ShareResultStatus.unavailable => const Ok<void, ShareFailure>(null),
        ShareResultStatus.dismissed => const Err<void, ShareFailure>(
          ShareCancelled(),
        ),
      };
    } on Object catch (error) {
      return Err<void, ShareFailure>(ShareRefused('$error'));
    }
  }
}
