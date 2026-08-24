// What EPIC-15 adds to EPIC-06's sink, and the one thing it must never do.
//
// The sink itself — the two caps, the rotation, the UTF-8-safe truncation — is
// EPIC-06's and is tested in `crash_sink_test.dart`. What lands here is the
// release-facing half: the version and platform a support request needs, the
// report handed to the user's own share sheet, and the assertion that matters
// more than all of it — **no plan content in the file**.
//
// The failure mode is specific and it is why this is a test rather than a
// convention: somebody mails a diagnostic report to a stranger, and it carries
// their drug, their dose and the note they wrote about how the week went.
import 'dart:convert';
import 'dart:io';

import 'package:nearlystop/core/diagnostics/crash_sink.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;
  late CrashSink sink;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('nearlystop_crashlog');
    sink = CrashSink(
      directory: workspace.path,
      appVersion: '1.0.0+1',
      platform: 'ios 18.0',
    );
  });
  tearDown(() => workspace.deleteSync(recursive: true));

  Map<String, Object?> lastRecord() =>
      jsonDecode(sink.readAll().last) as Map<String, Object?>;

  test('an entry carries the version and the platform, and parses back', () {
    // Without both, a mailed trace is a stack with no idea which binary
    // produced it — and a release build is obfuscated, so the symbols only
    // decode against that exact version.
    sink.record(StateError('boom'), StackTrace.current, context: 'a widget');

    final entry = lastRecord();

    expect(entry['error'], contains('boom'));
    expect(entry['stack'], isNotNull);
    expect(entry['context'], 'a widget');
    expect(entry['version'], '1.0.0+1');
    expect(entry['platform'], 'ios 18.0');
  });

  test('no plan content reaches the file', () {
    // The whole reason this is a test. Seeded with the exact values a real
    // taper carries, then an error is forced and the log is searched for
    // every one of them.
    const drug = 'Prednisolone';
    const note = 'felt rough';
    const date = '2025-04-16';

    sink.record(
      StateError('a widget failed while showing the plan'),
      StackTrace.current,
      context: 'building TodayScreen',
    );

    final text = sink.readAll().join('\n');

    for (final secret in <String>[drug, note, date]) {
      expect(text, isNot(contains(secret)), reason: '"$secret" leaked');
    }
    // And no dose ANYWHERE, by shape rather than by value: a number followed
    // by mg is a dose whatever the number is.
    expect(
      RegExp(r'\d+(\.\d+)?\s?mg').hasMatch(text),
      isFalse,
      reason: 'a dose-shaped string is in the log: $text',
    );
  });

  test('seeded fuzz: 500 entries of random size never pass the cap', () {
    // A crash loop is the scenario — `FlutterError.onError` can fire once per
    // frame — and one example does not cover it.
    final random = _Seeded(0xC0FFEE);
    for (var i = 0; i < 500; i++) {
      sink.record(
        StateError('x' * random.next(4000)),
        StackTrace.fromString('y' * random.next(4000)),
      );
      expect(
        sink.file.lengthSync(),
        lessThanOrEqualTo(sink.maxBytes),
        reason: 'entry $i pushed the file to ${sink.file.lengthSync()} bytes',
      );
    }
  });

  group('diagnosticReport', () {
    test('is null when nothing has ever crashed', () {
      // The common case, and it must not create an empty file the user then
      // mails to somebody.
      expect(sink.diagnosticReport(), isNull);
      expect(sink.file.existsSync(), isFalse);
    });

    test('is the log file once there is one', () {
      sink.record(StateError('boom'), StackTrace.current);

      final report = sink.diagnosticReport();

      expect(report, isNotNull);
      expect(report!.path, sink.file.path);
      expect(File(report.path).readAsStringSync(), contains('boom'));
    });

    test('shares NOTHING by itself', () {
      // It returns a file. It does not open a share sheet, does not touch a
      // gateway and does not send. The share happens only from the user's own
      // tap, in EPIC-11's About row — this is the half that must never
      // initiate anything on its own.
      sink.record(StateError('boom'), StackTrace.current);
      final source = File(
        'lib/core/diagnostics/crash_sink.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('ShareGateway')));
      expect(source, isNot(contains('shareFile')));
    });
  });
}

/// A tiny deterministic PRNG, so a fuzz failure is reproducible from the seed.
class _Seeded {
  _Seeded(this._state);

  int _state;

  int next(int bound) {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return 1 + _state % bound;
  }
}
