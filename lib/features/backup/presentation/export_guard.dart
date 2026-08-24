/// "Export before anything destructive", as a code path.
library;

import 'package:flutter/widgets.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/features/shared/presentation/widgets/confirm_sheet.dart';

/// How a guarded destruction ended.
enum ExportGuardOutcome {
  /// Nothing happened. The reader dismissed or cancelled.
  cancelled,

  /// The backup was written and the destruction ran.
  exportedThenDestroyed,

  /// The reader chose to proceed without a backup, and it ran.
  destroyedWithoutBackup,

  /// The export failed, so **nothing was destroyed**.
  exportFailed,
}

/// Offers a backup before running something that cannot be undone.
///
/// SPEC §5.3 as a code path rather than a habit. Used by delete-plan and by
/// replace-all restore — the two operations that can lose two years — on top of
/// EPIC-07's shared confirm sheet, never a fourth private dialog.
///
/// **A failed export destroys nothing.** Somebody who chose "export first"
/// chose it because they wanted the backup; proceeding without one is the
/// opposite of what they asked for, and a guard that does it anyway is a
/// formality with a progress spinner.
///
/// Three exits, not two and a pre-action: choosing to export is also choosing
/// to proceed, so "export first" has to close the sheet. That is what
/// [ConfirmRequest.alternateLabel] was added for.
Future<ExportGuardOutcome> showExportGuard({
  required BuildContext context,
  required ConfirmRequest request,
  required String exportLabel,
  required Future<Result<void, Failure>> Function() onExport,
  required Future<void> Function() onConfirmed,
}) async {
  final choice = await showConfirmSheet(
    context,
    ConfirmRequest(
      title: request.title,
      body: request.body,
      // The PRIMARY action keeps the reader's data. The destructive one is
      // still available, one step less prominent.
      confirmLabel: exportLabel,
      alternateLabel: request.confirmLabel,
      cancelLabel: request.cancelLabel,
      content: request.content,
      isDestructive: false,
    ),
  );

  switch (choice) {
    case ConfirmResult.cancelled:
      return ExportGuardOutcome.cancelled;
    case ConfirmResult.alternate:
      await onConfirmed();
      return ExportGuardOutcome.destroyedWithoutBackup;
    case ConfirmResult.confirmed:
      final exported = await onExport();
      if (exported is Err<void, Failure>) {
        return ExportGuardOutcome.exportFailed;
      }
      await onConfirmed();
      return ExportGuardOutcome.exportedThenDestroyed;
  }
}
