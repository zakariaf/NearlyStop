// The Schedule suite's own rules.
//
// `testing-strategy` rule 10 bans `pumpAndSettle` on a screen with an
// indefinite animation, because the call either hangs or returns immediately
// and neither outcome tests anything. **The rule is about the animation, not
// about the call**, so this file asserts the premise instead of the symptom:
// nothing in this feature animates for ever. The Schedule's loading state is a
// static skeleton with no shimmer, so `pumpAndSettle` here terminates — and
// banning it outright would push every suite onto hand-counted `pump()`s for
// no gain.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  List<File> dartFilesIn(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('nothing in the feature animates indefinitely', () {
    // `repeat()` on an `AnimationController`, or a `Ticker` nobody stops, is
    // what makes a settle meaningless. There is none, and this is what keeps
    // it that way.
    final sources = dartFilesIn('lib/features/schedule');
    expect(sources, isNotEmpty);
    for (final file in sources) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('.repeat(')),
        reason: '${file.path} animates for ever, so a settle proves nothing',
      );
    }
  });

  test('every suite in the directory is a real test file', () {
    // A file that ends up in `test/features/schedule/` without a `main` is a
    // suite that silently never runs. Support files live under `support/`.
    final suites = dartFilesIn(
      'test/features/schedule',
    ).where((file) => !file.path.contains('/support/'));
    expect(suites, isNotEmpty);
    for (final file in suites) {
      expect(
        file.readAsStringSync(),
        contains('void main('),
        reason: '${file.path} is in the suite directory and runs nothing',
      );
    }
  });

  test('the suite has no leftover scratch files', () {
    // Probes written to chase a defect are how a directory grows a file that
    // prints instead of asserting.
    // This file names the needle, so it excludes itself — the alternative is
    // a needle spelled in pieces, which is worse.
    final suites = dartFilesIn(
      'test/features/schedule',
    ).where((file) => !file.path.endsWith('suite_hygiene_test.dart'));
    for (final file in suites) {
      expect(
        file.readAsStringSync(),
        isNot(contains('avoid_print')),
        reason: '${file.path} still prints',
      );
      expect(
        file.path,
        isNot(contains('zz_')),
        reason: '${file.path} is a scratch file',
      );
    }
  });
}
