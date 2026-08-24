/// The share gateway every test talks to.
library;

import 'dart:ui';

import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/services/files/share_gateway.dart';

/// One recorded call to [FakeShareGateway.shareFile].
class RecordedShare {
  /// Records a call.
  const RecordedShare({
    required this.path,
    required this.mimeType,
    required this.subject,
    required this.originRect,
  });

  /// What was shared.
  final String path;

  /// What it was called.
  final String mimeType;

  /// The sheet's subject line.
  final String subject;

  /// The iPad anchor, or null when the caller forgot one.
  final Rect? originRect;
}

/// A `ShareGateway` that remembers instead of presenting.
///
/// **`implements`, with no `noSuchMethod`.** A new method on the port is a
/// compile error here rather than a silent pass in every test that trusts it.
class FakeShareGateway implements ShareGateway {
  /// Every call, in order.
  final List<RecordedShare> calls = <RecordedShare>[];

  /// When set, the next and every later call fails with it.
  ShareFailure? failure;

  @override
  Future<Result<void, ShareFailure>> shareFile({
    required String path,
    required String mimeType,
    required String subject,
    Rect? originRect,
  }) async {
    calls.add(
      RecordedShare(
        path: path,
        mimeType: mimeType,
        subject: subject,
        originRect: originRect,
      ),
    );
    final pending = failure;
    if (pending != null) return Err<void, ShareFailure>(pending);
    return const Ok<void, ShareFailure>(null);
  }
}
