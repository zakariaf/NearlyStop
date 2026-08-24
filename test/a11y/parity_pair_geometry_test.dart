// A pair whose two halves are different sizes is not a comparison.
//
// `daybreak-visual-parity` rule 6: capture the implementation at the
// reference's own geometry — 390x844 logical, DPR 2, so 780x1688 px. The rule
// exists because `.phone` is a fixed 390x844 box and a capture at any other
// scale compares two different layouts.
//
// It was not being followed. `pumpApp` never set `devicePixelRatio`, so the
// captures inherited the test binding's default of 3 and came out 1170x2532
// against a 780x1688 reference. Laid side by side at their native sizes the app
// half is 50% larger than the half it is being judged against — which is not a
// subtle effect, and it made a real set of spacing defects look like a much
// bigger one. Every measurement taken off that sheet was wrong by half again.
//
// Cheap to assert and impossible to argue with, so it is asserted on the
// committed files rather than left to whoever regenerates them next.
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

/// The reference's geometry: 390x844 logical at DPR 2.
const int kParityWidth = 780;
const int kParityHeight = 1688;

/// Reads a PNG's dimensions out of its IHDR, which is always the first chunk.
({int width, int height}) pngSize(File file) {
  final bytes = file.readAsBytesSync();
  final header = ByteData.sublistView(Uint8List.fromList(bytes), 16, 24);
  return (width: header.getUint32(0), height: header.getUint32(4));
}

void main() {
  final directory = Directory('parity/14-design-review');

  test('the fixture is there, or this file asserts nothing', () {
    expect(directory.existsSync(), isTrue);
    expect(
      directory.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.png'),
      ),
      isNotEmpty,
    );
  });

  final captures = directory.existsSync()
      ? (directory.listSync().whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  for (final file in captures.where((f) => f.path.endsWith('.png'))) {
    final name = file.uri.pathSegments.last;

    test('$name is 780x1688 — the reference geometry', () {
      final size = pngSize(file);

      expect(
        (size.width, size.height),
        (kParityWidth, kParityHeight),
        reason:
            '$name is ${size.width}x${size.height}. Both halves of a parity '
            'pair must be captured at 390x844 logical, DPR 2 — a pair at two '
            'different scales cannot be measured against each other.',
      );
    });
  }

  test('every app capture has the ref it is paired with', () {
    // The other half of the same point: a capture with no counterpart is not
    // evidence of anything, and it is the quiet way a screen drops out of the
    // matrix.
    final names = captures
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.png'))
        .toSet();
    final app = names.where((n) => n.startsWith('app--'));

    for (final capture in app) {
      expect(
        names,
        contains(capture.replaceFirst('app--', 'ref--')),
        reason: '$capture has no reference half',
      );
    }
    expect(app, isNotEmpty);
  });
}
