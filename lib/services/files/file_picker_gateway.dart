/// Choosing a backup file to restore from.
library;

import 'dart:io';

import 'package:nearlystop/core/result.dart';

/// Why no file arrived.
sealed class PickFailure extends Failure {
  /// Creates the failure.
  const PickFailure();
}

/// The reader closed the dialog.
///
/// Its own type, not a `null`: changing your mind needs no message, and a file
/// you chose on purpose that the app cannot open needs one. Collapsing the two
/// means either an error toast for a dismissal or silence for a real failure.
final class PickCancelled extends PickFailure {
  /// Creates the failure.
  const PickCancelled();

  @override
  String get code => 'pick.cancelled';
}

/// A file was chosen and could not be read.
final class PickUnreadable extends PickFailure {
  /// Creates the failure with what the platform said.
  const PickUnreadable(this.reason);

  /// For a log — never shown to the reader.
  final String reason;

  @override
  String get code => 'pick.unreadable';

  @override
  List<Object?> get props => <Object?>[reason];
}

/// The OS open dialog, behind one method.
// A one-method interface on purpose: it is a SEAM, not a helper. A top-level
// function cannot be swapped for a fake, and swapping it for a fake is the
// entire reason this file exists.
// ignore: one_member_abstracts
abstract interface class FilePickerGateway {
  /// Asks the reader for a backup file.
  ///
  /// The dialog's type filter is permissive on purpose. What decides whether a
  /// file is a backup is its **envelope** — never its extension and never its
  /// name, both of which survive a rename and neither of which says anything
  /// about the bytes.
  Future<Result<File, PickFailure>> pickBackupFile();
}
