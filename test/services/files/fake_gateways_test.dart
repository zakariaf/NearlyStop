// The two ports the export and import flows talk to, and their fakes.
//
// Every test in this epic runs against these fakes with no `MethodChannel`
// mocking anywhere. That only holds if the fakes behave like the platform —
// including failing, which is what makes "a failed export leaves the buttons
// enabled" testable at all.
import 'dart:io';
import 'dart:ui';

import 'package:nearlystop/core/result.dart';
import 'package:nearlystop/services/files/fake_file_picker_gateway.dart';
import 'package:nearlystop/services/files/fake_share_gateway.dart';
import 'package:nearlystop/services/files/file_picker_gateway.dart';
import 'package:nearlystop/services/files/share_gateway.dart';
import 'package:test/test.dart';

void main() {
  group('the share gateway', () {
    test('it records everything the platform would have used', () async {
      final gateway = FakeShareGateway();

      final result = await gateway.shareFile(
        path: '/tmp/nearlystop-backup-2025-04-16.ndjson',
        mimeType: 'application/x-ndjson',
        subject: 'NearlyStop backup',
        originRect: const Rect.fromLTWH(10, 20, 30, 40),
      );

      expect(result, isA<Ok<void, ShareFailure>>());
      expect(gateway.calls, hasLength(1));
      final call = gateway.calls.single;
      expect(call.path, '/tmp/nearlystop-backup-2025-04-16.ndjson');
      expect(call.mimeType, 'application/x-ndjson');
      expect(call.subject, 'NearlyStop backup');
      expect(call.originRect, const Rect.fromLTWH(10, 20, 30, 40));
    });

    test('it can be made to fail', () async {
      // A fake that can never fail makes the whole failure half of this epic
      // untestable — and the failure half is where a person loses two years.
      final gateway = FakeShareGateway()..failure = const ShareCancelled();

      final result = await gateway.shareFile(
        path: '/tmp/x.ndjson',
        mimeType: 'application/x-ndjson',
        subject: 's',
        originRect: Rect.zero,
      );

      expect(result, isA<Err<void, ShareFailure>>());
      expect(
        (result as Err<void, ShareFailure>).failure,
        isA<ShareCancelled>(),
      );
    });

    test('a call with no origin rect is recorded as such', () async {
      // Recorded rather than refused here, so the app-wide assertion in task 1
      // can walk the calls and report WHICH flow forgot. A share sheet with no
      // source rect crashes on iPad, and this is the only place that is
      // checkable off a device.
      final gateway = FakeShareGateway();

      await gateway.shareFile(
        path: '/tmp/x',
        mimeType: 'text/csv',
        subject: 's',
      );

      expect(gateway.calls.single.originRect, isNull);
    });
  });

  group('the file picker gateway', () {
    test('it hands back the file it was given', () async {
      final file = File('/tmp/nearlystop-backup-2025-04-16.ndjson');
      final gateway = FakeFilePickerGateway()..picked = file;

      final result = await gateway.pickBackupFile();

      expect(result, isA<Ok<File, PickFailure>>());
      expect((result as Ok<File, PickFailure>).value.path, file.path);
    });

    test('cancelled and unreadable are DIFFERENT answers', () async {
      // One is the reader changing their mind and needs no message at all; the
      // other is a file they chose on purpose that the app cannot open, and
      // needs to say so. A single `null` would collapse them.
      final gateway = FakeFilePickerGateway()..failure = const PickCancelled();
      expect(
        (await gateway.pickBackupFile() as Err<File, PickFailure>).failure,
        isA<PickCancelled>(),
      );

      gateway.failure = const PickUnreadable('permission denied');
      expect(
        (await gateway.pickBackupFile() as Err<File, PickFailure>).failure,
        isA<PickUnreadable>(),
      );
    });

    test('it records that it was asked', () async {
      final gateway = FakeFilePickerGateway()..failure = const PickCancelled();

      await gateway.pickBackupFile();
      await gateway.pickBackupFile();

      expect(gateway.callCount, 2);
    });
  });

  test(
    'both fakes are bare implements, so a new port method breaks the build',
    () {
      // `implements` with no `noSuchMethod`: a sixth method on either port is a
      // compile error here rather than a silent pass in every test that trusts
      // these.
      expect(FakeShareGateway(), isA<ShareGateway>());
      expect(FakeFilePickerGateway(), isA<FilePickerGateway>());
    },
  );
}
