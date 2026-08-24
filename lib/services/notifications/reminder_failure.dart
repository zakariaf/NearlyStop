/// Why a reminder could not be armed.
library;

import 'package:nearlystop/core/result.dart';

/// A reminder that did not get set up. Typed, never thrown at the UI.
sealed class ReminderFailure extends Failure {
  /// Creates the failure.
  const ReminderFailure();
}

/// The reader has not allowed notifications.
///
/// Distinct from [SchedulingRefused] because the answer is different: this one
/// is a sentence explaining where to turn them on, and the toggle goes back to
/// off because the setting could not take effect.
final class PermissionDenied extends ReminderFailure {
  /// Creates the failure.
  const PermissionDenied();

  @override
  String get code => 'reminder.permission_denied';
}

/// The platform refused to arm it.
///
/// Leaves the pending set in whatever state it reached; the next reconcile
/// repairs it, which is what makes the reconcile safe to call on every resume.
final class SchedulingRefused extends ReminderFailure {
  /// Creates the failure with what the platform said.
  const SchedulingRefused(this.reason);

  /// What the platform said, for a log — never shown to the reader.
  final String reason;

  @override
  String get code => 'reminder.scheduling_refused';

  @override
  List<Object?> get props => <Object?>[reason];
}
