// A local crash log, and nothing else.
//
// `SPEC.md` §5.3 bans any crash SDK that phones home, so the whole diagnostics
// story is a capped file the user could read themselves. That makes the sink's
// failure modes ours to get right: it runs from inside `FlutterError.onError`,
// so a throw here replaces a reportable crash with an unreportable one.
//
// Pure `package:test`: the sink is under `lib/core/`, which `check_core_purity`
// keeps free of Flutter. `FlutterErrorDetails` is adapted at the installation
// site in `lib/app/bootstrap.dart`, not here.
import 'dart:io';

import 'package:nearlystop/core/diagnostics/crash_sink.dart';
import 'package:nearlystop/core/result.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('nearlystop_cs'));
  tearDown(() => directory.deleteSync(recursive: true));

  CrashSink sinkWith({int maxRecords = 50, int maxBytes = 64 * 1024}) =>
      CrashSink(
        directory: directory.path,
        appVersion: '1.0.0+1',
        platform: 'test',
        maxRecords: maxRecords,
        maxBytes: maxBytes,
      );

  test('a record round-trips as one line, stack included', () {
    // One line per record: a multi-line stack in the middle of the file makes
    // the rotation below unable to count records without parsing them.
    final sink = sinkWith()
      ..record(
        StateError('bad state'),
        StackTrace.fromString('#0 first\n#1 second\n#2 third'),
        context: 'while opening the database',
      );

    final lines = sink.readAll();
    expect(lines, hasLength(1));
    expect(lines.single, isNot(contains('\n')));
    expect(lines.single, contains('bad state'));
    expect(lines.single, contains('while opening the database'));
    expect(lines.single, contains('#0 first'));
    expect(lines.single, contains('#2 third'));
  });

  test('a null stack and a null context are legal', () {
    final sink = sinkWith()..record(Exception('no stack'), null);

    final lines = sink.readAll();

    expect(lines, hasLength(1));
    expect(lines.single, contains('no stack'));
  });

  test('cap + 1 records leaves exactly cap, with the OLDEST dropped', () {
    final sink = sinkWith(maxRecords: 5);

    for (var i = 0; i < 6; i++) {
      sink.record(StateError('error $i'), null);
    }

    final lines = sink.readAll();
    expect(lines, hasLength(5));
    expect(lines.first, contains('error 1'));
    expect(lines.last, contains('error 5'));
    expect(lines.join(), isNot(contains('error 0')));
  });

  test('the file stays under the byte cap even with huge records', () {
    // A rotation that only counts records is not a cap: one 2MB stack trace
    // fills the user's disk on a phone that is already misbehaving.
    final sink = sinkWith(maxRecords: 1000, maxBytes: 2048);

    for (var i = 0; i < 50; i++) {
      sink.record(StateError('x' * 500), StackTrace.fromString('y' * 500));
    }

    expect(sink.file.lengthSync(), lessThanOrEqualTo(2048));
    expect(sink.readAll(), isNotEmpty);
  });

  test('the byte cap holds when the cut lands mid-character', () {
    // `utf8.decode(..., allowMalformed: true)` turns a half-written 3-byte
    // character into U+FFFD, which is itself 3 bytes — so slicing the encoded
    // bytes at exactly `maxBytes` can re-encode to MORE than `maxBytes`. Two
    // of this app's four locales are Perso-Arabic, so every character in a
    // Persian error message is 2 bytes and this is the ordinary case, not an
    // exotic one.
    final sink = sinkWith(maxRecords: 1000, maxBytes: 300)
      ..record(StateError('خطای پایگاه داده ' * 40), null);

    expect(sink.file.lengthSync(), lessThanOrEqualTo(300));
  });

  test('the byte cap holds at EVERY cut position', () {
    // Swept rather than sampled: whether the cut lands mid-character depends
    // on the cap, and one lucky cap proves nothing about the others.
    for (var cap = 120; cap <= 200; cap++) {
      final directory = Directory.systemTemp.createTempSync('nearlystop_cut');
      addTearDown(() => directory.deleteSync(recursive: true));
      CrashSink(
        directory: directory.path,
        appVersion: '1.0.0+1',
        platform: 'test',
        maxRecords: 1000,
        maxBytes: cap,
      ).record(StateError('میلی‌گرم ' * 60), null);

      expect(
        File('${directory.path}/diagnostics.log').lengthSync(),
        lessThanOrEqualTo(cap),
        reason: 'overshot at maxBytes = $cap',
      );
    }
  });

  test('truncation cuts on a character boundary, losing no byte to U+FFFD', () {
    // The truncated record is the only evidence left of the crash. A tail of
    // replacement characters is evidence destroyed, and in Persian — where
    // every character is two bytes — that is most of the last line.
    final sink = sinkWith(maxRecords: 1000, maxBytes: 151)
      ..record(StateError('میلی‌گرم ' * 60), null);

    final written = sink.file.readAsStringSync();
    expect(written, isNot(contains('\uFFFD')));
    expect(sink.file.lengthSync(), lessThanOrEqualTo(151));
  });

  test('an unwritable directory FAILS, it does not throw', () {
    // This runs from inside `FlutterError.onError`. A throw here turns a
    // reportable crash into an unreportable one, and the app loses the only
    // record of why it died.
    final sink = CrashSink(
      directory: '${directory.path}/does/not/exist',
      appVersion: '1.0.0+1',
      platform: 'test',
      maxRecords: 10,
      maxBytes: 1024,
    );

    final result = sink.record(StateError('nowhere to write'), null);

    expect(result, isA<Err<void, DiagnosticsFailure>>());
  });

  test('a successful write reports Ok', () {
    final sink = sinkWith();

    expect(
      sink.record(StateError('fine'), null),
      isA<Ok<void, DiagnosticsFailure>>(),
    );
  });

  test('reading a log that does not exist yet is empty, not a throw', () {
    expect(sinkWith().readAll(), isEmpty);
  });

  test('the log survives a new sink over the same directory', () {
    // The user relaunches after a crash; the record of it has to still be
    // there.
    sinkWith().record(StateError('before'), null);

    expect(sinkWith().readAll().single, contains('before'));
  });

  test('nothing in the sink reaches a network', () {
    // The premise of the product, asserted where the temptation lives: a crash
    // reporter is the single most likely place for a "just send it" to appear.
    final source = File(
      'lib/core/diagnostics/crash_sink.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('HttpClient')));
    expect(source, isNot(contains('Socket')));
    expect(source, isNot(contains('package:http')));
  });
}
