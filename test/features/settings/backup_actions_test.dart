// Export and import, from the Settings card.
//
// Two claims here are about what the reader SEES when it goes wrong: both
// buttons stay usable, and no exception text reaches the screen. The second is
// made checkable rather than aspirational by seeding a failure whose
// `toString()` carries a sentinel and asserting the sentinel appears nowhere.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/core/settings/app_settings.dart';
import 'package:nearlystop/features/backup/presentation/backup_actions.dart';
import 'package:nearlystop/features/settings/application/settings_controller.dart';
import 'package:nearlystop/features/settings/presentation/settings_screen.dart';
import 'package:nearlystop/features/shared/presentation/widgets/daybreak_buttons.dart';
import 'package:nearlystop/l10n/gen/app_localizations.dart';
import 'package:nearlystop/services/files/fake_file_picker_gateway.dart';
import 'package:nearlystop/services/files/fake_share_gateway.dart';
import 'package:nearlystop/services/files/file_picker_gateway.dart';
import 'package:nearlystop/services/notifications/sync_notifications.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/harness.dart';

void main() {
  setUpAll(initializeDateFormatting);

  late FakeShareGateway share;
  late FakeFilePickerGateway picker;
  late List<String> calls;

  setUp(() {
    share = FakeShareGateway();
    picker = FakeFilePickerGateway();
    calls = <String>[];
  });

  Future<AppLocalizations> pumpSettings(
    WidgetTester tester, {
    Future<Result<File, Failure>> Function()? export,
    Future<Result<void, Failure>> Function()? restore,
  }) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await pumpApp(
      tester,
      const SettingsScreen(),
      overrides: <Override>[
        ...launchOverrides(settings: AppSettings.defaults),
        settingsControllerProvider.overrideWith(_Fixed.new),
        shareGatewayProvider.overrideWithValue(share),
        filePickerGatewayProvider.overrideWithValue(picker),
        backupExportProvider.overrideWithValue(() async {
          calls.add('export');
          return await export?.call() ??
              Ok<File, Failure>(File('/tmp/nearlystop-backup.ndjson'));
        }),
        backupRestoreProvider.overrideWithValue((file) async {
          calls.add('restore');
          return await restore?.call() ?? const Ok<void, Failure>(null);
        }),
        reconcileNotificationsProvider.overrideWithValue(() async {
          calls.add('reconcile');
          return const Ok<void, ReminderFailure>(null);
        }),
      ],
      surfaceSize: const Size(390, 1400),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  Future<void> tapExport(WidgetTester tester, AppLocalizations l10n) async {
    await tester.ensureVisible(
      find.widgetWithText(SecondaryButton, l10n.settingsExport),
    );
    await tester.tap(find.widgetWithText(SecondaryButton, l10n.settingsExport));
    await tester.pumpAndSettle();
  }

  testWidgets('exporting writes a backup and hands it to the share sheet', (
    tester,
  ) async {
    final l10n = await pumpSettings(tester);

    await tapExport(tester, l10n);

    expect(calls, <String>['export']);
    expect(share.calls, hasLength(1));
    expect(share.calls.single.mimeType, 'application/x-ndjson');
  });

  testWidgets('every share carries an origin rect', (tester) async {
    // A share sheet presented without a source rectangle CRASHES on iPad, and
    // this is the only place it is checkable off a device.
    final l10n = await pumpSettings(tester);

    await tapExport(tester, l10n);

    expect(
      share.calls.single.originRect,
      isNotNull,
      reason: 'this flow will crash on iPad',
    );
  });

  testWidgets('a failed export leaves both buttons usable, and says why', (
    tester,
  ) async {
    final l10n = await pumpSettings(
      tester,
      export: () async => const Err<File, Failure>(_Sentinel()),
    );

    await tapExport(tester, l10n);

    for (final label in <String>[l10n.settingsExport, l10n.settingsImport]) {
      expect(
        tester
            .widget<SecondaryButton>(
              find.widgetWithText(SecondaryButton, label),
            )
            .onPressed,
        isNotNull,
        reason: '$label is dead after a failure the reader can retry',
      );
    }
    expect(share.calls, isEmpty);
  });

  testWidgets('no exception text ever reaches the screen', (tester) async {
    // The sentinel makes "no `e.toString()` on a screen" checkable rather than
    // aspirational: it is a string nothing localized would ever contain.
    final l10n = await pumpSettings(
      tester,
      export: () async => const Err<File, Failure>(_Sentinel()),
    );

    await tapExport(tester, l10n);

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(rendered, isNot(contains(_Sentinel.sentinel)));
  });

  testWidgets('a cancelled picker restores nothing, and says nothing', (
    tester,
  ) async {
    // Changing your mind is not an error, and an error toast for a dismissal
    // teaches somebody that the app complains when they touch it.
    picker.failure = const PickCancelled();
    final l10n = await pumpSettings(tester);

    await tester.ensureVisible(
      find.widgetWithText(SecondaryButton, l10n.settingsImport),
    );
    await tester.tap(find.widgetWithText(SecondaryButton, l10n.settingsImport));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(picker.callCount, 1);
  });

  testWidgets('a running export owns its own control, not the whole app', (
    tester,
  ) async {
    // The progress lives ON the button. A modal barrier over a taper app says
    // "you may not look at today's dose while this writes a file", which is
    // the opposite of what somebody reaching for an export wants.
    final gate = Completer<Result<File, Failure>>();
    final l10n = await pumpSettings(tester, export: () => gate.future);
    final barriersBefore = tester
        .widgetList<ModalBarrier>(
          find.byType(ModalBarrier),
        )
        .length;

    await tester.tap(find.widgetWithText(SecondaryButton, l10n.settingsExport));
    await tester.pump();

    expect(
      tester
          .widget<SecondaryButton>(
            find.widgetWithText(SecondaryButton, l10n.settingsExport),
          )
          .busy,
      isTrue,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).length,
      barriersBefore,
      reason: 'the export put a barrier over the app',
    );

    gate.complete(Ok<File, Failure>(File('/tmp/nearlystop-backup.ndjson')));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('importing confirms before it replaces two years', (
    tester,
  ) async {
    // Cancelling at the confirmation performs ZERO restores. Restore is the
    // one operation in this app that can lose a 780-day history.
    picker.picked = File('/tmp/chosen-backup.ndjson');
    final l10n = await pumpSettings(tester);

    await tester.ensureVisible(
      find.widgetWithText(SecondaryButton, l10n.settingsImport),
    );
    await tester.tap(find.widgetWithText(SecondaryButton, l10n.settingsImport));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsRestoreConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l10n.actionCancel));
    await tester.pumpAndSettle();

    expect(calls, isEmpty, reason: 'a cancelled confirmation restored anyway');
  });

  testWidgets('the card says the file is unencrypted plain text', (
    tester,
  ) async {
    // SPEC §5.3's honesty rule, and the store privacy claim depends on it
    // being said where the reader can see it — not only in a policy document.
    final l10n = await pumpSettings(tester);

    expect(find.text(l10n.settingsBackupPlainText), findsOneWidget);
  });

  testWidgets('a restore reconciles the reminders it just replaced', (
    tester,
  ) async {
    // The OS is holding notifications armed from the PRE-restore plan, and the
    // restored settings may have the reminder off, or at a different hour. A
    // restore that leaves them is a phone that pings at 07:00 for a plan its
    // owner no longer has.
    picker.picked = File('/tmp/chosen-backup.ndjson');
    final l10n = await pumpSettings(tester);

    await tester.ensureVisible(
      find.widgetWithText(SecondaryButton, l10n.settingsImport),
    );
    await tester.tap(find.widgetWithText(SecondaryButton, l10n.settingsImport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsRestoreConfirmAction));
    await tester.pumpAndSettle();

    expect(calls, <String>['restore', 'reconcile']);
  });

  test('no NotImplementedYet stub is left in lib/', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('NotImplementedYet'))
        .map((f) => f.path)
        .toList();

    expect(offenders, isEmpty);
  });
}

/// A failure whose `toString()` carries a string nothing else would.
final class _Sentinel extends Failure {
  const _Sentinel();

  /// A string no localized message would ever contain.
  static const String sentinel = 'RAW-EXCEPTION-LEAKED-XY7';

  @override
  String get code => 'test.sentinel';

  @override
  String toString() => sentinel;
}

final class _Fixed extends SettingsController {
  @override
  AppSettings build() => AppSettings.defaults;
}
