/// A capped, rotating, **local** crash log.
///
/// `SPEC.md` §5.3 bans any crash SDK that phones home, and rule 1 of this
/// project makes that the premise rather than a preference. So the entire
/// diagnostics story is a file the user could open and read themselves: no
/// Sentry, no Crashlytics, no queue waiting for a network.
///
/// **Pure Dart, on purpose.** `check_core_purity` keeps `lib/core/` free of
/// Flutter, and `FlutterErrorDetails` is a Flutter type — so this takes a plain
/// `(error, stack, context)` and the adaptation happens at the installation
/// site in `lib/app/bootstrap.dart`, which may import Flutter. That also keeps
/// this testable at the cheapest tier.
///
/// **Nothing here throws.** It is called from inside `FlutterError.onError`,
/// where an exception replaces a reportable crash with an unreportable one, so
/// every failure comes back as a [Result].
library;

import 'dart:convert';
import 'dart:io';

import 'package:nearlystop/core/result.dart';

/// Why a diagnostics write could not be completed.
final class DiagnosticsFailure extends Failure {
  /// Records the underlying [cause].
  const DiagnosticsFailure(this.cause);

  /// The original error. Never rendered to a user.
  final Object cause;

  @override
  String get code => 'diagnostics.write_failed';

  @override
  List<Object?> get props => <Object?>[cause];
}

/// Appends crash records to a bounded local file.
class CrashSink {
  /// Creates a sink writing under [directory].
  ///
  /// Both caps are enforced, and both are needed: [maxRecords] alone lets one
  /// 2MB stack trace fill the disk of a phone that is already misbehaving, and
  /// [maxBytes] alone lets a flood of tiny records push out the one that
  /// mattered.
  CrashSink({
    required this.directory,
    this.maxRecords = 50,
    this.maxBytes = 64 * 1024,
  });

  /// Where the log lives. Injected so tests never touch the real app support
  /// directory.
  final String directory;

  /// How many records to keep. The oldest are dropped first.
  final int maxRecords;

  /// The hard ceiling on the file's size.
  final int maxBytes;

  /// The log file itself.
  File get file => File('$directory/diagnostics.log');

  /// Appends one record, dropping the oldest to stay inside both caps.
  Result<void, DiagnosticsFailure> record(
    Object error,
    StackTrace? stack, {
    String? context,
  }) {
    try {
      final kept = <String>[..._existing(), _encode(error, stack, context)];
      file.writeAsStringSync(_trimmed(kept).join('\n'));
      return const Ok(null);
    } on Object catch (cause) {
      // An unwritable directory, a full disk, a permission change. The caller
      // is an error handler; it has nowhere to report this to and must not
      // make things worse.
      return Err(DiagnosticsFailure(cause));
    }
  }

  /// Every record currently in the log, oldest first.
  ///
  /// An absent file is an empty log, not an error: the common case is a user
  /// who has never crashed.
  List<String> readAll() {
    try {
      return _existing();
    } on Object {
      return const <String>[];
    }
  }

  List<String> _existing() {
    if (!file.existsSync()) return <String>[];
    return file
        .readAsStringSync()
        .split('\n')
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// One record, one line.
  ///
  /// A stack is multi-line by nature, so its newlines are escaped rather than
  /// written — otherwise counting records means parsing them, and the rotation
  /// below could not tell a record from a stack frame.
  String _encode(Object error, StackTrace? stack, String? context) {
    final parts = <String, String>{
      'context': ?context,
      'error': error.toString(),
      'stack': ?stack?.toString(),
    };
    return jsonEncode(parts);
  }

  /// The tail of [records] that fits inside both caps.
  List<String> _trimmed(List<String> records) {
    var kept = records.length > maxRecords
        ? records.sublist(records.length - maxRecords)
        : records;
    // Drop from the front until the joined file fits. The newest record is
    // the one worth keeping; if even that exceeds the cap it is truncated
    // rather than dropped, because an over-long record is still evidence.
    while (kept.length > 1 && _bytes(kept) > maxBytes) {
      kept = kept.sublist(1);
    }
    if (kept.length == 1 && _bytes(kept) > maxBytes) {
      kept = <String>[
        utf8.decode(
          utf8.encode(kept.single).sublist(0, maxBytes),
          allowMalformed: true,
        ),
      ];
    }
    return kept;
  }

  int _bytes(List<String> records) => utf8.encode(records.join('\n')).length;
}
