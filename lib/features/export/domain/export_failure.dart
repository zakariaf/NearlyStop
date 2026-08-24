/// Why a doctor's export did not happen.
library;

import 'package:nearlystop/core/result.dart';

/// The typed failures the export surface switches on.
sealed class ExportFailure extends Failure {
  /// Creates the failure.
  const ExportFailure();
}

/// There is no plan, or no day has elapsed yet.
///
/// **Its own type, not a write failure.** "Nothing to export yet" is a
/// sentence somebody can act on; "the file could not be made" for the same
/// state teaches a person on day one that the app is broken.
final class NothingToExport extends ExportFailure {
  /// Creates the failure.
  const NothingToExport();

  @override
  String get code => 'export.nothing_yet';
}

/// The file could not be written or rendered.
final class ExportWriteFailed extends ExportFailure {
  /// Creates the failure with what went wrong.
  const ExportWriteFailed(this.reason);

  /// For a log — never shown to the reader.
  final String reason;

  @override
  String get code => 'export.write_failed';

  @override
  List<Object?> get props => <Object?>[reason];
}
