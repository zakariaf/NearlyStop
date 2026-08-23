/// Loads the bundled faces into the test binding.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

/// The families and asset paths declared in `pubspec.yaml`.
///
/// Kept in step with the pubspec by `test/theme/font_bundling_test.dart`, which
/// reads the manifest rather than trusting this list. This is the APP's own
/// faces; [loadAppFonts] loads more than these (see below).
const Map<String, String> bundledFonts = <String, String>{
  'Nunito': 'assets/fonts/Nunito-VariableFont_wght.ttf',
  'Vazirmatn': 'assets/fonts/Vazirmatn-VariableFont_wght.ttf',
};

/// Registers every face in the bundle with the test binding.
///
/// Widget tests render with Ahem unless the real faces are loaded, and Ahem's
/// uniform metrics make a width measurement prove nothing.
///
/// **Driven by `FontManifest.json`, not by [bundledFonts]**, because the
/// manifest also carries `MaterialIcons` — which this app leans on hard. Every
/// state word has a glyph beside it precisely because colour is not allowed to
/// be the only channel, and an unloaded icon font renders every codepoint as
/// the same tofu box: nothing throws, no test fails, and a golden happily
/// baselines the box. `fonts_test.dart` asserts two different icons do not
/// rasterise identically, which is the only way that failure is visible.
Future<void> loadAppFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest) {
    final family = entry as Map<String, dynamic>;
    final loader = FontLoader(family['family'] as String);
    for (final font in family['fonts'] as List<dynamic>) {
      loader.addFont(
        rootBundle.load((font as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
  }
}
