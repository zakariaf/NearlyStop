/// The shipping open dialog.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/services/files/file_picker_gateway.dart';

/// Asks the reader for a backup file through `file_selector`.
class FileSelectorGateway implements FilePickerGateway {
  /// Creates the gateway.
  const FileSelectorGateway();

  /// The type filter, deliberately permissive.
  ///
  /// What decides whether a file is a backup is its **envelope** — never its
  /// extension and never its name, both of which survive a rename and neither
  /// of which says anything about the bytes. A filter tight enough to hide a
  /// renamed backup is a filter that hides the reader's own file from them.
  static const XTypeGroup backupTypeGroup = XTypeGroup(
    label: 'NearlyStop backup',
    extensions: <String>['ndjson', 'json', 'txt'],
    // Without this, iOS shows nothing at all: `UTTypeText` is what the files
    // actually are, and an extension list alone is not a UTI.
    uniformTypeIdentifiers: <String>['public.text', 'public.data'],
    mimeTypes: <String>['application/x-ndjson', 'application/json'],
  );

  @override
  Future<Result<File, PickFailure>> pickBackupFile() async {
    final XFile? picked;
    try {
      picked = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[backupTypeGroup],
      );
    } on Object catch (error) {
      return Err<File, PickFailure>(PickUnreadable('$error'));
    }
    // A dismissal, and its OWN type: changing your mind needs no message, and
    // a file that cannot be opened does.
    if (picked == null) return const Err<File, PickFailure>(PickCancelled());
    final file = File(picked.path);
    if (!file.existsSync()) {
      return Err<File, PickFailure>(PickUnreadable('gone: ${picked.path}'));
    }
    return Ok<File, PickFailure>(file);
  }
}
