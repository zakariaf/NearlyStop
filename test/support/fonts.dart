/// Loads the bundled faces into the test binding.
library;

import 'package:flutter/services.dart';

/// The families and asset paths declared in `pubspec.yaml`.
///
/// Kept in step with the pubspec by `test/theme/font_bundling_test.dart`, which
/// reads the manifest rather than trusting this list.
const Map<String, String> bundledFonts = <String, String>{
  'Nunito': 'assets/fonts/Nunito-VariableFont_wght.ttf',
  'Vazirmatn': 'assets/fonts/Vazirmatn-VariableFont_wght.ttf',
};

/// Registers every bundled face with the test binding.
///
/// Widget tests render with Ahem unless the real faces are loaded, and Ahem's
/// uniform metrics make a width measurement prove nothing.
Future<void> loadAppFonts() async {
  for (final MapEntry(key: family, value: asset) in bundledFonts.entries) {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }
}
