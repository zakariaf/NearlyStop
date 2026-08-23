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
///
/// **The steady-state write is an append.** `FlutterError.onError` can fire
/// once per frame — a throwing `build` method does exactly that — and a sink
/// that read, re-joined and rewrote the whole log every time would put O(n)
/// synchronous I/O on the UI isolate at frame rate, in an app that is already
/// in trouble. The kept records and their byte lengths are held in memory, so
/// the common path appends one line and the file is only rewritten on the
/// frames where rotation actually drops something.
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
  late final File file = File('$directory/diagnostics.log');

  /// The in-memory mirror of the file, oldest first. Null until first touched.
  List<String>? _kept;

  /// The UTF-8 length of each entry in [_kept], same order.
  ///
  /// Held because the rotation below needs byte counts for records it is
  /// deciding whether to drop; re-encoding the survivors once per dropped
  /// record made trimming quadratic in the size of the log.
  List<int>? _keptBytes;

  /// The byte length of the joined file, separators included.
  int _totalBytes = 0;

  /// Appends one record, dropping the oldest to stay inside both caps.
  Result<void, DiagnosticsFailure> record(
    Object error,
    StackTrace? stack, {
    String? context,
  }) {
    try {
      _load();
      final line = _encode(error, stack, context);
      _append(line, utf8.encode(line).length);

      if (_rotate()) {
        // Something was dropped or truncated, so the whole file changes.
        file.writeAsStringSync(_kept!.join('\n'));
      } else if (_kept!.length == 1) {
        // First record: this is also what creates the file.
        file.writeAsStringSync(line);
      } else {
        file.writeAsStringSync('\n$line', mode: FileMode.append);
      }
      return const Ok(null);
    } on Object catch (cause) {
      // An unwritable directory, a full disk, a permission change. The caller
      // is an error handler; it has nowhere to report this to and must not
      // make things worse. The mirror is dropped so the next attempt re-reads
      // rather than appending to a file that may not hold what we think.
      _kept = null;
      _keptBytes = null;
      return Err(DiagnosticsFailure(cause));
    }
  }

  /// Every record currently in the log, oldest first.
  ///
  /// An absent file is an empty log, not an error: the common case is a user
  /// who has never crashed.
  List<String> readAll() {
    try {
      // Deliberately from DISK, not from the mirror: this is also how a test
      // — and a support request — checks that what we believe we wrote is
      // what is actually on the device.
      return _existing();
    } on Object {
      return const <String>[];
    }
  }

  /// Reads the file into the mirror, once.
  void _load() {
    if (_kept != null) return;
    final records = _existing();
    _kept = records;
    _keptBytes = records.map((r) => utf8.encode(r).length).toList();
    _totalBytes = _joinedLength(_keptBytes!, 0);
  }

  void _append(String line, int bytes) {
    _kept!.add(line);
    _keptBytes!.add(bytes);
    _totalBytes += bytes + (_kept!.length > 1 ? 1 : 0);
  }

  /// Brings the mirror inside both caps. True if anything changed.
  bool _rotate() {
    final lengths = _keptBytes!;
    final total = _kept!.length;
    var drop = 0;
    var bytes = _totalBytes;

    // One pass, computing the drop count before mutating: `removeAt(0)` in a
    // loop shifts the whole list per record dropped.
    while (total - drop > maxRecords) {
      bytes -= lengths[drop] + 1;
      drop++;
    }
    while (total - drop > 1 && bytes > maxBytes) {
      bytes -= lengths[drop] + 1;
      drop++;
    }
    if (drop > 0) {
      _kept!.removeRange(0, drop);
      lengths.removeRange(0, drop);
      _totalBytes = bytes;
    }

    // The newest record alone still over the cap is truncated rather than
    // dropped, because an over-long record is still evidence.
    if (_kept!.length == 1 && _totalBytes > maxBytes) {
      final truncated = _truncateToBytes(_kept!.single, maxBytes);
      _kept![0] = truncated;
      lengths[0] = utf8.encode(truncated).length;
      _totalBytes = lengths[0];
      return true;
    }
    return drop > 0;
  }

  /// The longest prefix of [value] that encodes to at most [limit] bytes.
  ///
  /// **Not** `utf8.encode(value).sublist(0, limit)` decoded with
  /// `allowMalformed`. Cutting mid-character leaves a partial sequence that
  /// decodes to U+FFFD, which is itself three bytes — so that slice can
  /// re-encode LONGER than the cap it was supposed to enforce. Two of this
  /// app's four locales are Perso-Arabic, where every character is two bytes,
  /// so this is the ordinary case rather than an exotic one. Measured: a
  /// Persian record under a 120-byte cap wrote 122.
  static String _truncateToBytes(String value, int limit) {
    final bytes = utf8.encode(value);
    if (bytes.length <= limit) return value;
    // `bytes[end]` is the first byte NOT kept. While it is a continuation byte
    // (10xxxxxx) the slice ends mid-character, so step back — at most three
    // times, because a UTF-8 sequence is at most four bytes. Walking back one
    // CHARACTER at a time and re-encoding would be quadratic, and the record
    // that hits this path is the 2MB stack trace.
    var end = limit;
    while (end > 0 && (bytes[end] & 0xC0) == 0x80) {
      end--;
    }
    return utf8.decode(bytes.sublist(0, end));
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
  /// above could not tell a record from a stack frame.
  String _encode(Object error, StackTrace? stack, String? context) {
    final parts = <String, String>{
      'context': ?context,
      'error': error.toString(),
      'stack': ?stack?.toString(),
    };
    return jsonEncode(parts);
  }

  /// The joined length of [lengths] from [from], one separator between each.
  static int _joinedLength(List<int> lengths, int from) {
    var total = 0;
    for (var i = from; i < lengths.length; i++) {
      total += lengths[i] + (i > from ? 1 : 0);
    }
    return total;
  }
}
