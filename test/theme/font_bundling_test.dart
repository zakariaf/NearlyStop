// The fonts ship INSIDE the binary, with their licences registered.
//
// `google_fonts` is banned and already refused by tool/check_bans.sh: it opens
// an HTTP path in an app whose store listing claims none. These assertions are
// about the other half — that the faces we bundle are actually there, actually
// variable, and actually licensed in the app's own licenses page.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlystop/bootstrap.dart';

import '../support/fonts.dart';

void main() {
  test('both faces are declared and loadable', () async {
    for (final asset in bundledFonts.values) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });

  testWidgets('weight actually MOVES the variable face', (tester) async {
    // A measurement, not a picture. A fontWeight with no matching declared
    // asset renders identically at every weight, and a golden baselined
    // against that defect passes forever. Nunito's default instance is
    // wght 200, so this is the test that catches every heading rendering
    // ExtraLight.
    double widthAt(String family, FontWeight weight) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Prednisolone 9mg',
          style: TextStyle(
            fontFamily: family,
            fontSize: 40,
            fontWeight: weight,
            fontVariations: <FontVariation>[
              FontVariation('wght', weight.value.toDouble()),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    for (final family in bundledFonts.keys) {
      expect(
        widthAt(family, FontWeight.w800),
        greaterThan(widthAt(family, FontWeight.w400)),
        reason: '$family does not respond to the wght axis',
      );
    }
  });

  test(
    'the OFL text is registered, so the licenses page is not a lie',
    () async {
      registerFontLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      for (final family in bundledFonts.keys) {
        final entry = entries.where((e) => e.packages.contains(family));
        expect(entry, isNotEmpty, reason: '$family has no licence entry');
        final text = entry.first.paragraphs.map((p) => p.text).join('\n');
        expect(text, contains('SIL Open Font License'), reason: family);
        expect(text.length, greaterThan(500), reason: family);
      }
    },
  );
}
