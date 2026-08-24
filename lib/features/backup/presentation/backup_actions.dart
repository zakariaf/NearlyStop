/// Export and import, as the two things a screen calls.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearlystop/app/app_version.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/data/backup/backup_writer.dart';
import 'package:nearlystop/data/backup/restore_service.dart';
import 'package:nearlystop/data/database_restart.dart';
import 'package:nearlystop/data/db/database_location.dart';
import 'package:nearlystop/data/providers.dart';
import 'package:nearlystop/services/files/file_picker_gateway.dart';
import 'package:nearlystop/services/files/share_gateway.dart';
import 'package:path_provider/path_provider.dart';

/// Where a working file is written before it is shared or published.
///
/// A function, not a `Directory`, for the same reason [DatabaseLocation] is:
/// resolving it calls `path_provider`, and a provider that awaited a plugin at
/// build time would make every test that merely constructs the container need
/// a plugin binary.
typedef WorkingDirectory = Future<Directory> Function();

/// The shipping working directory: the OS scratch space.
///
/// **Temp, not documents.** A backup lives in the share sheet's hands for the
/// few seconds it takes somebody to pick Mail, and a copy of the whole history
/// left behind in a browsable folder is a second copy of the thing the privacy
/// promise is about.
Future<Directory> systemWorkingDirectory() => getTemporaryDirectory();

/// The OS share sheet.
///
/// Throws until overridden, like every other platform seam in this app: a
/// default that silently did nothing would let a whole suite pass while the
/// app shared no files at all.
final Provider<ShareGateway> shareGatewayProvider = Provider<ShareGateway>((
  ref,
) {
  throw UnimplementedError(
    'shareGatewayProvider must be overridden at the composition root '
    '(bootstrap) or with FakeShareGateway in a test.',
  );
});

/// The OS open dialog.
final Provider<FilePickerGateway> filePickerGatewayProvider =
    Provider<FilePickerGateway>((ref) {
      throw UnimplementedError(
        'filePickerGatewayProvider must be overridden at the composition root '
        '(bootstrap) or with FakeFilePickerGateway in a test.',
      );
    });

/// Where working files go.
final Provider<WorkingDirectory> workingDirectoryProvider =
    Provider<WorkingDirectory>((ref) => systemWorkingDirectory);

/// The live database file — the one a restore renames over.
final Provider<DatabaseLocation> databaseFileProvider =
    Provider<DatabaseLocation>((ref) => appDocumentsDatabaseFile);

/// Writes a backup and returns the file.
///
/// A provider-hosted **function** rather than a service class: the screen needs
/// exactly one verb, and a widget test needs to replace exactly one verb.
final Provider<Future<Result<File, Failure>> Function()> backupExportProvider =
    Provider<Future<Result<File, Failure>> Function()>(
      (ref) =>
          () async => writeBackup(
            database: ref.read(databaseProvider),
            directory: await ref.read(workingDirectoryProvider)(),
            appVersion: kAppVersionLabel,
            clock: ref.read(clockProvider),
          ),
    );

/// Replaces everything on this phone with the chosen file's contents.
///
/// **Closes the live connection first, and asks for a new one after.** The
/// publish is a rename over the database file; a handle held across it points
/// at the old inode and keeps answering with the pre-restore plan until the
/// next launch — see [databaseGenerationProvider].
final Provider<Future<Result<void, Failure>> Function(File)>
backupRestoreProvider = Provider<Future<Result<void, Failure>> Function(File)>(
  (ref) => (file) async {
    final live = await ref.read(databaseFileProvider)();
    final staging = await ref.read(workingDirectoryProvider)();
    final schemaVersion = ref.read(databaseProvider).schemaVersion;
    await ref.read(databaseProvider).close();
    try {
      return await restoreBackup(
        file: file,
        liveDatabaseFile: live,
        stagingDirectory: staging,
        appSchemaVersion: schemaVersion,
      );
    } finally {
      // In BOTH outcomes. The connection is closed either way, so the app
      // needs a fresh one whether the file changed or not.
      ref.read(databaseGenerationProvider.notifier).replaced();
    }
  },
);

/// Writes a backup and offers it to the share sheet.
///
/// [originRect] is passed through and is **not optional on iPad**: UIKit
/// anchors a popover to a source rectangle, and a share sheet without one
/// crashes the app. Callers take it from the tapped button's own bounds.
Future<Result<void, Failure>> exportAndShareBackup(
  WidgetRef ref, {
  required String subject,
  required Rect originRect,
}) async {
  final written = await ref.read(backupExportProvider)();
  if (written case Err<File, Failure>(:final failure)) {
    return Err<void, Failure>(failure);
  }
  return shareExportedFile(
    ref,
    file: (written as Ok<File, Failure>).value,
    mimeType: kBackupMimeType,
    subject: subject,
    originRect: originRect,
  );
}

/// Hands an already-written file to the share sheet.
Future<Result<void, Failure>> shareExportedFile(
  WidgetRef ref, {
  required File file,
  required String mimeType,
  required String subject,
  required Rect originRect,
}) async {
  final shared = await ref
      .read(shareGatewayProvider)
      .shareFile(
        path: file.path,
        mimeType: mimeType,
        subject: subject,
        originRect: originRect,
      );
  return switch (shared) {
    Ok<void, ShareFailure>() => const Ok<void, Failure>(null),
    // A dismissed share sheet is not a failed export: the file is written and
    // the reader chose not to send it. Saying "export failed" there teaches
    // them the feature is broken.
    Err<void, ShareFailure>(failure: ShareCancelled()) =>
      const Ok<void, Failure>(null),
    Err<void, ShareFailure>(:final failure) => Err<void, Failure>(failure),
  };
}

/// The rectangle a share sheet is anchored to on iPad.
///
/// The tapped widget's own bounds in global coordinates, or a degenerate rect
/// at the origin when the widget is gone by the time the file is written —
/// which is still a rect, and still does not crash.
Rect originRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}
