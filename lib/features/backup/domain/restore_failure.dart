/// Why a restore did not happen.
library;

import 'package:nearlystop/core/result.dart';

/// A refusal on the restore ladder. Six subtypes, one per reason.
///
/// **Named rather than counted.** Each of these is a different sentence the
/// reader needs, and collapsing any two would leave the app saying "the file
/// could not be read" to somebody whose file is fine and whose app is simply
/// too old.
sealed class RestoreFailure extends Failure {
  /// Creates the failure.
  const RestoreFailure();
}

/// The file is not a NearlyStop backup at all.
///
/// A CSV, a PDF, a photo, a truncated download. Decided by line one, before a
/// single byte of payload is read.
final class NotABackupFile extends RestoreFailure {
  /// Creates the failure.
  const NotABackupFile();

  @override
  String get code => 'restore.not_a_backup';
}

/// The envelope's own shape is newer than this build understands.
final class UnsupportedFormat extends RestoreFailure {
  /// Creates the failure with the version the file claims.
  const UnsupportedFormat(this.fileFormatVersion);

  /// What the file said.
  final int fileFormatVersion;

  @override
  String get code => 'restore.unsupported_format';

  @override
  List<Object?> get props => <Object?>[fileFormatVersion];
}

/// The payload was written by a newer version of the app.
///
/// **Refused, never guessed.** This is what stops somebody on an old build
/// from silently mangling data a new one wrote — the failure mode where the
/// app looks like it worked and two years of history quietly lost a column.
final class NewerThanApp extends RestoreFailure {
  /// Creates the failure with both schema versions.
  const NewerThanApp({required this.fileSchema, required this.appSchema});

  /// The schema the file was written from.
  final int fileSchema;

  /// The schema this build reads.
  final int appSchema;

  @override
  String get code => 'restore.newer_than_app';

  @override
  List<Object?> get props => <Object?>[fileSchema, appSchema];
}

/// The payload's bytes do not match the digest in the header.
final class CorruptedBackup extends RestoreFailure {
  /// Creates the failure.
  const CorruptedBackup();

  @override
  String get code => 'restore.corrupted';
}

/// A row could not be read, naming where.
///
/// The table AND the line, because "the backup is malformed" is not something
/// anybody can act on, and the line number is what makes a support
/// conversation possible at all.
final class MalformedPayload extends RestoreFailure {
  /// Creates the failure at [table] and [line].
  const MalformedPayload({
    required this.table,
    required this.line,
    required this.detail,
  });

  /// Which table the row belonged to.
  final String table;

  /// Which line of the file, 1-based, counting the header.
  final int line;

  /// What was wrong.
  final String detail;

  @override
  String get code => 'restore.malformed_payload';

  @override
  List<Object?> get props => <Object?>[table, line, detail];
}

/// The staged database could not be put in place.
///
/// The live database is byte-unchanged when this is returned: the rollback set
/// is restored before it is.
final class PublishFailed extends RestoreFailure {
  /// Creates the failure with what went wrong.
  const PublishFailed(this.reason);

  /// For a log — never shown to the reader.
  final String reason;

  @override
  String get code => 'restore.publish_failed';

  @override
  List<Object?> get props => <Object?>[reason];
}
