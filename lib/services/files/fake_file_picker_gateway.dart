/// The file picker every test talks to.
library;

import 'dart:io';

import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/services/files/file_picker_gateway.dart';

/// A `FilePickerGateway` that answers on demand.
///
/// **`implements`, with no `noSuchMethod`.** A new method on the port is a
/// compile error here rather than a silent pass.
class FakeFilePickerGateway implements FilePickerGateway {
  /// What the dialog returns when it succeeds.
  File? picked;

  /// When set, the dialog fails with this instead.
  PickFailure? failure;

  /// How many times the dialog was opened.
  int callCount = 0;

  @override
  Future<Result<File, PickFailure>> pickBackupFile() async {
    callCount++;
    final pending = failure;
    if (pending != null) return Err<File, PickFailure>(pending);
    final file = picked;
    if (file == null) return const Err<File, PickFailure>(PickCancelled());
    return Ok<File, PickFailure>(file);
  }
}
